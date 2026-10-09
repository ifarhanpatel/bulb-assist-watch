import Foundation
import Observation

/// Session-only coordinator measurements. Contains no credentials or device metadata.
/// A matching readback measures the service's report, never physical lamp response.
@MainActor @Observable
public final class ControlMeasurements {
    public private(set) var readRequests = 0
    public private(set) var writeRequests = 0
    public private(set) var acceptedWrites = 0
    public private(set) var matchingReadbacks = 0
    public private(set) var lastAction: String?
    public private(set) var lastResult: String?
    public private(set) var lastReadbackDelay: TimeInterval?

    @ObservationIgnored private let now: @MainActor @Sendable () -> TimeInterval
    @ObservationIgnored private var revision: Int?
    @ObservationIgnored private var actionStart: TimeInterval?

    init(now: @escaping @MainActor @Sendable () -> TimeInterval) { self.now = now }

    func begin(revision: Int, action: String) {
        guard self.revision != revision else { return }
        self.revision = revision
        actionStart = now()
        lastAction = action
        lastResult = "Pending"
        lastReadbackDelay = nil
    }

    func supersede() {
        revision = nil
        actionStart = nil
        lastAction = nil
        lastResult = nil
        lastReadbackDelay = nil
    }

    func requestStarted(isWrite: Bool) {
        if isWrite { writeRequests += 1 } else { readRequests += 1 }
    }

    func writeAccepted() { acceptedWrites += 1 }

    func confirmed(revision: Int, freshRead: Bool) {
        if freshRead { matchingReadbacks += 1 }
        guard self.revision == revision else { return }
        if freshRead, let actionStart { lastReadbackDelay = max(0, now() - actionStart) }
        lastResult = freshRead ? "Matching readback" : "Already reported; no write"
        actionStart = nil
    }

    func interrupted(_ result: String) {
        guard actionStart != nil else { return }
        lastResult = result
        actionStart = nil
    }

    func reset() {
        readRequests = 0
        writeRequests = 0
        acceptedWrites = 0
        matchingReadbacks = 0
        supersede()
    }
}
