import Foundation
import Testing
@testable import BulbCore

@MainActor private final class MeasurementTime { var value: TimeInterval = 0 }

@Suite @MainActor
struct ControlMeasurementTests {
    @Test func injectedAuthenticationFailureBlocksControlWithoutUsingCredentials() async {
        let bulb = SimulatedBulbController(scenario: .authenticationFailed, latency: .zero)
        let remote = BulbRemote(controller: bulb)
        await remote.activate()
        #expect(remote.status == .setupRequired(.authentication))
        #expect(!remote.canTogglePower)
        #expect(!remote.canSelectBrightness)
        #expect(remote.measurements.readRequests == 1)
        #expect(remote.measurements.writeRequests == 0)
        await #expect(throws: BulbFailure.authentication) { try await bulb.apply(.powerOff) }
        #expect(await bulb.commands.isEmpty)
    }

    @Test func countsActualRequestsAndTimesReadbackFromIdleWithoutDuplicateReset() async {
        let clock = ManualBulbClock()
        let time = MeasurementTime()
        let bulb = GatedBulbController(clock: clock)
        let remote = BulbRemote(controller: bulb, clock: clock, policy: .live,
                                measurementNow: { time.value })
        await remote.refresh()
        remote.resetMeasurements()
        #expect(remote.measurements.readRequests == 0)
        remote.selectBrightness(80)
        // Resetting measurements must retain the scheduler's initial-read spacing.
        await clock.advance(by: 0.9)
        await settleTasks()
        #expect(await bulb.commands.isEmpty)
        await clock.advance(by: 0.1)
        #expect(await eventually { await bulb.writeIDs.count == 1 })
        time.value = 10
        let idle = Task { await remote.commitBrightness() }
        await settleTasks()
        remote.resetMeasurements() // Busy reset must not erase an in-flight request.
        time.value = 10.5
        let duplicateIdle = Task { await remote.commitBrightness() }
        await settleTasks()
        await bulb.releaseWrite(1)
        #expect(await eventually { remote.acceptedRevision == 1 })
        time.value = 11.25
        await clock.advance(by: 1)
        await idle.value
        await duplicateIdle.value
        #expect(remote.measurements.writeRequests == 1)
        #expect(remote.measurements.acceptedWrites == 1)
        #expect(remote.measurements.readRequests == 1)
        #expect(remote.measurements.matchingReadbacks == 1)
        #expect(remote.measurements.lastReadbackDelay == 1.25)
        #expect(remote.measurements.lastResult == "Matching readback")
        time.value = 20
        await remote.commitBrightness()
        #expect(remote.measurements.lastReadbackDelay == 1.25)
        #expect(remote.measurements.writeRequests == 1)
    }

    @Test func obsoleteReadbackCannotMeasureANewerGestureAndInterruptionCannotBecomeSuccess() async {
        let clock = ManualBulbClock()
        let bulb = GatedBulbController(clock: clock)
        let remote = BulbRemote(controller: bulb, clock: clock)
        await remote.refresh()
        await bulb.setGateReads(true)
        remote.selectBrightness(30)
        let idle = Task { await remote.commitBrightness() }
        await settleTasks()
        await clock.advance(by: 0.5)
        #expect(await eventually { await bulb.writeIDs.count == 1 })
        await bulb.releaseWrite(1)
        #expect(await eventually { remote.acceptedRevision == 1 })
        await clock.advance(by: 0.5)
        #expect(await eventually { await bulb.readIDs.count == 2 })
        remote.selectBrightness(90)
        let newerIdle = Task { await remote.commitBrightness() }
        await settleTasks()
        await bulb.releaseRead(2)
        await settleTasks()
        #expect(remote.measurements.matchingReadbacks == 0)
        #expect(remote.measurements.lastReadbackDelay == nil)
        #expect(remote.measurements.lastAction == "Brightness 90%")
        remote.deactivate()
        await idle.value
        await newerIdle.value
        #expect(remote.measurements.lastResult == "Interrupted")
        #expect(remote.measurements.lastReadbackDelay == nil)
    }

    @Test func uncertainWriteCountsAttemptWithoutAcceptanceOrReportedConfirmation() async {
        let clock = ManualBulbClock()
        let bulb = GatedBulbController(clock: clock)
        let remote = BulbRemote(controller: bulb, clock: clock)
        await remote.refresh()
        remote.selectBrightness(80)
        let idle = Task { await remote.commitBrightness() }
        await settleTasks()
        await clock.advance(by: 0.5)
        #expect(await eventually { await bulb.writeIDs.count == 1 })
        await bulb.releaseWrite(1, failure: BulbFailure.uncertainWrite)
        await settleTasks()
        await clock.advance(by: 0.5)
        await idle.value
        #expect(remote.measurements.writeRequests == 1)
        #expect(remote.measurements.acceptedWrites == 0)
        #expect(remote.measurements.readRequests == 2)
        #expect(remote.measurements.matchingReadbacks == 0)
        #expect(remote.measurements.lastReadbackDelay == nil)
        #expect(remote.measurements.lastResult == "Failed or unconfirmed")
    }
}
