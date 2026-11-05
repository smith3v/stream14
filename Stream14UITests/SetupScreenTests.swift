import XCTest

@MainActor
final class SetupScreenTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testConfirmedDeletionRemovesOnlyItsFixture() throws {
        let fixtureID = ProcessInfo.processInfo.environment["STREAM14_DELETE_FIXTURE_ID"]
        try XCTSkipUnless(fixtureID != nil, "Seed an isolated Simulator recording fixture first.")
        let app = XCUIApplication()
        app.launch()
        let identifier = "deleteRecording-" + fixtureID!
        let target = app.buttons[identifier]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        let allDeletes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "deleteRecording-"))
        let originalCount = allDeletes.count
        for _ in 0..<16 {
            if target.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(target.isHittable)
        target.tap()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        cancel.tap()
        XCTAssertTrue(target.exists)
        target.tap()
        let confirm = app.buttons["Delete recording"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: target)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(allDeletes.count, originalCount - 1)
    }

    func testDeviceBackgroundFinalizesAndPlaybackOpens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAM14_DEVICE_UI"] == "1",
                          "Opt-in private device camera recording check.")
        let app = XCUIApplication()
        app.launch()
        let open = app.buttons["openExperiment"]
        for _ in 0..<8 {
            if open.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(open.isHittable)
        open.tap()
        let record = app.buttons["recordSample"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: record)
        waitForExpectations(timeout: 10)
        for _ in 0..<8 {
            if record.isHittable { break }
            app.swipeUp()
        }
        record.tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Stop recording"), evaluatedWith: record)
        waitForExpectations(timeout: 5)
        // Allow actual camera and audio samples before an actual Home transition.
        sleep(3)
        XCUIDevice.shared.press(.home)
        sleep(3)
        app.activate()
        XCTAssertTrue(app.buttons["openExperiment"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["recordSample"].exists)
        let play = app.buttons["Play sample"]
        for _ in 0..<12 {
            if play.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(play.isHittable)
        play.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.buttons["Export original sample"].exists)
    }

    func testDeniedCameraShowsSettingsGuidance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAM14_DENIED_PERMISSION_TEST"] == "1",
                          "Run after explicitly revoking Simulator camera permission.")
        let app = XCUIApplication()
        app.launch()
        let open = app.buttons["openExperiment"]
        for _ in 0..<8 {
            if open.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(open.isHittable)
        open.tap()
        let status = app.staticTexts["mediaStatus"]
        let denied = NSPredicate(format: "label CONTAINS %@", "Enable them in Settings")
        expectation(for: denied, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.buttons["recordSample"].exists)
        XCTAssertTrue(app.buttons["openExperiment"].exists)
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
