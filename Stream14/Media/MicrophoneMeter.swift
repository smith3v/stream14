import AVFoundation
import HaishinKit
import Synchronization

/// A mixed-output observer, never an audio owner or a queue. Sample at most 256
/// values/channel per callback and retain only one scalar; UI polls at 10 Hz.
final class MicrophoneMeter: MediaMixerOutput, Sendable {
    private struct Reading { var peak: Float = 0; var updated: TimeInterval = 0 }
    private let reading = Mutex(Reading())
    let videoTrackId: UInt8? = nil
    let audioTrackId: UInt8? = .max

    var level: Double {
        reading.withLock {
            guard ProcessInfo.processInfo.systemUptime - $0.updated < 0.5 else { return 0 }
            return Double($0.peak)
        }
    }

    static func peak(in buffer: AVAudioPCMBuffer) -> Float {
        let frames = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        guard frames > 0, channels > 0, channels <= 2 else { return 0 }
        let stride = max(1, (frames + 255) / 256)
        var peak: Float = 0
        for channel in 0..<channels {
            for frame in Swift.stride(from: 0, to: frames, by: stride) {
                let index = buffer.format.isInterleaved ? frame * channels + channel : frame
                let plane = buffer.format.isInterleaved ? 0 : channel
                let value: Float
                switch buffer.format.commonFormat {
                case .pcmFormatInt16: value = Float(buffer.int16ChannelData?[plane][index] ?? 0) / 32768
                case .pcmFormatInt32: value = Float(buffer.int32ChannelData?[plane][index] ?? 0) / 2147483648
                case .pcmFormatFloat32: value = buffer.floatChannelData?[plane][index] ?? 0
                default: value = 0
                }
                if value.isFinite { peak = max(peak, abs(value)) }
            }
        }
        return min(1, peak)
    }

    func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) async {}
    func mixer(_ mixer: MediaMixer, didOutput sampleBuffer: CMSampleBuffer) {}
    func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        let peak = Self.peak(in: buffer)
        reading.withLock { $0 = Reading(peak: peak, updated: ProcessInfo.processInfo.systemUptime) }
    }
}
