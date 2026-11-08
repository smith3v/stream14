import AVFoundation
import Synchronization

/// MP4 passthrough consumer of the one shared H.264/AAC encoder. This type owns
/// no encoder or capture lifecycle. The lock serializes writer/input access; a
/// finite startup buffer waits for both codec descriptions, never the network.
nonisolated final class LocalRecorder: Sendable {
    enum Failure: Error { case initialization, append, finalization, missingMedia }
    enum Injection: Sendable { case none, initialization, append, finalization }
    struct Metrics: Codable, Sendable {
        var videoReceived = 0
        var videoWritten = 0
        var missingOutputFrames: Int? = 0
        var videoDropped = 0
        var audioDropped = 0
        var videoStalls = 0
        var largestVideoGap = 0.0
    }
    private struct State {
        var writer: AVAssetWriter?
        var video: AVAssetWriterInput?
        var audio: AVAssetWriterInput?
        var started = false
        var failed = false
        var origin = CMTime.invalid
        var receivedVideoTime = CMTime.invalid
        var videoTime = CMTime.invalid
        var audioTime = CMTime.invalid
        var audioWritten = 0
        var metrics = Metrics()
        var injection = Injection.none
        var profile = SessionProfile.fullHD
        var pending: [CMSampleBuffer] = []
        var pendingBytes = 0
    }
    private let state = Mutex(State())
    private let failureContinuation: AsyncStream<Failure>.Continuation
    let failures: AsyncStream<Failure>

    init() {
        (failures, failureContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    func start(_ url: URL, injection: Injection = .none, profile: SessionProfile = .fullHD) throws {
        try state.withLock { state in
            guard state.writer == nil, injection != .initialization else { throw Failure.initialization }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path,
                                                  isDirectory: &isDirectory), isDirectory.boolValue else {
                throw Failure.initialization
            }
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            writer.movieFragmentInterval = CMTime(seconds: 10, preferredTimescale: 600)
            // Compression settings are nil when the actual formats arrive.
            // Creating the destination first catches initialization/path errors
            // before a session or publisher is allowed to start.
            state = State(writer: writer, injection: injection, profile: profile)
        }
    }

    func append(_ sample: CMSampleBuffer) {
        state.withLock { state in
            guard let writer = state.writer, !state.failed else { return }
            guard let format = sample.formatDescription,
                  format.mediaSubType.rawValue == kCMVideoCodecType_H264 || format.mediaSubType.rawValue == kAudioFormatMPEG4AAC,
                  format.mediaType == .video || format.mediaType == .audio,
                  sample.presentationTimeStamp.isNumeric else { fail(&state); return }
            if !state.started {
                let bytes = sample.dataBuffer.map { CMBlockBufferGetDataLength($0) } ?? sample.totalSampleSize
                guard state.pending.count < 16, bytes <= 2 * 1024 * 1024 - state.pendingBytes else {
                    fail(&state); return
                }
                state.pending.append(sample)
                state.pendingBytes += bytes
                guard let videoSample = state.pending.first(where: { $0.formatDescription?.mediaType == .video }),
                      let audioSample = state.pending.first(where: { $0.formatDescription?.mediaType == .audio }),
                      let videoFormat = videoSample.formatDescription, let audioFormat = audioSample.formatDescription else { return }
                guard videoFormat.mediaSubType.rawValue == kCMVideoCodecType_H264,
                      audioFormat.mediaSubType.rawValue == kAudioFormatMPEG4AAC,
                      videoFormat.dimensions.width == state.profile.width,
                      videoFormat.dimensions.height == state.profile.height else { fail(&state); return }
                let video = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: videoFormat)
                let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: audioFormat)
                video.expectsMediaDataInRealTime = true
                audio.expectsMediaDataInRealTime = true
                guard writer.canAdd(video), writer.canAdd(audio) else { fail(&state); return }
                writer.add(video); writer.add(audio)
                guard writer.startWriting() else { fail(&state); return }
                state.video = video; state.audio = audio
                state.origin = videoSample.presentationTimeStamp
                writer.startSession(atSourceTime: state.origin)
                state.started = true
                let pending = state.pending
                state.pending.removeAll(); state.pendingBytes = 0
                for packet in pending { append(packet, state: &state) }
            } else { append(sample, state: &state) }
        }
    }

    private func append(_ sample: CMSampleBuffer, state: inout State) {
        guard !state.failed, let writer = state.writer else { return }
        let isVideo = sample.formatDescription?.mediaType == .video
        let time = sample.presentationTimeStamp
        if isVideo {
            state.metrics.videoReceived += 1
            if state.receivedVideoTime.isValid, time > state.receivedVideoTime {
                let intervals = Int(((time - state.receivedVideoTime).seconds * 30).rounded())
                state.metrics.missingOutputFrames = (state.metrics.missingOutputFrames ?? 0) + max(0, intervals - 1)
            }
            state.receivedVideoTime = time
        }
        let previous = isVideo ? state.videoTime : state.audioTime
        guard writer.status == .writing, state.injection != .append,
              !previous.isValid || time > previous,
              let input = isVideo ? state.video : state.audio,
              input.isReadyForMoreMediaData, input.append(sample) else {
            // Dropping a compressed P frame can invalidate later references.
            // Fail this consumer explicitly; never stall or stop the uploader.
            fail(&state); return
        }
        if isVideo {
            if previous.isValid {
                let gap = (time - previous).seconds
                state.metrics.largestVideoGap = max(state.metrics.largestVideoGap, gap)
                if gap >= 0.5 { state.metrics.videoStalls += 1 }
            }
            state.videoTime = time
            state.metrics.videoWritten += 1
        } else {
            state.audioTime = time
            state.audioWritten += 1
        }
    }

    func encoderFailed() {
        state.withLock { state in
            if state.writer != nil, !state.failed { fail(&state) }
        }
    }

    private func fail(_ state: inout State) {
        guard !state.failed else { return }
        state.failed = true
        state.pending.removeAll(); state.pendingBytes = 0
        failureContinuation.yield(.append)
    }

    func finish() async throws -> Metrics {
        let terminal = state.withLock { state -> (AVAssetWriter?, Bool, Metrics) in
            let success = state.started && !state.failed && state.audioWritten > 0 &&
                state.metrics.videoWritten > 0 && state.injection != .finalization
            if state.started, state.writer?.status == .writing {
                state.video?.markAsFinished()
                state.audio?.markAsFinished()
            }
            let writer = state.writer
            // Never call cancelWriting here: it can remove an original file.
            state.writer = nil
            state.video = nil
            state.audio = nil
            state.pending.removeAll(); state.pendingBytes = 0
            return (writer, success, state.metrics)
        }
        guard let writer = terminal.0 else { throw Failure.finalization }
        if writer.status == .writing { await writer.finishWriting() }
        // A returned URL is insufficient: completion must be confirmed after finish.
        guard terminal.1, writer.status == .completed, writer.error == nil else {
            throw Failure.finalization
        }
        failureContinuation.finish()
        return terminal.2
    }

    /// Copy the library's mixed PCM buffer into a CoreMedia-owned buffer before
    /// returning from its callback. Host time shares the composed video timeline.
    static func audioSample(_ buffer: AVAudioPCMBuffer, when: AVAudioTime) -> CMSampleBuffer? {
        guard when.isHostTimeValid else { return nil }
        var sample: CMSampleBuffer?
        let time = CMTime(seconds: AVAudioTime.seconds(forHostTime: when.hostTime), preferredTimescale: 1_000_000_000)
        guard CMAudioSampleBufferCreateWithPacketDescriptions(allocator: nil, dataBuffer: nil,
            dataReady: false, makeDataReadyCallback: nil, refcon: nil,
            formatDescription: buffer.format.formatDescription, sampleCount: Int(buffer.frameLength),
            presentationTimeStamp: time, packetDescriptions: nil, sampleBufferOut: &sample) == noErr,
            let sample,
            CMSampleBufferSetDataBufferFromAudioBufferList(sample, blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0,
                bufferList: buffer.audioBufferList) == noErr else { return nil }
        return sample
    }

    var metrics: Metrics { state.withLock { $0.metrics } }
    var hasStarted: Bool { state.withLock { $0.started && !$0.failed && $0.writer?.status == .writing } }
}
