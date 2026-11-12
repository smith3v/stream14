import Observation
import SwiftUI
import WebKit

/// Public handoff: `image` is an immutable selected-profile raster. Consumers must apply
/// `visible` as well; keeping an image in memory never establishes source health.
@MainActor
@Observable
final class WebOverlayRenderer: NSObject, WKNavigationDelegate, WKUIDelegate {
    static let canvas = SessionProfile.fullHD.size
    private(set) var profile: SessionProfile
    var canvasSize: CGSize { profile.size }
    private(set) var webView: WKWebView
    private(set) var image: CGImage?
    private(set) var visible = false
    private(set) var healthy = false
    private(set) var status = "Overlay disabled · apply an HTTPS URL to enable it."
    private(set) var captureMilliseconds: Double = 0
    private(set) var viewport = "No render yet"
    private(set) var health = OverlayHealth()
    var captureInterval: TimeInterval = 1
    var isRunning: Bool { active && ticker?.isValid == true }
    #if DEBUG
    enum CaptureInjection { case none, stalled, unusable }
    var captureInjection: CaptureInjection = .none
    func interruptTickerForTesting() { ticker?.invalidate() }
    #endif
    private var ticker: Timer?
    private var nextCapture: TimeInterval = 0
    private var captureStarted: TimeInterval?
    private var renderAttemptStarted: TimeInterval = 0
    private var fixtureHTML: String?
    private let clock: () -> TimeInterval
    private var generation = 0
    private var currentNavigation: WKNavigation?
    private var awaitingProgrammaticStart = false
    private var loaded = false
    private var loadedAt: TimeInterval = 0
    private var navigationStarted: TimeInterval = 0
    private var sourceAccepted = false
    private var failed = false
    private var retryAt: TimeInterval = 0
    private var active = false
    private var sessionStarted: TimeInterval = 0
    private var requestedURL: URL?
    private var fixture = false
    private var freshDocument = false
    private var now: TimeInterval { clock() }

    init(profile: SessionProfile = .fullHD, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.profile = profile
        self.clock = clock
        webView = Self.makeWebView(size: profile.size)
        super.init()
        configureDelegates()
    }

    private static func makeWebView(size: CGSize, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) -> WKWebView {
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.insetsLayoutMarginsFromSafeArea = false
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.pageZoom = 1
        return view
    }

    private func configureDelegates() {
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    /// A new document cannot execute scripts or deliver results into the old session.
    private func replaceBrowser() {
        generation += 1
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.stopLoading()
        let host = webView.superview as? OverlayViewport
        let configuration = webView.configuration
        webView.removeFromSuperview()
        webView = Self.makeWebView(size: profile.size, configuration: configuration)
        configureDelegates()
        host?.setWebView(webView)
        currentNavigation = nil
        awaitingProgrammaticStart = false
        captureStarted = nil
        loaded = false
        sourceAccepted = false
        freshDocument = false
        renderAttemptStarted = now
        nextCapture = now
    }

    /// MediaSession calls this only with capture closed. Retire old callbacks and
    /// raster immediately; source/manual-hide intent survives the canvas rebuild.
    func setProfile(_ profile: SessionProfile) {
        guard profile != self.profile else { return }
        let url = requestedURL
        let html = fixtureHTML
        let wasActive = active
        self.profile = profile
        reset()
        if wasActive, let url { load(url.absoluteString) }
        else if wasActive, let html { loadFixture(html) }
    }

    static func validatedURL(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
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
        fixtureHTML = nil
        start()
        loadRequest(url)
    }

    /// Internal fixture route only; production URLs always pass HTTPS validation.
    func loadFixture(_ html: String) {
        reset()
        fixture = true
        fixtureHTML = html
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

    /// Foreground intent is owned by MediaSession, so this is suspension, not disable.
    func stop() {
        active = false
        ticker?.invalidate()
        ticker = nil
        replaceBrowser()
        image = nil
        visible = false
        healthy = false
        status = "Overlay paused · resumes when the app is active"
    }

    func disable() {
        guard active || requestedURL != nil || fixture || image != nil else {
            status = "Overlay disabled · apply an HTTPS URL to enable it."
            return
        }
        reset()
        status = "Overlay disabled · apply an HTTPS URL to enable it."
    }

    func ensureRunning(_ text: String) {
        guard let url = Self.validatedURL(text) else { return }
        if !active || requestedURL != url { load(text) }
        else if ticker?.isValid != true { installTicker() }
    }

    private func reset() {
        let hidden = health.manuallyHidden
        stop()
        health = OverlayHealth()
        health.manuallyHidden = hidden
        requestedURL = nil
        fixture = false
        fixtureHTML = nil
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
        renderAttemptStarted = now
        status = "Loading overlay…"
        installTicker()
    }

    private func installTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] timer in
            // Registered on the main run loop; no media work runs here.
            guard self != nil else { timer.invalidate(); return }
            MainActor.assumeIsolated { self?.supervise() }
        }
        ticker = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Independent of JS/snapshot completion. Time is injectable for deadline tests.
    func supervise() {
        guard active else { return }
        publishHealth()
        if let captureStarted, now - captureStarted >= 6 {
            recoverBrowser()
            return
        }
        if !failed, currentNavigation != nil, !loaded, now - navigationStarted >= 6 {
            webView.stopLoading()
            markFailure()
        }
        if failed {
            if now >= retryAt { recoverBrowser() }
            return
        }
        // No usable render, even though navigation or JS callbacks may keep arriving.
        // Do not restart simply because a static scoreboard has identical pixels.
        if webView.window != nil, now - max(health.renderTime ?? renderAttemptStarted, renderAttemptStarted) >= 10 {
            recoverBrowser()
            return
        }
        // Reference-page self-refreshes reset sourceTime, so no extra reload timer.
        if loaded, !webView.isLoading, let source = health.sourceTime,
           now - source >= 8, let url = requestedURL {
            loadRequest(url)
        }
        if now >= nextCapture, captureStarted == nil {
            capture()
        }
    }

    private func recoverBrowser() {
        replaceBrowser()
        failed = false
        if let requestedURL { loadRequest(requestedURL) }
        else if let fixtureHTML {
            beginNavigation()
            currentNavigation = webView.loadHTMLString(fixtureHTML, baseURL: nil)
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

    private func capture() {
        guard active, captureStarted == nil, loaded, webView.window != nil else { return }
        let token = generation
        let browser = webView
        let started = now
        captureStarted = started
        nextCapture = started + captureInterval
        #if DEBUG
        if captureInjection == .stalled { return }
        if captureInjection == .unusable { captureStarted = nil; return }
        #endif
        // Callback APIs avoid a suspended task retaining a renderer forever if WebKit
        // never answers. Deadlines retire the whole browser, never overlapping captures
        // on that browser. Every callback validates both browser identity and generation.
        browser.evaluateJavaScript("""
        ({width:innerWidth,height:innerHeight,
          ready:document.readyState!=='loading' && !!document.body && document.body.children.length>0,
          resources:[...document.images].every(i=>i.complete) && document.fonts.status==='loaded'})
        """) { [weak self, weak browser] result, _ in
            guard let self, let browser, self.active, browser === self.webView else { return }
            guard token == self.generation else { self.captureStarted = nil; return }
            guard self.loaded, let values = result as? [String: Any],
                  values["ready"] as? Bool == true,
                  (values["width"] as? Int) == self.profile.width, (values["height"] as? Int) == self.profile.height,
                  values["resources"] as? Bool == true || self.now - self.loadedAt >= 0.75 else {
                self.captureStarted = nil
                return
            }
            let configuration = WKSnapshotConfiguration()
            configuration.rect = CGRect(origin: .zero, size: self.canvasSize)
            configuration.snapshotWidth = NSNumber(value: self.canvasSize.width / max(browser.traitCollection.displayScale, 1))
            configuration.afterScreenUpdates = true
            browser.takeSnapshot(with: configuration) { [weak self, weak browser] snapshot, _ in
                guard let self, let browser, self.active, browser === self.webView else { return }
                guard token == self.generation else { self.captureStarted = nil; return }
                guard let source = snapshot?.cgImage else {
                    self.captureStarted = nil
                    return
                }
                Task { [weak self, weak browser] in
                    let profile = self?.profile ?? .fullHD
                    let normalized = await Task.detached(priority: .utility) { Self.normalize(source, profile: profile) }.value
                    guard let self, let browser, self.active, browser === self.webView else { return }
                    guard token == self.generation else { self.captureStarted = nil; return }
                    self.captureStarted = nil
                    guard self.loaded, let normalized else { return }
                    self.health.expire(at: self.now)
                    self.image = normalized
                    self.health.rendered(at: self.now, freshDocument: self.freshDocument)
                    self.freshDocument = false
                    self.captureMilliseconds = (self.now - started) * 1000
                    self.viewport = "\(self.profile.width)×\(self.profile.height) CSS → \(self.profile.width)×\(self.profile.height) pixels"
                    self.publishHealth()
                }
            }
        }
    }

    nonisolated static func normalize(_ source: CGImage, profile: SessionProfile = .fullHD) -> CGImage? {
        guard let context = CGContext(data: nil, width: profile.width, height: profile.height,
                bitsPerComponent: 8, bytesPerRow: profile.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: profile.width, height: profile.height))
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
        guard active, webView === self.webView else { decisionHandler(.cancel); return }
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
        guard active, webView === self.webView else { decisionHandler(.cancel); return }
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
        guard active, webView === self.webView, !awaitingProgrammaticStart || navigation === currentNavigation else { return }
        awaitingProgrammaticStart = false
        currentNavigation = navigation
        generation += 1
        loaded = false
        sourceAccepted = false
        freshDocument = false
        navigationStarted = now
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard active, webView === self.webView, navigation === currentNavigation, sourceAccepted || fixture else { return }
        loaded = true
        loadedAt = now
        failed = false
        freshDocument = true
        health.sourceSucceeded(at: now)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard active, webView === self.webView, navigation === currentNavigation, sourceAccepted || fixture else { return }
        failed = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard active, webView === self.webView, navigation === currentNavigation else { return }
        if (error as NSError).code != NSURLErrorCancelled { markFailure() }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard active, webView === self.webView, navigation === currentNavigation else { return }
        // Policy cancellation for a forced no-cache reload is expected.
        if (error as NSError).code != NSURLErrorCancelled { markFailure() }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { if active, webView === self.webView { markFailure() } }

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

/// Keep the snapshot window scoped to the scene that owns the overlay.
struct AttachedOverlayView: UIViewRepresentable {
    let renderer: WebOverlayRenderer
    func makeUIView(context: Context) -> OverlaySnapshotHost {
        OverlaySnapshotHost(webView: renderer.webView)
    }
    func updateUIView(_ uiView: OverlaySnapshotHost, context: Context) { uiView.setWebView(renderer.webView) }
}

final class OverlaySnapshotHost: UIView {
    private let viewport: OverlayViewport
    private var snapshotWindow: UIWindow?

    init(webView: WKWebView) {
        viewport = OverlayViewport(webView: webView)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { nil }

    func setWebView(_ view: WKWebView) { viewport.setWebView(view) }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        let scene = window?.windowScene
        guard snapshotWindow?.windowScene !== scene else { return }
        viewport.removeFromSuperview()
        snapshotWindow?.windowScene = nil
        snapshotWindow = nil
        guard let scene else { return }

        // The visible-window WebKit snapshot loses alpha on the iPhone 13 mini.
        // Attach the viewport directly because a hidden window does not lay out
        // its root controller. This window never becomes visible or key.
        let window = UIWindow(windowScene: scene)
        window.isUserInteractionEnabled = false
        viewport.frame = CGRect(x: 0, y: 0, width: 320, height: 60)
        window.addSubview(viewport)
        viewport.layoutIfNeeded()
        snapshotWindow = window
    }
}

/// Scale the attached view without changing its CSS canvas or snapshot rectangle.
private final class OverlayViewport: UIView {
    private var webView: WKWebView
    private var canvasSize: CGSize
    init(webView: WKWebView) {
        self.webView = webView
        canvasSize = webView.bounds.size
        super.init(frame: .zero)
        clipsToBounds = true
        isUserInteractionEnabled = false
        addSubview(webView)
    }
    func setWebView(_ view: WKWebView) {
        guard webView !== view else { return }
        webView.removeFromSuperview()
        webView = view
        canvasSize = view.bounds.size
        addSubview(view)
        setNeedsLayout()
        layoutIfNeeded()
    }
    required init?(coder: NSCoder) { nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        webView.transform = .identity
        webView.bounds = CGRect(origin: .zero, size: canvasSize)
        let scale = min(bounds.width / canvasSize.width, bounds.height / canvasSize.height)
        webView.transform = CGAffineTransform(scaleX: scale, y: scale)
        webView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}
