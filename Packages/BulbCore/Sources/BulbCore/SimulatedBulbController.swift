import Foundation

public enum SimulationScenario: String, CaseIterable, Identifiable, Sendable {
    case normal
    case slow
    case offline
    case rejected
    case unconfirmed
    case timedOut
    case rateLimited
    case uncertainWrite
    case authenticationFailed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .normal: "Connected"
        case .slow: "Slow connection"
        case .offline: "Bulb offline"
        case .rejected: "Command rejected"
        case .unconfirmed: "No confirmation"
        case .timedOut: "Connection timeout"
        case .rateLimited: "Rate limited"
        case .uncertainWrite: "Write outcome uncertain"
        case .authenticationFailed: "Invalid key"
        }
    }
}

public actor SimulatedBulbController: BulbControlling {
    private var state: BulbSnapshot
    private var scenario: SimulationScenario
    private let latency: Duration
    public private(set) var commands: [BulbCommand] = []

    public init(
        state: BulbSnapshot = .preview,
        scenario: SimulationScenario = .normal,
        latency: Duration = .milliseconds(180)
    ) {
        self.state = state
        self.scenario = scenario
        self.latency = latency
    }

    public func setScenario(_ scenario: SimulationScenario) {
        self.scenario = scenario
    }

    public func readState() async throws -> BulbSnapshot {
        try await wait()
        if scenario == .timedOut { throw BulbFailure.timedOut }
        if scenario == .rateLimited { throw BulbFailure.rateLimited(retryAfter: 2) }
        if scenario == .authenticationFailed { throw BulbFailure.authentication }
        return BulbSnapshot(
            isOn: state.isOn,
            brightness: state.brightness,
            mode: state.mode,
            isOnline: scenario != .offline
        )
    }

    public func apply(_ command: BulbCommand) async throws {
        try await wait()
        switch scenario {
        case .offline: throw BulbFailure.offline
        case .timedOut: throw BulbFailure.timedOut
        case .rejected: throw BulbFailure.rejected
        case .rateLimited: throw BulbFailure.rateLimited(retryAfter: 2)
        case .authenticationFailed: throw BulbFailure.authentication
        default: break
        }
        commands.append(command)
        if scenario == .unconfirmed { return }

        switch command {
        case .powerOn(let brightness):
            state = BulbSnapshot(
                isOn: true,
                brightness: try brightness.map { try ReportedBrightness(rawValue: $0.rawValue) } ?? state.brightness,
                mode: state.mode
            )
        case .powerOff:
            state = BulbSnapshot(isOn: false, brightness: state.brightness, mode: state.mode)
        case .brightness(let brightness):
            guard state.isOn, state.mode == .white else { throw BulbFailure.rejected }
            state = BulbSnapshot(isOn: true, brightness: try ReportedBrightness(rawValue: brightness.rawValue))
        }
        if scenario == .uncertainWrite { throw BulbFailure.uncertainWrite }
    }

    private func wait() async throws {
        let delay = scenario == .slow ? .milliseconds(1300) : latency
        if delay > .zero { try await Task.sleep(for: delay) }
        try Task.checkCancellation()
    }
}
