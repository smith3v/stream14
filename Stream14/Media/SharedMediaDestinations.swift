import AVFoundation
import Synchronization

/// Concrete fan-out from the one encoder. The mutex owns only references, never
/// file or network operations. Each consumer fails/detaches independently.
nonisolated final class SharedMediaDestinations: Sendable {
    private struct State {
        var recorder: LocalRecorder?
        var publisher: RTMPSPublisher?
    }
    private let state: Mutex<State>
    private let encoderFailure: AsyncStream<Void>.Continuation
    let encoderFailures: AsyncStream<Void>

    init(recorder: LocalRecorder) {
        state = Mutex(State(recorder: recorder))
        (encoderFailures, encoderFailure) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }
    func append(_ sample: CMSampleBuffer) {
        let outputs = state.withLock { ($0.recorder, $0.publisher) }
        outputs.0?.append(sample)
        outputs.1?.offer(sample)
    }
    func attachPublisher(_ publisher: RTMPSPublisher) { state.withLock { $0.publisher = publisher } }
    func detachPublisher() { state.withLock { $0.publisher = nil } }
    func detachRecorder() { state.withLock { $0.recorder = nil } }
    func encoderFailed() {
        state.withLock { $0.recorder }?.encoderFailed()
        encoderFailure.yield(())
    }
}

extension RTMPSPublisher {
    enum StartupFailure: Error { case recordingNotReady, cancelled, connection, contextChanged }

    /// F7 alone invokes this after explicit operator confirmation. Selection,
    /// preview and local recording never call it. The writer must already have
    /// started unless this is a retry of a previously admitted transport session.
    @MainActor static func connected(to prepared: PreparedYouTubeIngestion,
        canPublish: @escaping @Sendable () -> Bool,
        failed: @escaping @Sendable (Failure) -> Void) async throws -> RTMPSPublisher {
        guard canPublish() else { throw StartupFailure.recordingNotReady }
        let sender = RTMPSConnection()
        do {
            try await sender.connect(prepared.destination, profile: prepared.profile, canPublish: canPublish)
            guard !Task.isCancelled, canPublish() else {
                await sender.close(); throw StartupFailure.cancelled
            }
            let publisher = RTMPSPublisher(send: { sample, origin in try await sender.send(sample, origin: origin) },
                close: { await sender.close() }, failed: failed)
            publisher.activate()
            return publisher
        } catch {
            await sender.close()
            if error is StartupFailure { throw error }
            throw Task.isCancelled ? StartupFailure.cancelled : StartupFailure.connection
        }
    }
}
