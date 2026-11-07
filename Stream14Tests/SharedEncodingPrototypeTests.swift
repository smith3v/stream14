import AVFoundation
import Synchronization
import Testing
import VideoToolbox
@testable import Stream14

/// Offline feasibility only. No camera, mixer attachment, socket or production
/// output is created. This finite clip is not a production encoder/queue design.
@Suite(.serialized)
struct SharedEncodingPrototypeTests {
    @Test func oneNativeEncodeFeedsTwoCompressedFiles() async throws {
        let clip = try NativeClip.make()
        #expect(clip.video.count == 30)
        #expect(clip.audio.count > 30)
        #expect(clip.video.allSatisfy { $0.presentationTimeStamp > .zero })
        #expect(clip.audio.allSatisfy { $0.presentationTimeStamp > .zero })
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try PassthroughFile(directory.appendingPathComponent("first.mp4"), clip: clip)
        let second = try PassthroughFile(directory.appendingPathComponent("second.mp4"), clip: clip)
        for sample in clip.interleaved {
            try await first.append(sample)
            try await second.append(sample)
        }
        try await first.finish()
        try await second.finish()
        for type in [AVMediaType.video, .audio] {
            let expected = try clip.packets(type)
            #expect(!expected.isEmpty)
            #expect(try await packets(first.url, type) == expected)
            #expect(try await packets(second.url, type) == expected)
        }
    }

    @Test func stalledAdmissionAndFailedWriterDoNotStopOtherFile() async throws {
        let clip = try NativeClip.make()
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let healthy = try PassthroughFile(directory.appendingPathComponent("healthy.mp4"), clip: clip)
        let failing = try PassthroughFile(directory.appendingPathComponent("failed.mp4"), clip: clip)
        let encoded = try clip.video.map { sample in
            (data: try bytes(sample), keyframe: isKeyframe(sample))
        }
        let byteLimit = try #require(encoded.map(\.data.count).max()) * 2
        var sender = SenderAdmission(byteLimit: byteLimit, packetLimit: 2)
        var acceptedAfterWriterFailure = 0
        var index = 0
        for sample in clip.interleaved {
            try await healthy.append(sample)
            if index < 8 { try await failing.append(sample) }
            if index == 8 { failing.cancel() }
            if sample.formatDescription?.mediaType == .video {
                let packet = encoded[index]
                if index == 15 { sender.reconnect() }
                if sender.offer(packet.data, keyframe: packet.keyframe), index >= 15 {
                    acceptedAfterWriterFailure += 1
                }
                // Before reconnect the sender stalls while one packet is in flight.
                // After reconnect it acknowledges packets normally.
                if index == 0 || index >= 15 {
                    if let next = sender.take(), index >= 15 { sender.acknowledge(next) }
                }
                index += 1
            }
        }
        #expect(sender.overflowCount > 0)
        #expect(sender.highWaterBytes <= byteLimit)
        #expect(sender.highWaterPackets <= 2)
        #expect(acceptedAfterWriterFailure > 0)
        #expect(failing.writer.status == .cancelled)
        #expect(FileManager.default.fileExists(atPath: failing.url.path))
        try await healthy.finish()
        #expect(try await packets(healthy.url, .video) == clip.packets(.video))
        #expect(try await packets(healthy.url, .audio) == clip.packets(.audio))
        // This proves the test seam's independence, not HaishinKit socket bounds
        // or receiver delivery. The real library admission patch remains pending.
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private struct CodecPacket: Equatable {
    let data: Data
    let pts: CMTime
}

private struct NativeClip {
    let video: [CMSampleBuffer]
    let audio: [CMSampleBuffer]
    var interleaved: [CMSampleBuffer] {
        (video + audio).sorted { $0.presentationTimeStamp < $1.presentationTimeStamp }
    }
    func packets(_ type: AVMediaType) throws -> [CodecPacket] {
        try (type == .video ? video : audio).flatMap(codecPackets)
    }

    static func make() throws -> Self {
        // Exactly one compression session. Complete each submitted frame before
        // generating the next, so the prototype has at most one in-flight frame.
        var optionalSession: VTCompressionSession?
        try #require(VTCompressionSessionCreate(allocator: nil, width: 1280, height: 720,
            codecType: kCMVideoCodecType_H264, encoderSpecification: nil,
            imageBufferAttributes: nil, compressedDataAllocator: nil,
            outputCallback: nil, refcon: nil, compressionSessionOut: &optionalSession) == noErr)
        let session = try #require(optionalSession)
        defer { VTCompressionSessionInvalidate(session) }
        for (key, value) in [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue as CFTypeRef,
            kVTCompressionPropertyKey_AllowFrameReordering: kCFBooleanFalse as CFTypeRef,
            kVTCompressionPropertyKey_AverageBitRate: NSNumber(value: 8_000_000),
            kVTCompressionPropertyKey_MaxKeyFrameInterval: NSNumber(value: 60)
        ] {
            try #require(VTSessionSetProperty(session, key: key, value: value) == noErr)
        }
        try #require(VTCompressionSessionPrepareToEncodeFrames(session) == noErr)
        let output = Mutex((samples: [CMSampleBuffer](), failures: 0))
        for index in 0..<30 {
            let raw = try LocalRecorderTests.video(index, profile: .hd)
            let image = try #require(raw.imageBuffer)
            // First packet and reconnect packet are explicit random-access frames.
            let properties = [kVTEncodeFrameOptionKey_ForceKeyFrame: index == 0 || index == 15] as CFDictionary
            let time = CMTime(value: Int64(30 + index), timescale: 30)
            try #require(VTCompressionSessionEncodeFrame(session, imageBuffer: image,
                presentationTimeStamp: time, duration: CMTime(value: 1, timescale: 30),
                frameProperties: properties, infoFlagsOut: nil, outputHandler: { status, flags, sample in
                    output.withLock {
                        if status == noErr, !flags.contains(.frameDropped), let sample { $0.samples.append(sample) }
                        else { $0.failures += 1 }
                    }
                }) == noErr)
            try #require(VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid) == noErr)
        }
        let compressed = output.withLock { $0 }
        try #require(compressed.failures == 0 && compressed.samples.count == 30)
        let audio = try encodeAudio()
        return Self(video: compressed.samples, audio: audio)
    }

    private static func encodeAudio() throws -> [CMSampleBuffer] {
        let inputFormat = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let outputFormat = try #require(AVAudioFormat(settings: SessionProfile.hd.audioSettings))
        // Exactly one native converter. Finite generated PCM, not a realtime mic.
        let converter = try #require(AVAudioConverter(from: inputFormat, to: outputFormat))
        converter.bitRate = 128_000
        converter.primeMethod = .none
        var suppliedFrames = 0
        var packetIndex: Int64 = 0
        var samples: [CMSampleBuffer] = []
        // Bounds guard accidental converter spin even if a platform behaves oddly.
        for _ in 0..<128 {
            let buffer = AVAudioCompressedBuffer(format: outputFormat, packetCapacity: 1,
                maximumPacketSize: max(4096, converter.maximumOutputPacketSize))
            var error: NSError?
            let status = converter.convert(to: buffer, error: &error) { requested, inputStatus in
                guard suppliedFrames < 44_100 else {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                let count = min(Int(requested), 44_100 - suppliedFrames)
                guard let pcm = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(count)) else {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                pcm.frameLength = AVAudioFrameCount(count)
                for channel in 0..<2 {
                    for frame in 0..<count {
                        pcm.floatChannelData![channel][frame] = Float(sin(Double(suppliedFrames + frame) * 2 * .pi * 440 / 44_100) * 0.1)
                    }
                }
                suppliedFrames += count
                inputStatus.pointee = .haveData
                return pcm
            }
            try #require(error == nil && status != .error)
            if buffer.packetCount > 0 {
                var block: CMBlockBuffer?
                try #require(CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil,
                    blockLength: Int(buffer.byteLength), blockAllocator: nil, customBlockSource: nil,
                    offsetToData: 0, dataLength: Int(buffer.byteLength), flags: 0, blockBufferOut: &block) == noErr)
                let owned = try #require(block)
                try #require(CMBlockBufferReplaceDataBytes(with: buffer.data, blockBuffer: owned,
                    offsetIntoDestination: 0, dataLength: Int(buffer.byteLength)) == noErr)
                var sample: CMSampleBuffer?
                let pts = CMTime(value: 44_100 + packetIndex * 1024, timescale: 44_100)
                try #require(CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil,
                    dataBuffer: owned, formatDescription: outputFormat.formatDescription,
                    sampleCount: Int(buffer.packetCount), presentationTimeStamp: pts,
                    packetDescriptions: buffer.packetDescriptions, sampleBufferOut: &sample) == noErr)
                samples.append(try #require(sample))
                packetIndex += Int64(buffer.packetCount)
            }
            if status == .endOfStream { return samples }
        }
        throw PrototypeFailure.converterDidNotFinish
    }
}

private final class PassthroughFile {
    let url: URL
    let writer: AVAssetWriter
    private let video: AVAssetWriterInput
    private let audio: AVAssetWriterInput

    init(_ url: URL, clip: NativeClip) throws {
        self.url = url
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        video = AVAssetWriterInput(mediaType: .video, outputSettings: nil,
            sourceFormatHint: try #require(clip.video.first?.formatDescription))
        audio = AVAssetWriterInput(mediaType: .audio, outputSettings: nil,
            sourceFormatHint: try #require(clip.audio.first?.formatDescription))
        try #require(writer.canAdd(video) && writer.canAdd(audio))
        writer.add(video); writer.add(audio)
        try #require(writer.startWriting())
        writer.startSession(atSourceTime: CMTime(value: 1, timescale: 1))
    }

    func append(_ sample: CMSampleBuffer) async throws {
        let input = sample.formatDescription?.mediaType == .video ? video : audio
        for _ in 0..<200 {
            guard writer.status == .writing else { throw PrototypeFailure.writerFailed }
            if input.isReadyForMoreMediaData {
                try #require(input.append(sample))
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw PrototypeFailure.writerStalled
    }
    func cancel() { writer.cancelWriting() }
    func finish() async throws {
        video.markAsFinished(); audio.markAsFinished()
        await writer.finishWriting()
        try #require(writer.status == .completed && writer.error == nil)
    }
}

/// Deterministic send seam: counts queued PLUS one taken-but-unacknowledged
/// packet. A stalled send cannot free its byte budget. Overflow ends this
/// transport generation rather than dropping arbitrary encoded RTMP chunks.
private struct SenderAdmission {
    struct Lease { let generation: Int; let data: Data }
    let byteLimit: Int
    let packetLimit: Int
    private(set) var highWaterBytes = 0
    private(set) var highWaterPackets = 0
    private(set) var overflowCount = 0
    private var generation = 0
    private var queued: [Data] = []
    private var inFlight: Data?
    private var failed = false
    private var needsKeyframe = true
    private var bytes: Int { queued.reduce(0) { $0 + $1.count } + (inFlight?.count ?? 0) }

    mutating func offer(_ data: Data, keyframe: Bool) -> Bool {
        guard !failed, !needsKeyframe || keyframe else { return false }
        guard bytes + data.count <= byteLimit, queued.count + (inFlight == nil ? 0 : 1) < packetLimit else {
            overflowCount += 1; failed = true; queued.removeAll()
            return false
        }
        needsKeyframe = false
        queued.append(data)
        highWaterBytes = max(highWaterBytes, bytes)
        highWaterPackets = max(highWaterPackets, queued.count + (inFlight == nil ? 0 : 1))
        return true
    }
    mutating func take() -> Lease? {
        guard !failed, inFlight == nil, !queued.isEmpty else { return nil }
        inFlight = queued.removeFirst()
        return Lease(generation: generation, data: inFlight!)
    }
    mutating func acknowledge(_ lease: Lease) {
        guard lease.generation == generation else { return }
        inFlight = nil
    }
    mutating func reconnect() {
        generation += 1; queued.removeAll(); inFlight = nil; failed = false; needsKeyframe = true
    }
}

private func isKeyframe(_ sample: CMSampleBuffer) -> Bool {
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[String: Any]],
          let first = attachments.first else { return true }
    return first[kCMSampleAttachmentKey_NotSync as String] as? Bool != true
}

private func bytes(_ sample: CMSampleBuffer) throws -> Data {
    let block = try #require(sample.dataBuffer)
    var data = Data(count: CMBlockBufferGetDataLength(block))
    try data.withUnsafeMutableBytes {
        try #require(CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: $0.count,
            destination: $0.baseAddress!) == noErr)
    }
    return data
}

private func codecPackets(_ sample: CMSampleBuffer) throws -> [CodecPacket] {
    guard sample.numSamples > 0, sample.dataBuffer != nil else { return [] }
    let data = try bytes(sample)
    guard sample.formatDescription?.mediaType == .audio else {
        return [CodecPacket(data: data, pts: sample.presentationTimeStamp)]
    }
    var descriptions: UnsafePointer<AudioStreamPacketDescription>?
    var size = 0
    try #require(CMSampleBufferGetAudioStreamPacketDescriptionsPtr(sample,
        packetDescriptionsPointerOut: &descriptions, sizeOut: &size) == noErr)
    let packets = try #require(descriptions)
    let format = try #require(sample.formatDescription)
    let asbd = try #require(CMAudioFormatDescriptionGetStreamBasicDescription(format))
    var frames: Int64 = 0
    return try (0..<(size / MemoryLayout<AudioStreamPacketDescription>.size)).map { index in
        let packet = packets[index]
        let start = Int(packet.mStartOffset)
        let end = start + Int(packet.mDataByteSize)
        try #require(start >= 0 && end <= data.count)
        defer { frames += Int64(packet.mVariableFramesInPacket == 0 ? asbd.pointee.mFramesPerPacket : packet.mVariableFramesInPacket) }
        return CodecPacket(data: data.subdata(in: start..<end), pts: sample.presentationTimeStamp +
            CMTime(value: frames, timescale: CMTimeScale(asbd.pointee.mSampleRate)))
    }
}

private func packets(_ url: URL, _ type: AVMediaType) async throws -> [CodecPacket] {
    let asset = AVURLAsset(url: url)
    let track = try #require(try await asset.loadTracks(withMediaType: type).first)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
    reader.add(output)
    try #require(reader.startReading())
    var result: [CodecPacket] = []
    while let sample = output.copyNextSampleBuffer() { result += try codecPackets(sample) }
    try #require(reader.status == .completed)
    // MP4 begins at the same positive shared source origin but normalizes its
    // presentation timeline to zero on read. Restore that one common offset.
    return result.map { CodecPacket(data: $0.data, pts: $0.pts + CMTime(value: 1, timescale: 1)) }
}

private enum PrototypeFailure: Error { case converterDidNotFinish, writerFailed, writerStalled }
