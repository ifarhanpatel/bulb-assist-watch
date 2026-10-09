import Foundation
@testable import BulbCore

/// Entirely synthetic; no provider key, account metadata, or recorded HTTP bodies.
enum TuyaFixtures {
    static let key = "sk-IN-synthetic-fixture"
    static let device = SelectedDevice(id: "synthetic/bulb ?#%雪", name: "Fixture bulb")
    static let date = Date(timeIntervalSince1970: 1_700_000_000)

    static func response(_ result: Any, status: Int = 200, headers: [String: String] = [:]) -> TuyaHTTPResponse {
        TuyaHTTPResponse(statusCode: status, headers: headers,
                         body: try! JSONSerialization.data(withJSONObject: ["success": true, "result": result]))
    }
    static func failure(_ code: Any, headers: [String: String] = [:]) -> TuyaHTTPResponse {
        TuyaHTTPResponse(statusCode: 200, headers: headers, body: try! JSONSerialization.data(withJSONObject:
            ["success": false, "code": code, "msg": "unsafe key and device body: " + key + device.id]))
    }
    static func model(brightness: [String: Any] = ["type": "value", "min": 10, "max": 1000, "step": 1, "scale": 0],
                      powerAccess: String = "rw", modes: [String] = ["white", "colour", "scene", "music"],
                      stringSpec: Bool = false, duplicate: Bool = false) -> TuyaHTTPResponse {
        func spec(_ value: [String: Any]) -> Any {
            stringSpec ? String(decoding: try! JSONSerialization.data(withJSONObject: value), as: UTF8.self) : value
        }
        var properties: [[String: Any]] = [
            ["code": "switch_led", "accessMode": powerAccess, "typeSpec": spec(["type": "bool"])],
            ["code": "bright_value", "accessMode": "rw", "typeSpec": spec(brightness)],
            ["code": "work_mode", "accessMode": "rw", "typeSpec": spec(["type": "enum", "range": modes])],
            ["code": "temp_value", "accessMode": "rw", "typeSpec": ["type": "value"]]
        ]
        if duplicate { properties.append(properties[1]) }
        let model = ["services": [["properties": properties]]]
        let encoded = String(decoding: try! JSONSerialization.data(withJSONObject: model), as: UTF8.self)
        return response(["model": encoded])
    }
    static func detail(raw: Any = 62, power: Any = true, online: Any = true, mode: Any = "white",
                       deviceID: String = device.id) -> TuyaHTTPResponse {
        response(["device_id": deviceID, "online": online,
                  "properties": ["switch_led": power, "bright_value": raw, "work_mode": mode,
                                 "temp_value": 731, "colour_data": "untouched"]])
    }
    static func properties(_ request: URLRequest) throws -> [String: Any] {
        let outer = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let encoded = outer["properties"] as! String
        return try JSONSerialization.jsonObject(with: Data(encoded.utf8)) as! [String: Any]
    }
}

actor TuyaFixtureTransport: TuyaHTTPTransport {
    enum Outcome: Sendable {
        case response(TuyaHTTPResponse)
        case error(URLError.Code)
        case cancelled
        case cancelAndRespond
    }
    private var outcomes: [Outcome]
    private(set) var requests: [URLRequest] = []
    init(_ responses: [TuyaHTTPResponse]) { outcomes = responses.map(Outcome.response) }
    init(outcomes: [Outcome]) { self.outcomes = outcomes }
    func send(_ request: URLRequest) async throws -> TuyaHTTPResponse {
        requests.append(request)
        guard !outcomes.isEmpty else { throw URLError(.badServerResponse) }
        switch outcomes.removeFirst() {
        case .response(let response): return response
        case .error(let code): throw URLError(code, userInfo: [NSURLErrorFailingURLStringErrorKey: "unsafe secret URL"])
        case .cancelled: throw CancellationError()
        case .cancelAndRespond:
            withUnsafeCurrentTask { $0?.cancel() }
            return TuyaFixtures.response([:])
        }
    }
}

actor TuyaCancellationTransport: TuyaHTTPTransport {
    private var count = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func send(_ request: URLRequest) async throws -> TuyaHTTPResponse {
        count += 1
        if count == 1 { return TuyaFixtures.model() }
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
        try await Task.sleep(for: .seconds(30))
        return TuyaFixtures.response([:])
    }
    func waitForOperation() async {
        if count >= 2 { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func requestCount() -> Int { count }
}
