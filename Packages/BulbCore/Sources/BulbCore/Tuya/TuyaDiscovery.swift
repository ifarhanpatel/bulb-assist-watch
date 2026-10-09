import Foundation

public struct TuyaDiscovery: BulbDiscovering, CustomStringConvertible, CustomDebugStringConvertible {
    private let client: TuyaClient
    public var description: String { "TuyaDiscovery" }
    public var debugDescription: String { description }

    public init(apiKey: String, transport: any TuyaHTTPTransport = URLSessionTuyaTransport(),
                now: @escaping @Sendable () -> Date = { Date() }) throws {
        client = try TuyaClient(apiKey: apiKey, transport: transport, now: now)
    }

    public func listDevices() async throws -> [SelectedDevice] {
        let result = try await client.request("/v1.0/end-user/devices/all")
        guard let object = result as? [String: Any], let devices = object["devices"] as? [[String: Any]] else {
            throw BulbFailure.unsupportedSchema
        }
        var seen = Set<String>()
        return try devices.map { entry in
            guard let id = entry["device_id"] as? String, !id.isEmpty,
                  let name = entry["name"] as? String, !name.isEmpty, seen.insert(id).inserted else {
                throw BulbFailure.unsupportedSchema
            }
            return SelectedDevice(id: id, name: name)
        }
    }

    public func capabilities(for device: SelectedDevice) async throws -> DeviceCapabilities {
        _ = try await validatedSchema(for: device)
        return DeviceCapabilities(supportsPower: true, supportsBrightness: true)
    }

    /// Validate once at construction. Control operations never hide model or detail reads.
    public func makeController(for device: SelectedDevice) async throws -> TuyaBulbController {
        let schema = try await validatedSchema(for: device)
        return TuyaBulbController(client: client, deviceID: device.id,
                                  devicePath: try TuyaClient.devicePath(device), modes: schema)
    }

    private func validatedSchema(for device: SelectedDevice) async throws -> Set<String> {
        let result = try await client.request(TuyaClient.devicePath(device) + "/model")
        if result is NSNull { throw BulbFailure.missingDevice }
        guard let wrapper = result as? [String: Any],
              let encoded = wrapper["model"] as? String,
              let model = TuyaJSON.object(encoded), let services = model["services"] as? [[String: Any]] else {
            throw BulbFailure.unsupportedSchema
        }
        var controls: [String: [String: Any]] = [:]
        for service in services {
            guard let properties = service["properties"] as? [[String: Any]] else { throw BulbFailure.unsupportedSchema }
            for property in properties {
                guard let code = property["code"] as? String else { throw BulbFailure.unsupportedSchema }
                guard controls[code] == nil else { throw BulbFailure.unsupportedSchema }
                controls[code] = property
            }
        }
        func spec(_ code: String, type: String, writable: Bool) throws -> [String: Any] {
            guard let property = controls[code], let access = property["accessMode"] as? String,
                  writable ? access == "rw" : ["rw", "ro"].contains(access),
                  let value = TuyaJSON.object(property["typeSpec"]), value["type"] as? String == type else {
                throw BulbFailure.unsupportedSchema
            }
            return value
        }
        _ = try spec("switch_led", type: "bool", writable: true)
        let brightness = try spec("bright_value", type: "value", writable: true)
        guard TuyaJSON.integer(brightness["min"]) == 10, TuyaJSON.integer(brightness["max"]) == 1000,
              TuyaJSON.integer(brightness["step"]) == 1, TuyaJSON.integer(brightness["scale"]) == 0 else {
            throw BulbFailure.unsupportedSchema
        }
        let mode = try spec("work_mode", type: "enum", writable: false)
        guard let range = mode["range"] as? [String], range.contains("white"),
              range.allSatisfy({ !$0.isEmpty }), Set(range).count == range.count else {
            throw BulbFailure.unsupportedSchema
        }
        return Set(range)
    }
}
