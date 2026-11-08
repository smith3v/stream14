import AVFoundation
import Synchronization

/// One independently owned compressed transport generation. A new connection
/// gets a new instance and random-access epoch; file/encoder lifetimes are never
/// controlled here. Network adaptation is added after the immutable fork pin.
nonisolated final class RTMPSPublisher: Sendable {
    enum Failure: Error, Sendable { case overflow, invalidMedia, transport, cancelled }
    struct Limits: Sendable {
        var bytes = 2 * 1024 * 1024
        var packets = 128
    }
    struct Metrics: Sendable {
        var highWaterBytes = 0
        var highWaterPackets = 0
        var retainedBytes = 0
        var retainedPackets = 0
        var acceptedPackets = 0
        var acknowledgedPackets = 0
        var skippedBeforeOrigin = 0
        var overflowCount = 0
    }
    private struct Packet {
        let sample: CMSampleBuffer
        let bytes: Int
        let origin: CMTime
    }
    private struct State {
        var active = false
        var ended = false
        var origin: CMTime?
        var queued: [Packet] = []
        var inFlight: Packet?
        var failure: Failure?
        var metrics = Metrics()
    }
    private struct Tasks {
        var pump: Task<Void, Never>?
        var abort: Task<Void, Never>?
    }
    private let limits: Limits
    private let state = Mutex(State())
    private let tasks = Mutex(Tasks())
    private let wake: AsyncStream<Void>.Continuation
    private let abort: AsyncStream<Failure>.Continuation
    private let send: @Sendable (CMSampleBuffer, CMTime) async throws -> Void
    private let close: @Sendable () async -> Void
    private let failed: @Sendable (Failure) -> Void

    /// Test seams correspond exactly to one acknowledged media send and closing
    /// that same connection. Call activate only after connect/publish succeed.
    init(limits: Limits = Limits(),
         send: @escaping @Sendable (CMSampleBuffer, CMTime) async throws -> Void,
         close: @escaping @Sendable () async -> Void,
         failed: @escaping @Sendable (Failure) -> Void) {
        self.limits = limits
        self.send = send; self.close = close; self.failed = failed
        let (wakes, wake) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let (aborts, abort) = AsyncStream<Failure>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.wake = wake; self.abort = abort
        // Two fixed workers per transport, never a Task per media callback. The
        // abort worker can close a stalled socket while the send worker awaits
        // its acknowledgment; overflow does not wait behind the stalled send.
        let pump = Task { [weak self] in
            for await _ in wakes { await self?.consume() }
        }
        let closer = Task { [weak self] in
            for await failure in aborts {
                guard let self else { return }
                await self.close()
                if failure != .cancelled { self.failed(failure) }
                self.tasks.withLock { $0.pump?.cancel() }
                self.wake.finish()
                return
            }
        }
        tasks.withLock { $0 = Tasks(pump: pump, abort: closer) }
    }

    func activate() {
        state.withLock { if !$0.ended { $0.active = true } }
    }

    @discardableResult
    func offer(_ sample: CMSampleBuffer) -> Bool {
        let result = state.withLock { state -> (Bool, Failure?) in
            guard state.active, !state.ended else { return (false, nil) }
            guard let format = sample.formatDescription, sample.presentationTimeStamp.isNumeric,
                  format.mediaSubType.rawValue == kCMVideoCodecType_H264 || format.mediaSubType.rawValue == kAudioFormatMPEG4AAC,
                  let block = sample.dataBuffer else { return (false, .invalidMedia) }
            let video = format.mediaType == .video
            if state.origin == nil {
                guard video, Self.isKeyframe(sample) else {
                    state.metrics.skippedBeforeOrigin += 1
                    return (false, nil)
                }
                state.origin = sample.presentationTimeStamp
            }
            guard let origin = state.origin else { return (false, .invalidMedia) }
            guard sample.presentationTimeStamp >= origin else {
                state.metrics.skippedBeforeOrigin += 1
                return (false, nil)
            }
            let bytes = CMBlockBufferGetDataLength(block)
            guard bytes > 0, bytes <= limits.bytes - state.metrics.retainedBytes,
                  state.metrics.retainedPackets < limits.packets else {
                state.metrics.overflowCount += 1
                return (false, .overflow)
            }
            state.queued.append(Packet(sample: sample, bytes: bytes, origin: origin))
            state.metrics.retainedBytes += bytes
            state.metrics.retainedPackets += 1
            state.metrics.acceptedPackets += 1
            state.metrics.highWaterBytes = max(state.metrics.highWaterBytes, state.metrics.retainedBytes)
            state.metrics.highWaterPackets = max(state.metrics.highWaterPackets, state.metrics.retainedPackets)
            return (true, nil)
        }
        if let failure = result.1 { end(failure) }
        else if result.0 { wake.yield(()) }
        return result.0
    }

    private func consume() async {
        while !Task.isCancelled {
            let packet = state.withLock { state -> Packet? in
                guard !state.ended, state.inFlight == nil, !state.queued.isEmpty else { return nil }
                let packet = state.queued.removeFirst()
                state.inFlight = packet
                return packet
            }
            guard let packet else { return }
            var success = false
            do { try await send(packet.sample, packet.origin); success = true }
            catch { end(.transport) }
            state.withLock { state in
                // In-flight charge survives close/overflow until send actually
                // releases its retained media, even if cancellation is delayed.
                state.inFlight = nil
                state.metrics.retainedBytes -= packet.bytes
                state.metrics.retainedPackets -= 1
                if success { state.metrics.acknowledgedPackets += 1 }
            }
        }
    }

    private func end(_ failure: Failure) {
        let first = state.withLock { state in
            guard !state.ended else { return false }
            state.ended = true; state.active = false; state.failure = failure
            for packet in state.queued {
                state.metrics.retainedBytes -= packet.bytes
                state.metrics.retainedPackets -= 1
            }
            state.queued.removeAll()
            return true
        }
        if first { abort.yield(failure); abort.finish() }
    }

    /// Ends only transport. The caller may continue feeding its local writer.
    /// Closing is issued independently of the stalled acknowledgment task.
    func stop() async {
        end(.cancelled)
        let workers = tasks.withLock { ($0.pump, $0.abort) }
        await workers.1?.value
        await workers.0?.value
    }

    var metrics: Metrics { state.withLock { $0.metrics } }
    var hasFailed: Bool { state.withLock { $0.failure != nil && $0.failure != .cancelled } }

    static func isKeyframe(_ sample: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[String: Any]],
              let first = attachments.first else { return true }
        return first[kCMSampleAttachmentKey_NotSync as String] as? Bool != true
    }
}
