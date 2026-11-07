import AVFoundation
import UIKit
import WebKit
import Testing
@testable import Stream14

struct RearCameraLensTests {
    @Test func filtersDimensionsPixelFormatAndFrameRate() {
        let nv12 = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        #expect(RearCameraLens.supportsProfile(width: 1920, height: 1080, subtype: nv12, frameRates: [24...60]))
        #expect(RearCameraLens.supportsProfile(width: 1920, height: 1080, subtype: nv12, frameRates: [30...30]))
        #expect(!RearCameraLens.supportsProfile(width: 1280, height: 720, subtype: nv12, frameRates: [24...60]))
        #expect(!RearCameraLens.supportsProfile(width: 3840, height: 2160, subtype: nv12, frameRates: [24...60]))
        #expect(!RearCameraLens.supportsProfile(width: 1920, height: 1080, subtype: kCVPixelFormatType_32BGRA, frameRates: [24...60]))
        #expect(!RearCameraLens.supportsProfile(width: 1920, height: 1080, subtype: nv12, frameRates: [1...29, 31...60]))
        #expect(!RearCameraLens.supportsProfile(width: 1920, height: 1080, subtype: nv12, frameRates: []))
    }

    @Test @MainActor func startsWithWideWithoutActivatingCaptureAndRejectsUnavailableChoice() async {
        let session = MediaSession()
        let initiallyWide = session.selectedLens == .wide
        let noDiscoveryBeforePermission = session.availableLenses.isEmpty
        #expect(initiallyWide)
        #expect(noDiscoveryBeforePermission)
        await session.selectLens(.telephoto)
        let remainsWideAndIdle = session.selectedLens == .wide && session.phase == .idle
        #expect(remainsWideAndIdle)
    }

    /// Authorized, short private camera/microphone samples; never deletes originals.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STREAM14_DEVICE_LENSES"] == "1"))
    @MainActor func deviceLensSelectionAndRecording() async throws {
        let session = MediaSession()
        let previousIdle = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = previousIdle }
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        let host = OverlayViewport(webView: session.renderer.webView)
        host.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        controller.view.addSubview(host)
        session.preview.frame = CGRect(x: 0, y: 180, width: 320, height: 180)
        controller.view.addSubview(session.preview)
        window.makeKeyAndVisible()
        host.layoutIfNeeded()
        defer { session.requestStop(); window.isHidden = true }
        let fixture = """
            <html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body style="margin:0;background:transparent"><div style="color:white;background:#16704a;width:400px;height:100px;font-size:60px">Lens test</div></body></html>
            """
        session.renderer.loadFixture(fixture)
        for _ in 0..<100 {
            if session.renderer.visible { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let overlayReady = session.renderer.visible
        print("Lens fixture readiness: \(session.renderer.status); \(session.renderer.viewport)")
        try #require(overlayReady)
        await session.openPreview()
        let ready = session.canRecord
        try #require(ready)
        let lenses = session.availableLenses
        print("Compatible rear lenses: \(lenses.map(\.rawValue))")
        #expect(lenses.contains(.wide))
        // The owner's testing phone is the iPhone 13 mini.
        #expect(lenses.contains(.ultraWide))
        for lens in lenses {
            await session.selectLens(lens)
            let selected = session.selectedLens == lens && session.canRecord
            try #require(selected)
            let expectedType = lens.deviceType
            try await session.mixer.configuration(video: 0) { unit in
                guard let device = unit.device else { throw RearCameraLens.ConfigurationError.unavailable }
                #expect(device.deviceType == expectedType)
                let size = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                #expect(size.width == 1920 && size.height == 1080)
                #expect(abs(device.activeVideoMinFrameDuration.seconds - 1.0 / 30) < 0.001)
                print("Configured \(lens.rawValue): FOV \(device.activeFormat.videoFieldOfView), 1080p30")
            }
            session.renderer.loadFixture(fixture)
            for _ in 0..<100 {
                if session.renderer.visible { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            let overlayBeforeRecording = session.renderer.visible
            try #require(overlayBeforeRecording)
            try await Task.sleep(for: .seconds(1))
            await session.record()
            let recording = session.isRecording && !session.canSelectLens
            try #require(recording)
            await session.selectLens(lens == .wide ? .ultraWide : .wide)
            let locked = session.selectedLens == lens
            #expect(locked)
            try await Task.sleep(for: .seconds(4))
            await session.stopRecording()
            let completedURL = session.sampleURL
            let url = try #require(completedURL)
            let completed = session.savedSamples.first { $0.fileName == url.lastPathComponent }?.status == .completed
            #expect(completed)
            let asset = AVURLAsset(url: url)
            let videos = try await asset.loadTracks(withMediaType: .video)
            let audios = try await asset.loadTracks(withMediaType: .audio)
            #expect(videos.count == 1 && audios.count == 1)
            let video = try #require(videos.first)
            let size = try await video.load(.naturalSize)
            #expect(size.width == 1920 && size.height == 1080)
            let duration = try await asset.load(.duration)
            #expect(duration.seconds > 2)
            let generated = try await AVAssetImageGenerator(asset: asset).image(at: CMTime(seconds: 1, preferredTimescale: 600))
            let patch = try #require(generated.image.cropping(to: CGRect(x: 350, y: 50, width: 1, height: 1)))
            var pixel = [UInt8](repeating: 0, count: 4)
            let readPixel = pixel.withUnsafeMutableBytes { bytes -> Bool in
                guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                    bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                context.draw(patch, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                return true
            }
            #expect(readPixel && Int(pixel[1]) > Int(pixel[0]) + 30)
            print("Retained \(lens.rawValue) sample: \(url.lastPathComponent), duration \(duration.seconds)s")
        }
        // Unavailable choices must leave a usable selected camera.
        if !lenses.contains(.telephoto) {
            let previous = session.selectedLens
            await session.selectLens(.telephoto)
            let unchanged = session.selectedLens == previous && session.canRecord
            #expect(unchanged)
        }
        let previous = session.selectedLens
        let other: RearCameraLens = previous == .wide ? .ultraWide : .wide
        await session.selectLens(other, injection: .configuration)
        let restored = session.selectedLens == previous && session.canRecord
        try #require(restored)
        // Prove that rollback restores actual writable media, not just the label.
        await session.record()
        try await Task.sleep(for: .seconds(3))
        await session.stopRecording()
        let rollbackCompleted = session.sampleURL != nil && session.savedSamples.first?.status == .completed
        #expect(rollbackCompleted)
        await session.selectLens(other, injection: .restoration)
        let cannotRecordAfterFailedRestoration = !session.canRecord
        #expect(cannotRecordAfterFailedRestoration)
        for _ in 0..<100 {
            if session.phase == .idle { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let stoppedAfterFailedRestoration = session.phase == .idle
        #expect(stoppedAfterFailedRestoration)
        await session.openPreview()
        let reopened = session.canRecord
        try #require(reopened)
        let interruptedTarget: RearCameraLens = session.selectedLens == .wide ? .ultraWide : .wide
        await session.selectLens(interruptedTarget, injection: .interruption)
        let interruptionBlocksRecording = !session.canRecord
        #expect(interruptionBlocksRecording)
        for _ in 0..<100 {
            if session.phase == .idle { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let closed = session.phase == .idle
        #expect(closed)
        let mixerStopped = await !session.mixer.isRunning
        #expect(mixerStopped)
    }

}
