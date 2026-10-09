import CoreFoundation
import Foundation

/// Bound to one credential. Diagnostics deliberately omit request and response values.
struct TuyaClient: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    private let apiKey: String
    private let host: String
    private let transport: any TuyaHTTPTransport
    let now: @Sendable () -> Date
    var description: String { "TuyaClient" }
    var debugDescription: String { description }

    init(apiKey: String, transport: any TuyaHTTPTransport, now: @escaping @Sendable () -> Date) throws {
        let hosts = ["AY": "openapi.tuyacn.com", "AZ": "openapi.tuyaus.com", "EU": "openapi.tuyaeu.com",
                     "IN": "openapi.tuyain.com", "UE": "openapi-ueaz.tuyaus.com",
                     "WE": "openapi-weaz.tuyaeu.com", "SG": "openapi-sg.iotbing.com"]
        let bytes = Array(apiKey.utf8)
        guard bytes.count > 5, bytes.count <= 4096, apiKey.hasPrefix("sk-"),
              bytes.allSatisfy({ $0 > 32 && $0 < 127 }),
              let host = hosts[String(decoding: bytes[3..<5], as: UTF8.self)] else {
            throw BulbFailure.authentication
        }
        self.apiKey = apiKey
        self.host = host
        self.transport = transport
        self.now = now
    }

    static func devicePath(_ device: SelectedDevice) throws -> String {
        guard !device.id.isEmpty, device.id != ".", device.id != "..",
              let encoded = device.id.addingPercentEncoding(withAllowedCharacters:
                CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")) else {
            throw BulbFailure.missingDevice
        }
        return "/v1.0/end-user/devices/" + encoded
    }

    func request(_ path: String, properties: [String: Any]? = nil) async throws -> Any {
        try Task.checkCancellation()
        // All callers construct paths locally; identifiers are encoded as single segments.
        guard let url = URL(string: "https://" + host + path) else { throw BulbFailure.missingDevice }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = properties == nil ? "GET" : "POST"
        request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let isWrite = properties != nil
        if let properties {
            let inner = try JSONSerialization.data(withJSONObject: properties, options: .sortedKeys)
            request.httpBody = try JSONSerialization.data(withJSONObject:
                ["properties": String(decoding: inner, as: UTF8.self)], options: .sortedKeys)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let response: TuyaHTTPResponse
        do { response = try await transport.send(request) }
        catch {
            if isWrite { throw BulbFailure.uncertainWrite }
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            if (error as? URLError)?.code == .timedOut { throw BulbFailure.timedOut }
            throw BulbFailure.transport
        }
        // Some injected transports may finish after cancellation. Never publish that
        // result as current, and never infer that an issued write was undone.
        if Task.isCancelled {
            if isWrite { throw BulbFailure.uncertainWrite }
            throw CancellationError()
        }
        let retryAfter = retryAfter(response.headers)
        switch response.statusCode {
        case 200..<300: break
        case 401, 403: throw BulbFailure.authentication
        case 404: throw BulbFailure.missingDevice
        case 408: throw isWrite ? BulbFailure.uncertainWrite : BulbFailure.timedOut
        case 429: throw BulbFailure.rateLimited(retryAfter: retryAfter)
        case 500...599: throw isWrite ? BulbFailure.uncertainWrite : BulbFailure.transport
        default: throw BulbFailure.rejected
        }
        guard response.body.count <= 2_000_000,
              let envelope = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              let success = TuyaJSON.boolean(envelope["success"]) else {
            throw isWrite ? BulbFailure.uncertainWrite : BulbFailure.unsupportedSchema
        }
        guard success else {
            let code = (envelope["code"] as? String) ?? TuyaJSON.integer(envelope["code"]).map(String.init)
            switch code {
            case "1010", "10010": throw BulbFailure.authentication
            case "429": throw BulbFailure.rateLimited(retryAfter: retryAfter)
            case "40000901": throw BulbFailure.missingDevice
            case "40000903": throw BulbFailure.unsupportedSchema
            case "500": throw isWrite ? BulbFailure.uncertainWrite : BulbFailure.transport
            default: throw BulbFailure.rejected
            }
        }
        guard let result = envelope["result"] else {
            throw isWrite ? BulbFailure.uncertainWrite : BulbFailure.unsupportedSchema
        }
        return result
    }

    private func retryAfter(_ headers: [String: String]) -> TimeInterval? {
        guard let value = headers.first(where: { $0.key.lowercased() == "retry-after" })?.value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = Double(trimmed), seconds.isFinite, seconds >= 0 { return seconds }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        guard let date = formatter.date(from: trimmed) else { return nil }
        return max(0, date.timeIntervalSince(now()))
    }
}

enum TuyaJSON {
    static func boolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
    static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite, let integer = Int(exactly: number.doubleValue) else { return nil }
        return integer
    }
    static func object(_ value: Any?) -> [String: Any]? {
        if let string = value as? String, let data = string.data(using: .utf8) {
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        return value as? [String: Any]
    }
}
