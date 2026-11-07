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
            let firstPackets = try await packets(first.url, type, audioPriming: clip.audioPriming)
            let secondPackets = try await packets(second.url, type, audioPriming: clip.audioPriming)
            #expect(firstPackets == secondPackets)
            #expect(firstPackets.count == expected.count)
            #expect(firstPackets.first?.pts == expected.first?.pts)
            #expect(firstPackets.last?.pts == expected.last?.pts)
            #expect(zip(firstPackets, expected).allSatisfy { $0.data == $1.data })
            #expect(zip(firstPackets, expected).allSatisfy { $0.pts == $1.pts })
        }
        let marker = try await markerTimes(first.url)
        #expect(abs(marker.video - 0.5) < 0.005)
        #expect(abs(marker.audio - marker.video) < 0.035)
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
            if index == 8 { failing.injectFailure() }
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
        #expect(failing.injectedFailure)
        // Finish the retained partial native file, but keep the consumer's failed
        // state. cancelWriting would delete it and is unsuitable for this failure.
        try await failing.finish()
        #expect(FileManager.default.fileExists(atPath: failing.url.path))
        try await healthy.finish()
        #expect(try await packets(healthy.url, .video) == clip.packets(.video))
        #expect(try await packets(healthy.url, .audio, audioPriming: clip.audioPriming) == clip.packets(.audio))
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
    let audioPriming: CMTime
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
            CVPixelBufferLockBaseAddress(image, [])
            memset(CVPixelBufferGetBaseAddress(image), index >= 15 ? 255 : 90, CVPixelBufferGetDataSize(image))
            CVPixelBufferUnlockBaseAddress(image, [])
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
        return Self(video: compressed.samples, audio: audio.samples, audioPriming: audio.priming)
    }

    private static func encodeAudio() throws -> (samples: [CMSampleBuffer], priming: CMTime) {
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
                        pcm.floatChannelData![channel][frame] = suppliedFrames + frame < 22_050 ? 0 :
                            Float(sin(Double(suppliedFrames + frame) * 2 * .pi * 440 / 44_100) * 0.1)
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
                var description: CMAudioFormatDescription?
                let cookie = converter.magicCookie ?? Data()
                let formatStatus = cookie.withUnsafeBytes {
                    CMAudioFormatDescriptionCreate(allocator: nil, asbd: outputFormat.streamDescription,
                        layoutSize: 0, layout: nil, magicCookieSize: $0.count, magicCookie: $0.baseAddress,
                        extensions: nil, formatDescriptionOut: &description)
                }
                try #require(formatStatus == noErr)
                let format = try #require(description)
                var sample: CMSampleBuffer?
                let pts = CMTime(value: 44_100 + packetIndex * 1024, timescale: 44_100)
                try #require(CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil,
                    dataBuffer: owned, formatDescription: format,
                    sampleCount: Int(buffer.packetCount), presentationTimeStamp: pts,
                    packetDescriptions: buffer.packetDescriptions, sampleBufferOut: &sample) == noErr)
                samples.append(try #require(sample))
                packetIndex += Int64(buffer.packetCount)
            }
            if status == .endOfStream {
                let leading = Int64(converter.primeInfo.leadingFrames)
                return (try trimAudio(samples, leading: leading, sourceFrames: 44_100),
                    CMTime(value: leading, timescale: 44_100))
            }
        }
        throw PrototypeFailure.converterDidNotFinish
    }

    private static func trimAudio(_ samples: [CMSampleBuffer], leading: Int64, sourceFrames: Int64) throws -> [CMSampleBuffer] {
        let trailing = max(0, Int64(samples.count) * 1024 - leading - sourceFrames)
        return try samples.enumerated().map { index, sample in
            let frame = Int64(index) * 1024
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1024, timescale: 44_100),
                presentationTimeStamp: CMTime(value: 44_100 + frame - leading, timescale: 44_100),
                decodeTimeStamp: .invalid)
            var copy: CMSampleBuffer?
            try #require(CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sample,
                sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleBufferOut: &copy) == noErr)
            let result = try #require(copy)
            let startTrim = min(1024, max(0, leading - frame))
            CMSetAttachment(result, key: kCMSampleBufferAttachmentKey_TrimDurationAtStart,
                value: CMTimeCopyAsDictionary(CMTime(value: startTrim, timescale: 44_100), allocator: nil),
                attachmentMode: kCMAttachmentMode_ShouldPropagate)
            if index == samples.count - 1 {
                CMSetAttachment(result, key: kCMSampleBufferAttachmentKey_TrimDurationAtEnd,
                    value: CMTimeCopyAsDictionary(CMTime(value: min(1024, trailing), timescale: 44_100), allocator: nil),
                    attachmentMode: kCMAttachmentMode_ShouldPropagate)
            }
            return result
        }
    }
}

private final class PassthroughFile {
    let url: URL
    let writer: AVAssetWriter
    private let video: AVAssetWriterInput
    private let audio: AVAssetWriterInput
    private(set) var injectedFailure = false

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
        guard !injectedFailure else { throw PrototypeFailure.writerFailed }
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
    func injectFailure() { injectedFailure = true }
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

private func packets(_ url: URL, _ type: AVMediaType, audioPriming: CMTime = .zero) async throws -> [CodecPacket] {
    let asset = AVURLAsset(url: url)
    let track = try #require(try await asset.loadTracks(withMediaType: type).first)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
    reader.add(output)
    try #require(reader.startReading())
    var result: [CodecPacket] = []
    while let sample = output.copyNextSampleBuffer() { result += try codecPackets(sample) }
    try #require(reader.status == .completed)
    // The writer normalizes the movie session to zero and its compressed AAC
    // readback shifts packet PTS by the declared encoder priming. Restore both
    // known offsets explicitly. Decoded midpoint markers independently check the
    // playable A/V result; packet normalization alone is not proof of sync.
    let correction = CMTime(value: 1, timescale: 1) - (type == .audio ? audioPriming : .zero)
    return result.map { CodecPacket(data: $0.data, pts: $0.pts + correction) }
}

private func markerTimes(_ url: URL) async throws -> (video: Double, audio: Double) {
    let asset = AVURLAsset(url: url)
    var times: [AVMediaType: Double] = [:]
    for type in [AVMediaType.video, .audio] {
        let track = try #require(try await asset.loadTracks(withMediaType: type).first)
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = type == .video ?
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA] :
            [AVFormatIDKey: Int(kAudioFormatLinearPCM), AVLinearPCMIsFloatKey: true,
             AVLinearPCMBitDepthKey: 32, AVLinearPCMIsNonInterleaved: false]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        try #require(reader.startReading())
        while let sample = output.copyNextSampleBuffer() {
            if type == .video, let image = sample.imageBuffer {
                CVPixelBufferLockBaseAddress(image, .readOnly)
                let bright = CVPixelBufferGetBaseAddress(image)!.assumingMemoryBound(to: UInt8.self).pointee > 200
                CVPixelBufferUnlockBaseAddress(image, .readOnly)
                if bright { times[type] = sample.presentationTimeStamp.seconds; break }
            } else if type == .audio {
                let format = try #require(sample.formatDescription)
                let asbd = try #require(CMAudioFormatDescriptionGetStreamBasicDescription(format))
                let channels = Int(asbd.pointee.mChannelsPerFrame)
                let data = try bytes(sample)
                let onset = data.withUnsafeBytes { raw -> Int? in
                    for frame in 0..<(data.count / (channels * MemoryLayout<Float>.size)) {
                        let level = raw.loadUnaligned(fromByteOffset: frame * channels * MemoryLayout<Float>.size, as: Float.self)
                        if abs(level) > 0.02 { return frame }
                    }
                    return nil
                }
                if let onset {
                    times[type] = sample.presentationTimeStamp.seconds + Double(onset) / asbd.pointee.mSampleRate
                    break
                }
            }
        }
        reader.cancelReading()
    }
    return (try #require(times[.video]), try #require(times[.audio]))
}

private enum PrototypeFailure: Error { case converterDidNotFinish, writerFailed, writerStalled }
