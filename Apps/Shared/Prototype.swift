import BulbCore
import Foundation

@MainActor
struct Prototype {
    let controller: SimulatedBulbController
    let remote: BulbRemote
    let initialScenario: SimulationScenario

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let scenario = arguments.first { $0.hasPrefix("--scenario=") }
            .flatMap { SimulationScenario(rawValue: String($0.dropFirst("--scenario=".count))) } ?? .normal
        let brightness = arguments.contains("--below-range") ? 10 : 620
        let state = BulbSnapshot(
            isOn: !arguments.contains("--off"),
            brightness: try! ReportedBrightness(rawValue: brightness),
            mode: arguments.contains("--color-mode") ? .other : .white
        )
        controller = SimulatedBulbController(state: state, scenario: scenario)
        remote = BulbRemote(controller: controller)
        initialScenario = scenario
    }
}
