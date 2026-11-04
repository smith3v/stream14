import XCTest

@MainActor
final class SetupScreenTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsHonestSetupStatus() throws {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["stream14"].waitForExistence(timeout: 5))
        XCTAssertLessThan(app.frame.width, app.frame.height)
        XCTAssertTrue(app.staticTexts["setupStatus"].exists)
        XCTAssertEqual(app.staticTexts["setupStatus"].label, "Local recording")
        XCTAssertEqual(
            app.staticTexts["setupExplanation"].label,
            "Record camera, microphone and a transparent web overlay. Keep the phone in landscape with the rear camera upright."
        )
        XCTAssertFalse(app.buttons["recordSample"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Setup portrait"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        try app.performAccessibilityAudit()
    }

    func testOverlaySettingsAreAccessibleWithoutStartingCapture() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        let button = app.buttons["testWebOverlay"]
        for _ in 0..<8 {
            if button.isHittable { break }
            app.swipeUp()
        }
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        before.name = "Before opening overlay test"
        before.lifetime = .keepAlways
        add(before)
        XCTAssertTrue(button.isHittable)
        button.tap()
        XCTAssertTrue(app.navigationBars["Overlay"].waitForExistence(timeout: 5))
        let field = app.textFields["overlayURL"]
        for _ in 0..<5 {
            if field.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(field.isHittable)
        XCTAssertTrue(app.buttons["Load overlay"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Overlay settings landscape accessibility XXXL"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        try app.performAccessibilityAudit()
    }

    func testLargestTextRemainsAccessibleInLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()

        let status = app.staticTexts["setupStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        XCTAssertTrue(status.isHittable)

        let explanation = app.staticTexts["setupExplanation"]
        if !explanation.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(explanation.isHittable)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Setup landscape accessibility XXXL"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        try app.performAccessibilityAudit()
    }
}
