import AVFoundation
import HaishinKit
import Synchronization

/// MediaMixer delivers composed NV12 video and mixed PCM audio. The lock owns all
/// writer/input access; callbacks append synchronously, with no task/sample queue.
final class LocalRecorder: MediaMixerOutput, Sendable {
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
    }
    private let state = Mutex(State())
    private let failureContinuation: AsyncStream<Failure>.Continuation
    let failures: AsyncStream<Failure>
    let videoTrackId: UInt8? = .max
    let audioTrackId: UInt8? = .max

    init() {
        (failures, failureContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    func start(_ url: URL, injection: Injection = .none, profile: SessionProfile = .fullHD) throws {
        try state.withLock { state in
            guard state.writer == nil, injection != .initialization else { throw Failure.initialization }
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let video = AVAssetWriterInput(mediaType: .video, outputSettings: profile.videoSettings)
            let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: profile.audioSettings)
            video.expectsMediaDataInRealTime = true
            audio.expectsMediaDataInRealTime = true
            guard writer.canAdd(video), writer.canAdd(audio) else { throw Failure.initialization }
            writer.add(video)
            writer.add(audio)
            guard writer.startWriting() else { throw Failure.initialization }
            state = State(writer: writer, video: video, audio: audio, injection: injection)
        }
    }

    func append(_ sample: CMSampleBuffer) {
        state.withLock { state in
            guard let writer = state.writer, !state.failed else { return }
            let isVideo = sample.formatDescription?.mediaType == .video
            let time = sample.presentationTimeStamp
            guard time.isValid else { return }
            if isVideo {
                state.metrics.videoReceived += 1
                if state.receivedVideoTime.isValid, time > state.receivedVideoTime {
                    let intervals = Int(((time - state.receivedVideoTime).seconds * 30).rounded())
                    state.metrics.missingOutputFrames = (state.metrics.missingOutputFrames ?? 0) + max(0, intervals - 1)
                }
                if !state.receivedVideoTime.isValid || time > state.receivedVideoTime { state.receivedVideoTime = time }
            }
            // Establish the common session origin from video. Do not queue early audio.
            if !state.started {
                guard isVideo else { return }
                writer.startSession(atSourceTime: time)
                state.started = true
                state.origin = time
            }
            guard writer.status == .writing, state.injection != .append else { fail(&state); return }
            let previous = isVideo ? state.videoTime : state.audioTime
            guard !previous.isValid || time > previous else {
                if isVideo { state.metrics.videoDropped += 1 } else { state.metrics.audioDropped += 1 }
                return
            }
            // Audio preceding the first video timestamp must not enter the session.
            if !isVideo, time < state.origin { return }
            guard let input = isVideo ? state.video : state.audio else { fail(&state); return }
            guard input.isReadyForMoreMediaData else {
                if isVideo { state.metrics.videoDropped += 1 } else { state.metrics.audioDropped += 1 }
                return
            }
            guard input.append(sample) else { fail(&state); return }
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
    }

    private func fail(_ state: inout State) {
        state.failed = true
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
            if !state.started { writer?.cancelWriting() }
            state.writer = nil
            state.video = nil
            state.audio = nil
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
    func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) async {}
    func mixer(_ mixer: MediaMixer, didOutput sampleBuffer: CMSampleBuffer) { append(sampleBuffer) }
    func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        guard let sample = Self.audioSample(buffer, when: when) else {
            state.withLock { state in if state.writer != nil { fail(&state) } }
            return
        }
        append(sample)
    }
}
