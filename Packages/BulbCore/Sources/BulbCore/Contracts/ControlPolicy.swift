import Foundation

/// A monotonic time source. Adapter cancellation must finish before the next request starts.
public protocol BulbClock: Sendable {
    func now() async -> TimeInterval
    func sleep(for duration: Duration) async throws
}

public struct ContinuousBulbClock: BulbClock {
    private let origin = ContinuousClock.now
    public init() {}
    public func now() async -> TimeInterval {
        let components = origin.duration(to: .now).components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
    public func sleep(for duration: Duration) async throws { try await Task.sleep(for: duration) }
}

public struct RequestPolicy: Equatable, Sendable {
    public let minimumSpacing: Duration
    public let requestTimeout: Duration
    public let confirmationWindow: Duration
    public let maximumConfirmationReads: Int
    public let defaultCooldown: Duration
    public init(minimumSpacing: Duration = .milliseconds(500), requestTimeout: Duration = .seconds(5),
                confirmationWindow: Duration = .seconds(5), maximumConfirmationReads: Int = 2,
                defaultCooldown: Duration = .seconds(5)) {
        self.minimumSpacing = max(.zero, minimumSpacing)
        self.requestTimeout = max(.milliseconds(1), requestTimeout)
        self.confirmationWindow = max(.zero, confirmationWindow)
        self.maximumConfirmationReads = min(2, max(0, maximumConfirmationReads))
        self.defaultCooldown = max(.zero, defaultCooldown)
    }
    public static let simulated = RequestPolicy()
    public static let live = RequestPolicy(minimumSpacing: .seconds(1))
}
