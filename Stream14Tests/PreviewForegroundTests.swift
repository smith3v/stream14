import Foundation
import Testing
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
        for index in 30..<42 {
            #expect(media.offerRecordingInputFixture(try LocalRecorderTests.video(index, profile: .hd)))
            #expect(media.offerRecordingInputFixture(try LocalRecorderTests.audio(index)))
            try await Task.sleep(for: .milliseconds(20))
        }
        try await until { media.hasStartedWriting }
        await media.stopRecording()
        try #require(media.phase == .preview && !media.recordingFailed)
        media.setCaptureForeground(false)
        media.setCaptureForeground(true)
        try await until { media.phase == .preview && opens == 2 }
        media.requestStop()
        try await until { media.phase == .idle }
    }

    private func session(authorize: @escaping @MainActor () async -> Bool = { true }) -> MediaSession {
        MediaSession(readOverlayURL: { "" }, saveOverlayURL: { _ in }, profile: .hd,
                     persistProfile: { _ in }, authorizeCapture: authorize)
    }
    private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<400 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(condition())
    }
}
