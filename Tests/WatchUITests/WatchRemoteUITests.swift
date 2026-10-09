import XCTest
import XCUIAutomation

final class WatchRemoteUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testOffDraftIsAppliedByPowerOn() {
        let app = launch("--off")
        let dial = app.descendants(matching: .any)["brightnessDial"].firstMatch
        wait(dial, valueContains: "percent, Off")
        XCUIDevice.shared.rotateDigitalCrown(delta: -0.2)
        wait(dial, valueContains: "percent, Next time")
        let selected = String((dial.value as! String).split(separator: ",")[0])
        XCTAssertEqual(app.buttons["powerButton"].label, "Turn on")
        capture(app, "Off-state local draft")
        app.buttons["powerButton"].tap()
        wait(dial, valueContains: "\(selected), On")
        XCTAssertEqual(app.buttons["powerButton"].label, "Turn off")
        capture(app, "Power-on confirms the draft")
        let poweredOn = dial.value as! String
        XCUIDevice.shared.rotateDigitalCrown(delta: -0.2)
        expectation(for: NSPredicate { _, _ in
            guard let value = dial.value as? String else { return false }
            return value != poweredOn && value.hasSuffix(", On")
        }, evaluatedWith: dial)
        waitForExpectations(timeout: 5)
        capture(app, "Crown control after power-on")

        app.buttons["powerButton"].tap()
        wait(dial, valueContains: "percent, Off")
        XCTAssertEqual(app.buttons["powerButton"].label, "Turn on")
        XCUIDevice.shared.rotateDigitalCrown(delta: -0.2)
        wait(dial, valueContains: "percent, Next time")
        XCTAssertEqual(app.buttons["powerButton"].label, "Turn on")
        capture(app, "Local Crown draft after power-off")
    }

    @MainActor func testOnCrownDimmingConfirmsAfterIdle() {
        let app = launch()
        let dial = app.descendants(matching: .any)["brightnessDial"].firstMatch
        wait(dial, valueContains: "percent, On")
        let initial = dial.value as! String
        XCUIDevice.shared.rotateDigitalCrown(delta: -0.2)
        let changed = NSPredicate { _, _ in
            guard let value = dial.value as? String else { return false }
            return value != initial && value.hasSuffix(", On")
        }
        expectation(for: changed, evaluatedWith: dial)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["powerButton"].isEnabled)
        capture(app, "On-state Crown confirmation")
    }

    @MainActor func testCrownFocusReturnsAfterConnectionDetails() {
        let app = launch()
        let dial = app.descendants(matching: .any)["brightnessDial"].firstMatch
        wait(dial, valueContains: "percent, On")
        app.buttons.matching(identifier: "connectionDetailsButton").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Simulated bulb"].waitForExistence(timeout: 5))
        capture(app, "Connection details")
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.exists, app.debugDescription)
        back.tap()
        wait(dial, valueContains: "percent, On")
        let initial = dial.value as! String
        XCUIDevice.shared.rotateDigitalCrown(delta: -0.2)
        expectation(for: NSPredicate { _, _ in
            guard let value = dial.value as? String else { return false }
            return value != initial && value.hasSuffix(", On")
        }, evaluatedWith: dial)
        waitForExpectations(timeout: 5)
        capture(app, "Crown focus after returning")
    }

    @MainActor func testLargeTextRecoveryActionIsReachable() {
        let app = launch("--scenario=timedOut", "--large-text")
        XCTAssertTrue(app.staticTexts["Connection timed out"].waitForExistence(timeout: 5))
        XCUIDevice.shared.rotateDigitalCrown(delta: 1)
        let action = app.buttons["recoveryButton"]
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: action)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(action.label, "Check status")
        for _ in 0..<4 {
            if action.frame.maxY <= app.frame.maxY - 2 { break }
            XCUIDevice.shared.rotateDigitalCrown(delta: 1)
        }
        XCTAssertLessThanOrEqual(action.frame.maxY, app.frame.maxY - 2)
        capture(app, "Reachable larger-text recovery action")
    }

    @MainActor func testPowerOffDuringSlowDimmingDiscardsQueuedBrightness() {
        let app = launch("--scenario=slow")
        let dial = app.descendants(matching: .any)["brightnessDial"].firstMatch
        wait(dial, valueContains: "percent, On")
        XCUIDevice.shared.rotateDigitalCrown(delta: -0.5)
        let power = app.buttons["powerButton"]
        XCTAssertTrue(power.isEnabled)
        power.tap()
        wait(dial, valueContains: "percent, Off")
        XCTAssertEqual(power.label, "Turn on")
        capture(app, "Power-off follows dimming and discards queued values")
    }

    @MainActor func testCooldownRecoversThroughExplicitRefresh() {
        let app = launch("--scenario=rateLimited")
        XCTAssertTrue(app.staticTexts["Cooling down"].waitForExistence(timeout: 8))
        capture(app, "Rate-limit cooldown")
        app.buttons.matching(identifier: "connectionDetailsButton").firstMatch.tap()
        let picker = app.descendants(matching: .any)["simulationPicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        if !picker.isHittable { XCUIDevice.shared.rotateDigitalCrown(delta: 1) }
        picker.tap()
        let connected = app.descendants(matching: .any)["Connected"].firstMatch
        XCTAssertTrue(connected.waitForExistence(timeout: 5))
        connected.tap()
        app.buttons["Refresh"].firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        let dial = app.descendants(matching: .any)["brightnessDial"].firstMatch
        wait(dial, valueContains: "percent, On")
        capture(app, "Explicit refresh recovers from cooldown")
    }

    @MainActor func testForegroundReadsFreshStateWithoutReplayingOffDraft() {
        let app = launch("--off")
        let dial = app.descendants(matching: .any)["brightnessDial"].firstMatch
        wait(dial, valueContains: "percent, Off")
        XCUIDevice.shared.rotateDigitalCrown(delta: -0.3)
        wait(dial, valueContains: "percent, Next time")
        XCUIDevice.shared.press(.home)
        app.activate()
        wait(dial, valueContains: "62 percent, Off")
        XCTAssertEqual(app.buttons["powerButton"].label, "Turn on")
        capture(app, "Foreground refresh drops interrupted off-state draft")
    }

    @MainActor func testConfiguredLaunchReadsSavedBulbAndHidesSimulation() {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture-watch"]
        app.launch()
        let dial = app.descendants(matching: .any)["brightnessDial"].firstMatch
        wait(dial, valueContains: "62 percent, On")
        app.buttons.matching(identifier: "connectionDetailsButton").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Direct Watch connection"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["simulationPicker"].exists)
        capture(app, "Configured Watch launch with fixture storage")
    }

    @MainActor func testMeasurementsShowPowerReadbackAndResetWithoutChangingTheBulb() {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture-watch"]
        app.launch()
        let dial = app.descendants(matching: .any)["brightnessDial"].firstMatch
        wait(dial, valueContains: "62 percent, On")
        app.buttons["powerButton"].tap()
        wait(dial, valueContains: "62 percent, Off")
        app.buttons.matching(identifier: "connectionDetailsButton").firstMatch.tap()
        let measurements = app.descendants(matching: .any)["measurementsLink"].firstMatch
        XCTAssertTrue(measurements.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            if measurements.isHittable { break }
            XCUIDevice.shared.rotateDigitalCrown(delta: 1)
        }
        measurements.tap()
        XCTAssertTrue(app.staticTexts["Writes: 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["API accepted: 1"].exists)
        let reset = app.buttons["resetMeasurementsButton"]
        for _ in 0..<6 {
            if reset.isHittable { break }
            XCUIDevice.shared.rotateDigitalCrown(delta: 1)
        }
        XCTAssertTrue(reset.isHittable)
        capture(app, "Hardware measurement counters and reset")
        reset.tap()
        for _ in 0..<6 {
            if app.staticTexts["Writes: 0"].isHittable { break }
            XCUIDevice.shared.rotateDigitalCrown(delta: -1)
        }
        XCTAssertTrue(app.staticTexts["Writes: 0"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        wait(dial, valueContains: "62 percent, Off")
        XCTAssertEqual(app.buttons["powerButton"].label, "Turn on")
    }

    @MainActor func testInjectedInvalidKeyShowsReplacementAndBlocksControls() {
        let app = launch("--scenario=authenticationFailed")
        XCTAssertTrue(app.staticTexts["Replace your key"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["powerButton"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["brightnessDial"].exists)
        capture(app, "Injected invalid-key recovery")
    }

    @MainActor private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype"] + arguments
        app.launch()
        return app
    }

    @MainActor private func wait(_ element: XCUIElement, valueContains value: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "value CONTAINS %@", value), evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
