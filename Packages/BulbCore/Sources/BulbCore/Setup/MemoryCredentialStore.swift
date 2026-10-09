/// Fixture storage with the same revision and tombstone rules as device-local storage.
public actor MemoryCredentialStore: CredentialStoring {
    private var configuration: ProvisionedConfiguration?
    private var revision: UInt64

    public init(configuration: ProvisionedConfiguration? = nil, revision: UInt64 = 0) {
        self.configuration = configuration
        self.revision = max(revision, configuration?.revision ?? 0)
    }

    public func load() -> ProvisionedConfiguration? { configuration }
    public func latestRevision() -> UInt64 { revision }

    public func store(_ configuration: ProvisionedConfiguration) throws {
        if configuration.revision == revision, self.configuration == configuration { return }
        guard configuration.revision > revision else { throw SetupFailure.staleRevision }
        self.configuration = configuration
        revision = configuration.revision
    }

    public func delete(revision: UInt64) throws {
        if revision == self.revision, configuration == nil { return }
        guard revision > self.revision else { throw SetupFailure.staleRevision }
        configuration = nil
        self.revision = revision
    }
}

public struct FixtureDiscovery: BulbDiscovering {
    public let devices: [SelectedDevice]
    public let supported: Bool
    public init(devices: [SelectedDevice] = [SelectedDevice(id: "fixture-bulb", name: "Wipro NS9001")], supported: Bool = true) {
        self.devices = devices
        self.supported = supported
    }
    public func listDevices() async throws -> [SelectedDevice] { devices }
    public func capabilities(for device: SelectedDevice) async throws -> DeviceCapabilities {
        guard devices.contains(device) else { throw SetupFailure.discovery }
        return DeviceCapabilities(supportsPower: supported, supportsBrightness: supported)
    }
}
