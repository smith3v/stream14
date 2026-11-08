import XCTest

@MainActor
final class SetupScreenTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func auditInterface(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit { issue in
            print("F10 accessibility issue: \(issue.auditType) \(issue.element?.debugDescription ?? "unknown element")")
            return false
        }
    }

    private func fixtureApp(_ state: String = "idle", largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["STREAM14_INTERFACE_FIXTURE"] = state
        app.launchArguments = largeText ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []
        app.launch()
        return app
    }

    func testNativeDestinationsNeverStartCaptureOrPublishing() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp()
        XCTAssertTrue(app.staticTexts["setupStatus"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Session"].tap()
        XCTAssertTrue(app.buttons["openExperiment"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recordSample"].exists)
        XCTAssertFalse(app.buttons["endBroadcast"].exists)
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.staticTexts["Recordings"].exists)
        app.tabBars.buttons["Preparation"].tap()
        app.buttons["testWebOverlay"].tap()
        XCTAssertTrue(app.textFields["overlayURL"].waitForExistence(timeout: 5))
        app.buttons["Close overlay settings"].tap()
        app.tabBars.buttons["Session"].tap()
        XCTAssertTrue(app.buttons["openExperiment"].exists)
        XCTAssertFalse(app.buttons["endBroadcast"].exists)
        scrollTo(app.buttons["goLive"], in: app)
        try auditInterface(app)
    }

    func testPreflightBlockersAndExactPublishingConfirmation() throws {
        XCUIDevice.shared.orientation = .portrait
        for state in ["idle", "overlay-unavailable", "ready"] {
            let app = fixtureApp(state)
            let goLive = app.buttons["goLive"]
            scrollTo(goLive, in: app)
            goLive.tap()
            if state == "ready" {
                let confirm = app.buttons["Go Live — Unlisted"]
                XCTAssertTrue(confirm.waitForExistence(timeout: 5))
                let text = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
                for value in ["Fixture channel", "fixture-channel", "Fixture scheduled match", "Unlisted", "1080p30"] {
                    XCTAssertTrue(text.contains(value), value)
                }
                if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
                else { app.otherElements["PopoverDismissRegion"].tap() }
                XCTAssertFalse(app.buttons["endBroadcast"].exists)
            } else {
                XCTAssertFalse(app.buttons["Go Live — Unlisted"].exists)
                let status = app.staticTexts["broadcastStatus"]
                scrollTo(status, in: app)
                XCTAssertTrue(status.label.contains(state == "idle" ? "Open the camera" : "configured overlay is unavailable"))
            }
            app.terminate()
        }
    }

    func testPersistentFailureStatesAndLockedSettings() throws {
        XCUIDevice.shared.orientation = .portrait
        for (state, expected) in [("reconnecting", "Reconnecting"), ("backup-failed", "Local backup is unavailable"),
                                  ("unknown-end", "YouTube end not confirmed"), ("ended", "ended remotely")] {
            let app = fixtureApp(state)
            app.tabBars.buttons["Session"].tap()
            let status = app.staticTexts["broadcastStatus"]
            scrollTo(status, in: app)
            XCTAssertTrue(status.label.contains(expected))
            XCTAssertTrue(app.staticTexts["uploadStatus"].exists)
            XCTAssertTrue(app.staticTexts["overlayStatus"].exists)
            if state == "unknown-end" {
                XCTAssertTrue(app.buttons["reconcileBroadcast"].exists)
                XCTAssertTrue(app.links["Open YouTube Studio"].exists)
            }
            if state == "backup-failed" {
                let warning = app.staticTexts["backupWarning"]
                scrollTo(warning, in: app)
                XCTAssertTrue(warning.label.contains("Saved footage is retained"))
            }
            if state != "ended" {
                app.buttons["testWebOverlay"].tap()
                XCTAssertTrue(app.textFields["overlayURL"].waitForExistence(timeout: 5))
                XCTAssertFalse(app.textFields["overlayURL"].isEnabled)
                XCTAssertFalse(app.buttons["applyOverlayURL"].isEnabled)
                app.buttons["Close overlay settings"].tap()
            }
            app.terminate()
        }
    }

    func testSessionLayoutsAndManualOverlayAtLargestText() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        for large in [false, true] {
            for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
                XCUIDevice.shared.orientation = orientation
                let app = fixtureApp("ready", largeText: large)
                app.tabBars.buttons["Session"].tap()
                if !large {
                    let preview = app.descendants(matching: .any).matching(identifier: "cameraPreview").firstMatch
                    XCTAssertTrue(preview.waitForExistence(timeout: 5))
                    XCTAssertEqual(preview.frame.width / preview.frame.height, 16.0 / 9.0, accuracy: 0.05)
                }
                let mute = app.buttons["microphoneMute"]
                scrollTo(mute, in: app)
                XCTAssertGreaterThanOrEqual(mute.frame.height, 44)
                let hide = app.buttons["manualOverlayVisibility"]
                scrollTo(hide, in: app)
                let previous = hide.value as? String
                hide.tap()
                XCTAssertNotEqual(hide.value as? String, previous)
                let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                screenshot.name = "Session landscape \(orientation.rawValue) largest text \(large)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
                scrollTo(app.buttons["goLive"], in: app)
                try auditInterface(app)
                app.terminate()
            }
        }
    }

    func testFailedDeletionRetainsRowAndExplainsRetry() throws {
        let identifier = ProcessInfo.processInfo.environment["STREAM14_DELETE_FAILURE_FIXTURE_ID"]
        try XCTSkipUnless(identifier != nil, "Seed a nonregular-artifact Simulator fixture first.")
        let app = fixtureApp()
        app.tabBars.buttons["Recordings"].tap()
        let target = app.buttons["deleteRecording-" + identifier!]
        scrollTo(target, in: app)
        target.tap()
        app.buttons["Delete recording"].tap()
        let status = app.staticTexts["recordingsStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("Remaining files are kept; you can retry"))
        XCTAssertTrue(target.exists)
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
        app.tabBars.buttons["Session"].tap()
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
        app.tabBars.buttons["Recordings"].tap()
        let play = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "playRecording-")).firstMatch
        reveal(play)
        XCTAssertTrue(play.isHittable)
        play.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        app.tabBars.buttons["Session"].tap()
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
        app.tabBars.buttons["Recordings"].tap()
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
        app.tabBars.buttons["Session"].tap()
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
        app.tabBars.buttons["Recordings"].tap()
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
                app.tabBars.buttons["Recordings"].tap()
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
                try auditInterface(app)
                let missingPlay = app.buttons["playRecording-" + missingID]
                scrollTo(missingPlay, in: app)
                XCTAssertFalse(missingPlay.isEnabled)
                XCTAssertFalse(app.buttons["exportRecording-" + missingID].isEnabled)
                XCTAssertTrue(app.buttons["deleteRecording-" + missingID].isEnabled)
                XCTAssertTrue(app.staticTexts["recordingMetadata-" + missingID].label.contains("File size unavailable"))
                app.tabBars.buttons["Preparation"].tap()
                let privacy = app.descendants(matching: .any).matching(identifier: "privacyPolicy").firstMatch
                scrollTo(privacy, in: app)
                XCTAssertTrue(privacy.exists)
                let notices = app.buttons["thirdPartyNotices"]
                scrollTo(notices, in: app)
                let footer = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                footer.name = "Footer \(orientation.rawValue) large text \(largeText)"
                footer.lifetime = .keepAlways
                add(footer)
                try auditInterface(app)
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
        app.tabBars.buttons["Recordings"].tap()
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
        for attempt in 0..<24 {
            let scroll = app.scrollViews.firstMatch.exists ? app.scrollViews.firstMatch : app.collectionViews.firstMatch
            let raw = scroll.frame.intersection(app.frame)
            let top = max(raw.minY, app.navigationBars.firstMatch.frame.maxY)
            let bottom = app.tabBars.firstMatch.exists ? min(raw.maxY, app.tabBars.firstMatch.frame.minY) : raw.maxY
            let viewport = CGRect(x: raw.minX, y: top, width: raw.width, height: max(1, bottom - top)).insetBy(dx: 0, dy: 8)
            if attempt == 0 { print("F10 scroll viewport: \(viewport), raw: \(raw), tab: \(app.tabBars.firstMatch.frame), target: \(element.frame)") }
            if viewport.contains(element.frame), element.isHittable { return }
            let distance = max(-60, min(60, viewport.midY - element.frame.midY))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: viewport.midX, dy: viewport.midY))
            let end = origin.withOffset(CGVector(dx: viewport.midX, dy: viewport.midY + distance))
            start.press(forDuration: 0.05, thenDragTo: end,
                        withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(element.isHittable)
    }

    func testDeniedCameraShowsSettingsGuidance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAM14_DENIED_PERMISSION_TEST"] == "1",
                          "Run after explicitly revoking Simulator camera permission.")
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Session"].tap()
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

    func testProfileSelectionPersistsAndRemainsAccessibleInLandscape() throws {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        let profile = app.buttons["sessionProfile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(profile.frame.height, 44)
        profile.tap()
        app.buttons["720p30 · 8 Mbps"].tap()
        expectation(for: NSPredicate(format: "value == %@", "720p30 · 8 Mbps"), evaluatedWith: profile)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.buttons["recordSample"].exists)
        app.terminate()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        XCTAssertTrue(profile.waitForExistence(timeout: 5))
        XCTAssertEqual(profile.value as? String, "720p30 · 8 Mbps")
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            let scroll = app.scrollViews.firstMatch
            for _ in 0..<20 {
                let top = app.navigationBars["stream14"].frame.maxY + 8
                let visible = CGRect(x: scroll.frame.minX, y: top, width: scroll.frame.width,
                                     height: scroll.frame.maxY - top - 8)
                let frame = profile.frame
                if visible.contains(frame), !frame.isEmpty, profile.isHittable { break }
                // Full-screen flicks overshoot compact controls at very large text.
                // Bounded drags move toward the center without alternating past it.
                let delta = max(-70, min(70, frame.midY - visible.midY))
                let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.6))
                let end = start.withOffset(CGVector(dx: 0, dy: -delta))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            XCTAssertTrue(profile.isHittable)
            XCTAssertGreaterThanOrEqual(profile.frame.height, 44)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Profile largest text landscape \(orientation.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            try app.performAccessibilityAudit()
        }
        profile.tap()
        app.buttons["1080p30 · 14 Mbps"].tap()
        expectation(for: NSPredicate(format: "value == %@", "1080p30 · 14 Mbps"), evaluatedWith: profile)
        waitForExpectations(timeout: 5)
    }

    func testLaunchShowsHonestSetupStatus() throws {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["stream14"].waitForExistence(timeout: 5))
        XCTAssertLessThan(app.frame.width, app.frame.height)
        XCTAssertTrue(app.staticTexts["setupStatus"].exists)
        XCTAssertEqual(app.staticTexts["setupStatus"].label, "Prepare your session")
        // Only standard content padding precedes the heading; no 60-point strip.
        XCTAssertEqual(app.staticTexts["setupStatus"].frame.minY - app.navigationBars["stream14"].frame.maxY,
                       16, accuracy: 2)
        XCTAssertTrue(app.staticTexts["overlayStatus"].exists)
        XCTAssertTrue(app.buttons["manualOverlayVisibility"].exists)
        XCTAssertEqual(
            app.staticTexts["setupExplanation"].label,
            "Record locally without Google, or choose a scheduled YouTube event before confirming Go Live. Keep the phone in landscape with the rear camera upright."
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
        app.tabBars.buttons["Session"].tap()
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
