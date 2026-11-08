import AVFoundation
import Darwin
import Testing
import UIKit
@testable import Stream14

/// Explicit private camera/microphone opt-in. This is a short local smoke, not
/// network, physical A/V sync, storage-failure or long-event qualification.
@Suite(.serialized)
struct ShortPhoneSmokeTests {
    nonisolated private static var shouldRun: Bool {
        #if DEBUG && !targetEnvironment(simulator)
        ProcessInfo.processInfo.environment["STREAM14_SHORT_DEVICE_SMOKE"] == "1"
        #else
        false
        #endif
    }

    @Test(.enabled(if: Self.shouldRun), .timeLimit(.minutes(1)))
    @MainActor func twoProfilesRetainComposedOriginals() async throws {
        guard Self.hardwareModel() == "iPhone14,4" else { throw SmokeFailure.requires13Mini }
        guard Self.hasPermissions else { throw SmokeFailure.permissionsRequired }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(50))
        let previousIdle = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = previousIdle }
        for profile in SessionProfile.allCases {
            try Task.checkCancellation()
            guard clock.now < deadline else { throw SmokeFailure.deadline }
            let clip = try await capture(profile: profile, deadline: deadline)
            // File inspection runs after capture closes, off the main actor.
            let inspection = Task.detached { try await Self.inspect(clip) }
            let result = try await withTaskCancellationHandler {
                try await inspection.value
            } onCancel: { inspection.cancel() }
            #expect(result.validMedia)
            #expect(result.redMarker && result.greenMarker)
            print("Short phone smoke \(profile.rawValue): retained \(clip.id.uuidString), duration \(result.duration)s")
        }
    }

    @MainActor private func capture(profile: SessionProfile, deadline: ContinuousClock.Instant) async throws -> SmokeClip {
        let session = MediaSession(readOverlayURL: { "" }, saveOverlayURL: { _ in },
            profile: profile, persistProfile: { _ in }, authorizeCapture: { Self.hasPermissions })
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        controller.view.backgroundColor = .systemBackground
        let host = OverlayViewport(webView: session.renderer.webView)
        host.frame = CGRect(x: 0, y: 0, width: 320, height: 60)
        controller.view.addSubview(host)
        let cover = UIView(frame: controller.view.bounds)
        cover.backgroundColor = .systemBackground
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.view.addSubview(cover)
        session.preview.frame = CGRect(x: 0, y: 80, width: 320, height: 180)
        controller.view.addSubview(session.preview)
        window.makeKeyAndVisible()
        host.layoutIfNeeded()
        defer {
            session.renderer.disable()
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        do {
            session.renderer.loadFixture(Self.fixture)
            try await wait(until: deadline, seconds: 5) { session.renderer.visible }
            let image = try #require(session.renderer.image)
            let data = try #require(image.dataProvider?.data)
            let bytes = try #require(CFDataGetBytePtr(data))
            let alphaCorrect = bytes[3] == 0 && bytes[(40 * profile.width + 40) * 4 + 3] == 128
            #expect(image.width == profile.width && image.height == profile.height)
            #expect(alphaCorrect)
            #expect(host.window != nil && !host.isHidden && host.alpha == 1)

            await session.openPreview()
            try Task.checkCancellation()
            guard ContinuousClock().now < deadline else { throw SmokeFailure.deadline }
            let ready = session.canRecord
            try #require(ready)
            let originalProfile = session.profile
            session.selectProfile(profile == .fullHD ? .hd : .fullHD)
            let frozenProfile = session.profile == originalProfile
            #expect(frozenProfile)
            await session.record()
            let recording = session.isRecording
            try #require(recording)
            let id = try #require(session.recordingID)
            try await wait(until: deadline, seconds: 4) { (session.recordingMetrics?.videoWritten ?? 0) > 0 }
            let clock = ContinuousClock()
            let firstVideoObserved = clock.now
            try await pause(.seconds(1.2), deadline: deadline)

            // Explicit source change, fresh snapshot, then enough composed frames
            // before selecting the green marker's saved-file inspection time.
            _ = try await session.renderer.webView.evaluateJavaScript(
                "document.getElementById('probe').style.backgroundColor='rgb(0,255,0)'")
            try await wait(until: deadline, seconds: 3) {
                guard let image = session.renderer.image, let data = image.dataProvider?.data,
                      let bytes = CFDataGetBytePtr(data) else { return false }
                let offset = ((profile.height - 20) * profile.width + profile.width - 20) * 4
                return bytes[offset] < 40 && bytes[offset + 1] > 220 && bytes[offset + 2] < 40
            }
            await session.setMicrophoneMuted(true)
            let muted = session.microphoneMuted && session.microphoneLevel == 0
            #expect(muted)
            session.renderer.setManuallyHidden(true)
            let hidden = !session.renderer.visible
            #expect(hidden)
            try await pause(.milliseconds(400), deadline: deadline)
            session.renderer.setManuallyHidden(false)
            let restored = session.renderer.visible
            #expect(restored)
            await session.setMicrophoneMuted(false)
            let unmuted = !session.microphoneMuted
            #expect(unmuted)
            try await pause(.seconds(1), deadline: deadline)
            let elapsed = firstVideoObserved.duration(to: clock.now)
            let greenSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18 - 0.2
            await session.stopRecording()
            let url = try #require(session.sampleURL)
            let status = session.savedSamples.first(where: { $0.id == id })?.status
            #expect(status == .completed)
            let stopped = await close(session)
            try #require(stopped)
            return SmokeClip(id: id, url: url, profile: profile, greenSeconds: greenSeconds)
        } catch {
            _ = await close(session)
            throw error
        }
    }

    @MainActor private func wait(until deadline: ContinuousClock.Instant, seconds: Double,
                                condition: () -> Bool) async throws {
        let clock = ContinuousClock()
        let localDeadline = min(deadline, clock.now.advanced(by: .seconds(seconds)))
        while true {
            try Task.checkCancellation()
            guard clock.now < localDeadline else { throw SmokeFailure.deadline }
            if condition() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @MainActor private func pause(_ duration: Duration, deadline: ContinuousClock.Instant) async throws {
        guard ContinuousClock().now.advanced(by: duration) < deadline else { throw SmokeFailure.deadline }
        try await Task.sleep(for: duration)
    }

    /// Cleanup gets its own bounded, uncancelled task so a cancelled sleep does
    /// not busy-loop and starve the session's asynchronous finalization task.
    @MainActor private func close(_ session: MediaSession) async -> Bool {
        await Task { @MainActor in
            session.requestStop()
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(6))
            while session.phase != .idle && clock.now < deadline {
                try? await Task.sleep(for: .milliseconds(100))
            }
            return session.phase == .idle
        }.value
    }

    nonisolated private static func inspect(_ clip: SmokeClip) async throws -> SmokeInspection {
        try Task.checkCancellation()
        let asset = AVURLAsset(url: clip.url)
        let videos = try await asset.loadTracks(withMediaType: .video)
        let audios = try await asset.loadTracks(withMediaType: .audio)
        let video = try #require(videos.first)
        let audio = try #require(audios.first)
        let size = try await video.load(.naturalSize)
        let transform = try await video.load(.preferredTransform)
        let videoFormats = try await video.load(.formatDescriptions)
        let audioFormats = try await audio.load(.formatDescriptions)
        let duration = try await asset.load(.duration).seconds
        let valid = videos.count == 1 && audios.count == 1 && size == clip.profile.size &&
            transform == .identity && duration > 2 &&
            videoFormats.first.map { CMFormatDescriptionGetMediaSubType($0) } == kCMVideoCodecType_H264 &&
            audioFormats.first.map { CMFormatDescriptionGetMediaSubType($0) } == kAudioFormatMPEG4AAC
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 10)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 10)
        let red = try await generator.image(at: CMTime(seconds: 0.7, preferredTimescale: 600))
        let green = try await generator.image(at: CMTime(seconds: clip.greenSeconds, preferredTimescale: 600))
        let redPixel = try markerPixel(red.image)
        let greenPixel = try markerPixel(green.image)
        // Decode actual AAC instead of inferring audio usability from a track name.
        try Task.checkCancellation()
        let reader = try AVAssetReader(asset: asset)
        defer { reader.cancelReading() }
        let output = AVAssetReaderTrackOutput(track: audio,
            outputSettings: [AVFormatIDKey: Int(kAudioFormatLinearPCM)])
        reader.add(output)
        try #require(reader.startReading())
        var audioFrames = 0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            audioFrames += sample.numSamples
        }
        return SmokeInspection(duration: duration, validMedia: valid && audioFrames > 0 && reader.status == .completed,
            redMarker: redPixel.0 > 180 && redPixel.1 < 70 && redPixel.2 < 70,
            greenMarker: greenPixel.0 < 70 && greenPixel.1 > 180 && greenPixel.2 < 70)
    }

    nonisolated private static func markerPixel(_ image: CGImage) throws -> (UInt8, UInt8, UInt8) {
        let crop = try #require(image.cropping(to: CGRect(x: image.width - 24, y: image.height - 24, width: 8, height: 8)))
        var pixel = [UInt8](repeating: 0, count: 4)
        try pixel.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(data: bytes.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return (pixel[0], pixel[1], pixel[2])
    }

    @MainActor private static var hasPermissions: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized &&
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    nonisolated private static func hardwareModel() -> String {
        var system = utsname()
        uname(&system)
        let capacity = MemoryLayout.size(ofValue: system.machine)
        return withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: capacity) { String(cString: $0) }
        }
    }

    private static let fixture = """
        <html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
        <body style="margin:0;background:transparent;overflow:hidden">
        <div style="position:absolute;left:32px;top:32px;width:32px;height:32px;background:rgba(0,0,0,.5)"></div>
        <div id="score" style="position:absolute;left:20px;top:100px;color:white;font:48px sans-serif">0</div>
        <div id="probe" style="position:absolute;right:0;bottom:0;width:64px;height:64px;background:rgb(255,0,0)"></div>
        <script>setInterval(()=>document.getElementById('score').textContent=Number(document.getElementById('score').textContent)+1,1000)</script>
        </body></html>
        """
}

nonisolated private struct SmokeClip: Sendable {
    let id: UUID
    let url: URL
    let profile: SessionProfile
    let greenSeconds: Double
}

nonisolated private struct SmokeInspection: Sendable {
    let duration: Double
    let validMedia: Bool
    let redMarker: Bool
    let greenMarker: Bool
}

private enum SmokeFailure: Error {
    case requires13Mini
    case permissionsRequired
    case deadline
}
