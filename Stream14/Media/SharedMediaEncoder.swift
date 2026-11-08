import AVFoundation
import HaishinKit
import Synchronization
import VideoToolbox

/// One codec owner after the existing HaishinKit composed-media boundary.
/// Currently a draft integration component: MediaSession does not attach it yet.
actor SharedMediaEncoder: MediaMixerOutput {
    enum Failure: Error, Sendable { case configuration, codec, timeline, audioFormat, rawOverflow, stopped }
    struct Limits: Sendable {
        var videoFrames = 2
        var audioFrames = 11_025 // 250 ms at the selected 44.1 kHz mixer rate
        var bytes = 16 * 1024 * 1024
    }
    struct Metrics: Sendable {
        var highWaterBytes = 0
        var highWaterVideoFrames = 0
        var highWaterAudioFrames = 0
        var rejectedVideoFrames = 0
        var rejectedAudioFrames = 0
    }
    private struct Intake {
        var samples: [CMSampleBuffer] = []
        var bytes = 0
        var videos = 0
        var audioFrames = 0
        var accepting = true
        var failure: Failure?
        var metrics = Metrics()
    }
    nonisolated let videoTrackId: UInt8? = .max
    nonisolated let audioTrackId: UInt8? = .max
    private nonisolated let intake = Mutex(Intake())
    private nonisolated let limits: Limits
    private nonisolated let wake: AsyncStream<Void>.Continuation
    private let wakes: AsyncStream<Void>
    private let core: SharedMediaCodec
    private var worker: Task<Void, Never>?
    private let output: @Sendable (CMSampleBuffer) -> Void
    private let failed: @Sendable (Failure) -> Void
    private var terminal = false

    init(profile: SessionProfile, limits: Limits = Limits(),
         output: @escaping @Sendable (CMSampleBuffer) -> Void,
         failed: @escaping @Sendable (Failure) -> Void) throws {
        self.limits = limits
        (wakes, wake) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        core = try SharedMediaCodec(profile: profile)
        self.output = output
        self.failed = failed
    }

    func start() {
        guard worker == nil, !terminal else { return }
        worker = Task { [weak self, wakes] in
            for await _ in wakes {
                guard let self else { return }
                await self.consume()
            }
        }
    }

    /// Admission includes the current in-flight item until encode returns. Copy
    /// library-owned PCM only after reservation, under the finite intake budget.
    @discardableResult
    nonisolated func offer(_ sample: CMSampleBuffer) -> Bool {
        admit(video: sample.formatDescription?.mediaType == .video,
              frames: sample.numSamples, bytes: Self.cost(sample)) { sample }
    }

    private nonisolated static func cost(_ sample: CMSampleBuffer) -> Int {
        if let image = sample.imageBuffer { return CVPixelBufferGetDataSize(image) }
        return sample.totalSampleSize
    }

    private nonisolated func admit(video: Bool, frames: Int, bytes: Int,
                                    copy: () -> CMSampleBuffer?) -> Bool {
        let admitted = intake.withLock { state in
            guard state.accepting else { return false }
            guard bytes > 0, bytes <= limits.bytes - state.bytes,
                  video ? state.videos < limits.videoFrames : frames <= limits.audioFrames - state.audioFrames else {
                if video { state.metrics.rejectedVideoFrames += 1 }
                else {
                    state.metrics.rejectedAudioFrames += frames
                    state.failure = .rawOverflow
                    state.accepting = false
                }
                return false
            }
            guard let sample = copy() else {
                state.failure = .audioFormat
                state.accepting = false
                return false
            }
            state.samples.append(sample)
            state.bytes += bytes
            if video { state.videos += 1 } else { state.audioFrames += frames }
            state.metrics.highWaterBytes = max(state.metrics.highWaterBytes, state.bytes)
            state.metrics.highWaterVideoFrames = max(state.metrics.highWaterVideoFrames, state.videos)
            state.metrics.highWaterAudioFrames = max(state.metrics.highWaterAudioFrames, state.audioFrames)
            return true
        }
        wake.yield(())
        return admitted
    }

    private func consume() {
        while !terminal {
            let next = intake.withLock { state -> (CMSampleBuffer?, Failure?) in
                if let failure = state.failure { return (nil, failure) }
                return (state.samples.isEmpty ? nil : state.samples.removeFirst(), nil)
            }
            if let failure = next.1 { fail(failure); return }
            guard let sample = next.0 else { return }
            do {
                for packet in try core.append(sample) { output(packet) }
            } catch {
                fail(error as? Failure ?? .codec)
                return
            }
            intake.withLock { state in
                state.bytes -= Self.cost(sample)
                if sample.formatDescription?.mediaType == .video { state.videos -= 1 }
                else { state.audioFrames -= sample.numSamples }
            }
        }
    }

    private func fail(_ failure: Failure) {
        terminal = true
        intake.withLock { state in
            state.accepting = false
            state.samples.removeAll()
            state.bytes = 0; state.videos = 0; state.audioFrames = 0
        }
        core.invalidate()
        wake.finish()
        failed(failure)
    }

    /// No media may be offered after this call begins. Drain admitted media and
    /// codec delay before the independently owned writer is finalized.
    func finish() throws {
        intake.withLock { $0.accepting = false }
        consume()
        guard !terminal else { throw Failure.stopped }
        do { for packet in try core.finish() { output(packet) } }
        catch { fail(error as? Failure ?? .codec); throw error }
        terminal = true
        core.invalidate()
        wake.finish()
        worker?.cancel(); worker = nil
    }

    nonisolated var metrics: Metrics { intake.withLock { $0.metrics } }
    nonisolated func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) async {}
    nonisolated func mixer(_ mixer: MediaMixer, didOutput sampleBuffer: CMSampleBuffer) { offer(sampleBuffer) }
    nonisolated func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        let list = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let bytes = list.reduce(0) { $0 + Int($1.mDataByteSize) }
        admit(video: false, frames: Int(buffer.frameLength), bytes: bytes) {
            LocalRecorder.audioSample(buffer, when: when)
        }
    }
}

/// Non-Sendable on purpose: all codec operations are serialized by the enclosing
/// actor. VT's completion owns only its finite Mutex result, never codec state.
nonisolated final class SharedMediaCodec {
    private let profile: SessionProfile
    private var video: VTCompressionSession?
    private var lastVideo = CMTime.invalid
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var audioOrigin = CMTime.invalid
    private var audioSourceFrames: Int64 = 0
    private var audioPackets: Int64 = 0
    private var pendingPCM: [AVAudioPCMBuffer] = []
    private var pcmOffset = 0
    private var pcmFrames = 0
    private var pendingAudio: CMSampleBuffer?
    private var forceKeyframe = true

    init(profile: SessionProfile) throws {
        self.profile = profile
        guard VTCompressionSessionCreate(allocator: nil, width: Int32(profile.width), height: Int32(profile.height),
            codecType: kCMVideoCodecType_H264, encoderSpecification: nil, imageBufferAttributes: nil,
            compressedDataAllocator: nil, outputCallback: nil, refcon: nil,
            compressionSessionOut: &video) == noErr, let video else { throw SharedMediaEncoder.Failure.configuration }
        let properties: [CFString: CFTypeRef] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_AllowFrameReordering: kCFBooleanFalse,
            kVTCompressionPropertyKey_AverageBitRate: NSNumber(value: profile.videoBitRate),
            kVTCompressionPropertyKey_ExpectedFrameRate: NSNumber(value: profile.frameRate),
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: NSNumber(value: profile.keyframeSeconds),
            kVTCompressionPropertyKey_ColorPrimaries: kCVImageBufferColorPrimaries_ITU_R_709_2,
            kVTCompressionPropertyKey_TransferFunction: kCVImageBufferTransferFunction_ITU_R_709_2,
            kVTCompressionPropertyKey_YCbCrMatrix: kCVImageBufferYCbCrMatrix_ITU_R_709_2
        ]
        for (key, value) in properties {
            guard VTSessionSetProperty(video, key: key, value: value) == noErr else {
                VTCompressionSessionInvalidate(video); self.video = nil
                throw SharedMediaEncoder.Failure.configuration
            }
        }
        guard VTCompressionSessionPrepareToEncodeFrames(video) == noErr else {
            invalidate(); throw SharedMediaEncoder.Failure.configuration
        }
    }

    func requestKeyframe() { forceKeyframe = true }

    func append(_ sample: CMSampleBuffer) throws -> [CMSampleBuffer] {
        guard let format = sample.formatDescription, sample.presentationTimeStamp.isNumeric else {
            throw SharedMediaEncoder.Failure.timeline
        }
        if format.mediaType == .video { return try encodeVideo(sample) }
        guard format.mediaType == .audio else { throw SharedMediaEncoder.Failure.audioFormat }
        return try encodeAudio(sample)
    }

    private func encodeVideo(_ sample: CMSampleBuffer) throws -> [CMSampleBuffer] {
        guard let video, let image = sample.imageBuffer,
              CVPixelBufferGetWidth(image) == profile.width, CVPixelBufferGetHeight(image) == profile.height,
              !lastVideo.isValid || sample.presentationTimeStamp > lastVideo else {
            throw SharedMediaEncoder.Failure.timeline
        }
        let result = Mutex((sample: Optional<CMSampleBuffer>.none, failed: false))
        let properties = [kVTEncodeFrameOptionKey_ForceKeyFrame: forceKeyframe] as CFDictionary
        guard VTCompressionSessionEncodeFrame(video, imageBuffer: image,
            presentationTimeStamp: sample.presentationTimeStamp, duration: CMTime(value: 1, timescale: 30),
            frameProperties: properties, infoFlagsOut: nil, outputHandler: { status, flags, sample in
                result.withLock { state in
                    if status != noErr || flags.contains(.frameDropped) || state.sample != nil { state.failed = true }
                    else { state.sample = sample }
                }
            }) == noErr,
            VTCompressionSessionCompleteFrames(video, untilPresentationTimeStamp: .invalid) == noErr else {
            throw SharedMediaEncoder.Failure.codec
        }
        let encoded = result.withLock { $0 }
        guard !encoded.failed, let packet = encoded.sample else { throw SharedMediaEncoder.Failure.codec }
        lastVideo = sample.presentationTimeStamp
        forceKeyframe = false
        return [packet]
    }

    private func encodeAudio(_ sample: CMSampleBuffer) throws -> [CMSampleBuffer] {
        guard let description = sample.formatDescription else { throw SharedMediaEncoder.Failure.audioFormat }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        guard format.sampleRate == profile.audioSampleRate, format.channelCount == profile.audioChannels,
              sample.numSamples > 0, sample.numSamples <= 11_025 else { throw SharedMediaEncoder.Failure.audioFormat }
        if let inputFormat {
            guard inputFormat == format else { throw SharedMediaEncoder.Failure.audioFormat }
            let expected = audioOrigin + CMTime(value: audioSourceFrames, timescale: 44_100)
            // CoreMedia host-clock conversion can round to a nanosecond. Never
            // compress a real discontinuity by renumbering incoming PCM frames.
            guard abs((sample.presentationTimeStamp - expected).seconds) < 1 / profile.audioSampleRate else {
                throw SharedMediaEncoder.Failure.timeline
            }
        } else {
            guard let outputFormat = AVAudioFormat(settings: profile.audioSettings),
                  let converter = AVAudioConverter(from: format, to: outputFormat) else {
                throw SharedMediaEncoder.Failure.configuration
            }
            converter.bitRate = profile.audioBitRate
            converter.primeMethod = .none
            self.converter = converter
            inputFormat = format
            audioOrigin = sample.presentationTimeStamp
        }
        guard pcmFrames + sample.numSamples <= 11_025,
              let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sample.numSamples)),
              CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(sample.numSamples),
                into: pcm.mutableAudioBufferList) == noErr else { throw SharedMediaEncoder.Failure.audioFormat }
        pcm.frameLength = AVAudioFrameCount(sample.numSamples)
        pendingPCM.append(pcm)
        pcmFrames += sample.numSamples
        audioSourceFrames += Int64(sample.numSamples)
        return try drainAudio(end: false)
    }

    private func takePCM(_ requested: AVAudioPacketCount) -> AVAudioPCMBuffer? {
        guard let inputFormat, pcmFrames > 0 else { return nil }
        let count = min(Int(requested), pcmFrames)
        guard let result = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(count)) else { return nil }
        let destination = UnsafeMutableAudioBufferListPointer(result.mutableAudioBufferList)
        let bytesPerFrame = Int(inputFormat.streamDescription.pointee.mBytesPerFrame)
        var copied = 0
        while copied < count, let first = pendingPCM.first {
            let frames = min(count - copied, Int(first.frameLength) - pcmOffset)
            let source = UnsafeMutableAudioBufferListPointer(first.mutableAudioBufferList)
            for plane in 0..<destination.count {
                guard let target = destination[plane].mData, let origin = source[plane].mData else { return nil }
                memcpy(target.advanced(by: copied * bytesPerFrame), origin.advanced(by: pcmOffset * bytesPerFrame), frames * bytesPerFrame)
            }
            copied += frames; pcmOffset += frames; pcmFrames -= frames
            if pcmOffset == Int(first.frameLength) { pendingPCM.removeFirst(); pcmOffset = 0 }
        }
        result.frameLength = AVAudioFrameCount(copied)
        return result
    }

    private func drainAudio(end: Bool) throws -> [CMSampleBuffer] {
        guard let converter else { return [] }
        var packets: [CMSampleBuffer] = []
        // A bounded 250 ms input plus codec delay cannot require 64 output
        // packets. Treat a converter that does not converge as an error.
        for _ in 0..<64 {
            let buffer = AVAudioCompressedBuffer(format: converter.outputFormat, packetCapacity: 1,
                maximumPacketSize: max(4096, converter.maximumOutputPacketSize))
            var error: NSError?
            let status = converter.convert(to: buffer, error: &error) { requested, state in
                if let pcm = self.takePCM(requested) { state.pointee = .haveData; return pcm }
                state.pointee = end ? .endOfStream : .noDataNow
                return nil
            }
            guard status != .error, error == nil else { throw SharedMediaEncoder.Failure.codec }
            if buffer.packetCount > 0 {
                if let pendingAudio { packets.append(pendingAudio) }
                pendingAudio = try makeAudioPacket(buffer, converter: converter)
                audioPackets += Int64(buffer.packetCount)
            }
            if status == .endOfStream {
                if let pendingAudio {
                    let leading = Int64(converter.primeInfo.leadingFrames)
                    let trailing = max(0, audioPackets * 1024 - leading - audioSourceFrames)
                    Self.trim(pendingAudio, key: kCMSampleBufferAttachmentKey_TrimDurationAtEnd,
                              frames: min(1024, trailing))
                    packets.append(pendingAudio)
                    self.pendingAudio = nil
                }
                return packets
            }
            if status == .inputRanDry { return packets }
        }
        throw SharedMediaEncoder.Failure.codec
    }

    private func makeAudioPacket(_ buffer: AVAudioCompressedBuffer, converter: AVAudioConverter) throws -> CMSampleBuffer {
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: Int(buffer.byteLength),
            blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: Int(buffer.byteLength),
            flags: 0, blockBufferOut: &block) == noErr, let block,
            CMBlockBufferReplaceDataBytes(with: buffer.data, blockBuffer: block,
                offsetIntoDestination: 0, dataLength: Int(buffer.byteLength)) == noErr else { throw SharedMediaEncoder.Failure.codec }
        var description: CMAudioFormatDescription?
        let cookie = converter.magicCookie ?? Data()
        let formatStatus = cookie.withUnsafeBytes {
            CMAudioFormatDescriptionCreate(allocator: nil, asbd: converter.outputFormat.streamDescription,
                layoutSize: 0, layout: nil, magicCookieSize: $0.count, magicCookie: $0.baseAddress,
                extensions: nil, formatDescriptionOut: &description)
        }
        guard formatStatus == noErr, let description else { throw SharedMediaEncoder.Failure.codec }
        let leading = Int64(converter.primeInfo.leadingFrames)
        let frame = audioPackets * 1024
        let time = audioOrigin + CMTime(value: frame - leading, timescale: 44_100)
        var sample: CMSampleBuffer?
        guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block,
            formatDescription: description, sampleCount: Int(buffer.packetCount), presentationTimeStamp: time,
            packetDescriptions: buffer.packetDescriptions, sampleBufferOut: &sample) == noErr, let sample else {
            throw SharedMediaEncoder.Failure.codec
        }
        Self.trim(sample, key: kCMSampleBufferAttachmentKey_TrimDurationAtStart, frames: min(1024, max(0, leading - frame)))
        Self.trim(sample, key: kCMSampleBufferAttachmentKey_TrimDurationAtEnd, frames: 0)
        return sample
    }

    private static func trim(_ sample: CMSampleBuffer, key: CFString, frames: Int64) {
        CMSetAttachment(sample, key: key,
            value: CMTimeCopyAsDictionary(CMTime(value: frames, timescale: 44_100), allocator: nil),
            attachmentMode: kCMAttachmentMode_ShouldPropagate)
    }

    func finish() throws -> [CMSampleBuffer] { try drainAudio(end: true) }
    func invalidate() {
        if let video { VTCompressionSessionInvalidate(video) }
        video = nil; converter = nil; pendingPCM.removeAll(); pendingAudio = nil
    }
    deinit { if let video { VTCompressionSessionInvalidate(video) } }
}
