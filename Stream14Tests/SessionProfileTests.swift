import AVFoundation
import HaishinKit
import Synchronization
import Testing
import UIKit
import WebKit
@testable import Stream14

@Suite(.serialized)
struct SessionProfileTests {
    @Test func profileMediaSettingsAndPreferenceFallback() {
        let defaults = UserDefaults(suiteName: "stream14-profile-tests-" + UUID().uuidString)!
        defer { defaults.removeObject(forKey: SessionProfile.preferenceKey) }
        #expect(SessionProfile.saved(in: defaults) == .fullHD)
        defaults.set("unknown", forKey: SessionProfile.preferenceKey)
        #expect(SessionProfile.saved(in: defaults) == .fullHD)
        for profile in SessionProfile.allCases {
            defaults.set(profile.rawValue, forKey: SessionProfile.preferenceKey)
            #expect(SessionProfile.saved(in: defaults) == profile)
            #expect(profile.videoSettings[AVVideoWidthKey] as? Int == profile.width)
            #expect(profile.videoSettings[AVVideoHeightKey] as? Int == profile.height)
            #expect(profile.audioSettings[AVEncoderBitRateKey] as? Int == 128_000)
            #expect(profile.audioSettings(muted: true).isMuted)
            #expect(!profile.audioSettings(muted: false).isMuted)
            #expect(RearCameraLens.supportsProfile(width: Int32(profile.width), height: Int32(profile.height),
                subtype: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, frameRates: [30...30], profile: profile))
            let other: SessionProfile = profile == .fullHD ? .hd : .fullHD
            #expect(!RearCameraLens.supportsProfile(width: Int32(other.width), height: Int32(other.height),
                subtype: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, frameRates: [30...30], profile: profile))
        }
    }

    @Test @MainActor func selectionRebuildsCanvasWithoutOpeningCameraOrLosingHideIntent() {
        var saved: SessionProfile?
        let session = MediaSession(readOverlayURL: { "" }, saveOverlayURL: { _ in }, profile: .fullHD,
                                   persistProfile: { saved = $0 })
        session.renderer.setManuallyHidden(true)
        let previous = session.renderer.webView
        session.selectProfile(.hd)
        #expect(session.profile == .hd && saved == .hd)
        #expect(session.phase == .idle && session.canSelectProfile)
        #expect(session.renderer.profile == .hd)
        #expect(session.renderer.webView !== previous)
        #expect(session.renderer.webView.bounds.size == SessionProfile.hd.size)
        #expect(session.renderer.health.manuallyHidden)
        #expect(!session.renderer.isRunning)
    }

    @Test @MainActor func profileChangeDuringCapturePreparationIsRejectedAndCancellationWins() async {
        var continuation: CheckedContinuation<Bool, Never>?
        let session = MediaSession(readOverlayURL: { "" }, saveOverlayURL: { _ in }, profile: .fullHD,
                                   persistProfile: { _ in }, authorizeCapture: {
            await withCheckedContinuation { continuation = $0 }
        })
        let opening = Task { await session.openPreview() }
        for _ in 0..<100 {
            if continuation != nil { break }
            await Task.yield()
        }
        #expect(session.phase == .preparing)
        #expect(!session.canSelectProfile)
        session.selectProfile(.hd)
        #expect(session.profile == .fullHD)
        #expect(session.renderer.profile == .fullHD)
        session.requestStop()
        continuation?.resume(returning: true)
        await opening.value
        #expect(!session.canRecord)
    }

    @Test @MainActor func bothAttachedProfileViewportsRenderExactAlphaRasters() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        for profile in SessionProfile.allCases {
            let renderer = WebOverlayRenderer(profile: profile)
            let host = OverlayViewport(webView: renderer.webView)
            host.frame = CGRect(x: 0, y: 80, width: 320, height: 60)
            window.rootViewController!.view.addSubview(host)
            defer { renderer.disable(); host.removeFromSuperview() }
            renderer.loadFixture("""
                <html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
                <body style="margin:0;background:transparent"><div style="position:absolute;right:0;bottom:0;width:20px;height:20px;background:rgba(255,0,0,0.5)">.</div></body></html>
                """)
            host.layoutIfNeeded()
            for _ in 0..<100 {
                if renderer.image != nil { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            let image = try #require(renderer.image)
            #expect(renderer.visible)
            #expect(image.width == profile.width && image.height == profile.height)
            #expect(renderer.viewport == "\(profile.width)×\(profile.height) CSS → \(profile.width)×\(profile.height) pixels")
            let data = try #require(image.dataProvider?.data)
            let bytes = try #require(CFDataGetBytePtr(data))
            #expect(bytes[3] == 0)
            let corner = ((profile.height - 10) * profile.width + profile.width - 10) * 4
            #expect(bytes[corner + 3] == 128)
        }
    }

    @Test func meterHandlesIntegerInterleavedAndFloatAudio() throws {
        for interleaved in [false, true] {
            let format = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44_100,
                                                   channels: 2, interleaved: interleaved))
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4))
            buffer.frameLength = 4
            for plane in 0..<(interleaved ? 1 : 2) {
                buffer.int16ChannelData![plane].update(repeating: 16384, count: interleaved ? 8 : 4)
            }
            #expect(abs(MicrophoneMeter.peak(in: buffer) - 0.5) < 0.001)
        }
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4))
        buffer.frameLength = 4
        for plane in 0..<2 { buffer.floatChannelData![plane].update(repeating: .nan, count: 4) }
        #expect(MicrophoneMeter.peak(in: buffer) == 0)
        buffer.floatChannelData![0][0] = -2
        #expect(MicrophoneMeter.peak(in: buffer) == 1)
    }

    @Test func sharedMixerMutePrecedesEveryOutput() async throws {
        let mixer = MediaMixer(captureSessionMode: .single)
        let first = AudioProbe()
        let second = AudioProbe()
        await mixer.setAudioMixerSettings(SessionProfile.hd.audioSettings(muted: true))
        await mixer.addOutput(first)
        await mixer.addOutput(second)
        await mixer.startRunning()
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        for index in 0..<20 {
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
            buffer.frameLength = 1024
            for plane in 0..<2 { buffer.floatChannelData![plane].update(repeating: 0.75, count: 1024) }
            await mixer.append(buffer, when: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: Double(index) * 1024 / 44_100)))
            try await Task.sleep(for: .milliseconds(10))
        }
        try await Task.sleep(for: .milliseconds(100))
        #expect(first.result.0 > 0 && second.result.0 > 0)
        #expect(first.result.1 == 0 && second.result.1 == 0)
        await mixer.setAudioMixerSettings(SessionProfile.hd.audioSettings(muted: false))
        for index in 20..<40 {
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
            buffer.frameLength = 1024
            for plane in 0..<2 { buffer.floatChannelData![plane].update(repeating: 0.75, count: 1024) }
            await mixer.append(buffer, when: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: Double(index) * 1024 / 44_100)))
            try await Task.sleep(for: .milliseconds(10))
        }
        try await Task.sleep(for: .milliseconds(100))
        await mixer.stopRunning()
        #expect(first.result.1 > 0.5 && second.result.1 > 0.5)
    }
}

private final class AudioProbe: MediaMixerOutput, Sendable {
    private let state = Mutex((0, Float(0)))
    let videoTrackId: UInt8? = nil
    let audioTrackId: UInt8? = .max
    var result: (Int, Float) { state.withLock { $0 } }
    func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) async {}
    func mixer(_ mixer: MediaMixer, didOutput sampleBuffer: CMSampleBuffer) {}
    func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        let peak = MicrophoneMeter.peak(in: buffer)
        state.withLock { $0.0 += 1; $0.1 = max($0.1, peak) }
    }
}
