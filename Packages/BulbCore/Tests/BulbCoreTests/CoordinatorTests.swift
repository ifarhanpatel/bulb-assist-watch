import Foundation
import Testing
@testable import BulbCore

@Suite @MainActor
struct CoordinatorTests {
    private func fixture(state: BulbSnapshot = .preview, policy: RequestPolicy = .simulated) async -> (BulbRemote, ManualBulbClock, GatedBulbController) {
        let clock = ManualBulbClock()
        let controller = GatedBulbController(clock: clock, state: state)
        let remote = BulbRemote(controller: controller, clock: clock, policy: policy)
        await remote.refresh()
        return (remote, clock, controller)
    }
    private func tick(_ clock: ManualBulbClock, _ seconds: TimeInterval = 0.5) async {
        await settleTasks()
        await clock.advance(by: seconds)
        await settleTasks()
    }
    private func waitWrites(_ controller: GatedBulbController, _ count: Int) async {
        #expect(await eventually { await controller.writeIDs.count == count })
    }
    private func waitReads(_ controller: GatedBulbController, _ count: Int) async {
        #expect(await eventually { await controller.readIDs.count == count })
    }

    @Test func rapidReversalsEndpointsAndRepeatedIdleDeliverOnlyLatestWithSharedSpacing() async {
        let (remote, clock, bulb) = await fixture(policy: .live)
        remote.selectBrightness(10)
        await tick(clock, 0.9)
        #expect(await bulb.commands.isEmpty)
        await tick(clock, 0.1)
        await waitWrites(bulb, 1)
        #expect(remote.requestedRevision == 1)
        #expect(remote.acceptedRevision == nil)
        for percent in [100.0, 20, 90, 10, 100] { remote.selectBrightness(percent) }
        let idle = Task { await remote.commitBrightness() }
        await settleTasks()
        await bulb.releaseWrite(1)
        await tick(clock, 0.9)
        #expect(await bulb.commands.count == 1)
        await tick(clock, 0.1)
        await waitWrites(bulb, 2)
        #expect(await bulb.commands == [.brightness(.init(percent: 10)), .brightness(.init(percent: 100))])
        await bulb.releaseWrite(2)
        await tick(clock, 1)
        await idle.value
        await remote.commitBrightness()
        #expect(remote.status == .ready)
        #expect(remote.selection == nil)
        #expect(remote.acceptedRevision == 6)
        #expect(remote.reportedRevision == 6)
        #expect(remote.reportedState?.brightness.rawValue == 1000)
        #expect(await bulb.maximumConcurrent == 1)
        let starts = await bulb.starts
        #expect(zip(starts, starts.dropFirst()).allSatisfy { $1.at - $0.at >= 1 })
        #expect(starts.count == 4) // initial read, two writes, final read
    }

    @Test func newGestureSupersedesAnOlderReadWithoutRollbackOrCompletingNewRevision() async {
        let (remote, clock, bulb) = await fixture()
        await bulb.setGateReads(true)
        remote.selectBrightness(30)
        let firstIdle = Task { await remote.commitBrightness() }
        await tick(clock)
        await waitWrites(bulb, 1)
        await bulb.releaseWrite(1)
        await tick(clock)
        await waitReads(bulb, 2)
        remote.selectBrightness(90)
        let finalIdle = Task { await remote.commitBrightness() }
        await settleTasks()
        await bulb.releaseRead(2)
        await settleTasks()
        #expect(remote.displayedBrightness == 90)
        #expect(remote.reportedRevision == nil)
        #expect(remote.status == .updating)
        await tick(clock)
        await waitWrites(bulb, 2)
        await bulb.releaseWrite(3)
        await tick(clock)
        await waitReads(bulb, 3)
        await bulb.releaseRead(4)
        await firstIdle.value
        await finalIdle.value
        #expect(remote.reportedRevision == remote.requestedRevision)
        #expect(remote.displayedBrightness == 90)
        #expect(await bulb.maximumConcurrent == 1)
    }

    @Test func powerOffDropsQueuedDimmingAndBlocksRepeatedTapsAndCrown() async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(40)
        await tick(clock)
        await waitWrites(bulb, 1)
        remote.selectBrightness(100)
        #expect(remote.canTogglePower)
        let off = Task { await remote.togglePower() }
        await settleTasks()
        #expect(remote.isPowerPending)
        remote.selectBrightness(10)
        await remote.togglePower()
        #expect(remote.selection == nil)
        #expect(!remote.canSelectBrightness)
        await bulb.releaseWrite(1)
        await tick(clock)
        await waitWrites(bulb, 2)
        #expect(await bulb.commands == [.brightness(.init(percent: 40)), .powerOff])
        await bulb.releaseWrite(2)
        await tick(clock)
        await off.value
        #expect(remote.reportedState?.isOn == false)
        #expect(remote.status == .ready)
        #expect(await bulb.maximumConcurrent == 1)
    }

    @Test func intermediateFinalValueIsDeduplicatedWhenIdleArrivesLater() async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(80)
        await tick(clock)
        await waitWrites(bulb, 1)
        await bulb.releaseWrite(1)
        await remote.waitUntilIdle()
        #expect(remote.selection?.percent == 80)
        #expect(remote.acceptedRevision == 1)
        #expect(remote.reportedRevision == nil)
        let idle = Task { await remote.commitBrightness() }
        await tick(clock)
        await idle.value
        #expect(await bulb.commands == [.brightness(.init(percent: 80))])
        #expect(remote.status == .ready)
    }

    @Test func failedConfirmationIsLimitedToTwoReadsAndKeepsReportedAcceptanceSeparate() async {
        let (remote, clock, bulb) = await fixture()
        await bulb.setGateReads(true)
        remote.selectBrightness(80)
        let idle = Task { await remote.commitBrightness() }
        await tick(clock)
        await waitWrites(bulb, 1)
        await bulb.releaseWrite(1, applies: false)
        await tick(clock)
        await waitReads(bulb, 2)
        await bulb.releaseRead(2)
        await tick(clock)
        await waitReads(bulb, 3)
        await bulb.releaseRead(3)
        await idle.value
        await tick(clock, 10)
        #expect(await bulb.readIDs.count == 3)
        #expect(remote.acceptedRevision == 1)
        #expect(remote.reportedRevision == nil)
        #expect(remote.status == .unconfirmed)
        #expect(remote.selection?.percent == 80)
        #expect(!remote.canSelectBrightness)
    }

    @Test func overallConfirmationWindowIncludesPacingAndReadTimeout() async {
        let policy = RequestPolicy(minimumSpacing: .seconds(3), requestTimeout: .seconds(5), confirmationWindow: .seconds(5))
        let (remote, clock, bulb) = await fixture(policy: policy)
        await bulb.setGateReads(true)
        remote.selectBrightness(80)
        let idle = Task { await remote.commitBrightness() }
        await tick(clock, 3)
        await waitWrites(bulb, 1)
        await bulb.releaseWrite(1)
        await tick(clock, 3)
        await waitReads(bulb, 2)
        await tick(clock, 2)
        #expect(remote.status == .failed(.timedOut))
        #expect(await eventually { await bulb.cancellations.contains(2) })
        #expect(await bulb.readIDs.count == 2)
        // The adapter ignores cancellation: deadline is shown, but ownership is retained.
        await bulb.releaseRead(2)
        await idle.value
        #expect(remote.status == .failed(.timedOut))
        #expect(await bulb.maximumConcurrent == 1)
    }

    @Test func writeTimeoutStopsQueueAndDrainsBeforeReconciliationWithoutReplay() async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(40)
        await tick(clock)
        await waitWrites(bulb, 1)
        remote.selectBrightness(100)
        let idle = Task { await remote.commitBrightness() }
        await tick(clock, 5)
        #expect(remote.status == .unconfirmed)
        #expect(!remote.canSelectBrightness)
        #expect(await eventually { await bulb.cancellations.contains(1) })
        #expect(await bulb.starts.count == 2)
        #expect(await bulb.maximumConcurrent == 1)
        await bulb.releaseWrite(1)
        await idle.value
        #expect(await bulb.commands == [.brightness(.init(percent: 40))])
        #expect(remote.reportedState?.brightness.rawValue == 400)
        #expect(remote.status == .ready)
        #expect(remote.selection == nil)
        #expect(remote.acceptedRevision == nil)
        #expect(await bulb.readIDs.count == 2)
    }

    @Test func uncertainWriteDiscardsQueuedPowerOffAndReconcilesBeforeFreshAction() async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(40)
        await tick(clock)
        await waitWrites(bulb, 1)
        let off = Task { await remote.togglePower() }
        await settleTasks()
        await bulb.releaseWrite(1, failure: BulbFailure.uncertainWrite)
        await tick(clock)
        await off.value
        #expect(await bulb.commands == [.brightness(.init(percent: 40))])
        #expect(remote.reportedState?.isOn == true)
        #expect(remote.displayedBrightness == 40)
        #expect(remote.status == .ready)
        #expect(!remote.isPowerPending)
    }

    @Test func retryAfterStopsQueueUntilExplicitRefreshAfterDeadline() async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(40)
        await tick(clock)
        await waitWrites(bulb, 1)
        remote.selectBrightness(100)
        await bulb.releaseWrite(1, failure: BulbFailure.rateLimited(retryAfter: 3), applies: false)
        await remote.waitUntilIdle()
        #expect(remote.status == .cooldown(until: 3.5))
        await remote.refresh()
        #expect(await bulb.starts.count == 2)
        await tick(clock, 2.9)
        await remote.refresh()
        #expect(await bulb.starts.count == 2)
        await tick(clock, 0.1)
        await remote.refresh()
        #expect(remote.status == .ready)
        #expect(remote.selection == nil)
        #expect(await bulb.commands.count == 1)
        #expect(await bulb.readIDs.count == 2)
    }

    @Test func interruptionNeverOverlapsAnUncancellableWriteOrReplaysItsQueue() async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(40)
        await tick(clock)
        await waitWrites(bulb, 1)
        remote.selectBrightness(100)
        remote.deactivate()
        let reopen = Task { await remote.activate() }
        await settleTasks()
        #expect(await bulb.starts.count == 2)
        #expect(remote.status == .stale)
        #expect(remote.selection == nil)
        #expect(await eventually { await bulb.cancellations.contains(1) })
        await bulb.releaseWrite(1)
        await tick(clock)
        await reopen.value
        #expect(await bulb.maximumConcurrent == 1)
        #expect(await bulb.commands == [.brightness(.init(percent: 40))])
        #expect(remote.displayedBrightness == 40)
        #expect(remote.status == .ready)
        #expect(remote.acceptedRevision == nil)
    }

    @Test func concurrentActivationAndRefreshCoalesceTheirInitialRead() async {
        let clock = ManualBulbClock()
        let bulb = GatedBulbController(clock: clock)
        await bulb.setGateReads(true)
        let remote = BulbRemote(controller: bulb, clock: clock)
        let first = Task { await remote.activate() }
        await waitReads(bulb, 1)
        let second = Task { await remote.activate() }
        let third = Task { await remote.refresh() }
        await settleTasks()
        await bulb.releaseRead(0)
        await first.value
        await second.value
        await third.value
        #expect(await bulb.readIDs.count == 1)
        #expect(remote.status == .ready)
    }

    @Test func deactivationWaitsForActualDrainBeforeConfigurationReplacement() async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(80)
        await tick(clock)
        await waitWrites(bulb, 1)
        var drained = false
        let invalidate = Task { await remote.deactivateAndWait(); drained = true }
        await settleTasks()
        #expect(!drained)
        await bulb.releaseWrite(1)
        await invalidate.value
        #expect(drained)
        #expect(await bulb.completions == [0, 1])
        #expect(remote.status == .stale)
        #expect(remote.reportedState?.brightness.rawValue == 620)
    }

    @Test func confirmationDeadlineEndsDuringLongSpacingWithoutIssuingARead() async {
        let policy = RequestPolicy(minimumSpacing: .seconds(10), confirmationWindow: .seconds(50))
        let (remote, clock, bulb) = await fixture(policy: policy)
        remote.selectBrightness(80)
        await tick(clock, 10)
        await waitWrites(bulb, 1)
        let idle = Task { await remote.commitBrightness() }
        await settleTasks()
        await bulb.releaseWrite(1)
        await tick(clock, 4.9)
        #expect(remote.status == .updating)
        #expect(await bulb.readIDs.count == 1)
        await tick(clock, 0.1)
        await idle.value
        #expect(remote.status == .unconfirmed)
        #expect(await bulb.readIDs.count == 1)
    }

    @Test func slowWriteKeepsOnlyTheNewestPendingValueAndDoesNotWaitExtraSpacing() async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(10)
        await tick(clock)
        await waitWrites(bulb, 1)
        for percent in [30.0, 70, 20, 90] { remote.selectBrightness(percent) }
        let idle = Task { await remote.commitBrightness() }
        await tick(clock, 2)
        #expect(await bulb.commands.count == 1)
        #expect(remote.displayedBrightness == 90)
        await bulb.releaseWrite(1)
        await waitWrites(bulb, 2)
        #expect(await bulb.starts.last?.at == 2.5)
        #expect(await bulb.commands == [.brightness(.init(percent: 10)), .brightness(.init(percent: 90))])
        await bulb.releaseWrite(2)
        await tick(clock)
        await idle.value
        #expect(remote.status == .ready)
        #expect(await bulb.maximumConcurrent == 1)
    }

    @Test func obsoleteReadTimeoutCannotDiscardANewerGesture() async {
        let (remote, clock, bulb) = await fixture()
        await bulb.setGateReads(true)
        remote.selectBrightness(30)
        let first = Task { await remote.commitBrightness() }
        await tick(clock)
        await waitWrites(bulb, 1)
        await bulb.releaseWrite(1)
        await tick(clock)
        await waitReads(bulb, 2)
        remote.selectBrightness(90)
        let final = Task { await remote.commitBrightness() }
        await tick(clock, 5)
        #expect(remote.status == .updating)
        #expect(remote.selection?.percent == 90)
        #expect(remote.measurements.lastAction == "Brightness 90%")
        #expect(remote.measurements.lastResult == "Pending")
        #expect(await bulb.maximumConcurrent == 1)
        await bulb.releaseRead(2)
        await waitWrites(bulb, 2)
        await bulb.releaseWrite(3)
        await tick(clock)
        await waitReads(bulb, 3)
        await bulb.releaseRead(4)
        await first.value
        await final.value
        #expect(remote.status == .ready)
        #expect(remote.displayedBrightness == 90)
        #expect(remote.measurements.lastResult == "Matching readback")
    }

    @Test func cancelledIssuedWriteReconcilesEvenWhenCoordinatorIsStillActive() async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(80)
        await tick(clock)
        await waitWrites(bulb, 1)
        remote.selectBrightness(30)
        await bulb.releaseWrite(1, failure: CancellationError())
        await tick(clock)
        await remote.waitUntilIdle()
        #expect(remote.status == .ready)
        #expect(remote.displayedBrightness == 80)
        #expect(remote.selection == nil)
        #expect(await bulb.commands.count == 1)
        #expect(await bulb.readIDs.count == 2)
    }

    @Test func absentRetryAfterUsesFallbackAndDoesNotRefreshAutomatically() async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(80)
        await tick(clock)
        await waitWrites(bulb, 1)
        await bulb.releaseWrite(1, failure: BulbFailure.rateLimited(retryAfter: nil), applies: false)
        await remote.waitUntilIdle()
        #expect(remote.status == .cooldown(until: 5.5))
        await tick(clock, 10)
        #expect(await bulb.readIDs.count == 1)
        #expect(remote.status == .cooldown(until: 5.5))
        await remote.refresh()
        #expect(remote.status == .ready)
        #expect(await bulb.commands.count == 1)
    }

    @Test func selectingCurrentReportedBrightnessDoesNotIssueAWrite() async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(62)
        let idle = Task { await remote.commitBrightness() }
        await tick(clock)
        await idle.value
        #expect(await bulb.commands.isEmpty)
        #expect(remote.acceptedRevision == nil)
        #expect(remote.reportedRevision == 1)
        #expect(remote.status == .ready)
    }

    @Test(arguments: [BulbFailure.authentication, .missingDevice, .unsupportedSchema])
    func setupFailuresRequireSetupRatherThanAutomaticReplay(_ failure: BulbFailure) async {
        let (remote, clock, bulb) = await fixture()
        remote.selectBrightness(80)
        await tick(clock)
        await waitWrites(bulb, 1)
        await bulb.releaseWrite(1, failure: failure, applies: false)
        await remote.waitUntilIdle()
        #expect(remote.status == .setupRequired(failure))
        #expect(!remote.canSelectBrightness)
        #expect(!remote.canTogglePower)
        #expect(await bulb.readIDs.count == 1)
    }
}
