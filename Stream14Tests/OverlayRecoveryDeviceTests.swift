import AVFoundation
import Foundation
import Testing
import UIKit
import WebKit
@testable import Stream14

/// Explicit opt-in: real camera/microphone recording; preserves owner URL and originals.
@Suite(.serialized)
struct OverlayRecoveryDeviceTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STREAM14_OVERLAY_RECOVERY_DEVICE"] == "1"))
    @MainActor func recordingSurvivesOverlayFailures() async throws {
        var configured = "https://heren14-overlay.smith3v.com/overlay.html"
        let session = MediaSession(readOverlayURL: { configured }, saveOverlayURL: { configured = $0 })
        let previousIdle = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        let host = OverlayViewport(webView: session.renderer.webView)
        host.frame = CGRect(x: 0, y: 60, width: 320, height: 180)
        controller.view.addSubview(host)
        session.preview.frame = CGRect(x: 0, y: 240, width: 320, height: 180)
        controller.view.addSubview(session.preview)
        window.makeKeyAndVisible()
        defer {
            session.setOverlayForeground(false)
            session.requestStop()
            window.isHidden = true
            UIApplication.shared.isIdleTimerDisabled = previousIdle
        }
        session.setOverlayForeground(true)
        host.layoutIfNeeded()
        try await wait(session) { $0.renderer.visible }
        await session.openPreview()
        let ready = session.canRecord
        try #require(ready)
        // Let the real camera settle before measuring a recovery recording.
        try await Task.sleep(for: .seconds(2))
        await session.record()
        let recording = session.isRecording
        try #require(recording)
        let recordingID = session.recordingID
        try await Task.sleep(for: .seconds(2))
        let changeWhileRecording = session.applyOverlayURL("")
        #expect(!changeWhileRecording)
        #expect(!configured.isEmpty)
        // Simulate stopped renderer timer, then use the independent owner reconciler.
        session.renderer.interruptTickerForTesting()
        session.reconcileOverlay()
        let supervised = session.renderer.isRunning
        #expect(supervised)
        let beforeStall = session.renderer.health.renderTime ?? 0
        let oldBrowser = ObjectIdentifier(session.renderer.webView)
        session.renderer.captureInjection = .stalled
        try await wait(session) { ObjectIdentifier($0.renderer.webView) != oldBrowser }
        session.renderer.captureInjection = .none
        try await wait(session) { $0.renderer.visible && ($0.renderer.health.renderTime ?? 0) > beforeStall }
        let afterStall = session.isRecording && session.recordingID == recordingID
        #expect(afterStall)
        // Deny real document requests, retaining normal TLS and the phone's radios.
        let rule = try await WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "stream14-overlay-recovery-outage", encodedContentRuleList:
                #"[{"trigger":{"url-filter":".*","resource-type":["document"]},"action":{"type":"block"}}]"#)
        let blocker = try #require(rule)
        session.renderer.webView.configuration.userContentController.add(blocker)
        session.renderer.reload()
        try await Task.sleep(for: .seconds(11))
        let hiddenDuringOutage = !session.renderer.visible
        #expect(hiddenDuringOutage)
        let recordingDuringOutage = session.isRecording && session.recordingID == recordingID
        #expect(recordingDuringOutage)
        session.renderer.setManuallyHidden(true)
        session.renderer.webView.configuration.userContentController.removeAllContentRuleLists()
        try await wait(session) { $0.renderer.healthy }
        let manuallyHidden = !session.renderer.visible && session.renderer.health.manuallyHidden
        #expect(manuallyHidden)
        session.renderer.setManuallyHidden(false)
        let restored = session.renderer.visible
        #expect(restored)
        // Allow compositor handoff and encoded frames, not only renderer state.
        try await Task.sleep(for: .seconds(2))
        let beforeTermination = session.renderer.health.renderTime ?? 0
        session.renderer.webViewWebContentProcessDidTerminate(session.renderer.webView)
        try await wait(session) { $0.renderer.visible && ($0.renderer.health.renderTime ?? 0) > beforeTermination }
        let stillRecording = session.isRecording && session.recordingID == recordingID
        #expect(stillRecording)
        try await Task.sleep(for: .seconds(2))
        await session.stopRecording()
        let completedURL = session.sampleURL
        let url = try #require(completedURL)
        let sample = session.savedSamples.first { $0.id == recordingID }
        let saved = try #require(sample)
        #expect(saved.status == .completed)
        let videos = try await AVURLAsset(url: url).loadTracks(withMediaType: .video)
        let audios = try await AVURLAsset(url: url).loadTracks(withMediaType: .audio)
        #expect(videos.count == 1 && audios.count == 1)
        print("Overlay recovery recording retained: \(saved.id); video frames: \(saved.metrics?.videoWritten ?? 0)")
        let disabled = session.applyOverlayURL("")
        #expect(disabled)
        session.setOverlayForeground(false)
        session.setOverlayForeground(true)
        let staysDisabled = !session.renderer.isRunning && !session.renderer.visible && session.renderer.image == nil
        #expect(staysDisabled)
    }

    @MainActor private func wait(_ session: MediaSession, until condition: (MediaSession) -> Bool) async throws {
        for _ in 0..<200 {
            session.reconcileOverlay()
            if condition(session) { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        // Avoid reflecting a renderer/session that might contain a private URL.
        let satisfied = condition(session)
        try #require(satisfied)
    }
}
