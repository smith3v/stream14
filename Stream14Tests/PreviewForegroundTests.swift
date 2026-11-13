import AVFoundation
import Foundation
@testable import HaishinKit
import Testing
import UIKit
@testable import Stream14

@MainActor @Suite(.serialized, .timeLimit(.minutes(1))) struct PreviewForegroundTests {
    @Test func previewReturnsOnlyAfterBackgroundAndCompleteTeardown() async throws {
        let media = session()
        var opens = 0
        var closing: CheckedContinuation<Void, Never>?
        var holdClose = true
        media.installPreviewLifecycleFixture(start: { opens += 1 }, close: {
            if holdClose { holdClose = false; await withCheckedContinuation { closing = $0 } }
        })
        await media.openPreview()
        #expect(media.phase == .preview && opens == 1)
        media.setCaptureForeground(false)
        try await until { closing != nil }
        #expect(media.phase == .stopping && !media.canRecord)
        media.setCaptureForeground(true)
        media.setCaptureForeground(true)
        await Task.yield()
        #expect(opens == 1)
        closing?.resume()
        try await until { media.phase == .preview && opens == 2 }
        media.setCaptureForeground(true)
        await Task.yield()
        #expect(opens == 2)
        media.requestStop()
        try await until { media.phase == .idle }
    }

    @Test func captureKeepsItsLandscapeOrientationUntilItReopens() async throws {
        @MainActor final class OrientationSource {
            var current = UIInterfaceOrientation.landscapeLeft
            var reads = 0
        }
        let source = OrientationSource()
        let media = session(orientation: {
            source.reads += 1
            return source.current
        })
        media.installPreviewLifecycleFixture(start: {})
        await media.openPreview()
        #expect(media.phase == .preview)
        #expect(await media.mixer.videoOrientation == .landscapeLeft)

        source.current = .portrait
        media.setCaptureForeground(true)
        await media.openPreview()
        #expect(await media.mixer.videoOrientation == .landscapeLeft)
        #expect(source.reads == 1)

        media.setCaptureForeground(false)
        try await until { media.phase == .idle }
        media.setCaptureForeground(true)
        try await until { media.phase == .preview }
        #expect(await media.mixer.videoOrientation == .landscapeRight)
        #expect(source.reads == 2)

        media.requestStop()
        try await until { media.phase == .idle }
        source.current = .landscapeRight
        await media.openPreview()
        #expect(await media.mixer.videoOrientation == .landscapeRight)
        #expect(source.reads == 3)
        media.requestStop()
        try await until { media.phase == .idle }
    }

    @Test func earlySystemInterruptionDoesNotLosePreviewReturnIntent() async throws {
        for reason in [SessionInterruption.camera, .audio, .audioUnavailable] {
            let media = session()
            var opens = 0
            media.installPreviewLifecycleFixture(start: { opens += 1 })
            await media.openPreview()
            media.interrupt(reason)
            try await until { media.phase == .idle }
            media.setCaptureForeground(false)
            media.setCaptureForeground(true)
            try await until { media.phase == .preview && opens == 2 }
            media.requestStop()
            try await until { media.phase == .idle }
        }
    }

    @Test func lateNativeStartNeverBecomesRecordableAfterBackground() async throws {
        let media = session()
        var opening: CheckedContinuation<Void, Never>?
        var opens = 0
        media.installPreviewLifecycleFixture(start: {
            opens += 1
            if opens == 1 { await withCheckedContinuation { opening = $0 } }
        })
        let task = Task { await media.openPreview() }
        try await until { opening != nil }
        media.setCaptureForeground(false)
        opening?.resume()
        await task.value
        #expect(!media.canRecord)
        try await until { media.phase == .idle }
        #expect(opens == 1)
        media.setCaptureForeground(true)
        try await until { media.phase == .preview && opens == 2 }
        media.requestStop()
        try await until { media.phase == .idle }
    }

    @Test func closeCancelsPendingReturnAndRapidCyclesDoNotOpenInBackground() async throws {
        let media = session()
        var opens = 0
        media.installPreviewLifecycleFixture(start: { opens += 1 })
        await media.openPreview()
        media.setCaptureForeground(false)
        media.setCaptureForeground(true)
        media.setCaptureForeground(false)
        try await until { media.phase == .idle }
        for _ in 0..<10 { await Task.yield() }
        #expect(opens == 1)
        media.requestStop()
        media.setCaptureForeground(true)
        for _ in 0..<10 { await Task.yield() }
        #expect(media.phase == .idle && opens == 1)
    }

    @Test func backgroundDuringPermissionPromptResumesOnlyOnceAfterReturn() async throws {
        var permission: CheckedContinuation<Bool, Never>?
        var permissions = 0
        let media = session(authorize: {
            permissions += 1
            if permissions == 1 { return await withCheckedContinuation { permission = $0 } }
            return true
        })
        var opens = 0
        media.installPreviewLifecycleFixture(start: { opens += 1 })
        let task = Task { await media.openPreview() }
        try await until { permission != nil }
        media.setCaptureForeground(false)
        media.setCaptureForeground(true)
        permission?.resume(returning: true)
        await task.value
        try await until { media.phase == .preview }
        #expect(opens == 1 && permissions == 2)
        media.requestStop()
        try await until { media.phase == .idle }
    }

    @Test func setupFailureDoesNotLoopOnSubsequentForeground() async throws {
        enum Failure: Error { case unavailable }
        let media = session()
        var opens = 0
        media.installPreviewLifecycleFixture(start: { opens += 1; throw Failure.unavailable })
        await media.openPreview()
        try await until { media.phase == .idle }
        media.setCaptureForeground(false)
        media.setCaptureForeground(true)
        for _ in 0..<10 { await Task.yield() }
        #expect(opens == 1 && media.phase == .idle && !media.canRecord)
    }

    @Test func confirmedBroadcastPreparationAndRecordingNeverAutoReopen() async throws {
        for recording in [false, true] {
            let media = session()
            var opens = 0
            media.installPreviewLifecycleFixture(start: { opens += 1 })
            await media.openPreview()
            if recording {
                // Exact Record entry clears preview intent even if native writer
                // initialization fails; return must not silently restart camera.
                await media.record()
                try #require(media.isRecording)
            } else {
                // Coordinator locks configuration before its first async writer/API work.
                media.broadcastConfigurationLocked = true
            }
            media.setCaptureForeground(false)
            media.setCaptureForeground(true)
            try await until { media.phase == .idle }
            for _ in 0..<10 { await Task.yield() }
            #expect(opens == 1 && !media.isRecording && !media.hasUpload)
            media.broadcastConfigurationLocked = false
        }
    }

    @Test func normalForegroundRecordingStopRestoresPreviewEligibility() async throws {
        let media = session()
        var opens = 0
        media.installPreviewLifecycleFixture(start: { opens += 1 })
        await media.openPreview()
        await media.record()
        try #require(media.isRecording)
        var admittedVideo = false
        var admittedAudio = false
        for index in 30..<42 {
            // This lifecycle check needs real readable A/V, not a no-drop promise:
            // the shared encoder intentionally rejects excess admission under load.
            admittedVideo = media.offerRecordingInputFixture(try LocalRecorderTests.video(index, profile: .hd)) || admittedVideo
            admittedAudio = media.offerRecordingInputFixture(try LocalRecorderTests.audio(index)) || admittedAudio
            try await Task.sleep(for: .milliseconds(40))
        }
        try #require(admittedVideo && admittedAudio)
        try await until { media.hasStartedWriting }
        await media.stopRecording()
        try #require(media.phase == .preview && !media.recordingFailed)
        media.setCaptureForeground(false)
        media.setCaptureForeground(true)
        try await until { media.phase == .preview && opens == 2 }
        media.requestStop()
        try await until { media.phase == .idle }
    }

    @Test func stoppedCaptureRetiresMixerAndMetalViewOnlyAfterCompleteClose() async throws {
        let media = session()
        let originalMixer = media.mixer
        let originalView = media.preview
        var closing: CheckedContinuation<Void, Never>?
        media.installPreviewLifecycleFixture(start: {}, close: {
            await withCheckedContinuation { closing = $0 }
        })
        await media.openPreview()
        media.setCaptureForeground(false)
        try await until { closing != nil }
        #expect(media.mixer === originalMixer && media.preview === originalView)
        media.setCaptureForeground(true)
        closing?.resume()
        try await until { media.phase == .preview }
        #expect(media.mixer !== originalMixer && media.preview !== originalView)
        media.installPreviewLifecycleFixture(start: {})
        media.requestStop()
        try await until { media.phase == .idle }
    }

    @Test func previewCannotBecomeReadyUntilActualFrameEvidenceAndCloseCancelsWait() async throws {
        let media = session()
        var ready = false
        var opens = 0
        media.installPreviewLifecycleFixture(start: { opens += 1 }, ready: { ready })
        let first = Task { await media.openPreview() }
        try await until { opens == 1 }
        #expect(media.phase == .preparing && !media.canRecord && !media.broadcastCaptureReady)
        ready = true
        await first.value
        #expect(media.phase == .preview && media.canRecord)
        media.requestStop()
        try await until { media.phase == .idle }
        ready = false
        let second = Task { await media.openPreview() }
        try await until { opens == 2 }
        media.requestStop()
        await second.value
        try await until { media.phase == .idle }
        #expect(!media.canRecord && !media.isRecording && !media.hasUpload)
    }

    @Test func backgroundDuringFrameWaitReopensOnlyFreshPreviewOnReturn() async throws {
        let media = session()
        var ready = false
        var opens = 0
        media.installPreviewLifecycleFixture(start: { opens += 1 }, ready: { ready })
        let first = Task { await media.openPreview() }
        try await until { opens == 1 }
        media.setCaptureForeground(false)
        await first.value
        try await until { media.phase == .idle }
        #expect(!media.canRecord && !media.isRecording && !media.hasUpload)
        ready = true
        media.setCaptureForeground(true)
        try await until { media.phase == .preview && opens == 2 }
        #expect(!media.isRecording && !media.hasUpload)
        media.requestStop()
        try await until { media.phase == .idle }
    }

    @Test func stalledFrameReadinessFailsWithoutRecordingOrAutomaticRetry() async throws {
        let media = session()
        var opens = 0
        media.installPreviewLifecycleFixture(start: { opens += 1 }, ready: { false }, frameTimeout: .milliseconds(30))
        await media.openPreview()
        try await until { media.phase == .idle }
        let message = media.message
        #expect(message.contains("fresh frames") && !media.canRecord && !media.isRecording)
        media.setCaptureForeground(false)
        media.setCaptureForeground(true)
        for _ in 0..<10 { await Task.yield() }
        #expect(opens == 1 && media.phase == .idle)
    }

    @Test func rawCameraProgressAndSubsequentCompositionAreBothRequired() throws {
        let readiness = PreviewFrameReadiness()
        let mixer = MediaMixer(captureSessionMode: .manual)
        let camera = PreviewFrameObserver(readiness: readiness, camera: true)
        let composed = PreviewFrameObserver(readiness: readiness, camera: false)
        #expect(camera.videoTrackId == 0 && composed.videoTrackId == .max)
        let first = try LocalRecorderTests.video(30, profile: .hd)
        let second = try LocalRecorderTests.video(31, profile: .hd)
        composed.mixer(mixer, didOutput: first)
        #expect(!readiness.isReady)
        camera.mixer(mixer, didOutput: first)
        camera.mixer(mixer, didOutput: first)
        composed.mixer(mixer, didOutput: second)
        #expect(!readiness.isReady)
        camera.mixer(mixer, didOutput: second)
        #expect(!readiness.isReady)
        composed.mixer(mixer, didOutput: second)
        #expect(readiness.isReady)
        #expect(!PreviewFrameReadiness().isReady)
    }

    @Test func pinnedScreenResetRetainsTimingWhileFreshScreenDoesNotStallAfterGap() async throws {
        let result = await Task { @ScreenActor in
            func tick(_ time: Double) -> DisplayLinkTime {
                DisplayLinkTime(timestamp: time, targetTimestamp: time + 1.0 / 30)
            }
            let reused = Screen()
            _ = reused.makeSampleBuffer(tick(100))
            reused.setVideoCaptureLatency(CMTime(seconds: 100.02, preferredTimescale: 1_000_000))
            _ = reused.makeSampleBuffer(tick(100.033333))
            reused.reset()
            // On reopening, camera input can precede the first new display tick.
            reused.setVideoCaptureLatency(CMTime(seconds: 120, preferredTimescale: 1_000_000))
            let jumped = reused.makeSampleBuffer(tick(120))
            reused.setVideoCaptureLatency(CMTime(seconds: 120.02, preferredTimescale: 1_000_000))
            let suppressed = reused.makeSampleBuffer(tick(120.033333))
            let fresh = Screen()
            fresh.setVideoCaptureLatency(CMTime(seconds: 120, preferredTimescale: 1_000_000))
            let initial = fresh.makeSampleBuffer(tick(120))
            fresh.setVideoCaptureLatency(CMTime(seconds: 120.02, preferredTimescale: 1_000_000))
            let next = fresh.makeSampleBuffer(tick(120.033333))
            return (jumped?.presentationTimeStamp.seconds, suppressed == nil,
                    initial?.presentationTimeStamp.seconds, next?.presentationTimeStamp.seconds)
        }.value
        #expect((result.0 ?? 0) > 139 && result.1)
        #expect(result.2 == 120 && (result.3 ?? 0) > 120 && (result.3 ?? 999) < 121)
    }

    private func session(orientation: @escaping @MainActor () -> UIInterfaceOrientation = { .unknown },
                         authorize: @escaping @MainActor () async -> Bool = { true }) -> MediaSession {
        MediaSession(readOverlayURL: { "" }, saveOverlayURL: { _ in }, profile: .hd,
                     persistProfile: { _ in }, interfaceOrientation: orientation, authorizeCapture: authorize)
    }
    private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<400 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(condition())
    }
}
