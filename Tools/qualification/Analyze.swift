import AVFoundation
import Foundation

/// Read-only original analysis. Prints aggregate numbers/enums only, no paths or
/// SDK error descriptions. Media is streamed, never copied, repaired or encoded.
@main struct Analyze {
    struct Track: Codable {
        var buffers = 0
        var mediaSamples = 0
        var emptyMarkerBuffers = 0
        var invalidTimestampBuffers = 0
        var firstPTS: Double?
        var lastPTS: Double?
        var nonIncreasingPTS = 0
        var largestGap = 0.0
        var gapsAtLeast500ms = 0
        var estimatedMissing30HzIntervals = 0
        var finishedReading = false
        var failure: Failure?
    }
    struct Report: Encodable {
        let schema = 1
        var compressedVideo: Track
        var compressedAudio: Track
        var decodedVideo: Track
        var decodedAudio: Track
        let sync = "pendingPhysicalStartAndEndMarkers"
    }
    enum Failure: String, Error, Codable { case arguments, noTrack, cannotAdd, cannotStart, invalidTimestamp, unavailable }
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
            result.buffers += 1
            guard sample.numSamples > 0 else { result.emptyMarkerBuffers += 1; continue }
            result.mediaSamples += sample.numSamples
            // Audio buffers batch many AAC packets or PCM frames. Inspect
            // sample timing, rather than calling buffer-to-buffer distance an
            // audio gap. The single-entry case has uniform native timing and
            // needs only its first/last sample, keeping a three-hour scan cheap.
            var timingCount = 0
            guard CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: 0,
                arrayToFill: nil, entriesNeededOut: &timingCount) == noErr else {
                result.invalidTimestampBuffers += 1; continue
            }
            let uniform = timingCount == 1 && sample.numSamples > 1
            var previousIndex = 0
            var index = 0
            while index < sample.numSamples {
                defer { index += uniform && index == 0 ? sample.numSamples - 1 : 1 }
                var timing = CMSampleTimingInfo()
                guard CMSampleBufferGetSampleTimingInfo(sample, at: index, timingInfoOut: &timing) == noErr,
                      timing.presentationTimeStamp.isNumeric else {
                    result.invalidTimestampBuffers += 1; continue
                }
                let pts = timing.presentationTimeStamp.seconds
                if result.firstPTS == nil { result.firstPTS = pts }
                if let last = result.lastPTS {
                    let gap = pts - last
                    let steps = max(1, index - previousIndex)
                    let interval = gap / Double(steps)
                    if interval <= 0 { result.nonIncreasingPTS += steps }
                    result.largestGap = max(result.largestGap, interval)
                    if interval >= 0.5 { result.gapsAtLeast500ms += steps }
                    if type == .video, interval > 0 {
                        result.estimatedMissing30HzIntervals += max(0, Int((interval * 30).rounded()) - 1) * steps
                    }
                }
                result.lastPTS = pts
                previousIndex = index
            }
        }
        result.finishedReading = reader.status == .completed
        return result
    }
    static func checkedScan(_ asset: AVAsset, type: AVMediaType, decoded: Bool) async -> Track {
        do { return try await scan(asset, type: type, decoded: decoded) }
        catch { var result = Track(); result.failure = error as? Failure ?? .unavailable; return result }
    }
    static func main() async {
        do {
            guard CommandLine.arguments.count == 2 else { throw Failure.arguments }
            let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
            let report = await Report(compressedVideo: checkedScan(asset, type: .video, decoded: false),
                compressedAudio: checkedScan(asset, type: .audio, decoded: false),
                decodedVideo: checkedScan(asset, type: .video, decoded: true),
                decodedAudio: checkedScan(asset, type: .audio, decoded: true))
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            FileHandle.standardOutput.write(try encoder.encode(report))
            if ![report.compressedVideo, report.compressedAudio, report.decodedVideo, report.decodedAudio]
                .allSatisfy({ $0.finishedReading && $0.invalidTimestampBuffers == 0 }) { exit(2) }
        } catch {
            // Deliberately omit associated error, original path and CLI arguments.
            let code = (error as? Failure ?? .unavailable).rawValue
            FileHandle.standardError.write(Data(("analysisUnavailable:" + code + "\n").utf8))
            exit(1)
        }
    }
}
