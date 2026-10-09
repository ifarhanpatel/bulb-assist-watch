import Foundation

public struct SelectedDevice: Equatable, Sendable, Codable, Identifiable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

public struct DeviceCapabilities: Equatable, Sendable, Codable {
    public let supportsPower: Bool
    public let supportsBrightness: Bool
    public init(supportsPower: Bool, supportsBrightness: Bool) {
        self.supportsPower = supportsPower; self.supportsBrightness = supportsBrightness
    }
    public var isSupported: Bool { supportsPower && supportsBrightness }
}

public protocol BulbDiscovering: Sendable {
    func listDevices() async throws -> [SelectedDevice]
    func capabilities(for device: SelectedDevice) async throws -> DeviceCapabilities
}

/// Only encoded in active messages and device-local Keychain. Never log this value.
public struct ProvisionedConfiguration: Equatable, Sendable, Codable {
    public let revision: UInt64
    public let device: SelectedDevice
    public let apiKey: String
    public init(revision: UInt64, device: SelectedDevice, apiKey: String) {
        self.revision = revision; self.device = device; self.apiKey = apiKey
    }
}

/// Store revisions/tombstones durably as well as the configuration, preventing stale replay after relaunch.
public protocol CredentialStoring: Sendable {
    func load() async throws -> ProvisionedConfiguration?
    func latestRevision() async throws -> UInt64
    func store(_ configuration: ProvisionedConfiguration) async throws
    func delete(revision: UInt64) async throws
}

public enum ProvisioningMessage: Equatable, Sendable, Codable {
    case provision(ProvisionedConfiguration)
    case remove(revision: UInt64)
    case verify(revision: UInt64)
    public var revision: UInt64 {
        switch self {
        case .provision(let configuration): configuration.revision
        case .remove(let revision), .verify(let revision): revision
        }
    }
}

public enum ProvisioningResult: Equatable, Sendable, Codable {
    case persisted
    case removed
    case connected(BulbSnapshot)
    case failed(SetupFailure)
}

public struct ProvisioningAcknowledgement: Equatable, Sendable, Codable {
    public let revision: UInt64
    public let result: ProvisioningResult
    public init(revision: UInt64, result: ProvisioningResult) { self.revision = revision; self.result = result }
}

/// Active messaging only; a persistence reply does not establish direct Watch connectivity.
public protocol ActiveMessageTransport: Sendable {
    func send(_ message: ProvisioningMessage) async throws -> ProvisioningAcknowledgement
}

public enum SetupFailure: Error, Equatable, Sendable, Codable {
    case invalidKey, discovery, unsupportedDevice, unreachableWatch, interrupted, persistence, staleRevision
    case bulb(BulbFailure)
}
