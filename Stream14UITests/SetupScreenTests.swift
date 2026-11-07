import XCTest

@MainActor
final class SetupScreenTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDeviceRearLensSelector() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAM14_DEVICE_LENS_UI"] == "1",
                          "Opt-in private device camera recording check.")
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        func reveal(_ element: XCUIElement) {
            let scroll = app.scrollViews.firstMatch
            for _ in 0..<12 {
                let visible = scroll.frame.insetBy(dx: 0, dy: 8)
                let frame = element.frame
                // XCTest can fail the test while querying an offscreen element's
                // activation point after rotation. Scroll it fully into view first.
                if visible.contains(frame), !frame.isEmpty, element.isHittable { return }
                if frame.midY < visible.midY { scroll.swipeDown() }
                else { scroll.swipeUp() }
            }
        }
        XCTAssertFalse(app.buttons["cameraLensSelector"].exists)
        let open = app.buttons["openExperiment"]
        reveal(open)
        XCTAssertTrue(open.isHittable)
        open.tap()
        let selector = app.buttons["cameraLensSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 15))
        reveal(selector)
        XCTAssertTrue(selector.isEnabled)
        XCTAssertEqual(selector.value as? String, "1× · Wide")
        selector.tap()
        let ultraWide = app.buttons["0.5× · Ultra Wide"]
        XCTAssertTrue(ultraWide.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Telephoto"].exists)
        ultraWide.tap()
        expectation(for: NSPredicate(format: "enabled == true AND value == %@", "0.5× · Ultra Wide"), evaluatedWith: selector)
        waitForExpectations(timeout: 10)
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            reveal(selector)
            XCTAssertTrue(selector.isHittable)
            XCTAssertGreaterThanOrEqual(selector.frame.height, 44)
            XCTAssertLessThanOrEqual(selector.frame.height, 64)
            XCTAssertLessThanOrEqual(selector.frame.width, 180)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Ultra Wide selector \(orientation.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        let record = app.buttons["recordSample"]
        reveal(record)
        XCTAssertTrue(record.isEnabled)
        record.tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Stop recording"), evaluatedWith: record)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(selector.isEnabled)
        sleep(3)
        record.tap()
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: selector)
        waitForExpectations(timeout: 10)
        let play = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "playRecording-")).firstMatch
        reveal(play)
        XCTAssertTrue(play.isHittable)
        play.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        let close = app.buttons["Close camera"]
        reveal(close)
        XCTAssertTrue(close.isHittable)
        close.tap()
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["cameraLensSelector"].exists)
        XCTAssertFalse(app.otherElements["cameraPreview"].exists)
        reveal(open)
        open.tap()
        XCTAssertTrue(selector.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "enabled == true AND value == %@", "0.5× · Ultra Wide"), evaluatedWith: selector)
        waitForExpectations(timeout: 10)
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
        let play = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "playRecording-")).firstMatch
        for _ in 0..<12 {
            if play.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(play.isHittable)
        play.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "exportRecording-")).firstMatch.exists)
    }

    func testRecordingActionsAndMetadataLayouts() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["STREAM14_RECORDING_UI_FIXTURE_ID"] != nil,
                          "Seed an isolated Simulator recording fixture first.")
        let id = try XCTUnwrap(environment["STREAM14_RECORDING_UI_FIXTURE_ID"],
                               "Seed an isolated Simulator recording fixture first.")
        let missingID = try XCTUnwrap(environment["STREAM14_RECORDING_UI_MISSING_ID"])
        let app = XCUIApplication()
        defer { XCUIDevice.shared.orientation = .portrait }
        for largeText in [false, true] {
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft, .landscapeRight] {
                app.terminate()
                app.launchArguments = largeText ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []
                XCUIDevice.shared.orientation = orientation
                app.launch()
                let play = app.buttons["playRecording-" + id]
                scrollTo(play, in: app)
                let export = app.buttons["exportRecording-" + id]
                let delete = app.buttons["deleteRecording-" + id]
                let metadata = app.staticTexts["recordingMetadata-" + id]
                XCTAssertTrue(metadata.label.contains("·"))
                XCTAssertFalse(metadata.label.contains("unavailable"))
                for (button, verb) in [(play, "Play recording from"), (export, "Export original recording from"), (delete, "Delete recording from")] {
                    XCTAssertTrue(button.isEnabled)
                    XCTAssertTrue(button.isHittable)
                    XCTAssertTrue(button.label.hasPrefix(verb))
                    XCTAssertGreaterThanOrEqual(button.frame.width, 44)
                    XCTAssertGreaterThanOrEqual(button.frame.height, 44)
                }
                // A fresh launch may still be settling the navigation title height.
                let aligned = NSPredicate { _, _ in
                    let frames = [play, export, delete].map(\.frame)
                    return frames.allSatisfy { abs($0.midY - frames[0].midY) <= 1 }
                }
                expectation(for: aligned, evaluatedWith: app)
                waitForExpectations(timeout: 5)
                let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                screenshot.name = "Recordings \(orientation.rawValue) large text \(largeText)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
                try auditVisibleRecordingContent(in: app)
                let missingPlay = app.buttons["playRecording-" + missingID]
                scrollTo(missingPlay, in: app)
                XCTAssertFalse(missingPlay.isEnabled)
                XCTAssertFalse(app.buttons["exportRecording-" + missingID].isEnabled)
                XCTAssertTrue(app.buttons["deleteRecording-" + missingID].isEnabled)
                XCTAssertTrue(app.staticTexts["recordingMetadata-" + missingID].label.contains("File size unavailable"))
                let privacy = app.descendants(matching: .any).matching(identifier: "privacyPolicy").firstMatch
                scrollTo(privacy, in: app)
                XCTAssertGreaterThan(privacy.frame.minY, missingPlay.frame.maxY)
                let notices = app.buttons["thirdPartyNotices"]
                scrollTo(notices, in: app)
                let footer = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                footer.name = "Footer \(orientation.rawValue) large text \(largeText)"
                footer.lifetime = .keepAlways
                add(footer)
                try auditVisibleRecordingContent(in: app)
            }
        }
    }

    func testRecordingIconPlaybackAndExport() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAM14_RECORDING_UI_FIXTURE_ID"] != nil,
                          "Seed an isolated Simulator recording fixture first.")
        let id = try XCTUnwrap(ProcessInfo.processInfo.environment["STREAM14_RECORDING_UI_FIXTURE_ID"])
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        let play = app.buttons["playRecording-" + id]
        scrollTo(play, in: app)
        play.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let export = app.buttons["exportRecording-" + id]
        scrollTo(export, in: app)
        export.tap()
        XCTAssertTrue(app.cells["Save to Files"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Original recording export"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<24 {
            if element.isHittable { break }
            let viewport = app.scrollViews.firstMatch.frame.intersection(app.frame)
            let distance = max(-viewport.height / 2,
                               min(viewport.height / 2, viewport.midY - element.frame.midY))
            let start = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: viewport.midX, dy: viewport.midY))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
        }
        XCTAssertTrue(element.isHittable)
    }

    private func auditVisibleRecordingContent(in app: XCUIApplication) throws {
        let viewport = app.scrollViews.firstMatch.frame
        // The audit can adjust scrolling before invoking its issue handler. Keep
        // the geometry of the screenshot it is about to inspect, not that later UI.
        let textFrames = app.staticTexts.allElementsBoundByIndex.map { (label: $0.label, frame: $0.frame) }
        try app.performAccessibilityAudit { issue in
            // Scrolling normally clips a line at the viewport edge. The contrast
            // audit can sample that covered text against the fixed WebKit surface.
            // Exempt only that case; fully visible text and every control still audit.
            guard issue.auditType == .contrast, let element = issue.element,
                  element.elementType == .staticText else { return false }
            let matches = textFrames.filter { $0.label == element.label }
            guard matches.count == 1, let frame = matches.first?.frame else { return false }
            return frame.intersects(viewport) && !viewport.contains(frame)
                && frame.minX >= viewport.minX && frame.maxX <= viewport.maxX
        }
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
        // Only standard content padding precedes the heading; no 60-point strip.
        XCTAssertEqual(app.staticTexts["setupStatus"].frame.minY - app.navigationBars["stream14"].frame.maxY,
                       16, accuracy: 2)
        XCTAssertTrue(app.staticTexts["overlayStatus"].exists)
        XCTAssertTrue(app.switches["Hide overlay manually"].exists)
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
        XCTAssertTrue(app.buttons["Apply URL"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Overlay settings landscape accessibility XXXL"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        try app.performAccessibilityAudit()
    }

    func testOverlayDraftIsDiscardedAndInvalidApplyKeepsConfiguration() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["testWebOverlay"].tap()
        let field = app.textFields["overlayURL"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let original = field.value as? String
        app.buttons["Use reference URL"].tap()
        app.buttons["Close overlay settings"].tap()
        app.buttons["testWebOverlay"].tap()
        let draftWasDiscarded = field.value as? String == original
        XCTAssertTrue(draftWasDiscarded)
        field.tap()
        // Select all through the standard editing gesture, then replace with invalid input.
        field.press(forDuration: 1.2)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        else if let value = field.value as? String, !value.isEmpty, value != "HTTPS overlay URL" {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText("http://invalid.example")
        app.buttons["Apply URL"].tap()
        XCTAssertTrue(app.staticTexts["Enter an HTTPS URL without username or password."].waitForExistence(timeout: 3))
        app.buttons["Close overlay settings"].tap()
        app.buttons["testWebOverlay"].tap()
        let invalidWasDiscarded = field.value as? String == original
        XCTAssertTrue(invalidWasDiscarded)
        app.buttons["Close overlay settings"].tap()
        XCTAssertTrue(app.buttons["openExperiment"].exists)
        XCTAssertFalse(app.buttons["recordSample"].exists)
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
