import Foundation

/// A deadline must not await a losing request that ignores cancellation. Only
/// one work task and one timer exist per control operation (never per frame).
/// YouTubeClient still bounds URLSession requests; generation checks reject late
/// results and writeOnce never retries a timed-out mutation.
@MainActor private final class BroadcastRequestGate<Value: Sendable> {
    var continuation: CheckedContinuation<Value, any Error>?
    var work: Task<Void, Never>?
    var timer: Task<Void, Never>?
    private var finished = false
    func resolve(_ result: Result<Value, any Error>) {
        guard !finished else { return }
        finished = true
        work?.cancel(); timer?.cancel()
        work = nil; timer = nil
        continuation?.resume(with: result); continuation = nil
    }
}

nonisolated enum BroadcastDeadlineError: Error { case elapsed }

@MainActor func withBroadcastDeadline<Value: Sendable>(seconds: Double,
    operation: @escaping @MainActor @Sendable () async throws -> Value) async throws -> Value {
    let gate = BroadcastRequestGate<Value>()
    return try await withTaskCancellationHandler {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            gate.continuation = continuation
            gate.work = Task {
                do { gate.resolve(.success(try await operation())) }
                catch { gate.resolve(.failure(error)) }
            }
            gate.timer = Task {
                do { try await Task.sleep(for: .seconds(seconds)); gate.resolve(.failure(BroadcastDeadlineError.elapsed)) }
                catch { }
            }
        }
    } onCancel: {
        Task { @MainActor in gate.resolve(.failure(CancellationError())) }
    }
}
