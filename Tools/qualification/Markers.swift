import AVFoundation
import CoreImage
import CryptoKit
import Darwin
import Foundation

/// Offline only. All generated images, waveforms and manifests are private media.
/// Failures deliberately omit source paths, CLI arguments and SDK descriptions.
@main struct Markers {
    enum Failure: String, Error { case arguments, input, outputExists, output, media, bounds, timing, selection, changedInput }
    struct Window: Codable {
        let name: String
        let lower: Double
        let upper: Double
    }
    struct Frame: Codable {
        let pts: Double
        let image: String
    }
    struct Bin: Codable {
        var firstPTS: Double
        var lastPTS: Double
        var minimum: Float
        var maximum: Float
        var peakPTS: Double
        var peak: Float
        var samples: Int
    }
    struct Audio: Codable {
        let sampleRate: Double
        let channels: Int
        let bins: [[Bin]]
    }
    struct Inspection: Codable {
        let window: Window
        let frames: [Frame]
        let audio: Audio
    }
    struct Manifest: Codable {
        let schema: Int
        let inputSHA256: String
        let inspections: [Inspection]
    }
    struct Bracket: Codable {
        let lower: Double
        let upper: Double
    }
    struct Selection: Codable {
        let name: String
        let channel: Int?
        let video: Bracket?
        let audio: Bracket?
    }
    struct Selections: Codable {
        let schema: Int
        let markers: [Selection]
    }
    struct Measurement: Encodable {
        let name: String
        let status: String
        let channel: Int?
        let offsetLowerSeconds: Double?
        let offsetUpperSeconds: Double?
        let midpointSeconds: Double?
        let halfRangeSeconds: Double?
    }
    struct Result: Encodable {
        let schema = 1
        let convention = "audioMinusVideoPositiveMeansAudioLater"
        let markerRecognition = "humanSelectionNotVerifiedByTool"
        let qualification = "notDetermined"
        let markers: [Measurement]
    }
    static var fileManager: FileManager { FileManager() }

    static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }
    static func fileURL(_ path: String) throws -> URL {
        let url = URL(fileURLWithPath: path)
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else { throw Failure.input }
        return url
    }
    static func hash(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { digest.update(data: data) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    static func write(_ data: Data, _ url: URL) throws {
        try data.write(to: url, options: .withoutOverwriting)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func boundedData(_ path: String, maximum: Int) throws -> Data {
        let url = try fileURL(path)
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? maximum + 1
        guard size <= maximum else { throw Failure.bounds }
        let data = try Data(contentsOf: url)
        guard data.count <= maximum else { throw Failure.bounds }
        return data
    }
    static func validWindow(_ window: Window) -> Bool {
        window.lower.isFinite && window.upper.isFinite && window.lower >= 0 &&
            window.upper > window.lower && window.upper - window.lower <= 2.000_001
    }
    static func reader(_ asset: AVAsset, _ track: AVAssetTrack, _ window: Window,
                       _ settings: [String: Any]) throws -> (AVAssetReader, AVAssetReaderTrackOutput) {
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: window.lower, preferredTimescale: 1_000_000),
            end: CMTime(seconds: window.upper, preferredTimescale: 1_000_000))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw Failure.media }
        reader.add(output)
        guard reader.startReading() else { throw Failure.media }
        return (reader, output)
    }
    static func video(_ asset: AVAsset, track: AVAssetTrack, window: Window, directory: URL) async throws -> [Frame] {
        let (reader, output) = try reader(asset, track, window,
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let transform = try await track.load(.preferredTransform)
        guard [transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty]
            .allSatisfy(\.isFinite) else { throw Failure.media }
        let context = CIContext(options: [.cacheIntermediates: false])
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        var frames: [Frame] = []
        while let sample = output.copyNextSampleBuffer() {
            guard sample.numSamples > 0 else { continue }
            let pts = sample.presentationTimeStamp.seconds
            guard pts.isFinite, frames.last.map({ pts > $0.pts }) ?? true else { throw Failure.timing }
            guard pts >= window.lower && pts <= window.upper else { continue }
            guard frames.count < 240, let pixel = sample.imageBuffer,
                  CVPixelBufferGetWidth(pixel) <= 4096, CVPixelBufferGetHeight(pixel) <= 4096 else { throw Failure.bounds }
            let source = CIImage(cvPixelBuffer: pixel).transformed(by: transform)
            let extent = source.extent
            guard extent.width > 0, extent.height > 0, !extent.isInfinite else { throw Failure.media }
            let scale = min(1, min(640 / extent.width, 360 / extent.height))
            let thumbnail = source.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            guard let data = context.jpegRepresentation(of: thumbnail, colorSpace: colorSpace,
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.8]) else { throw Failure.media }
            let name = "\(window.name)-frame-\(String(format: "%03d", frames.count)).jpg"
            try write(data, directory.appendingPathComponent(name))
            frames.append(Frame(pts: pts, image: name))
        }
        guard reader.status == .completed, frames.count >= 2 else { throw Failure.media }
        return frames
    }
    static func audio(_ asset: AVAsset, track: AVAssetTrack, window: Window) throws -> Audio {
        let (reader, output) = try reader(asset, track, window, [AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false])
        var bins: [[Bin]] = []
        var sampleRate: Double?
        var lastPTS: Double?
        var sampleCount = 0
        while let sample = output.copyNextSampleBuffer() {
            guard sample.numSamples > 0 else { continue }
            guard let format = sample.formatDescription,
                  let description = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
                  let block = sample.dataBuffer else { throw Failure.media }
            let channels = Int(description.mChannelsPerFrame)
            let rate = description.mSampleRate
            guard (1...8).contains(channels), (8_000...192_000).contains(rate),
                  description.mFormatID == kAudioFormatLinearPCM,
                  description.mBitsPerChannel == 32,
                  Int(description.mBytesPerFrame) == channels * 4,
                  description.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                  description.mFormatFlags & kAudioFormatFlagIsBigEndian == 0,
                  description.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0,
                  sample.numSamples <= 400_000 else { throw Failure.bounds }
            if let sampleRate {
                guard sampleRate == rate && bins.count == channels else { throw Failure.media }
            } else { sampleRate = rate; bins = Array(repeating: [], count: channels) }
            let count = sample.numSamples * channels
            guard CMBlockBufferGetDataLength(block) == count * MemoryLayout<Float>.size else { throw Failure.media }
            var values = [Float](repeating: 0, count: count)
            let status = values.withUnsafeMutableBytes {
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!)
            }
            guard status == kCMBlockBufferNoErr else { throw Failure.media }
            var timingCount = 0
            guard CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: 0, arrayToFill: nil,
                entriesNeededOut: &timingCount) == noErr else { throw Failure.timing }
            var firstTiming = CMSampleTimingInfo()
            guard CMSampleBufferGetSampleTimingInfo(sample, at: 0, timingInfoOut: &firstTiming) == noErr,
                  firstTiming.presentationTimeStamp.isNumeric else { throw Failure.timing }
            if timingCount == 1 {
                guard firstTiming.duration.isNumeric,
                      abs(firstTiming.duration.seconds - 1 / rate) < 0.000_000_01 else { throw Failure.timing }
            }
            for index in 0..<sample.numSamples {
                var pts: Double
                if timingCount == 1 { pts = firstTiming.presentationTimeStamp.seconds + Double(index) / rate }
                else {
                    var timing = CMSampleTimingInfo()
                    guard CMSampleBufferGetSampleTimingInfo(sample, at: index, timingInfoOut: &timing) == noErr,
                          timing.presentationTimeStamp.isNumeric else { throw Failure.timing }
                    pts = timing.presentationTimeStamp.seconds
                }
                guard pts.isFinite, lastPTS.map({ pts > $0 }) ?? true else { throw Failure.timing }
                lastPTS = pts
                guard pts >= window.lower && pts <= window.upper else { continue }
                sampleCount += 1
                guard sampleCount <= 400_000 else { throw Failure.bounds }
                for channel in 0..<channels {
                    let value = values[index * channels + channel]
                    guard value.isFinite else { throw Failure.media }
                    let last = bins[channel].last
                    // Never bridge a missing PCM interval inside a waveform bin.
                    if let last, pts - last.firstPTS < 0.001 && pts - last.lastPTS <= 1.5 / rate {
                        let n = bins[channel].count - 1
                        bins[channel][n].lastPTS = pts
                        bins[channel][n].minimum = min(last.minimum, value)
                        bins[channel][n].maximum = max(last.maximum, value)
                        bins[channel][n].samples += 1
                        if abs(value) > abs(last.peak) {
                            bins[channel][n].peak = value; bins[channel][n].peakPTS = pts
                        }
                    } else {
                        guard bins[channel].count < 4_000 else { throw Failure.bounds }
                        bins[channel].append(Bin(firstPTS: pts, lastPTS: pts, minimum: value,
                            maximum: value, peakPTS: pts, peak: value, samples: 1))
                    }
                }
            }
        }
        guard reader.status == .completed, let sampleRate,
              bins.allSatisfy({ !$0.isEmpty && $0.count <= 4_000 }) else { throw Failure.media }
        return Audio(sampleRate: sampleRate, channels: bins.count, bins: bins)
    }
    static func waveform(_ inspection: Inspection, channel: Int) -> String {
        let window = inspection.window
        let bins = inspection.audio.bins[channel]
        let scale = max(0.000_001, Double(bins.map { max(abs($0.minimum), abs($0.maximum)) }.max() ?? 1))
        func x(_ t: Double) -> Double { 50 + (t - window.lower) / (window.upper - window.lower) * 1_000 }
        var parts = ["<svg xmlns='http://www.w3.org/2000/svg' width='1100' height='250' viewBox='0 0 1100 250'><rect width='1100' height='250' fill='white'/><path d='M50 120H1050' stroke='#888'/>"]
        for bin in bins {
            parts.append("<path d='M\(x(bin.firstPTS)) \(120 - Double(bin.maximum) / scale * 90)L\(x(bin.firstPTS)) \(120 - Double(bin.minimum) / scale * 90)' stroke='#174c7e'/>")
        }
        for index in 0...10 {
            let pts = window.lower + Double(index) / 10 * (window.upper - window.lower)
            parts.append("<path d='M\(x(pts)) 215V220' stroke='black'/><text x='\(x(pts))' y='237' font-size='11' text-anchor='middle'>\(String(format: "%.4f", pts))</text>")
        }
        parts.append("<text x='50' y='18' font-size='14'>Channel \(channel) — decoded asset PTS seconds; amplitude normalized per channel, not dB</text></svg>")
        return parts.joined()
    }
    static func html(_ inspections: [Inspection]) -> String {
        var parts = ["<!doctype html><meta charset='utf-8'><title>Private marker inspection</title><style>body{font:16px system-ui;margin:24px}section{margin:30px 0}.frames{display:flex;flex-wrap:wrap;gap:12px}figure{margin:0;width:320px}figure img{width:320px}object{width:100%;min-width:550px}code{white-space:pre-wrap}</style><h1>Private marker inspection</h1><p>Human selection required. Frame labels are actual decoded asset PTS. Bracket last separated hands → first contact; bracket the matching audible transient using waveform.json sample-derived bins. Do not treat a peak as an automatically identified clap. Missing/ambiguous markers stay pending. Keep these media artifacts private.</p>"]
        for inspection in inspections {
            let name = inspection.window.name
            parts.append("<section><h2>\(name)</h2><div class='frames'>")
            for frame in inspection.frames {
                parts.append("<figure><a href='\(frame.image)'><img src='\(frame.image)'></a><figcaption>PTS \(String(format: "%.9f", frame.pts)) s</figcaption></figure>")
            }
            parts.append("</div>")
            for channel in 0..<inspection.audio.channels {
                parts.append("<h3>Audio channel \(channel)</h3><object data='\(name)-channel-\(channel).svg' type='image/svg+xml'></object>")
            }
            parts.append("<p>Exact first/last/peak sample times and min/max per ≤1 ms bin: <a href='\(name)-waveform.json'>waveform JSON</a>. Sample rate \(inspection.audio.sampleRate) Hz. Choose bounds conservatively; a quiet region or another sound does not establish a clap.</p></section>")
        }
        return parts.joined()
    }
    static func inspect(_ args: [String]) async throws {
        guard args.count == 6,
              let firstLower = Double(args[2]), let firstUpper = Double(args[3]),
              let endLower = Double(args[4]), let endUpper = Double(args[5]) else { throw Failure.arguments }
        let windows = [Window(name: "beginning", lower: firstLower, upper: firstUpper),
            Window(name: "end", lower: endLower, upper: endUpper)]
        guard windows.allSatisfy(validWindow), firstUpper < endLower else { throw Failure.bounds }
        let input = try fileURL(args[0])
        let directory = URL(fileURLWithPath: args[1], isDirectory: true)
        let before = try hash(input)
        let asset = AVURLAsset(url: input)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite && endUpper <= duration else { throw Failure.bounds }
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
              let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else { throw Failure.media }
        let formats = try await videoTrack.load(.formatDescriptions)
        guard !formats.isEmpty, formats.allSatisfy({
            let dimensions = CMVideoFormatDescriptionGetDimensions($0)
            return dimensions.width > 0 && dimensions.height > 0 && dimensions.width <= 4096 && dimensions.height <= 4096
        }) else { throw Failure.bounds }
        // POSIX mkdir is exclusive; an existing directory is never reused/emptied.
        guard mkdir(directory.path, 0o700) == 0 else { throw Failure.outputExists }
        do {
            var inspections: [Inspection] = []
            for window in windows {
                let frames = try await video(asset, track: videoTrack, window: window, directory: directory)
                let audio = try audio(asset, track: audioTrack, window: window)
                let inspection = Inspection(window: window, frames: frames, audio: audio)
                inspections.append(inspection)
                try write(encoded(audio), directory.appendingPathComponent("\(window.name)-waveform.json"))
                for channel in 0..<audio.channels {
                    try write(Data(waveform(inspection, channel: channel).utf8),
                        directory.appendingPathComponent("\(window.name)-channel-\(channel).svg"))
                }
            }
            guard try hash(input) == before else { throw Failure.changedInput }
            let manifest = Manifest(schema: 1, inputSHA256: before, inspections: inspections)
            try write(Data(html(inspections).utf8), directory.appendingPathComponent("index.html"))
            let selections = Selections(schema: 1, markers: windows.map {
                Selection(name: $0.name, channel: nil, video: nil, audio: nil)
            })
            try write(encoded(selections), directory.appendingPathComponent("selections-template.json"))
            try write(encoded(manifest), directory.appendingPathComponent("manifest.json"))
        } catch {
            // Retain partial outputs for inspection, but never leave a success manifest.
            // The manifest is written only after both decoded windows and input hash pass.
            throw error
        }
        FileHandle.standardOutput.write(Data("markerInspectionCreated\n".utf8))
    }
    static func bracket(_ b: Bracket) -> Bool { b.lower.isFinite && b.upper.isFinite && b.lower <= b.upper }
    static func measure(_ args: [String]) throws {
        guard args.count == 2 else { throw Failure.arguments }
        let manifestData = try boundedData(args[0], maximum: 10_000_000)
        let selectionData = try boundedData(args[1], maximum: 16_384)
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        let selections = try JSONDecoder().decode(Selections.self, from: selectionData)
        guard manifest.schema == 1, selections.schema == 1, manifest.inspections.count == 2,
              selections.markers.count == 2, Set(selections.markers.map(\.name)) == Set(["beginning", "end"]),
              Set(manifest.inspections.map(\.window.name)) == Set(["beginning", "end"]) else { throw Failure.selection }
        var measurements: [Measurement] = []
        for inspection in manifest.inspections {
            let marker = selections.markers.first { $0.name == inspection.window.name }!
            guard validWindow(inspection.window) else { throw Failure.selection }
            if marker.channel == nil && marker.video == nil && marker.audio == nil {
                measurements.append(Measurement(name: marker.name, status: "pendingMissingOrAmbiguousMarker",
                    channel: nil, offsetLowerSeconds: nil, offsetUpperSeconds: nil, midpointSeconds: nil, halfRangeSeconds: nil))
                continue
            }
            guard let channel = marker.channel, let v = marker.video, let a = marker.audio,
                  bracket(v), bracket(a), v.lower < v.upper, a.lower < a.upper,
                  (0..<inspection.audio.channels).contains(channel),
                  inspection.audio.channels == inspection.audio.bins.count,
                  inspection.frames.contains(where: { abs($0.pts - v.lower) <= 0.000_000_001 }),
                  inspection.frames.contains(where: { abs($0.pts - v.upper) <= 0.000_000_001 }) else { throw Failure.selection }
            let bins = inspection.audio.bins[channel]
            guard let first = bins.first, let last = bins.last,
                  a.lower >= first.firstPTS, a.upper <= last.lastPTS,
                  v.lower >= inspection.window.lower, v.upper <= inspection.window.upper else { throw Failure.selection }
            // Reject an audio bracket spanning a decoded discontinuity. The bracket
            // must be covered by contiguous PCM, not merely track endpoints.
            let relevant = bins.filter { $0.lastPTS >= a.lower && $0.firstPTS <= a.upper }
            guard !relevant.isEmpty, inspection.audio.sampleRate.isFinite,
                  (8_000...192_000).contains(inspection.audio.sampleRate),
                  relevant.first!.firstPTS <= a.lower + 1 / inspection.audio.sampleRate,
                  relevant.last!.lastPTS >= a.upper - 1 / inspection.audio.sampleRate else { throw Failure.selection }
            for pair in zip(relevant, relevant.dropFirst()) {
                guard pair.1.firstPTS - pair.0.lastPTS <= 1.5 / inspection.audio.sampleRate else { throw Failure.selection }
            }
            let lower = a.lower - v.upper
            let upper = a.upper - v.lower
            measurements.append(Measurement(name: marker.name, status: "humanSelectedInterval",
                channel: channel, offsetLowerSeconds: lower, offsetUpperSeconds: upper,
                midpointSeconds: (lower + upper) / 2, halfRangeSeconds: (upper - lower) / 2))
        }
        FileHandle.standardOutput.write(try encoded(Result(markers: measurements)))
    }
    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            guard let command = args.first else { throw Failure.arguments }
            switch command {
            case "inspect": try await inspect(Array(args.dropFirst()))
            case "measure": try measure(Array(args.dropFirst()))
            default: throw Failure.arguments
            }
        } catch {
            let code = (error as? Failure ?? .media).rawValue
            FileHandle.standardError.write(Data(("markerUnavailable:" + code + "\n").utf8))
            exit(1)
        }
    }
}
