import AVFoundation
import CoreImage
import HaishinKit
import Synchronization
import Testing
@testable import Stream14

private final class CompositionProbe: MediaMixerOutput, Sendable {
    let videoTrackId: UInt8? = .max
    let audioTrackId: UInt8? = nil
    private let value = Mutex<UInt8?>(nil)
    var luminance: UInt8? { value.withLock { $0 } }
    func clear() { value.withLock { $0 = nil } }
    func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) async {}
    func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {}
    func mixer(_ mixer: MediaMixer, didOutput sample: CMSampleBuffer) {
        guard let pixel = sample.imageBuffer else { return }
        CVPixelBufferLockBaseAddress(pixel, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixel, .readOnly) }
        guard CVPixelBufferGetPlaneCount(pixel) > 0,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixel, 0) else { return }
        value.withLock { $0 = base.load(as: UInt8.self) }
    }
}

@Suite(.serialized)
struct WebOverlayCompositionTests {
    @Test @MainActor func hiddenLayerStopsDrawingCachedRasterAndRestores() async throws {
        let mixer = MediaMixer(captureSessionMode: .manual)
        await mixer.setVideoMixerSettings(VideoMixerSettings(mode: .offscreen))
        try await mixer.setFrameRate(30)
        let layer = await WebOverlayLayer()
        try await layer.install(on: mixer)
        let context = CIContext()
        let red = try #require(context.createCGImage(CIImage(color: .red),
            from: CGRect(x: 0, y: 0, width: 1920, height: 1080)))
        let probe = CompositionProbe()
        await mixer.addOutput(probe)
        await mixer.startRunning()
        // Each check observes actual HaishinKit-rendered NV12 output, not model flags.
        await layer.update(image: red, visible: true)
        for _ in 0..<100 {
            if let y = probe.luminance, y > 30 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let shown = try #require(probe.luminance)
        #expect(shown > 30)
        await layer.update(image: red, visible: false)
        probe.clear()
        for _ in 0..<100 {
            if let y = probe.luminance, y < 25 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let hidden = try #require(probe.luminance)
        #expect(hidden < 25)
        await layer.update(image: red, visible: true)
        probe.clear()
        for _ in 0..<100 {
            if let y = probe.luminance, y > 30 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(try #require(probe.luminance) > 30)
        await mixer.stopRunning()
        await mixer.removeOutput(probe)
    }
}
