import Foundation

/// A deliberate Crown selection, expressed as a percentage of the maximum command value.
public struct BrightnessSelection: Equatable, Sendable, Codable {
    public let percent: Int
    public var rawValue: Int { percent * 10 }

    public init(percent: Int) {
        self.percent = min(100, max(10, percent))
    }
}

/// Reported brightness may be below the app's selection range. Reading it never clamps it.
public struct ReportedBrightness: Equatable, Sendable, Codable {
    public let rawValue: Int
    public var percent: Double { Double(rawValue) / 10 }

    public init(rawValue: Int) throws {
        guard (10...1000).contains(rawValue) else {
            throw BulbFailure.unsupportedBrightness
        }
        self.rawValue = rawValue
    }
}

public enum BulbMode: Equatable, Sendable, Codable {
    case white
    case other
}

public struct BulbSnapshot: Equatable, Sendable, Codable {
    public let isOn: Bool
    public let brightness: ReportedBrightness
    public let mode: BulbMode
    public let isOnline: Bool
    public let observedAt: Date

    public init(
        isOn: Bool,
        brightness: ReportedBrightness,
        mode: BulbMode = .white,
        isOnline: Bool = true,
        observedAt: Date = Date()
    ) {
        self.isOn = isOn
        self.brightness = brightness
        self.mode = mode
        self.isOnline = isOnline
        self.observedAt = observedAt
    }

    public static var preview: BulbSnapshot {
        // A constant inside the verified range; no device read or credential is involved.
        BulbSnapshot(isOn: true, brightness: try! ReportedBrightness(rawValue: 620))
    }
}

public enum BulbCommand: Equatable, Sendable, Codable {
    case powerOn(brightness: BrightnessSelection?)
    case powerOff
    case brightness(BrightnessSelection)

    public func matches(_ snapshot: BulbSnapshot) -> Bool {
        guard snapshot.isOnline else { return false }
        switch self {
        case .powerOn(let brightness):
            return snapshot.isOn && (brightness == nil || snapshot.brightness.rawValue == brightness?.rawValue)
        case .powerOff:
            return !snapshot.isOn
        case .brightness(let brightness):
            return snapshot.isOn && snapshot.mode == .white && snapshot.brightness.rawValue == brightness.rawValue
        }
    }
}

public enum BulbFailure: Error, Equatable, Sendable, Codable {
    case offline
    case timedOut
    case rejected
    case unsupportedBrightness
    case failed
    case authentication
    case rateLimited(retryAfter: TimeInterval?)
    case missingDevice
    case unsupportedSchema
    case transport
    case uncertainWrite

    /// Only a known rejection permits treating an issued command as unapplied.
    public var requiresReconciliation: Bool {
        switch self {
        case .timedOut, .transport, .uncertainWrite: true
        default: false
        }
    }
}

/// The seam used by the remote and its tests. Applying a command establishes acceptance only.
/// A subsequent matching read is required to show reported confirmation.
public protocol BulbControlling: Sendable {
    func readState() async throws -> BulbSnapshot
    func apply(_ command: BulbCommand) async throws
}
