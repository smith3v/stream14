import Testing
@testable import Stream14

@MainActor
struct OverlayConfigurationTests {
    private let source = "https://127.0.0.1:1/overlay"

    @Test func savedURLStartsOnlyOverlayAndReconcilesStoppedWork() {
        let session = MediaSession(readOverlayURL: { source }, saveOverlayURL: { _ in })
        defer { session.setOverlayForeground(false) }
        #expect(!session.renderer.isRunning)
        session.setOverlayForeground(true)
        #expect(session.renderer.isRunning)
        let browser = session.renderer.webView
        session.reconcileOverlay()
        #expect(session.renderer.webView === browser)
        session.renderer.interruptTickerForTesting()
        #expect(!session.renderer.isRunning)
        session.reconcileOverlay()
        #expect(session.renderer.isRunning)
        #expect(session.renderer.webView === browser)
        session.renderer.setManuallyHidden(true)
        session.renderer.stop()
        session.reconcileOverlay()
        #expect(session.renderer.isRunning)
        #expect(session.renderer.health.manuallyHidden)
        #expect(session.phase == .idle)
        #expect(!session.isRecording)
        session.setOverlayForeground(false)
        session.reconcileOverlay()
        #expect(!session.renderer.isRunning)
        session.setOverlayForeground(true)
        #expect(session.renderer.isRunning)
        #expect(session.phase == .idle)
    }

    @Test func explicitCommitValidationPersistenceFailureAndEmptyDisable() {
        var persisted = source
        var failSaving = false
        var writes = 0
        let session = MediaSession(readOverlayURL: { persisted }, saveOverlayURL: {
            if failSaving { throw OverlayURLStore.StoreError.unavailable }
            writes += 1
            persisted = $0
        })
        defer { session.setOverlayForeground(false) }
        session.setOverlayForeground(true)
        let originalBrowser = session.renderer.webView
        // A local draft has no relationship to the active session until explicitly applied.
        var draft = "https://127.0.0.1:1/replacement"
        draft = ""
        #expect(session.overlayURL == source)
        #expect(session.renderer.webView === originalBrowser)
        #expect(!session.applyOverlayURL("http://invalid.example"))
        #expect(writes == 0)
        failSaving = true
        #expect(!session.applyOverlayURL(draft))
        #expect(session.overlayURL == source)
        #expect(session.renderer.webView === originalBrowser)
        #expect(session.renderer.isRunning)
        failSaving = false
        #expect(session.applyOverlayURL("  https://127.0.0.1:1/replacement  "))
        #expect(session.overlayURL == "https://127.0.0.1:1/replacement")
        #expect(persisted == session.overlayURL)
        #expect(session.renderer.webView !== originalBrowser)
        #expect(session.applyOverlayURL(" \n "))
        #expect(persisted.isEmpty)
        #expect(session.overlayURL.isEmpty)
        #expect(!session.renderer.isRunning)
        #expect(!session.renderer.visible)
        #expect(session.renderer.image == nil)
        session.reconcileOverlay()
        session.setOverlayForeground(false)
        session.setOverlayForeground(true)
        #expect(!session.renderer.isRunning)
        let relaunched = MediaSession(readOverlayURL: { persisted }, saveOverlayURL: { _ in })
        relaunched.setOverlayForeground(true)
        #expect(!relaunched.renderer.isRunning)
        relaunched.setOverlayForeground(false)
    }

    @Test func missingUnreadableAndInvalidSavedURLsDoNotStartNetworking() {
        func check(_ read: @MainActor () throws -> String) {
            let session = MediaSession(readOverlayURL: read, saveOverlayURL: { _ in })
            session.setOverlayForeground(true)
            session.reconcileOverlay()
            #expect(!session.renderer.isRunning)
            #expect(session.phase == .idle)
            session.setOverlayForeground(false)
        }
        check { "" }
        check { "http://invalid.example" }
        check { throw OverlayURLStore.StoreError.unavailable }
    }
}
