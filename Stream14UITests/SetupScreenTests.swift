import XCTest

@MainActor
final class SetupScreenTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func auditInterface(_ app: XCUIApplication) throws {
        let scroll = app.scrollViews.firstMatch
        let raw = (scroll.exists ? scroll.frame : app.frame).intersection(app.frame)
        let top = max(raw.minY, app.navigationBars.firstMatch.frame.maxY)
        let bottom = app.tabBars.firstMatch.exists ? min(raw.maxY, app.tabBars.firstMatch.frame.minY) : raw.maxY
        let viewport = CGRect(x: raw.minX, y: top, width: raw.width, height: max(1, bottom - top))
        let textFrames = app.staticTexts.allElementsBoundByIndex.map {
            (identifier: $0.identifier, label: $0.label, frame: $0.frame)
        }
        try app.performAccessibilityAudit { issue in
            // Native contrast inspection can sample a scrolled/clipped text node
            // outside the picture (observed YouTube heading y709 on a 375pt screen).
            // Exempt only the same uniquely identified static text proven clipped
            // both before inspection and in its callback; visible text, controls
            // and unknown elements retain every audit, including contrast.
            if issue.auditType == .contrast, let element = issue.element,
               element.elementType == .staticText {
                let matches = textFrames.filter { $0.identifier == element.identifier && $0.label == element.label }
                if matches.count == 1, let frame = matches.first?.frame {
                    let current = element.frame
                    let clipped = [frame, current].allSatisfy {
                        !$0.isEmpty && $0.minX >= viewport.minX - 1 && $0.maxX <= viewport.maxX + 1
                            && ($0.minY < viewport.minY || $0.maxY > viewport.maxY)
                    }
                    if clipped {
                        print("F10 contrast artifact: clipped static text \(element.identifier), before \(frame), callback \(current), viewport \(viewport)")
                        return true
                    }
                }
            }
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

    private func openSettings(_ app: XCUIApplication) {
        app.buttons["sessionMore"].tap()
        app.buttons["openSettings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    private func openOverlay(_ app: XCUIApplication) {
        openSettings(app)
        app.buttons["testWebOverlay"].tap()
        XCTAssertTrue(app.textFields["overlayURL"].waitForExistence(timeout: 5))
    }

    private func navigate(_ destination: String, in app: XCUIApplication) {
        if app.tabBars.buttons[destination].exists { app.tabBars.buttons[destination].tap() }
        else {
            app.buttons["sessionMore"].tap()
            app.buttons["Navigate"].tap()
            app.buttons[destination].tap()
        }
    }

    func testYouTubeConsentLeavesLocalRehearsalAvailable() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp("policy-unaccepted")
        let camera = app.buttons["openExperiment"]
        scrollTo(camera, in: app)
        camera.tap()
        let record = app.buttons["recordSample"]
        scrollTo(record, in: app)
        XCTAssertEqual(record.label, "Record only")
        record.tap()
        XCTAssertEqual(app.staticTexts["localSavingStatus"].label, "Local saving: Recording")
        openSettings(app)
        app.buttons["YouTube"].tap()
        let agree = app.buttons["acceptYouTubePolicy"]
        scrollTo(agree, in: app)
        XCTAssertTrue(app.links["Privacy policy"].exists)
        XCTAssertFalse(app.buttons["Connect YouTube"].exists)
        agree.tap()
        XCTAssertTrue(app.buttons["Connect YouTube"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        scrollTo(record, in: app)
        XCTAssertEqual(record.label, "Stop recording")
        record.tap()
        let next = app.buttons["prepareNextSession"]
        scrollTo(next, in: app)
        XCTAssertTrue(next.isEnabled)
        next.tap()
        XCTAssertEqual(app.staticTexts["setupStatus"].label, "Next session")
        XCTAssertTrue(app.staticTexts["No scheduled event selected"].exists)
    }

    func testMoreMenuRemainsUsableDuringSessionUpdates() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            let app = fixtureApp("menu-updates")
            let status = app.staticTexts["mediaStatus"]
            XCTAssertTrue(status.waitForExistence(timeout: 5))
            app.buttons["sessionMore"].tap()
            let settings = app.buttons["openSettings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 3))
            let before = status.label
            let deadline = Date().addingTimeInterval(3)
            repeat {
                XCTAssertTrue(settings.exists && settings.isHittable,
                    "More must remain available while session status changes")
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            } while Date() < deadline
            XCTAssertNotEqual(status.label, before, "The fixture must update under the open menu")
            settings.tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
            app.buttons["Done"].tap()
            if orientation != .portrait {
                navigate("Recordings", in: app)
                navigate("Session", in: app)
            }
            XCTAssertFalse(app.buttons["endBroadcast"].exists)
            XCTAssertEqual(app.staticTexts["localSavingStatus"].label, "Local saving: Not started")
            app.terminate()
        }
    }

    func testNativeDestinationsNeverStartCaptureOrPublishing() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp()
        XCTAssertEqual(app.tabBars.buttons.count, 2)
        XCTAssertFalse(app.buttons["recordSample"].exists)
        XCTAssertFalse(app.links["Privacy policy"].exists)
        navigate("Recordings", in: app)
        navigate("Session", in: app)
        openSettings(app)
        app.buttons["About & Legal"].tap()
        XCTAssertTrue(app.links["privacyPolicy"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let event = app.buttons["chooseEvent"]
        scrollTo(event, in: app)
        event.tap()
        XCTAssertTrue(app.buttons["refreshYouTubeEvents"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["openExperiment"].exists)
        XCTAssertFalse(app.buttons["endBroadcast"].exists)
    }

    func testPreflightBlockersAndExactPublishingConfirmation() throws {
        XCUIDevice.shared.orientation = .portrait
        for state in ["idle", "overlay-unavailable", "ready"] {
            let app = fixtureApp(state)
            let start = app.buttons["goLive"]
            scrollTo(start, in: app)
            if state == "ready" {
                XCTAssertTrue(start.isEnabled)
                start.tap()
                XCTAssertTrue(app.buttons["Go Live — Unlisted"].waitForExistence(timeout: 5))
                let text = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
                for value in ["Fixture channel", "fixture-channel", "Fixture scheduled match", "Unlisted", "1080p30"] {
                    XCTAssertTrue(text.contains(value), value)
                }
                if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
                else { app.otherElements["PopoverDismissRegion"].tap() }
                XCTAssertFalse(app.buttons["endBroadcast"].exists)
                XCTAssertEqual(app.staticTexts["localSavingStatus"].label, "Local saving: Not started")
            } else {
                XCTAssertFalse(start.isEnabled)
                if state == "idle" { XCTAssertTrue(app.staticTexts["cameraReadiness"].exists) }
                else {
                    scrollTo(app.buttons["Overlay settings"], in: app)
                    app.buttons["Overlay settings"].tap()
                    XCTAssertTrue(app.buttons["applyOverlayURL"].waitForExistence(timeout: 5))
                }
            }
            app.terminate()
        }
    }

    func testMissingPermissionAndEventHaveDirectFixes() throws {
        XCUIDevice.shared.orientation = .portrait
        let denied = fixtureApp("permission-denied")
        let settings = denied.links["Open iPhone Settings"]
        scrollTo(settings, in: denied)
        XCTAssertTrue(settings.isHittable)
        XCTAssertFalse(denied.buttons["goLive"].isEnabled)
        denied.terminate()
        let app = fixtureApp("no-event")
        let choose = app.buttons["chooseEvent"]
        scrollTo(choose, in: app)
        choose.tap()
        XCTAssertTrue(app.links["Schedule an encoder event in YouTube Studio"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["refreshYouTubeEvents"].exists)
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["goLive"].isEnabled)
    }

    func testWriterFinalizationIsActionableBeforeStart() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp("writer-pending")
        let start = app.buttons["goLive"]
        scrollTo(start, in: app)
        XCTAssertFalse(start.isEnabled)
        XCTAssertFalse(app.staticTexts["sessionReady"].exists)
        scrollTo(app.staticTexts["writerReadiness"], in: app)
        XCTAssertTrue(app.staticTexts["writerReadiness"].label.contains("finalization"))
    }

    func testCompactCameraPanelHasAccessibleTarget() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = fixtureApp("ready")
        let panel = app.buttons["Camera controls"]
        scrollTo(panel, in: app)
        XCTAssertGreaterThanOrEqual(panel.frame.height, 44)
        panel.tap()
        let close = app.buttons["Close camera"]
        scrollTo(close, in: app)
        XCTAssertTrue(close.isEnabled)
        XCTAssertGreaterThanOrEqual(close.frame.height, 44)
    }

    func testActiveOverlayFailureOffersRecoveryWithoutStoppingOutputs() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp("active-overlay-unavailable")
        let retry = app.buttons["retryOverlay"]
        scrollTo(retry, in: app)
        XCTAssertTrue(retry.isEnabled)
        XCTAssertTrue(app.staticTexts["overlayWarning"].exists)
        XCTAssertEqual(app.staticTexts["localSavingStatus"].label, "Local saving: Recording")
        XCTAssertTrue(app.staticTexts["uploadStatus"].exists)
        app.buttons["Overlay settings"].tap()
        XCTAssertTrue(app.textFields["overlayURL"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["overlayURL"].isEnabled)
    }

    func testPersistentFailureStatesAndLockedSettings() throws {
        XCUIDevice.shared.orientation = .portrait
        for (state, local, upload) in [("reconnecting", "Recording", "Reconnecting"),
            ("upload-recovered", "Recording", "Connected"), ("backup-failed", "Failed", "connected"),
            ("unknown-end", "Not started", "stopped"), ("ended", "Saved", "stopped"),
            ("finalizing", "Finalizing", "not started")] {
            let app = fixtureApp(state)
            XCTAssertTrue(app.staticTexts["localSavingStatus"].label.contains(local))
            XCTAssertTrue(app.staticTexts["uploadStatus"].label.contains(upload))
            if state == "reconnecting" {
                let stop = app.buttons["recordSample"]
                scrollTo(stop, in: app)
                XCTAssertEqual(stop.label, "Stop recording")
                XCTAssertTrue(stop.isEnabled)
            }
            if state == "backup-failed" {
                scrollTo(app.staticTexts["localRecoveryGuidance"], in: app)
                XCTAssertTrue(app.staticTexts["localRecoveryGuidance"].label.contains("gap"))
            }
            if state == "unknown-end" {
                scrollTo(app.buttons["reconcileBroadcast"], in: app)
                XCTAssertTrue(app.links["Open YouTube Studio"].exists)
            }
            if ["ended", "finalizing"].contains(state) {
                let next = app.buttons["prepareNextSession"]
                scrollTo(next, in: app)
                XCTAssertEqual(next.isEnabled, state == "ended")
                if state == "ended" {
                    next.tap()
                    XCTAssertEqual(app.staticTexts["setupStatus"].label, "Next session")
                    XCTAssertEqual(app.staticTexts["localSavingStatus"].label, "Local saving: Not started")
                    XCTAssertEqual(app.staticTexts["uploadStatus"].label, "Upload: Upload not started")
                    XCTAssertTrue(app.staticTexts["No scheduled event selected"].exists)
                }
            } else {
                openOverlay(app)
                XCTAssertFalse(app.textFields["overlayURL"].isEnabled)
                XCTAssertFalse(app.buttons["applyOverlayURL"].isEnabled)
            }
            app.terminate()
        }
    }

    func testSessionLayoutsAndManualOverlayAtLargestText() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        for large in [false, true] {
            for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
                XCUIDevice.shared.orientation = orientation
                let app = fixtureApp("upload-recovered", largeText: large)
                XCTAssertFalse(app.tabBars.firstMatch.exists)
                if !large {
                    let preview = app.descendants(matching: .any).matching(identifier: "cameraPreview").firstMatch
                    XCTAssertTrue(preview.waitForExistence(timeout: 5))
                    XCTAssertEqual(preview.frame.width / preview.frame.height, 16.0 / 9.0, accuracy: 0.05)
                    XCTAssertLessThan(preview.frame.maxX, app.staticTexts["uploadStatus"].frame.minX)
                    XCTAssertLessThanOrEqual(app.frame.maxY - app.scrollViews.firstMatch.frame.maxY, 22)
                }
                let mute = app.buttons["microphoneMute"]
                scrollTo(mute, in: app)
                XCTAssertGreaterThanOrEqual(mute.frame.height, 44)
                app.buttons["sessionMore"].tap()
                app.buttons["manualOverlayVisibility"].tap()
                let landscapeShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                landscapeShot.name = "Session landscape \(orientation.rawValue), large \(large)"
                landscapeShot.lifetime = .keepAlways
                add(landscapeShot)
                navigate("Recordings", in: app)
                XCUIDevice.shared.orientation = .portrait
                XCTAssertTrue(app.tabBars.buttons["Recordings"].isSelected)
                navigate("Session", in: app)
                XCTAssertTrue(app.staticTexts["localSavingStatus"].label.contains("Recording"))
                XCTAssertTrue(app.staticTexts["uploadStatus"].label.contains("Connected"))
                let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                screenshot.name = "Session preserved after rotation \(orientation.rawValue), large \(large)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
                app.terminate()
            }
        }
    }

    func testLastSessionControlFitsNativeViewport() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        for large in [false, true] {
            for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
                XCUIDevice.shared.orientation = orientation
                let app = fixtureApp("ready", largeText: large)
                navigate("Session", in: app)
                let button = app.buttons["goLive"]
                XCTAssertTrue(button.waitForExistence(timeout: 5))
                let scroll = app.scrollViews.firstMatch
                let raw = scroll.frame.intersection(app.frame)
                let top = max(raw.minY, app.navigationBars.firstMatch.frame.maxY)
                let bottom = app.tabBars.firstMatch.exists ? min(raw.maxY, app.tabBars.firstMatch.frame.minY) : raw.maxY
                let viewport = CGRect(x: raw.minX, y: top, width: raw.width, height: bottom - top)
                // Use actual native bounds, not the drag helper's optional 8pt
                // clearance. One point tolerates AX subpixel conversion only.
                scrollTo(button, in: app)
                let frame = button.frame
                print("F10 final control: \(frame), native viewport: \(viewport)")
                XCTAssertTrue(viewport.insetBy(dx: -1, dy: -1).contains(frame),
                              "Final control \(frame) must fit native viewport \(viewport)")
                XCTAssertTrue(button.isHittable)
                XCTAssertGreaterThanOrEqual(frame.height, 44)
                let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                screenshot.name = "Final Session control \(orientation.rawValue) largest text \(large)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
                app.terminate()
            }
        }
    }

    func testFailedDeletionRetainsRowAndExplainsRetry() throws {
        let identifier = ProcessInfo.processInfo.environment["STREAM14_DELETE_FAILURE_FIXTURE_ID"]
        try XCTSkipUnless(identifier != nil, "Seed a nonregular-artifact Simulator fixture first.")
        let app = fixtureApp()
        navigate("Recordings", in: app)
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
        navigate("Session", in: app)
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
        XCTAssertFalse(selector.exists)
        sleep(3)
        record.tap()
        let next = app.buttons["prepareNextSession"]
        reveal(next)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: next)
        waitForExpectations(timeout: 10)
        next.tap()
        reveal(selector)
        XCTAssertTrue(selector.isEnabled)
        navigate("Recordings", in: app)
        let play = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "playRecording-")).firstMatch
        reveal(play)
        XCTAssertTrue(play.isHittable)
        play.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        navigate("Session", in: app)
        let controls = app.buttons["Camera controls"]
        reveal(controls)
        controls.tap()
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
        navigate("Recordings", in: app)
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
        navigate("Session", in: app)
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
        navigate("Recordings", in: app)
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
                navigate("Recordings", in: app)
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

            }
        }
    }

    func testQualificationSummaryLoadsAndDeliberateShareOpens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAM14_QUALIFICATION_FIXTURE_ID"] != nil,
            "Seed a dedicated Simulator qualification checkpoint first.")
        let id = try XCTUnwrap(ProcessInfo.processInfo.environment["STREAM14_QUALIFICATION_FIXTURE_ID"])
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp()
        navigate("Recordings", in: app)
        let load = app.buttons["loadQualification-" + id]
        scrollTo(load, in: app)
        load.tap()
        let export = app.buttons["exportQualification-" + id]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        scrollTo(export, in: app)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Deliberate numeric qualification summary export"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        export.tap()
        XCTAssertTrue(app.cells["Save to Files"].waitForExistence(timeout: 5))
    }

    func testRecordingIconPlaybackAndExport() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAM14_RECORDING_UI_FIXTURE_ID"] != nil,
                          "Seed an isolated Simulator recording fixture first.")
        let id = try XCTUnwrap(ProcessInfo.processInfo.environment["STREAM14_RECORDING_UI_FIXTURE_ID"])
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        navigate("Recordings", in: app)
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

    func testSeparateRecoveryPersistsAndCopyDeletionKeepsOriginal() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAM14_RECOVERY_FIXTURE_ID"] != nil,
            "Seed a dedicated Simulator with an expendable interrupted source first.")
        let id = try XCTUnwrap(ProcessInfo.processInfo.environment["STREAM14_RECOVERY_FIXTURE_ID"])
        let app = fixtureApp()
        navigate("Recordings", in: app)
        let recover = app.buttons["recoverRecording-" + id]
        scrollTo(recover, in: app)
        let row = app.otherElements["recordingRow-" + id]
        let copies = row.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recoveryStatus-"))
        let previousIDs = Set(copies.allElementsBoundByIndex.map(\.identifier))
        recover.tap()
        let feedback = app.staticTexts["recordingsStatus"]
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Recovered copy saved"), evaluatedWith: feedback)
        waitForExpectations(timeout: 30)
        XCTAssertEqual(copies.count, previousIDs.count + 1)
        let newID = try XCTUnwrap(copies.allElementsBoundByIndex.map(\.identifier).first { !previousIDs.contains($0) })
            .replacingOccurrences(of: "recoveryStatus-", with: "")
        XCTAssertEqual(app.staticTexts["recordingStatus-" + id].label, "interrupted")
        app.terminate()
        app.launch()
        navigate("Recordings", in: app)
        XCTAssertTrue(copies.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["recordingStatus-" + id].label, "interrupted")
        let play = row.buttons["playRecovery-" + newID]
        scrollTo(play, in: app)
        XCTAssertTrue(play.isEnabled)
        play.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let export = row.buttons["exportRecovery-" + newID]
        scrollTo(export, in: app)
        try auditInterface(app)
        let recoveredScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        recoveredScreenshot.name = "Distinct recovery copy and original interrupted status"
        recoveredScreenshot.lifetime = .keepAlways
        add(recoveredScreenshot)
        export.tap()
        XCTAssertTrue(app.cells["Save to Files"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        navigate("Recordings", in: app)
        let remove = row.buttons["deleteRecovery-" + newID]
        scrollTo(remove, in: app)
        remove.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(remove.exists)
        remove.tap()
        app.alerts.buttons["Delete recovery copy"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: remove)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["exportRecording-" + id].isEnabled)
        XCTAssertTrue(app.staticTexts["recordingStatus-" + id].exists)
        XCTAssertTrue(feedback.label.contains("Original recording is retained"))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Original retained after selective recovery deletion"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testUnreadableRecoveryFailureRetainsOriginalExportAndFailedAttempt() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["STREAM14_RECOVERY_UNREADABLE_ID"] != nil,
            "Seed an expendable pre-fragment interrupted source first.")
        let id = try XCTUnwrap(environment["STREAM14_RECOVERY_UNREADABLE_ID"])
        let app = fixtureApp()
        navigate("Recordings", in: app)
        let recover = app.buttons["recoverRecording-" + id]
        scrollTo(recover, in: app)
        recover.tap()
        let feedback = app.staticTexts["recordingsStatus"]
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Recovery could not finish"), evaluatedWith: feedback)
        waitForExpectations(timeout: 20)
        XCTAssertTrue(app.buttons["exportRecording-" + id].isEnabled)
        XCTAssertEqual(app.staticTexts["recordingStatus-" + id].label, "interrupted")
        let row = app.otherElements["recordingRow-" + id]
        XCTAssertTrue(row.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recoveryStatus-")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["recordingReview-" + id].label.contains("unreadable"))
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for attempt in 0..<64 {
            let scroll = app.scrollViews.firstMatch.exists ? app.scrollViews.firstMatch : app.collectionViews.firstMatch
            let raw = scroll.frame.intersection(app.frame)
            let top = max(raw.minY, app.navigationBars.firstMatch.frame.maxY)
            let bottom = app.tabBars.firstMatch.exists ? min(raw.maxY, app.tabBars.firstMatch.frame.minY) : raw.maxY
            let viewport = CGRect(x: raw.minX, y: top, width: raw.width, height: max(1, bottom - top)).insetBy(dx: 0, dy: 8)
            if attempt == 0 { print("F10 scroll viewport: \(viewport), raw: \(raw), tab visible: \(app.tabBars.firstMatch.exists), target: \(element.frame)") }
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
        navigate("Session", in: app)
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
        let initial = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        initial.launch()
        let initialProfile = initial.buttons["sessionProfile"]
        XCTAssertTrue(initialProfile.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(initialProfile.frame.height, 44)
        initialProfile.tap()
        initial.buttons["720p30 · 8 Mbps"].tap()
        expectation(for: NSPredicate(format: "value == %@", "720p30 · 8 Mbps"), evaluatedWith: initialProfile)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(initial.buttons["recordSample"].exists)
        initial.terminate()
        // Use fresh queries for the relaunched process; do not carry AX handles
        // across termination into the native accessibility audit.
        let app = XCUIApplication()
        let profile = app.buttons["sessionProfile"]
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        XCTAssertTrue(profile.waitForExistence(timeout: 5))
        XCTAssertEqual(profile.value as? String, "720p30 · 8 Mbps")
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            scrollTo(profile, in: app)
            XCTAssertTrue(profile.isHittable)
            XCTAssertGreaterThanOrEqual(profile.frame.height, 44)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Profile largest text landscape \(orientation.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            try auditInterface(app)
        }
        profile.tap()
        app.buttons["1080p30 · 14 Mbps"].tap()
        expectation(for: NSPredicate(format: "value == %@", "1080p30 · 14 Mbps"), evaluatedWith: profile)
        waitForExpectations(timeout: 5)
    }

    func testLaunchShowsHonestSetupStatus() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp()
        XCTAssertEqual(app.staticTexts["setupStatus"].label, "Next session")
        XCTAssertTrue(app.buttons["openExperiment"].exists)
        XCTAssertFalse(app.buttons["recordSample"].exists)
        XCTAssertFalse(app.links["Privacy policy"].exists)
        XCTAssertTrue(app.staticTexts["uploadStatus"].exists)
        XCTAssertTrue(app.staticTexts["localSavingStatus"].exists)
    }

    func testOverlaySettingsAreAccessibleWithoutStartingCapture() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = fixtureApp(largeText: true)
        openOverlay(app)
        XCTAssertTrue(app.textFields["overlayURL"].isEnabled)
        scrollTo(app.buttons["applyOverlayURL"], in: app)
        XCTAssertTrue(app.buttons["applyOverlayURL"].isEnabled)
        try auditInterface(app)
    }

    func testOverlayDraftIsDiscardedAndInvalidApplyKeepsConfiguration() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp()
        openOverlay(app)
        let field = app.textFields["overlayURL"]
        let original = field.value as? String
        app.buttons["Use reference URL"].tap()
        app.buttons["Done"].tap()
        openOverlay(app)
        XCTAssertEqual(field.value as? String, original)
        field.tap()
        field.typeText("http://invalid.example")
        app.buttons["Apply URL"].tap()
        XCTAssertTrue(app.staticTexts["Enter an HTTPS URL without username or password."].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        openOverlay(app)
        XCTAssertEqual(field.value as? String, original)
    }

    func testLargestTextRemainsAccessibleInLandscape() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = fixtureApp(largeText: true)
        XCTAssertTrue(app.staticTexts["setupStatus"].waitForExistence(timeout: 5))
        let check = app.buttons["openExperiment"]
        scrollTo(check, in: app)
        XCTAssertGreaterThanOrEqual(check.frame.height, 44)
        try auditInterface(app)
        openSettings(app)
        app.buttons["About & Legal"].tap()
        let privacy = app.links["privacyPolicy"]
        scrollTo(privacy, in: app)
        XCTAssertGreaterThanOrEqual(privacy.frame.height, 44)
        let notices = app.buttons["thirdPartyNotices"]
        scrollTo(notices, in: app)
        XCTAssertGreaterThanOrEqual(notices.frame.height, 44)
    }
}
