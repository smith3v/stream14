import AVFoundation
import HaishinKit

/// Fixed landscape media contract. The selected value is frozen from preview open
/// through capture close; no component derives dimensions from screen points.
nonisolated enum SessionProfile: String, CaseIterable, Identifiable, Sendable {
    case fullHD = "1080p30"
    case hd = "720p30"

    var id: String { rawValue }
    var width: Int { self == .fullHD ? 1920 : 1280 }
    var height: Int { self == .fullHD ? 1080 : 720 }
    var size: CGSize { CGSize(width: width, height: height) }
    var videoBitRate: Int { self == .fullHD ? 14_000_000 : 8_000_000 }
    var frameRate: Double { 30 }
    var audioSampleRate: Double { 44_100 }
    var audioChannels: UInt32 { 2 }
    var audioBitRate: Int { 128_000 }
    var keyframeSeconds: Int { 2 }
    var label: String { "\(rawValue) · \(videoBitRate / 1_000_000) Mbps" }
    static let preferenceKey = "sessionProfile"

    static func saved(in defaults: UserDefaults = .standard) -> Self {
        defaults.string(forKey: preferenceKey).flatMap(Self.init(rawValue:)) ?? .fullHD
    }

    func audioSettings(muted: Bool) -> AudioMixerSettings {
        AudioMixerSettings(sampleRate: audioSampleRate, channels: audioChannels, isMuted: muted)
    }

    var videoSettings: [String: Any] {
        [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
         AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
             AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
             AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
         AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: videoBitRate,
             AVVideoMaxKeyFrameIntervalDurationKey: keyframeSeconds,
             AVVideoExpectedSourceFrameRateKey: frameRate]]
    }

    var audioSettings: [String: Any] {
        [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: audioSampleRate,
         AVNumberOfChannelsKey: audioChannels, AVEncoderBitRateKey: audioBitRate]
    }
}
