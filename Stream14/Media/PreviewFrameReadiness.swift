import AVFoundation
import HaishinKit
import Synchronization

/// Preview startup and rotation evidence. Holds scalar timing, never a camera frame or media queue.
nonisolated final class PreviewFrameReadiness: Sendable {
    private struct State {
        var cameraPTS: CMTime = .invalid
        var advancingCameraFrames = 0
        var ready = false
        var requiredCameraFrames = 2
        var expectsPortrait: Bool?
    }
    private let state = Mutex(State())

    var isReady: Bool { state.withLock { $0.ready } }

    func waitForRotation(portrait: Bool) {
        state.withLock {
            // Allow several fresh inputs and a render tick for the queued
            // camera image to settle after connection reconfiguration.
            $0 = State(requiredCameraFrames: 4, expectsPortrait: portrait)
        }
    }

    func observeCamera(_ sample: CMSampleBuffer) {
        let pts = sample.presentationTimeStamp
        guard let image = sample.imageBuffer, pts.isValid, pts.isNumeric else { return }
        state.withLock {
            guard !$0.ready else { return }
            if let expectsPortrait = $0.expectsPortrait {
                guard (CVPixelBufferGetWidth(image) < CVPixelBufferGetHeight(image)) == expectsPortrait else { return }
            }
            if !$0.cameraPTS.isValid || pts > $0.cameraPTS {
                $0.cameraPTS = pts
                $0.advancingCameraFrames = min($0.requiredCameraFrames, $0.advancingCameraFrames + 1)
            }
        }
    }

    func observeComposition(_ sample: CMSampleBuffer) {
        let pts = sample.presentationTimeStamp
        guard sample.imageBuffer != nil, pts.isValid, pts.isNumeric else { return }
        state.withLock {
            // A render tick/old image alone is not evidence that camera input resumed.
            if $0.advancingCameraFrames == $0.requiredCameraFrames { $0.ready = true }
        }
    }
}

/// Two concrete outputs distinguish raw camera acquisition from composed rendering.
nonisolated final class PreviewFrameObserver: MediaMixerOutput, Sendable {
    let videoTrackId: UInt8?
    let audioTrackId: UInt8? = nil
    private let readiness: PreviewFrameReadiness

    init(readiness: PreviewFrameReadiness, camera: Bool) {
        self.readiness = readiness
        videoTrackId = camera ? 0 : .max
    }
    func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) async {}
    func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {}
    func mixer(_ mixer: MediaMixer, didOutput sampleBuffer: CMSampleBuffer) {
        if videoTrackId == 0 { readiness.observeCamera(sampleBuffer) }
        else { readiness.observeComposition(sampleBuffer) }
    }
}
