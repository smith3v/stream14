import XCTest

@MainActor
final class StreamingButtonContrastTests: XCTestCase {
    func testDarkEnabledStreamingButtonContrast() throws { try checkStart(style: "Dark") }
    func testLightEnabledStreamingButtonContrast() throws { try checkStart(style: "Light") }

    func testDarkRecordingAndEndingButtonContrast() throws { try checkStopActions(style: "Dark") }
    func testLightRecordingAndEndingButtonContrast() throws { try checkStopActions(style: "Light") }

    private enum Fill: String { case green, red, neutral }

    private func checkStart(style: String) throws {
        let app = launch(style: style, fixture: "preview")
        defer { app.terminate() }
        let screenImage = try XCTUnwrap(app.screenshot().image.cgImage)
        let page = try XCTUnwrap(screenImage.cropping(to: CGRect(x: 1, y: screenImage.height / 2, width: 2, height: 2)))
        let pageLuminance = try XCTUnwrap(interiorPixels(page).first).luminance
        if style == "Dark" { XCTAssertLessThan(pageLuminance, 0.1) }
        else { XCTAssertGreaterThan(pageLuminance, 0.9) }

        let button = app.buttons["goLive"]
        try check(button, in: app, label: "Start recording and streaming", style: style,
                  fill: .green, pageLuminance: pageLuminance)
        XCTAssertEqual(app.buttons["recordSample"].label, "Record only")
        XCTAssertFalse(app.buttons["endBroadcast"].exists)
    }

    private func checkStopActions(style: String) throws {
        let local = launch(style: style, fixture: "no-event")
        let record = local.buttons["recordSample"]
        XCTAssertFalse(local.buttons["goLive"].exists)
        try check(record, in: local, label: "Record only", style: style, fill: .neutral)
        record.tap()
        let localEnd = local.buttons["End session"]
        try check(localEnd, in: local, label: "End session", style: style, fill: .red)
        localEnd.tap()
        XCTAssertTrue(local.buttons["Stop local recording and capture"].waitForExistence(timeout: 5))
        dismissConfirmation(in: local)
        try check(record, in: local, label: "Stop recording only", style: style, fill: .red)
        record.tap()
        local.buttons["Finalize local recording"].tap()
        XCTAssertTrue(local.buttons["prepareNextSession"].waitForExistence(timeout: 5))
        local.terminate()

        let broadcast = launch(style: style, fixture: "upload-recovered")
        defer { broadcast.terminate() }
        let broadcastEnd = broadcast.buttons["endBroadcast"]
        try check(broadcastEnd, in: broadcast, label: "End session", style: style, fill: .red)
        broadcastEnd.tap()
        XCTAssertTrue(broadcast.buttons["End session and local recording"].waitForExistence(timeout: 5))
        dismissConfirmation(in: broadcast)
        XCTAssertEqual(broadcast.staticTexts["localSavingStatus"].label, "Local saving: Recording")
        try check(broadcast.buttons["stopStreaming"], in: broadcast, label: "Stop streaming only", style: style, fill: .red)
    }

    private func dismissConfirmation(in app: XCUIApplication) {
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else { app.otherElements["PopoverDismissRegion"].tap() }
    }

    private func launch(style: String, fixture: String) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["STREAM14_INTERFACE_FIXTURE"] = fixture
        app.launchEnvironment["STREAM14_INTERFACE_COLOR_SCHEME"] = style.lowercased()
        app.launch()
        return app
    }

    private func check(_ button: XCUIElement, in app: XCUIApplication, label: String,
                       style: String, fill: Fill, pageLuminance: Double? = nil) throws {
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<12 {
            if button.isHittable && button.frame.minY > app.navigationBars.firstMatch.frame.maxY &&
                button.frame.maxY < app.tabBars.firstMatch.frame.minY { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(button.isHittable)
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.label, label)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        XCTAssertGreaterThanOrEqual(button.frame.width, 44)
        let screenshot = button.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(label) \(style)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let pixels = try interiorPixels(image)
        let fillCount = pixels.count { pixel in
            switch fill {
            case .green: pixel.green >= 155 && pixel.green - pixel.red >= 25 && pixel.green - pixel.blue >= 25
            case .red: pixel.red - pixel.green >= 25 && pixel.red - pixel.blue >= 25
            case .neutral:
                max(pixel.red, pixel.green, pixel.blue) - min(pixel.red, pixel.green, pixel.blue) <= 12
            }
        }
        XCTAssertGreaterThan(Double(fillCount) / Double(pixels.count), 0.6, "Expected a \(fill.rawValue) fill")
        let luminances = pixels.map(\.luminance).sorted()
        // Sample the central pill interior so rounded corners cannot make a
        // blank white-on-white label appear contrasting against the page.
        let dark = luminances[Int(Double(luminances.count - 1) * 0.03)]
        let light = luminances[Int(Double(luminances.count - 1) * 0.97)]
        let ratio = (light + 0.05) / (dark + 0.05)
        print("\(label) rendered contrast: \(style), ratio=\(ratio)")
        XCTAssertGreaterThanOrEqual(ratio, 4.5,
            "The actual rendered label must remain visible against its fill")
        if fill == .green, let pageLuminance {
            let edgeRatio = (max(light, pageLuminance) + 0.05) / (min(light, pageLuminance) + 0.05)
            print("Start fill contrast against the \(style) page: \(edgeRatio)")
            XCTAssertGreaterThanOrEqual(edgeRatio, 3, "The green fill must be distinct from the page")
        }
    }

    private struct Pixel {
        let red: Int
        let green: Int
        let blue: Int

        var luminance: Double {
            func linear(_ channel: Int) -> Double {
                let s = Double(channel) / 255
                return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
    }

    private func interiorPixels(_ image: CGImage) throws -> [Pixel] {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { storage in
            let context = try XCTUnwrap(CGContext(data: storage.baseAddress,
                width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let insetX = min(width / 3, Int(Double(height) * 0.6))
        let insetY = height / 5
        var values: [Pixel] = []
        for y in insetY..<(height - insetY) {
            for x in insetX..<(width - insetX) {
                let i = (y * width + x) * 4
                values.append(Pixel(red: Int(bytes[i]), green: Int(bytes[i + 1]), blue: Int(bytes[i + 2])))
            }
        }
        return values
    }
}
