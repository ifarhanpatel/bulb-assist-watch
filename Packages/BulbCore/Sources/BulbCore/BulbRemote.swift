import Foundation
import Observation

public enum RemoteStatus: Equatable, Sendable {
    case connecting
    case ready
    case updating
    case stale
    case unconfirmed
    case cooldown(until: TimeInterval)
    case setupRequired(BulbFailure)
    case failed(BulbFailure)
}

/// Owns foreground intent, acceptance and reported confirmation independently.
/// One worker owns all adapter operations, including cancellation drain time.
@MainActor @Observable
public final class BulbRemote {
    public let measurements: ControlMeasurements
    public private(set) var reportedState: BulbSnapshot?
    public private(set) var selection: BrightnessSelection?
    public private(set) var status: RemoteStatus = .connecting
    public private(set) var isPowerPending = false
    public private(set) var isBrightnessPending = false
    public private(set) var isReading = false
    public private(set) var requestedRevision = 0
    public private(set) var acceptedRevision: Int?
    public private(set) var reportedRevision: Int?

    private struct Intent {
        let command: BulbCommand
        let revision: Int
    }
    private struct Confirmation {
        let intent: Intent
        let startedAt: TimeInterval
        var reads = 0
    }

    @ObservationIgnored private let controller: any BulbControlling
    @ObservationIgnored private let clock: any BulbClock
    @ObservationIgnored private let policy: RequestPolicy
    @ObservationIgnored private var session = 0
    @ObservationIgnored private var isActive = true
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var pendingBrightness: Intent?
    @ObservationIgnored private var pendingPower: Intent?
    @ObservationIgnored private var lastAccepted: Intent?
    @ObservationIgnored private var activeWrite: Intent?
    @ObservationIgnored private var finalRevision: Int?
    @ObservationIgnored private var confirmation: Confirmation?
    @ObservationIgnored private var needsRead = false
    @ObservationIgnored private var lastRequestStart: TimeInterval?
    @ObservationIgnored private var cooldownUntil: TimeInterval?
    @ObservationIgnored private var operationSession: Int?

    public init(controller: any BulbControlling, clock: any BulbClock = ContinuousBulbClock(),
                policy: RequestPolicy = .simulated,
                measurementNow: @escaping @MainActor @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        measurements = ControlMeasurements(now: measurementNow)
        self.controller = controller
        self.clock = clock
        self.policy = policy
    }

    public var displayedBrightness: Double? {
        selection.map { Double($0.percent) } ?? reportedState?.brightness.percent
    }
    public var crownValue: Double { min(100, max(10, displayedBrightness ?? 62)) }
    private var permitsIntent: Bool { status == .ready || status == .updating }
    public var canSelectBrightness: Bool {
        isActive && reportedState?.isOnline == true && reportedState?.mode == .white
            && !isPowerPending && permitsIntent
    }
    public var canTogglePower: Bool {
        isActive && reportedState?.isOnline == true && !isPowerPending && permitsIntent
            && (reportedState?.isOn == true || !isBrightnessPending)
    }
    public var isBusy: Bool { isReading || isPowerPending || isBrightnessPending }

    public func selectBrightness(_ percent: Double) {
        guard canSelectBrightness, percent.isFinite else { return }
        let value = BrightnessSelection(percent: Int(min(100, max(10, percent.rounded()))))
        guard selection != value else { return }
        measurements.supersede()
        selection = value
        requestedRevision += 1
        finalRevision = nil
        confirmation = nil
        if reportedState?.isOn == true {
            pendingBrightness = Intent(command: .brightness(value), revision: requestedRevision)
            isBrightnessPending = true
            status = .updating
            startWorker()
        }
    }

    public func commitBrightness() async {
        guard canSelectBrightness, reportedState?.isOn == true, let selection else { return }
        measurements.begin(revision: requestedRevision, action: "Brightness \(selection.percent)%")
        finalRevision = requestedRevision
        let command = BulbCommand.brightness(selection)
        let alreadyAccepted = lastAccepted?.command == command && acceptedRevision == requestedRevision
        let alreadyIssued = activeWrite?.command == command && activeWrite?.revision == requestedRevision
        if !alreadyAccepted && !alreadyIssued {
            pendingBrightness = Intent(command: .brightness(selection), revision: requestedRevision)
        }
        isBrightnessPending = true
        status = .updating
        startWorker()
        await worker?.value
    }

    public func togglePower() async {
        guard canTogglePower, let snapshot = reportedState else { return }
        requestedRevision += 1
        let command: BulbCommand = snapshot.isOn ? .powerOff
            : .powerOn(brightness: snapshot.mode == .white ? selection : nil)
        measurements.begin(revision: requestedRevision, action: snapshot.isOn ? "Power off" : "Power on")
        pendingBrightness = nil
        finalRevision = nil
        confirmation = nil
        if snapshot.isOn { selection = nil }
        pendingPower = Intent(command: command, revision: requestedRevision)
        isPowerPending = true
        isBrightnessPending = false
        status = .updating
        startWorker()
        await worker?.value
    }

    /// Reset is observational only: it never changes scheduler history or sends a request.
    public func resetMeasurements() {
        guard !isBusy, worker == nil else { return }
        measurements.reset()
    }

    public func waitUntilIdle() async {
        while let running = worker { await running.value }
    }

    public func deactivateAndWait() async {
        deactivate()
        await waitUntilIdle()
    }

    public func activate() async {
        isActive = true
        await refresh()
    }

    public func deactivate() {
        measurements.interrupted("Interrupted")
        isActive = false
        session += 1
        discardIntents()
        needsRead = false
        selection = nil
        isReading = false
        status = reportedState == nil ? .connecting : .stale
        worker?.cancel()
    }

    /// Explicit refresh also reconciles an uncertain result, without replaying an intent.
    public func refresh() async {
        guard isActive else { return }
        if needsRead || (isReading && operationSession == session && confirmation == nil) {
            await waitUntilIdle()
            return
        }
        let now = await clock.now()
        guard isActive else { return }
        if needsRead || (isReading && operationSession == session && confirmation == nil) {
            await waitUntilIdle()
            return
        }
        if let deadline = cooldownUntil, now < deadline {
            status = .cooldown(until: deadline)
            return
        }
        cooldownUntil = nil
        measurements.interrupted("Refreshed; action discarded")
        discardIntents()
        selection = nil
        needsRead = true
        status = reportedState == nil ? .connecting : .stale
        startWorker()
        // An old cancelled request remains owned until its adapter finishes.
        while let running = worker {
            await running.value
            if needsRead && isActive { startWorker() }
        }
    }

    private func discardIntents() {
        pendingBrightness = nil
        pendingPower = nil
        finalRevision = nil
        confirmation = nil
        lastAccepted = nil
        isPowerPending = false
        isBrightnessPending = false
    }

    private func startWorker() {
        guard worker == nil, isActive else { return }
        let currentSession = session
        worker = Task { [weak self] in
            guard let self else { return }
            await self.run(session: currentSession)
            self.worker = nil
            // Activation can queue a fresh read while an old operation drains.
            if self.isActive && self.needsRead { self.startWorker() }
        }
    }

    private func run(session currentSession: Int) async {
        while isActive && session == currentSession && !Task.isCancelled {
            if confirmation == nil, let finalRevision, let accepted = lastAccepted, finalRevision == accepted.revision {
                let now = await clock.now()
                guard session == currentSession, isActive else { return }
                if self.finalRevision == finalRevision && requestedRevision == accepted.revision {
                    confirmation = Confirmation(intent: accepted, startedAt: now)
                }
            }
            if pendingPower == nil && pendingBrightness == nil && !needsRead && confirmation == nil {
                isBrightnessPending = false
                return
            }
            do {
                // Wait before choosing work: changes during spacing replace the pending value.
                try await waitForSpacing()
                guard isActive, session == currentSession, !Task.isCancelled else { return }
                if let intent = pendingPower ?? pendingBrightness {
                    if pendingPower != nil { pendingPower = nil } else { pendingBrightness = nil }
                    if lastAccepted == nil, !isPowerPending, let reportedState, intent.command.matches(reportedState) {
                        measurements.confirmed(revision: intent.revision, freshRead: false)
                        reportedRevision = intent.revision
                        selection = nil
                        finalRevision = nil
                        isBrightnessPending = false
                        status = .ready
                        continue
                    }
                    if lastAccepted?.command != intent.command {
                        activeWrite = intent
                        try await request(timeout: policy.requestTimeout, session: currentSession, isWrite: true) {
                            try await self.controller.apply(intent.command)
                        }
                        activeWrite = nil
                        guard session == currentSession, isActive else { return }
                    }
                    acceptedRevision = intent.revision
                    lastAccepted = intent
                    if isPowerPending || finalRevision == intent.revision {
                        let now = await clock.now()
                        guard session == currentSession, isActive else { return }
                        if requestedRevision == intent.revision && (isPowerPending || finalRevision == intent.revision) {
                            confirmation = Confirmation(intent: intent, startedAt: now)
                        }
                    }
                    continue
                }
                if needsRead {
                    needsRead = false
                    isReading = true
                    let snapshot = try await request(timeout: policy.requestTimeout, session: currentSession, isWrite: false) {
                        try await self.controller.readState()
                    }
                    guard session == currentSession, isActive else { return }
                    isReading = false
                    reportedState = snapshot
                    reportedRevision = nil
                    status = snapshot.isOnline ? .ready : .failed(.offline)
                    continue
                }
                if var check = confirmation {
                    let now = await clock.now()
                    guard session == currentSession, isActive else { return }
                    guard confirmation?.intent.revision == check.intent.revision,
                          requestedRevision == check.intent.revision,
                          pendingPower == nil, pendingBrightness == nil, !needsRead else { continue }
                    let remaining = min(5, policy.confirmationWindow.seconds) - (now - check.startedAt)
                    guard check.reads < policy.maximumConfirmationReads, remaining > 0 else {
                        finishUnconfirmed()
                        return
                    }
                    check.reads += 1
                    confirmation = check
                    isReading = true
                    let snapshot = try await request(timeout: min(policy.requestTimeout, .seconds(remaining)),
                                                     session: currentSession, isWrite: false, revision: check.intent.revision) {
                        try await self.controller.readState()
                    }
                    guard session == currentSession, isActive else { return }
                    isReading = false
                    reportedState = snapshot
                    reportedRevision = nil
                    // A read already issued cannot complete a newer gesture or queued power-off.
                    guard confirmation?.intent.revision == check.intent.revision,
                          requestedRevision == check.intent.revision else { continue }
                    if check.intent.command.matches(snapshot) {
                        measurements.confirmed(revision: check.intent.revision, freshRead: true)
                        reportedRevision = check.intent.revision
                        selection = nil
                        confirmation = nil
                        finalRevision = nil
                        isPowerPending = false
                        isBrightnessPending = false
                        status = .ready
                    } else if !snapshot.isOnline {
                        measurements.interrupted("Bulb offline")
                        discardIntents()
                        status = .failed(.offline)
                    } else if check.reads >= policy.maximumConfirmationReads {
                        finishUnconfirmed()
                    }
                    continue
                }
                // Intermediate accepted values wait for the next gesture or idle callback.
                isBrightnessPending = false
                return
            } catch {
                activeWrite = nil
                guard session == currentSession, isActive else { return }
                isReading = false
                let wasWrite = lastOperationWasWrite
                let failure = error is CancellationError ? (wasWrite ? BulbFailure.uncertainWrite : .transport)
                    : (error as? BulbFailure ?? .failed)
                if !wasWrite, let operationRevision, operationRevision != requestedRevision {
                    switch failure {
                    case .authentication, .rateLimited, .missingDevice, .unsupportedSchema, .unsupportedBrightness: break
                    default: continue
                    }
                }
                measurements.interrupted("Failed or unconfirmed")
                discardIntents()
                status = .failed(failure)
                switch failure {
                case .rateLimited(let retryAfter):
                    let delay = retryAfter.flatMap { $0.isFinite ? max(0, $0) : nil } ?? policy.defaultCooldown.seconds
                    let until = await clock.now() + delay
                    cooldownUntil = until
                    needsRead = false
                    status = .cooldown(until: until)
                case .authentication, .missingDevice, .unsupportedSchema, .unsupportedBrightness:
                    needsRead = false
                    status = .setupRequired(failure)
                default:
                    if wasWrite && failure.requiresReconciliation {
                        selection = nil
                        status = .unconfirmed
                        needsRead = true
                    } else {
                        needsRead = false
                        status = .failed(failure)
                    }
                }
            }
        }
    }

    private func finishUnconfirmed() {
        measurements.interrupted("Unconfirmed")
        confirmation = nil
        finalRevision = nil
        isPowerPending = false
        isBrightnessPending = false
        status = .unconfirmed
    }

    private func waitForSpacing() async throws {
        guard let start = lastRequestStart else { try Task.checkCancellation(); return }
        while true {
            try Task.checkCancellation()
            let now = await clock.now()
            let remaining = policy.minimumSpacing.seconds - (now - start)
            guard remaining > 0 else { return }
            var wait = remaining
            if pendingPower == nil, pendingBrightness == nil, !needsRead, let check = confirmation {
                let window = min(5, policy.confirmationWindow.seconds) - (now - check.startedAt)
                if window <= 0 || check.reads >= policy.maximumConfirmationReads { return }
                wait = min(wait, window)
            }
            try await clock.sleep(for: .seconds(wait))
            // A new intent can arrive during sleep; it still owes the full request spacing.
        }
    }

    @ObservationIgnored private var lastOperationWasWrite = false
    @ObservationIgnored private var operationRevision: Int?

    /// Timeout cancels the adapter and updates UI immediately, but still drains it.
    /// Structured task-group races would also have to wait for an uncooperative child.
    private func request<Value: Sendable>(timeout: Duration, session currentSession: Int,
                                          isWrite: Bool, revision: Int? = nil,
                                          operation: @escaping @MainActor @Sendable () async throws -> Value) async throws -> Value {
        operationSession = currentSession
        let startedAt = await clock.now()
        try Task.checkCancellation()
        guard session == currentSession, isActive else { throw CancellationError() }
        measurements.requestStarted(isWrite: isWrite)
        lastRequestStart = startedAt
        lastOperationWasWrite = isWrite
        operationRevision = revision
        let state = RequestLifetime()
        let operationTask = Task { try await operation() }
        let timer = Task { [weak self] in
            guard let self else { return }
            do {
                let remaining = timeout.seconds - (await self.clock.now() - startedAt)
                if remaining > 0 { try await self.clock.sleep(for: .seconds(remaining)) }
            } catch { return }
            guard !Task.isCancelled, !state.completed else { return }
            state.timedOut = true
            operationTask.cancel()
            guard self.session == currentSession, self.isActive,
                  revision == nil || revision == self.requestedRevision || isWrite else { return }
            self.measurements.interrupted("Timed out; unconfirmed")
            self.discardIntents()
            self.selection = nil
            self.status = isWrite ? .unconfirmed : .failed(.timedOut)
        }
        let result = await withTaskCancellationHandler {
            await operationTask.result
        } onCancel: {
            timer.cancel()
            operationTask.cancel()
        }
        state.completed = true
        timer.cancel()
        if state.timedOut { throw BulbFailure.timedOut }
        if isWrite, case .success = result { measurements.writeAccepted() }
        try Task.checkCancellation()
        return try result.get()
    }
}

@MainActor private final class RequestLifetime {
    var completed = false
    var timedOut = false
}

extension Duration {
    var seconds: TimeInterval {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
