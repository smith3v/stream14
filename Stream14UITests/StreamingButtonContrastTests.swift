import XCTest

@MainActor
final class StreamingButtonContrastTests: XCTestCase {
    func testDarkEnabledStreamingButtonContrast() throws { try check(style: "Dark", fixture: "preview", enabled: true) }
    func testDarkUnavailableStreamingButtonContrast() throws { try check(style: "Dark", fixture: "no-event", enabled: false) }
    func testLightEnabledStreamingButtonContrast() throws { try check(style: "Light", fixture: "preview", enabled: true) }
    func testLightUnavailableStreamingButtonContrast() throws { try check(style: "Light", fixture: "no-event", enabled: false) }

    private func check(style: String, fixture: String, enabled: Bool) throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["STREAM14_INTERFACE_FIXTURE"] = fixture
        app.launchEnvironment["STREAM14_INTERFACE_COLOR_SCHEME"] = style.lowercased()
        app.launch()
        let screen = app.screenshot()
        let screenAttachment = XCTAttachment(screenshot: screen)
        screenAttachment.name = "Streaming controls \(style) \(enabled ? "enabled" : "unavailable")"
        screenAttachment.lifetime = .keepAlways
        add(screenAttachment)
        let screenImage = try XCTUnwrap(screen.image.cgImage)
        let page = try XCTUnwrap(screenImage.cropping(to: CGRect(x: 1, y: screenImage.height / 2, width: 2, height: 2)))
        let pageLuminance = try interiorLuminances(page).last!
        if style == "Dark" { XCTAssertLessThan(pageLuminance, 0.1) }
        else { XCTAssertGreaterThan(pageLuminance, 0.9) }
        let button = app.buttons["goLive"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<12 {
            if button.isHittable && button.frame.minY > app.navigationBars.firstMatch.frame.maxY &&
                button.frame.maxY < app.tabBars.firstMatch.frame.minY { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(button.isHittable)
        XCTAssertEqual(button.isEnabled, enabled)
        XCTAssertEqual(button.label, "Start recording and streaming")
        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        let screenshot = button.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Streaming button \(style) \(enabled ? "enabled" : "unavailable")"
        attachment.lifetime = .keepAlways
        add(attachment)
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let luminances = try interiorLuminances(image)
        // Sample only the central pill interior: rounded corners cannot make a
        // blank white-on-white label appear contrasting against the page.
        let dark = luminances[Int(Double(luminances.count - 1) * 0.03)]
        let light = luminances[Int(Double(luminances.count - 1) * 0.97)]
        let ratio = (light + 0.05) / (dark + 0.05)
        print("Streaming button rendered contrast: \(style), enabled=\(enabled), ratio=\(ratio)")
        // Inactive controls are exempt from WCAG's text contrast minimum.
        // The inactive 1.5 floor is only a raster visibility-regression heuristic
        // for the blank-pill defect; screenshots still require visual review.
        XCTAssertGreaterThanOrEqual(ratio, enabled ? 4.5 : 1.5,
            "The actual rendered label must remain visible against its fill")
        // The fixture fails closed. Opening the interface must not start media.
        XCTAssertFalse(app.buttons["stopSample"].exists)
        XCTAssertFalse(app.buttons["endBroadcast"].exists)
        app.terminate()
    }

    private func interiorLuminances(_ image: CGImage) throws -> [Double] {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { storage in
            let context = try XCTUnwrap(CGContext(data: storage.baseAddress,
                width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        func linear(_ channel: UInt8) -> Double {
            let s = Double(channel) / 255
            return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        let insetX = min(width / 3, Int(Double(height) * 0.6))
        let insetY = height / 5
        var values: [Double] = []
        for y in insetY..<(height - insetY) {
            for x in insetX..<(width - insetX) {
                let i = (y * width + x) * 4
                values.append(0.2126 * linear(bytes[i]) + 0.7152 * linear(bytes[i + 1]) + 0.0722 * linear(bytes[i + 2]))
            }
        }
        return values.sorted()
    }
}
