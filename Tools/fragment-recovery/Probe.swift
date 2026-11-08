import AVFoundation
import Foundation
import CryptoKit

// Standalone laptop experiment, never linked into Stream14.
@main struct Probe {
    static func emit(_ value: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        FileHandle.standardOutput.write(data + Data([10]))
    }
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "FragmentProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func main() async {
        do {
            let args = CommandLine.arguments
            let url = URL(fileURLWithPath: args[2])
            if args[1] == "write" { try await write(url, mode: args[3]); return }
            if args[1] == "inspect" { try await inspect(url); return }
            if args[1] == "export" {
                let asset = AVURLAsset(url: url)
                guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
                    throw NSError(domain: "ExportUnavailable", code: 1)
                }
                try await export.export(to: URL(fileURLWithPath: args[3]), as: .mp4)
                emit(["export": "completed"])
            }
        } catch { emit(["error": String(describing: error)]); exit(1) }
    }
    static func write(_ url: URL, mode: String) async throws {
        #if APP_WRITER
        try await AppWriter.write(url, mode: mode)
        #else
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        writer.movieFragmentInterval = CMTime(seconds: 10, preferredTimescale: 600)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 180,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 300_000, AVVideoMaxKeyFrameIntervalKey: 30]])
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64_000])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 180])
        video.expectsMediaDataInRealTime = true; audio.expectsMediaDataInRealTime = true
        try check(writer.canAdd(video) && writer.canAdd(audio), "writer inputs unavailable")
        writer.add(video); writer.add(audio)
        try check(writer.startWriting(), "start: \(String(describing: writer.error))")
        writer.startSession(atSourceTime: .zero)
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        let seconds = mode == "before" ? 5 : 25
        for frame in 0..<(seconds * 30) {
            if frame % 30 == 0 { emit(["checkpoint": "progress", "frame": frame]) }
            while !video.isReadyForMoreMediaData {
                try check(writer.status == .writing, "writer: \(String(describing: writer.error))")
                try await Task.sleep(for: .milliseconds(1))
            }
            var pixel: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixel)
            let pb = pixel!
            CVPixelBufferLockBaseAddress(pb, [])
            let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(pb)
            for y in 0..<180 { for x in 0..<320 {
                let offset = y * stride + x * 4
                base[offset] = UInt8(frame % 256); base[offset+1] = UInt8((frame / 30) * 9)
                base[offset+2] = UInt8(x % 256); base[offset+3] = 255
            }}
            CVPixelBufferUnlockBaseAddress(pb, [])
            try check(adaptor.append(pb, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)), "video append")
            let pcm = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: 1600)!
            pcm.frameLength = 1600
            for n in 0..<1600 { pcm.floatChannelData![0][n] = Float(sin(Double(frame * 1600 + n) * 2 * .pi * 440 / 48_000)) * 0.1 }
            var sample: CMSampleBuffer?
            let status = CMAudioSampleBufferCreateWithPacketDescriptions(allocator: nil, dataBuffer: nil, dataReady: false,
                makeDataReadyCallback: nil, refcon: nil, formatDescription: audioFormat.formatDescription,
                sampleCount: 1600, presentationTimeStamp: CMTime(value: Int64(frame * 1600), timescale: 48_000),
                packetDescriptions: nil, sampleBufferOut: &sample)
            try check(status == noErr, "audio sample")
            try check(CMSampleBufferSetDataBufferFromAudioBufferList(sample!, blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0, bufferList: pcm.audioBufferList) == noErr, "audio data")
            while !audio.isReadyForMoreMediaData {
                try check(writer.status == .writing, "audio readiness")
                try await Task.sleep(for: .milliseconds(1))
            }
            try check(audio.append(sample!), "audio append")
        }
        emit(["checkpoint": "appended", "seconds": seconds])
        if mode == "before" || mode == "after" {
            // Allow asynchronous encoder/file IO to drain without finalizing the movie.
            try await Task.sleep(for: .milliseconds(500))
            emit(["checkpoint": "kill-ready"])
            try await Task.sleep(for: .seconds(30))
            return
        }
        video.markAsFinished(); audio.markAsFinished()
        // The callback signal precedes waiting so the parent races actual finalization.
        writer.finishWriting {
            emit(["checkpoint": "finish-completed"])
        }
        emit(["checkpoint": "finish-started"])
        while writer.status == .writing { try await Task.sleep(for: .milliseconds(1)) }
        try check(writer.status == .completed, "finish: \(String(describing: writer.error))")
        // Remain alive so parent can detect a kill that happened after completion.
        if mode == "finalize" { try await Task.sleep(for: .seconds(2)) }
        emit(["checkpoint": "normal-complete"])
        #endif
    }
    static func inspect(_ url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.load(.tracks)
        var reports = [[String: Any]]()
        for track in tracks {
            // Read decoded output, not just track metadata or compressed packets.
            let reader = try AVAssetReader(asset: asset)
            let settings: [String: Any] = track.mediaType == .video
                ? [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                : [AVFormatIDKey: kAudioFormatLinearPCM]
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
            reader.add(output)
            try check(reader.startReading(), "reader start: \(String(describing: reader.error))")
            let frameRate = try await track.load(.nominalFrameRate)
            var count = 0, sampleUnits = 0, first = Double.nan, end = 0.0, lastPTS = 0.0
            while let sample = output.copyNextSampleBuffer() {
                let start = sample.presentationTimeStamp.seconds
                if count == 0 { first = start }
                let d = sample.duration.seconds
                end = max(end, start + (d.isFinite && d > 0 ? d : (frameRate > 0 ? 1 / Double(frameRate) : 0)))
                lastPTS = start
                sampleUnits += sample.numSamples
                count += 1
            }
            let packetReader = try AVAssetReader(asset: asset)
            let packets = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            packetReader.add(packets)
            try check(packetReader.startReading(), "compressed reader start")
            var hash = SHA256(), packetCount = 0, emptySamples = 0, compressedBytes = 0
            while let sample = packets.copyNextSampleBuffer() {
                if sample.numSamples == 0 { emptySamples += 1; continue }
                guard let buffer = sample.dataBuffer else { throw NSError(domain: "MissingPacketData", code: 1) }
                let length = CMBlockBufferGetDataLength(buffer)
                var data = Data(count: length)
                let result = data.withUnsafeMutableBytes {
                    CMBlockBufferCopyDataBytes(buffer, atOffset: 0, dataLength: length, destination: $0.baseAddress!)
                }
                try check(result == noErr, "compressed packet copy")
                compressedBytes += length
                hash.update(data: data)
                packetCount += 1
            }
            reports.append(["type": track.mediaType.rawValue, "samples": count,
                "compressedBuffers": packetCount, "emptyCompressedSamples": emptySamples,
                "compressedBytes": compressedBytes, "compressedReaderStatus": packetReader.status.rawValue,
                "compressedSHA256": hash.finalize().map { String(format: "%02x", $0) }.joined(),
                "first": first.isFinite ? first : -1, "lastPTS": lastPTS, "endEstimate": end,
                "decodedSampleUnits": sampleUnits, "readerStatus": reader.status.rawValue,
                "error": reader.error.map(String.init(describing:)) ?? ""])
        }
        emit(["duration": duration.isFinite ? duration : -1, "tracks": reports])
    }
}
