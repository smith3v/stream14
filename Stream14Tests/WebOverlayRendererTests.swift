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
        let host = OverlaySnapshotHost(webView: renderer.webView)
        host.frame = CGRect(x: 0, y: 80, width: 375, height: 60)
        controller.view.addSubview(host)
        // Cover the scene anchor as the main screen does. WebKit snapshots
        // come from the separate hidden window.
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
        let snapshotWindow = try #require(renderer.webView.window)
        #expect(snapshotWindow !== window && snapshotWindow.isHidden && !snapshotWindow.isKeyWindow)
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
    @Test @MainActor func navigationThatNeverCommitsRetriesWithoutAnAttachedView() {
        var offset: TimeInterval = 0
        let renderer = WebOverlayRenderer(clock: { ProcessInfo.processInfo.systemUptime + offset })
        defer { renderer.disable() }
        renderer.load("https://127.0.0.1:1/overlay")
        let first = renderer.webView
        // Cancel before callbacks run: no commit and no isLoading signal to rely on.
        first.stopLoading()
        offset += 6
        renderer.supervise()
        #expect(renderer.webView === first)
        offset += 2
        renderer.supervise()
        #expect(renderer.webView !== first)
        #expect(renderer.isRunning)
        #expect(renderer.image == nil)
    }

    @Test @MainActor func callbackDeadlinesProcessRecoveryAndDisabledLateCallbacks() async throws {
        var time: TimeInterval = 0
        let renderer = WebOverlayRenderer(clock: { ProcessInfo.processInfo.systemUptime + time })
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        let host = OverlaySnapshotHost(webView: renderer.webView)
        host.frame = CGRect(x: 0, y: 80, width: 375, height: 60)
        controller.view.addSubview(host)
        window.makeKeyAndVisible()
        defer { renderer.disable(); window.isHidden = true }
        renderer.loadFixture("<html><head><meta name='viewport' content='width=device-width,initial-scale=1'></head><body style='background:transparent'><div>Static healthy score</div></body></html>")
        host.layoutIfNeeded()
        try await waitForImage(renderer)
        let firstBrowser = renderer.webView
        // Unchanged pixels with a usable render are healthy. No browser replacement.
        time += 1
        renderer.supervise()
        try await Task.sleep(for: .milliseconds(200))
        #expect(renderer.webView === firstBrowser)
        #expect(renderer.visible)
        // JS/snapshot work never calls back: supervision remains independent.
        let beforeStall = renderer.health.renderTime ?? 0
        renderer.captureInjection = .stalled
        time += 1
        renderer.supervise()
        time += 6
        renderer.supervise()
        #expect(renderer.webView !== firstBrowser)
        #expect(renderer.webView.superview === host)
        renderer.captureInjection = .none
        time += 1
        try await waitForFreshRender(renderer, after: beforeStall)
        #expect(renderer.visible)
        // Actual process-termination delegate path enters bounded failure/retry.
        let beforeTermination = renderer.health.renderTime ?? 0
        let terminatedBrowser = renderer.webView
        renderer.setManuallyHidden(true)
        renderer.webViewWebContentProcessDidTerminate(terminatedBrowser)
        renderer.supervise()
        #expect(renderer.webView === terminatedBrowser)
        time += 2
        renderer.supervise()
        #expect(renderer.webView !== terminatedBrowser)
        time += 1
        try await waitForFreshRender(renderer, after: beforeTermination)
        #expect(renderer.healthy)
        #expect(!renderer.visible)
        #expect(renderer.health.manuallyHidden)
        renderer.setManuallyHidden(false)
        #expect(renderer.visible)
        // Returning unusable results forever must also recover, not just hang.
        let beforeUnusable = renderer.health.renderTime ?? 0
        renderer.captureInjection = .unusable
        let unusableBrowser = renderer.webView
        time += 10
        renderer.supervise()
        #expect(!renderer.visible)
        #expect(renderer.webView !== unusableBrowser)
        renderer.captureInjection = .none
        time += 1
        try await waitForFreshRender(renderer, after: beforeUnusable)
        #expect(renderer.visible)
        let retired = renderer.webView
        let retiredNavigation = retired.loadHTMLString("<html><body>late</body></html>", baseURL: nil)
        renderer.disable()
        renderer.webViewWebContentProcessDidTerminate(retired)
        renderer.webView(retired, didCommit: retiredNavigation)
        renderer.webView(retired, didFinish: retiredNavigation)
        time += 30
        renderer.supervise()
        try await Task.sleep(for: .milliseconds(200))
        #expect(!renderer.isRunning)
        #expect(!renderer.visible)
        #expect(renderer.image == nil)
        #expect(renderer.webView !== retired)
        #expect(renderer.status.hasPrefix("Overlay disabled"))
    }

    @MainActor private func waitForImage(_ renderer: WebOverlayRenderer) async throws {
        for _ in 0..<100 {
            renderer.supervise()
            if renderer.image != nil { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(renderer.image != nil)
    }

    @MainActor private func waitForFreshRender(_ renderer: WebOverlayRenderer, after time: TimeInterval) async throws {
        for _ in 0..<100 {
            renderer.supervise()
            if let rendered = renderer.health.renderTime, rendered > time { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect((renderer.health.renderTime ?? 0) > time)
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
        let host = OverlaySnapshotHost(webView: renderer.webView)
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
