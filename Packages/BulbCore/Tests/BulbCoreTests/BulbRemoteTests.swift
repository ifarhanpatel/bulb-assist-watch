import Testing
@testable import BulbCore

@Suite @MainActor
struct BulbRemoteTests {
    private func snapshot(isOn: Bool = false, raw: Int = 620, mode: BulbMode = .white) throws -> BulbSnapshot {
        BulbSnapshot(isOn: isOn, brightness: try ReportedBrightness(rawValue: raw), mode: mode)
    }

    @Test(arguments: [(0, 10, 100), (10, 10, 100), (50, 50, 500), (100, 100, 1000), (150, 100, 1000)])
    func selectionsRespectTheUIRange(_ input: Int, _ percent: Int, _ raw: Int) {
        let selection = BrightnessSelection(percent: input)
        #expect(selection.percent == percent)
        #expect(selection.rawValue == raw)
    }

    @Test func openingDoesNotSendACommand() async throws {
        let bulb = SimulatedBulbController(state: try snapshot(raw: 10), latency: .zero)
        let remote = BulbRemote(controller: bulb)
        #expect(!remote.canTogglePower)
        await remote.refresh()
        #expect(remote.displayedBrightness == 1)
        #expect(remote.crownValue == 10)
        #expect(await bulb.commands.isEmpty)
    }

    @Test func crownWhileOffIsOnlyALocalSelection() async throws {
        let bulb = SimulatedBulbController(state: try snapshot(), latency: .zero)
        let remote = BulbRemote(controller: bulb)
        await remote.refresh()
        remote.selectBrightness(35)
        await remote.commitBrightness()
        #expect(remote.displayedBrightness == 35)
        #expect(remote.reportedState?.brightness.rawValue == 620)
        #expect(remote.reportedState?.isOn == false)
        #expect(await bulb.commands.isEmpty)

        await remote.togglePower()
        #expect(await bulb.commands == [.powerOn(brightness: BrightnessSelection(percent: 35))])
        #expect(remote.reportedState?.isOn == true)
        #expect(remote.reportedState?.brightness.rawValue == 350)
        #expect(remote.selection == nil)
    }

    @Test func powerOnWithoutSelectionPreservesBelowRangeBrightness() async throws {
        let bulb = SimulatedBulbController(state: try snapshot(raw: 10), latency: .zero)
        let remote = BulbRemote(controller: bulb)
        await remote.refresh()
        await remote.togglePower()
        #expect(await bulb.commands == [.powerOn(brightness: nil)])
        #expect(remote.displayedBrightness == 1)
    }

    @Test func synchronousCrownBurstCoalescesAndUsesTheFinalValue() async throws {
        let bulb = SimulatedBulbController(state: try snapshot(isOn: true), latency: .zero)
        let remote = BulbRemote(controller: bulb)
        await remote.refresh()
        for value in 10...100 { remote.selectBrightness(Double(value)) }
        #expect(await bulb.commands.isEmpty)
        await remote.commitBrightness()
        await remote.commitBrightness()
        #expect(await bulb.commands == [.brightness(BrightnessSelection(percent: 100))])
        #expect(remote.status == .ready)
        #expect(remote.reportedState?.brightness.rawValue == 1000)
    }

    @Test func acceptedCommandWithStaleReadbackIsUnconfirmed() async throws {
        let bulb = SimulatedBulbController(state: try snapshot(), scenario: .unconfirmed, latency: .zero)
        let remote = BulbRemote(controller: bulb)
        await remote.refresh()
        await remote.togglePower()
        #expect(remote.status == .unconfirmed)
        #expect(!remote.canTogglePower)
        #expect(remote.reportedState?.isOn == false)
        #expect(await bulb.commands.count == 1)
    }

    @Test func offlineDoesNotAllowControl() async {
        let bulb = SimulatedBulbController(scenario: .offline, latency: .zero)
        let remote = BulbRemote(controller: bulb)
        await remote.refresh()
        remote.selectBrightness(35)
        await remote.togglePower()
        #expect(remote.status == .failed(.offline))
        #expect(remote.selection == nil)
        #expect(await bulb.commands.isEmpty)
    }

    @Test func rejectedCommandIsNotShownAsSuccessful() async {
        let bulb = SimulatedBulbController(scenario: .rejected, latency: .zero)
        let remote = BulbRemote(controller: bulb)
        await remote.refresh()
        await remote.togglePower()
        #expect(remote.status == .failed(.rejected))
        #expect(remote.reportedState?.isOn == true)
    }

    @Test func timeoutIsDistinctFromOffline() async {
        let remote = BulbRemote(controller: SimulatedBulbController(scenario: .timedOut, latency: .zero))
        await remote.refresh()
        #expect(remote.status == .failed(.timedOut))
        #expect(remote.reportedState == nil)
    }

    @Test func nonWhiteModeRetainsPowerWithoutBrightness() async throws {
        let bulb = SimulatedBulbController(state: try snapshot(mode: .other), latency: .zero)
        let remote = BulbRemote(controller: bulb)
        await remote.refresh()
        #expect(!remote.canSelectBrightness)
        remote.selectBrightness(35)
        await remote.togglePower()
        #expect(await bulb.commands == [.powerOn(brightness: nil)])
    }

    @Test func invalidNumericInputCannotCrashOrChangeSelection() async {
        let remote = BulbRemote(controller: SimulatedBulbController(latency: .zero))
        await remote.refresh()
        remote.selectBrightness(.nan)
        remote.selectBrightness(.infinity)
        #expect(remote.selection == nil)
        remote.selectBrightness(.greatestFiniteMagnitude)
        #expect(remote.selection?.percent == 100)
    }

    @Test func backgroundingDiscardsTheOffStateDraftWithoutReplay() async throws {
        let bulb = SimulatedBulbController(state: try snapshot(), latency: .zero)
        let remote = BulbRemote(controller: bulb)
        await remote.refresh()
        remote.selectBrightness(35)
        remote.deactivate()
        await remote.activate()
        #expect(remote.selection == nil)
        #expect(remote.displayedBrightness == 62)
        #expect(await bulb.commands.isEmpty)
    }

    @Test func oldPowerResponseCannotChangeAnInactiveSession() async {
        let bulb = SuspendedController()
        let remote = BulbRemote(controller: bulb)
        await remote.refresh()
        let operation = Task { await remote.togglePower() }
        await bulb.waitForCommand()
        remote.deactivate()
        await bulb.releaseCommand()
        await operation.value
        #expect(remote.status == .stale)
        #expect(!remote.isPowerPending)
        #expect(!remote.canTogglePower)
        #expect(await bulb.readCount == 1)
    }

    @Test func unsupportedRawBrightnessIsRejected() {
        #expect(throws: BulbFailure.unsupportedBrightness) { try ReportedBrightness(rawValue: 0) }
        #expect(throws: BulbFailure.unsupportedBrightness) { try ReportedBrightness(rawValue: 1001) }
    }
}

private actor SuspendedController: BulbControlling {
    private var pending: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    private var commandStarted = false
    private(set) var readCount = 0

    func readState() -> BulbSnapshot {
        readCount += 1
        return .preview
    }

    func apply(_ command: BulbCommand) async {
        await withCheckedContinuation { continuation in
            pending = continuation
            commandStarted = true
            observer?.resume()
            observer = nil
        }
    }

    func waitForCommand() async {
        if commandStarted { return }
        await withCheckedContinuation { observer = $0 }
    }

    func releaseCommand() {
        pending?.resume()
        pending = nil
    }
}
