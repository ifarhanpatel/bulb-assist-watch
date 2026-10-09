import Foundation

public actor TuyaBulbController: BulbControlling, CustomStringConvertible, CustomDebugStringConvertible {
    private let client: TuyaClient
    private let devicePath: String
    private let deviceID: String
    private let modes: Set<String>
    private var lastMode: BulbMode?
    private var lastOnline: Bool?
    public nonisolated var description: String { "TuyaBulbController" }
    public nonisolated var debugDescription: String { description }

    init(client: TuyaClient, deviceID: String, devicePath: String, modes: Set<String>) {
        self.client = client
        self.deviceID = deviceID
        self.devicePath = devicePath
        self.modes = modes
    }

    public func readState() async throws -> BulbSnapshot {
        lastMode = nil
        lastOnline = nil
        let result = try await client.request(devicePath + "/detail")
        if result is NSNull { throw BulbFailure.missingDevice }
        guard let detail = result as? [String: Any], detail["device_id"] as? String == deviceID,
              let online = TuyaJSON.boolean(detail["online"]) else {
            throw BulbFailure.unsupportedSchema
        }
        lastOnline = online
        guard online else { lastMode = nil; throw BulbFailure.offline }
        guard let properties = detail["properties"] as? [String: Any],
              let power = TuyaJSON.boolean(properties["switch_led"]),
              let raw = TuyaJSON.integer(properties["bright_value"]), (10...1000).contains(raw),
              let mode = properties["work_mode"] as? String, modes.contains(mode) else {
            lastMode = nil
            throw BulbFailure.unsupportedSchema
        }
        let mappedMode: BulbMode = mode == "white" ? .white : .other
        lastMode = mappedMode
        return BulbSnapshot(isOn: power, brightness: try ReportedBrightness(rawValue: raw), mode: mappedMode,
                            isOnline: true, observedAt: client.now())
    }

    public func apply(_ command: BulbCommand) async throws {
        try Task.checkCancellation()
        if lastOnline == false { throw BulbFailure.offline }
        var patch: [String: Any] = [:]
        switch command {
        case .powerOff: patch["switch_led"] = false
        case .powerOn(let brightness):
            patch["switch_led"] = true
            if let brightness {
                guard lastMode != nil else { throw BulbFailure.unsupportedSchema }
                if lastMode == .white { patch["bright_value"] = brightness.rawValue }
            }
        case .brightness(let brightness):
            guard lastMode == .white else { throw BulbFailure.unsupportedSchema }
            patch["bright_value"] = brightness.rawValue
        }
        let result = try await client.request(devicePath + "/shadow/properties/issue", properties: patch)
        // A success envelope acknowledges submission, never physical state.
        guard result is [String: Any] else { throw BulbFailure.uncertainWrite }
    }
}
