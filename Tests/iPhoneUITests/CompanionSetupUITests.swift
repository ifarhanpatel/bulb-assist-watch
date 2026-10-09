import XCTest
import XCUIAutomation

final class CompanionSetupUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testFixtureProvisionReplacementAndRemoval() {
        let app = launch("--fixture-setup")
        let key = app.secureTextFields["apiKeyField"]
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        key.tap()
        key.typeText("fixture-key")
        app.buttons["discoverDevicesButton"].tap()
        let device = app.buttons["fixture-bulb"]
        XCTAssertTrue(device.waitForExistence(timeout: 5))
        device.tap()
        XCTAssertTrue(app.staticTexts["Ready when\nyou are."].waitForExistence(timeout: 8))
        capture(app, "Fixture setup after direct Watch read")
        app.buttons["connectionSettingsButton"].tap()
        app.buttons["replaceKeyButton"].tap()
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        key.tap()
        key.typeText("replacement-fixture-key")
        app.buttons["discoverDevicesButton"].tap()
        XCTAssertTrue(device.waitForExistence(timeout: 5))
        device.tap()
        XCTAssertTrue(app.staticTexts["API key saved"].waitForExistence(timeout: 8))
        XCTAssertFalse(key.exists)
        capture(app, "Fixture replacement confirmed in connection settings")
        app.buttons["removeConnectionButton"].tap()
        app.buttons["Remove"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Connection removed"].waitForExistence(timeout: 5))
        capture(app, "Fixture acknowledged removal")
    }

    @MainActor func testUnreachableWatchKeepsSetupPending() {
        let app = launch("--fixture-setup", "--fixture-unreachable")
        let key = app.secureTextFields["apiKeyField"]
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        key.tap()
        key.typeText("fixture-key")
        app.buttons["discoverDevicesButton"].tap()
        let device = app.buttons["fixture-bulb"]
        XCTAssertTrue(device.waitForExistence(timeout: 5))
        device.tap()
        XCTAssertTrue(app.staticTexts["Finish on\nyour Watch"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Ready when\nyou are."].exists)
        capture(app, "Pending fixture provisioning while Watch unreachable")
    }

    @MainActor func testInvalidKeyHasActionableError() {
        let app = launch("--fixture-setup")
        let key = app.secureTextFields["apiKeyField"]
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        key.tap()
        key.typeText("invalid key")
        app.buttons["discoverDevicesButton"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Check your API key")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "Invalid key recovery")
    }

    @MainActor private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
