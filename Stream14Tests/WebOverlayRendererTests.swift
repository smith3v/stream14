import Foundation
import Testing
import UIKit
import WebKit
@testable import Stream14

@Suite(.serialized)
struct WebOverlayRendererTests {
    @Test @MainActor func urlValidation() {
        #expect(WebOverlayRenderer.validatedURL("https://example.org/score?token=example") != nil)
        for text in ["http://example.org", "file:///tmp/test", "javascript:alert(1)", "https://user:password@example.org"] {
            #expect(WebOverlayRenderer.validatedURL(text) == nil)
        }
    }

    @Test @MainActor func coveredAttachedFixtureHasCanvasAndAlpha() async throws {
        let fixtureURL = try #require(Bundle(for: FixtureBundle.self).url(forResource: "overlay", withExtension: "html", subdirectory: "Fixtures")
            ?? Bundle(for: FixtureBundle.self).url(forResource: "overlay", withExtension: "html"))
        let html = try String(contentsOf: fixtureURL, encoding: .utf8)
        let previousIdle = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = previousIdle }
        let renderer = WebOverlayRenderer()
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        let host = OverlayViewport(webView: renderer.webView)
        host.frame = CGRect(x: 0, y: 80, width: 375, height: 60)
        controller.view.addSubview(host)
        // Main-screen source host sits behind an opaque scroll surface, without
        // being hidden, detached, zero-sized or made transparent itself.
        let cover = UIView(frame: controller.view.bounds)
        cover.backgroundColor = .systemBackground
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.view.addSubview(cover)
        window.makeKeyAndVisible()
        host.setNeedsLayout()
        host.layoutIfNeeded()
        defer { renderer.stop(); window.isHidden = true }
        let staleNavigation = try #require(renderer.webView.loadHTMLString("<html><body>old</body></html>", baseURL: nil))
        renderer.loadFixture(html)
        for _ in 0..<100 {
            if renderer.image != nil { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let image = try #require(renderer.image)
        #expect(image.width == 1920)
        #expect(image.height == 1080)
        #expect(renderer.visible)
        #expect(renderer.viewport == "1920×1080 CSS → 1920×1080 pixels")
        #expect(renderer.webView.window != nil)
        #expect(!host.isHidden && host.alpha == 1)
        // Normalize to RGBA and inspect untouched transparency and the CSS panel.
        let data = try #require(image.dataProvider?.data)
        let bytes = CFDataGetBytePtr(data)!
        #expect(bytes[3] == 0)
        // CSS anchors must survive normalization at opposite canvas corners.
        let corner = ((1080 - 10) * 1920 + 1920 - 10) * 4
        #expect(bytes[corner] == 255 && bytes[corner + 1] == 0 && bytes[corner + 2] == 0 && bytes[corner + 3] == 255)
        let panel = (250 * 1920 + 850) * 4
        #expect(bytes[panel + 3] == 128)
        let alphaValues = stride(from: 3, to: CFDataGetLength(data), by: 4).map { bytes[$0] }
        #expect(alphaValues.contains(128))
        #expect(alphaValues.contains(255))
        try UIImage(cgImage: image).pngData()?.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("stream14-overlay-fixture.png"))
        print("Fixture capture ms: \(renderer.captureMilliseconds)")
        // A failure from a superseded navigation must not stop fresh captures.
        let previous = renderer.image
        renderer.webView(renderer.webView, didFail: staleNavigation, withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))
        try await Task.sleep(for: .seconds(1.5))
        #expect(renderer.image !== previous)
        let updated = try #require(renderer.image?.dataProvider?.data)
        #expect(!CFEqual(data, updated))
        renderer.setManuallyHidden(true)
        #expect(!renderer.visible)
        #expect(renderer.image != nil)
        renderer.stop()
        renderer.setManuallyHidden(false)
        #expect(!renderer.visible)
    }
    // Opt-in live-service evidence only. Deterministic CI/default tests never depend
    // on the current contents or availability of an external scoreboard.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STREAM14_REFERENCE_TEST"] == "1"))
    @MainActor func referencePageReloadEvidence() async throws {
        let previousIdle = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = previousIdle }
        let renderer = WebOverlayRenderer()
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        let host = OverlayViewport(webView: renderer.webView)
        host.frame = CGRect(x: 0, y: 80, width: 375, height: 211)
        controller.view.addSubview(host)
        window.makeKeyAndVisible()
        host.setNeedsLayout()
        host.layoutIfNeeded()
        defer { renderer.stop(); window.isHidden = true }
        renderer.load("https://heren14-overlay.smith3v.com/overlay.html")
        for _ in 0..<150 {
            if renderer.image != nil { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let first = try #require(renderer.image)
        var sourceTimes = Set<TimeInterval>()
        var costs = [Double]()
        for _ in 0..<30 {
            try await Task.sleep(for: .milliseconds(500))
            #expect(renderer.visible)
            #expect(renderer.image != nil)
            if let time = renderer.health.sourceTime { sourceTimes.insert(time) }
            costs.append(renderer.captureMilliseconds)
            if let image = renderer.image {
                let data = try #require(image.dataProvider?.data)
                let bytes = CFDataGetBytePtr(data)!
                // Transparent top-left survives every sampled output, including reloads.
                #expect(bytes[3] == 0)
                #expect(bytes[(540 * 1920 + 960) * 4 + 3] > 0)
            }
        }
        #expect(sourceTimes.count >= 4)
        #expect(first.width == 1920 && first.height == 1080)
        let image = try #require(renderer.image)
        try UIImage(cgImage: image).pngData()?.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("stream14-overlay-reference.png"))
        print("Reference reload source confirmations: \(sourceTimes.count); sampled capture ms range: \(costs.min() ?? 0)...\(costs.max() ?? 0)")
    }
}

private final class FixtureBundle: NSObject {}
