import Foundation
@testable import BulbCore

actor ManualBulbClock: BulbClock {
    private struct Sleeper {
        let deadline: TimeInterval
        let continuation: CheckedContinuation<Void, any Error>
    }
    private var instant: TimeInterval = 0
    private var sleepers: [UUID: Sleeper] = [:]
    private var cancelled: Set<UUID> = []
    func now() -> TimeInterval { instant }
    func sleep(for duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if cancelled.remove(id) != nil || Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if duration <= .zero {
                    continuation.resume()
                } else {
                    sleepers[id] = Sleeper(deadline: instant + duration.seconds, continuation: continuation)
                }
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }
    private func cancel(_ id: UUID) {
        if let sleeper = sleepers.removeValue(forKey: id) {
            sleeper.continuation.resume(throwing: CancellationError())
        } else { cancelled.insert(id) }
    }
    func advance(by seconds: TimeInterval) {
        instant += seconds
        let ready = sleepers.filter { $0.value.deadline <= instant }
        for (id, sleeper) in ready {
            sleepers.removeValue(forKey: id)
            sleeper.continuation.resume()
        }
    }
    var waitingCount: Int { sleepers.count }
}

/// Deliberately ignores cancellation until the test releases the operation.
/// Reads can capture an old snapshot at request start to model stale responses.
actor GatedBulbController: BulbControlling {
    struct Start: Equatable {
        enum Kind: Equatable { case read; case write(BulbCommand) }
        let kind: Kind
        let at: TimeInterval
    }
    private let clock: ManualBulbClock
    private var state: BulbSnapshot
    private var gateReads = false
    private var writes: [Int: (BulbCommand, CheckedContinuation<Void, any Error>)] = [:]
    private var reads: [Int: (BulbSnapshot, CheckedContinuation<BulbSnapshot, any Error>)] = [:]
    private var active = 0
    private(set) var starts: [Start] = []
    private(set) var completions: [Int] = []
    private(set) var cancellations: [Int] = []
    private(set) var maximumConcurrent = 0
    private(set) var writeIDs: [Int] = []
    private(set) var readIDs: [Int] = []

    init(clock: ManualBulbClock, state: BulbSnapshot = .preview) {
        self.clock = clock
        self.state = state
    }
    func setGateReads(_ value: Bool) { gateReads = value }
    func setState(_ state: BulbSnapshot) { self.state = state }
    private func begin(_ kind: Start.Kind) async -> Int {
        let at = await clock.now()
        let id = starts.count
        starts.append(Start(kind: kind, at: at))
        active += 1
        maximumConcurrent = max(maximumConcurrent, active)
        return id
    }
    private func complete(_ id: Int) { active -= 1; completions.append(id) }
    private func cancelled(_ id: Int) { cancellations.append(id) }
    func readState() async throws -> BulbSnapshot {
        let id = await begin(.read)
        readIDs.append(id)
        defer { complete(id) }
        if !gateReads { return state }
        let captured = state
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { reads[id] = (captured, $0) }
        } onCancel: { Task { await self.cancelled(id) } }
    }
    func apply(_ command: BulbCommand) async throws {
        let id = await begin(.write(command))
        writeIDs.append(id)
        defer { complete(id) }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { writes[id] = (command, $0) }
        } onCancel: { Task { await self.cancelled(id) } }
    }
    func releaseWrite(_ id: Int, failure: (any Error)? = nil, applies: Bool = true) {
        guard let (command, continuation) = writes.removeValue(forKey: id) else { return }
        if applies {
            switch command {
            case .powerOff:
                state = BulbSnapshot(isOn: false, brightness: state.brightness, mode: state.mode)
            case .powerOn(let brightness):
                state = BulbSnapshot(isOn: true, brightness: brightness.map { try! ReportedBrightness(rawValue: $0.rawValue) } ?? state.brightness, mode: state.mode)
            case .brightness(let brightness):
                state = BulbSnapshot(isOn: state.isOn, brightness: try! ReportedBrightness(rawValue: brightness.rawValue), mode: state.mode)
            }
        }
        if let failure { continuation.resume(throwing: failure) }
        else { continuation.resume() }
    }
    func releaseRead(_ id: Int, snapshot: BulbSnapshot? = nil, failure: BulbFailure? = nil) {
        guard let (captured, continuation) = reads.removeValue(forKey: id) else { return }
        if let failure { continuation.resume(throwing: failure) }
        else { continuation.resume(returning: snapshot ?? captured) }
    }
    var commands: [BulbCommand] {
        starts.compactMap { if case .write(let command) = $0.kind { return command }; return nil }
    }
}

@MainActor
func settleTasks() async {
    for _ in 0..<150 { await Task.yield() }
}

@MainActor
func eventually(_ condition: () async -> Bool) async -> Bool {
    for _ in 0..<3000 {
        if await condition() { return true }
        await Task.yield()
    }
    return false
}
