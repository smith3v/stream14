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
        XCTAssertEqual(app.staticTexts["setupStatus"].label, "App setup ready")
        XCTAssertEqual(
            app.staticTexts["setupExplanation"].label,
            "This build verifies app setup on your iPhone. Recording and web overlays are not available yet."
        )
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Setup portrait"
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
