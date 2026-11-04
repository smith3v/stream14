import Observation
import SwiftUI
import WebKit

/// Public handoff: `image` is an immutable 1920×1080 raster. Consumers must apply
/// `visible` as well; keeping an image in memory never establishes source health.
@MainActor
@Observable
final class WebOverlayRenderer: NSObject, WKNavigationDelegate, WKUIDelegate {
    static let canvas = CGSize(width: 1920, height: 1080)
    let webView: WKWebView
    private(set) var image: CGImage?
    private(set) var visible = false
    private(set) var healthy = false
    private(set) var status = "Overlay disabled · load an HTTPS URL to enable it."
    private(set) var captureMilliseconds: Double = 0
    private(set) var viewport = "No render yet"
    private(set) var health = OverlayHealth()
    var captureInterval: TimeInterval = 1
    private var loop: Task<Void, Never>?
    private var healthLoop: Task<Void, Never>?
    private var generation = 0
    private var currentNavigation: WKNavigation?
    private var awaitingProgrammaticStart = false
    private var loaded = false
    private var loadedAt: TimeInterval = 0
    private var navigationStarted: TimeInterval = 0
    private var sourceAccepted = false
    private var failed = false
    private var retryAt: TimeInterval = 0
    private var captureBusy = false
    private var active = false
    private var sessionStarted: TimeInterval = 0
    private var requestedURL: URL?
    private var fixture = false
    private var freshDocument = false
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: CGRect(origin: .zero, size: Self.canvas), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        // The source uses video pixels, never the hosting phone's safe-area insets.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.insetsLayoutMarginsFromSafeArea = false
        webView.isUserInteractionEnabled = false
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        webView.pageZoom = 1
    }

    static func validatedURL(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    func load(_ text: String) {
        guard let url = Self.validatedURL(text) else {
            status = "Use an HTTPS URL without embedded username or password."
            return
        }
        reset()
        requestedURL = url
        fixture = false
        start()
        loadRequest(url)
    }

    /// Internal fixture route only; production URLs always pass HTTPS validation.
    func loadFixture(_ html: String) {
        reset()
        fixture = true
        start()
        beginNavigation()
        currentNavigation = webView.loadHTMLString(html, baseURL: nil)
    }

    func reload() {
        guard active else { return }
        if let requestedURL { loadRequest(requestedURL) }
        else if fixture {
            beginNavigation()
            currentNavigation = webView.reload()
        }
    }

    func setManuallyHidden(_ hidden: Bool) {
        health.manuallyHidden = hidden
        publishHealth()
    }

    func stop() {
        active = false
        generation += 1
        loop?.cancel()
        healthLoop?.cancel()
        webView.stopLoading()
        currentNavigation = nil
        visible = false
        healthy = false
        status = "Overlay stopped · load to resume"
    }

    private func reset() {
        stop()
        image = nil
        health = OverlayHealth()
        requestedURL = nil
        loaded = false
        sourceAccepted = false
        freshDocument = false
        failed = false
    }

    private func beginNavigation() {
        generation += 1
        loaded = false
        sourceAccepted = false
        freshDocument = false
        navigationStarted = now
        awaitingProgrammaticStart = true
    }

    private func loadRequest(_ url: URL) {
        beginNavigation()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        currentNavigation = webView.load(request)
    }

    private func start() {
        active = true
        sessionStarted = now
        status = "Loading overlay…"
        // Serialized loop: never overlap JavaScript/snapshot requests, including reloads.
        // A separate ticker enforces the deadline even if WebKit stalls.
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.active else { return }
                let start = self.now
                await self.capture()
                let delay = max(0.05, self.captureInterval - (self.now - start))
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            }
        }
        healthLoop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.active else { return }
                self.publishHealth()
                if self.webView.isLoading && self.now - self.navigationStarted >= 6 {
                    self.webView.stopLoading()
                    self.markFailure()
                }
                // A page with its own reloads (reference: 2 s) never reaches this.
                // Otherwise refresh the actual document before source freshness expires;
                // no separate reachability probe can certify its scoring backend.
                if !self.failed, self.loaded, !self.webView.isLoading,
                   let source = self.health.sourceTime, self.now - source >= 8,
                   let url = self.requestedURL {
                    self.loaded = false
                    self.loadRequest(url)
                }
                if self.failed && self.now >= self.retryAt, let url = self.requestedURL {
                    self.failed = false
                    self.loadRequest(url)
                }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
        }
    }

    private func publishHealth() {
        guard active else { visible = false; healthy = false; return }
        health.expire(at: now)
        healthy = health.isHealthy(at: now) && health.recovered
        visible = health.isVisible(at: now)
        if health.manuallyHidden { status = "Overlay manually hidden" }
        else if healthy { status = "Overlay healthy" }
        else if failed || image != nil || now - sessionStarted >= 10 { status = "Overlay unavailable · waiting for source access and a fresh render" }
    }

    private func capture() async {
        guard active, !captureBusy, loaded, webView.window != nil else { return }
        captureBusy = true
        defer { captureBusy = false }
        let token = generation
        let start = now
        do {
            // Wait up to 750 ms for fonts/images. Broken resources cannot prevent all
            // future captures; a loaded DOM with layout is still required afterwards.
            let result = try await webView.evaluateJavaScript("""
            ({width:innerWidth,height:innerHeight,
              ready:document.readyState!=='loading' && !!document.body && document.body.children.length>0,
              resources:[...document.images].every(i=>i.complete) && document.fonts.status==='loaded'})
            """)
            guard active, token == generation, loaded,
                  let values = result as? [String: Any], values["ready"] as? Bool == true,
                  (values["width"] as? Int) == 1920, (values["height"] as? Int) == 1080,
                  values["resources"] as? Bool == true || now - loadedAt >= 0.75 else { return }
            let configuration = WKSnapshotConfiguration()
            configuration.rect = CGRect(origin: .zero, size: Self.canvas)
            // snapshotWidth is in points; request video pixels rather than a 3×
            // phone-scale raster, then normalize defensively off the main actor.
            configuration.snapshotWidth = NSNumber(value: 1920 / max(webView.traitCollection.displayScale, 1))
            configuration.afterScreenUpdates = true
            let snapshot = try await webView.takeSnapshot(configuration: configuration)
            guard let source = snapshot.cgImage else { return }
            let normalized = await Task.detached(priority: .utility) { Self.normalize(source) }.value
            guard active, token == generation, loaded,
                  let cgImage = normalized else { return }
            health.expire(at: now)
            image = cgImage
            health.rendered(at: now, freshDocument: freshDocument)
            // Once an outage has expired, cached snapshots cannot re-enable the layer.
            freshDocument = false
            captureMilliseconds = (now - start) * 1000
            viewport = "1920×1080 CSS → \(cgImage.width)×\(cgImage.height) pixels"
            publishHealth()
        } catch {
            // Preserve the last good image. Deadline ticker handles persistent failure.
        }
    }

    nonisolated static func normalize(_ source: CGImage) -> CGImage? {
        guard let context = CGContext(data: nil, width: 1920, height: 1080,
                bitsPerComponent: 8, bytesPerRow: 1920 * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        return context.makeImage()
    }

    private func markFailure() {
        generation += 1
        loaded = false
        sourceAccepted = false
        freshDocument = false
        failed = true
        retryAt = now + 2
        // Invalidate a capture from this navigation without restarting the single loop.
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard active else { decisionHandler(.cancel); return }
        guard !navigationAction.shouldPerformDownload else {
            decisionHandler(.cancel)
            if navigationAction.targetFrame?.isMainFrame == true { markFailure() }
            return
        }
        let url = navigationAction.request.url
        guard navigationAction.targetFrame?.isMainFrame == true else {
            decisionHandler(url?.scheme == "https" ? .allow : .cancel)
            return
        }
        if fixture && url?.scheme == "about" { decisionHandler(.allow); return }
        guard let url, Self.validatedURL(url.absoluteString) != nil else {
            decisionHandler(.cancel)
            markFailure()
            return
        }
        // Page-driven reloads must validate the source rather than reuse cached HTML.
        if navigationAction.request.cachePolicy != .reloadIgnoringLocalCacheData {
            decisionHandler(.cancel)
            loadRequest(url)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        guard active else { decisionHandler(.cancel); return }
        if let response = navigationResponse.response as? HTTPURLResponse,
           response.value(forHTTPHeaderField: "Content-Disposition")?.lowercased().contains("attachment") == true {
            decisionHandler(.cancel)
            markFailure()
            return
        }
        if navigationResponse.isForMainFrame {
            let response = navigationResponse.response as? HTTPURLResponse
            sourceAccepted = fixture || (response.map { (200..<300).contains($0.statusCode) } == true)
            guard sourceAccepted, navigationResponse.canShowMIMEType,
                  navigationResponse.response.mimeType == "text/html" else {
                decisionHandler(.cancel)
                markFailure()
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard active, !awaitingProgrammaticStart || navigation === currentNavigation else { return }
        awaitingProgrammaticStart = false
        currentNavigation = navigation
        generation += 1
        loaded = false
        sourceAccepted = false
        freshDocument = false
        navigationStarted = now
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard active, navigation === currentNavigation, sourceAccepted || fixture else { return }
        loaded = true
        loadedAt = now
        failed = false
        freshDocument = true
        health.sourceSucceeded(at: now)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard active, navigation === currentNavigation, sourceAccepted || fixture else { return }
        failed = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard active, navigation === currentNavigation else { return }
        if (error as NSError).code != NSURLErrorCancelled { markFailure() }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard active, navigation === currentNavigation else { return }
        // Policy cancellation for a forced no-cache reload is expected.
        if (error as NSError).code != NSURLErrorCancelled { markFailure() }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { if active { markFailure() } }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void) { decisionHandler(.deny) }

    func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void) { decisionHandler(.deny) }

    func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void) { decisionHandler(.deny) }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor () -> Void) { completionHandler() }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (Bool) -> Void) { completionHandler(false) }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping @MainActor (String?) -> Void) { completionHandler(nil) }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }
}

/// The WKWebView remains attached, visible and alpha=1. Scaling its layer changes
/// presentation size without changing the CSS viewport or snapshot rectangle.
struct AttachedOverlayView: UIViewRepresentable {
    let renderer: WebOverlayRenderer
    func makeUIView(context: Context) -> OverlayViewport {
        OverlayViewport(webView: renderer.webView)
    }
    func updateUIView(_ uiView: OverlayViewport, context: Context) {}
}

final class OverlayViewport: UIView {
    private let webView: WKWebView
    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        clipsToBounds = true
        isUserInteractionEnabled = false
        addSubview(webView)
    }
    required init?(coder: NSCoder) { nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        webView.transform = .identity
        webView.bounds = CGRect(origin: .zero, size: WebOverlayRenderer.canvas)
        let scale = min(bounds.width / 1920, bounds.height / 1080)
        webView.transform = CGAffineTransform(scaleX: scale, y: scale)
        webView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}
