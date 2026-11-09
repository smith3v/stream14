import Foundation
import Observation

/// One outstanding native file finalizer. A UI deadline may stop waiting, but
/// ownership ends only when the actual finish operation returns, even if that
/// operation ignores task cancellation. A held finalizer blocks another writer.
@MainActor @Observable final class RecordingFinalization {
    enum Failure: Error { case alreadyFinalizing }
    private(set) var recordingID: UUID?
    private var work: Task<LocalRecorder.Metrics, any Error>?

    func finish(id: UUID, deadline: Double = 5,
                operation: @escaping @MainActor @Sendable () async throws -> LocalRecorder.Metrics,
                released: @escaping @MainActor @Sendable () -> Void) async throws -> LocalRecorder.Metrics {
        guard work == nil else { throw Failure.alreadyFinalizing }
        recordingID = id
        let task = Task {
            defer {
                recordingID = nil
                work = nil
                released()
            }
            return try await operation()
        }
        work = task
        // The deadline cancels only its waiting wrapper. Retain the original
        // task and UUID until the operation's actual native callback completes.
        return try await withBroadcastDeadline(seconds: deadline) { try await task.value }
    }
}
