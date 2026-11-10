import AVFoundation
import HaishinKit
import Synchronization

/// Startup evidence only. Holds scalar timing, never a camera frame or media queue.
nonisolated final class PreviewFrameReadiness: Sendable {
    private struct State {
        var cameraPTS: CMTime = .invalid
        var advancingCameraFrames = 0
        var ready = false
    }
    private let state = Mutex(State())

    var isReady: Bool { state.withLock { $0.ready } }

    func observeCamera(_ sample: CMSampleBuffer) {
        let pts = sample.presentationTimeStamp
        guard sample.imageBuffer != nil, pts.isValid, pts.isNumeric else { return }
        state.withLock {
            guard !$0.ready else { return }
            if !$0.cameraPTS.isValid || pts > $0.cameraPTS {
                $0.cameraPTS = pts
                $0.advancingCameraFrames = min(2, $0.advancingCameraFrames + 1)
            }
        }
    }

    func observeComposition(_ sample: CMSampleBuffer) {
        let pts = sample.presentationTimeStamp
        guard sample.imageBuffer != nil, pts.isValid, pts.isNumeric else { return }
        state.withLock {
            // A render tick/old image alone is not evidence that camera input resumed.
            if $0.advancingCameraFrames == 2 { $0.ready = true }
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
