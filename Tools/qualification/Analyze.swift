import AVFoundation
import Foundation

/// Read-only original analysis. Prints aggregate numbers/enums only, no paths or
/// SDK error descriptions. Media is streamed, never copied, repaired or encoded.
@main struct Analyze {
    struct Track: Codable {
        var samples = 0
        var firstPTS: Double?
        var lastPTS: Double?
        var nonIncreasingPTS = 0
        var largestGap = 0.0
        var gapsAtLeast500ms = 0
        var estimatedMissing30HzIntervals = 0
        var finishedReading = false
    }
    struct Report: Encodable {
        let schema = 1
        var compressedVideo: Track
        var compressedAudio: Track
        var decodedVideo: Track
        var decodedAudio: Track
        let sync = "pendingPhysicalStartAndEndMarkers"
    }
    enum Failure: String, Error { case arguments, noTrack, cannotAdd, cannotStart, invalidTimestamp, unavailable }
    static func scan(_ asset: AVAsset, type: AVMediaType, decoded: Bool) async throws -> Track {
        guard let track = try await asset.loadTracks(withMediaType: type).first else { throw Failure.noTrack }
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any]? = !decoded ? nil : type == .video
            ? [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            : [AVFormatIDKey: kAudioFormatLinearPCM]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw Failure.cannotAdd }
        reader.add(output)
        guard reader.startReading() else { throw Failure.cannotStart }
        var result = Track()
        while let sample = output.copyNextSampleBuffer() {
            let pts = sample.presentationTimeStamp.seconds
            guard pts.isFinite else { throw Failure.invalidTimestamp }
            result.samples += 1
            if result.firstPTS == nil { result.firstPTS = pts }
            if let last = result.lastPTS {
                let gap = pts - last
                if gap <= 0 { result.nonIncreasingPTS += 1 }
                result.largestGap = max(result.largestGap, gap)
                if gap >= 0.5 { result.gapsAtLeast500ms += 1 }
                if type == .video, gap > 0 {
                    result.estimatedMissing30HzIntervals += max(0, Int((gap * 30).rounded()) - 1)
                }
            }
            result.lastPTS = pts
        }
        result.finishedReading = reader.status == .completed
        return result
    }
    static func main() async {
        do {
            guard CommandLine.arguments.count == 2 else { throw Failure.arguments }
            let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
            let report = try await Report(compressedVideo: scan(asset, type: .video, decoded: false),
                compressedAudio: scan(asset, type: .audio, decoded: false),
                decodedVideo: scan(asset, type: .video, decoded: true),
                decodedAudio: scan(asset, type: .audio, decoded: true))
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            FileHandle.standardOutput.write(try encoder.encode(report))
        } catch {
            // Deliberately omit associated error, original path and CLI arguments.
            let code = (error as? Failure ?? .unavailable).rawValue
            FileHandle.standardError.write(Data(("analysisUnavailable:" + code + "\n").utf8))
            exit(1)
        }
    }
}
