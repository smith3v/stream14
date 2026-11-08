import AVFoundation
import Darwin

struct InvalidFixture: Error { let message: String }
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw InvalidFixture(message: message) }
}

@main struct DecodePrivateReceiver {
    static func main() async {
        do { try await run() }
        catch {
            FileHandle.standardError.write(Data("Receiver validation failed: \(error)\n".utf8))
            exit(1)
        }
    }
    static func run() async throws {
        let paths = Array(CommandLine.arguments.dropFirst())
        try require(paths.count == 2, "expected two retained receiver generations")
        var misaligned = 0
        for (generation, path) in paths.enumerated() {
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            var markers: [AVMediaType: Double] = [:]
            for type in [AVMediaType.video, .audio] {
                let tracks = try await asset.loadTracks(withMediaType: type)
                try require(tracks.count == 1, "expected exactly one track per media type")
                let track = tracks[0]
                let formats = try await track.load(.formatDescriptions)
                try require(formats.count == 1, "unexpected format changes")
                let codec = CMFormatDescriptionGetMediaSubType(formats[0])
                try require(codec == (type == .video ? kCMVideoCodecType_H264 : kAudioFormatMPEG4AAC), "unexpected codec")
                if type == .video {
                    let dimensions = CMVideoFormatDescriptionGetDimensions(formats[0])
                    try require(dimensions.width == 1280 && dimensions.height == 720, "unexpected dimensions")
                } else {
                    guard let format = CMAudioFormatDescriptionGetStreamBasicDescription(formats[0]) else {
                        throw InvalidFixture(message: "missing audio format")
                    }
                    try require(format.pointee.mSampleRate == 44_100 && format.pointee.mChannelsPerFrame == 2, "unexpected audio format")
                }
                let reader = try AVAssetReader(asset: asset)
                let settings: [String: Any] = type == .video ?
                    [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA] :
                    [AVFormatIDKey: Int(kAudioFormatLinearPCM), AVLinearPCMIsFloatKey: true,
                     AVLinearPCMBitDepthKey: 32, AVLinearPCMIsNonInterleaved: false]
                let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
                reader.add(output)
                try require(reader.startReading(), "decode startup failed")
                var last = -Double.infinity
                var first: Double?
                var count = 0
                var frames = 0
                var decodedEnd = 0.0
                while let sample = output.copyNextSampleBuffer() {
                    let pts = sample.presentationTimeStamp.seconds
                    try require(pts > last, "nonmonotonic decoded timestamps")
                    if first == nil { first = pts }
                    last = pts
                    count += 1
                    frames += sample.numSamples
                    let duration = sample.duration.isNumeric ? sample.duration.seconds :
                        (type == .video ? 1 / 30 : Double(sample.numSamples) / 44_100)
                    decodedEnd = max(decodedEnd, pts + duration)
                    if type == .video, let image = sample.imageBuffer {
                        CVPixelBufferLockBaseAddress(image, .readOnly)
                        let bright = CVPixelBufferGetBaseAddress(image)!.assumingMemoryBound(to: UInt8.self).pointee > 200
                        CVPixelBufferUnlockBaseAddress(image, .readOnly)
                        if bright && markers[type] == nil { markers[type] = pts }
                    } else if type == .audio, markers[type] == nil, let block = sample.dataBuffer {
                        var bytes = Data(count: CMBlockBufferGetDataLength(block))
                        let status = bytes.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0,
                            dataLength: $0.count, destination: $0.baseAddress!) }
                        try require(status == noErr, "PCM read failed")
                        let onset = bytes.withUnsafeBytes { raw -> Int? in
                            for frame in 0..<(raw.count / 8) {
                                if abs(raw.loadUnaligned(fromByteOffset: frame * 8, as: Float.self)) > 0.02 { return frame }
                            }
                            return nil
                        }
                        if let onset { markers[type] = pts + Double(onset) / 44_100 }
                    }
                }
                try require(reader.status == .completed, "decode did not complete")
                try require(frames >= (type == .video ? 170 : 245_000), "too few decoded frames")
                print("generation \(generation + 1) \(type.rawValue): buffers=\(count) frames=\(frames) start=\(first!) end=\(decodedEnd)")
                try require(first != nil && abs(first!) < 0.1 && decodedEnd > 5.75 && decodedEnd < 6.2, "unexpected receiver timeline")
            }
            guard let video = markers[.video], let audio = markers[.audio] else { throw InvalidFixture(message: "missing marker") }
            print("generation \(generation + 1): video marker=\(video), audio marker=\(audio), offset=\(audio-video)")
            try require(abs(video - 4.5) < 0.1, "video marker moved from common origin")
            if abs(audio - video) >= 0.035 { misaligned += 1 }
        }
        try require(misaligned == 0, "receiver A/V marker offset exceeds 35ms in \(misaligned) generations")
    }
}
