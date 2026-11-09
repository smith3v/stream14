import Foundation
import Testing
@testable import Stream14

@MainActor @Suite(.serialized, .timeLimit(.minutes(1)))
struct RecordingFinalizationTests {
    @Test func deadlineRetainsUUIDAndOneNativeOperationUntilActualCallback() async throws {
        let owner = RecordingFinalization()
        let id = UUID()
        var nativeCallback: CheckedContinuation<LocalRecorder.Metrics, Never>?
        var operations = 0
        var releases = 0
        let waiting = Task {
            try await owner.finish(id: id, deadline: 0, operation: {
                operations += 1
                return await withCheckedContinuation { nativeCallback = $0 }
            }, released: { releases += 1 })
        }
        defer { nativeCallback?.resume(returning: LocalRecorder.Metrics()) }
        try await until { nativeCallback != nil }
        await #expect(throws: BroadcastDeadlineError.self) { try await waiting.value }
        #expect(owner.recordingID == id)
        #expect(releases == 0 && operations == 1)
        await #expect(throws: RecordingFinalization.Failure.self) {
            try await owner.finish(id: UUID(), deadline: 0, operation: {
                operations += 1
                return LocalRecorder.Metrics()
            }, released: { releases += 1 })
        }
        #expect(owner.recordingID == id && operations == 1)
        nativeCallback?.resume(returning: LocalRecorder.Metrics())
        nativeCallback = nil
        try await until { owner.recordingID == nil }
        #expect(releases == 1)
        // The UI timeout never promotes the previous caller to a late success.
        await #expect(throws: BroadcastDeadlineError.self) { try await waiting.value }
    }

    @Test func timedOutNativeFinishBlocksReviewRecoveryDeletionAndAnotherWriter() async throws {
        let media = MediaSession(readOverlayURL: { "" }, saveOverlayURL: { _ in },
            profile: .hd, persistProfile: { _ in }, authorizeCapture: { false })
        media.installInterfaceFixture("ready")
        let sample = ExperimentSample()
        var nativeCallback: CheckedContinuation<LocalRecorder.Metrics, Never>?
        let waiting = Task {
            try await media.holdNativeFinalizationFixture(id: sample.id) {
                await withCheckedContinuation { nativeCallback = $0 }
            }
        }
        defer { nativeCallback?.resume(returning: LocalRecorder.Metrics()) }
        try await until { nativeCallback != nil }
        await #expect(throws: BroadcastDeadlineError.self) { try await waiting.value }
        #expect(media.recordingID == nil)
        #expect(media.protectedRecordingID == sample.id)
        #expect(!media.canRecord && !media.canDeleteSamples)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try sample.save(in: directory)
        // The production refresh passes this protection through reconciliation;
        // neither a UI deadline nor an absent active recorder retires the UUID.
        #expect(try ExperimentSample.loadAll(in: directory, activeID: media.protectedRecordingID).first?.status == .pending)
        await media.record()
        #expect(media.recordingID == nil && media.protectedRecordingID == sample.id)
        await media.recoverSample(sample)
        #expect(media.recoveringSampleID == nil)
        nativeCallback?.resume(returning: LocalRecorder.Metrics())
        nativeCallback = nil
        try await until { media.protectedRecordingID == nil }
        #expect(media.canRecord && media.canDeleteSamples)
    }

    @Test func protectedNativeWriterStillAllowsSeparateSanitizedCheckpointRead() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let media = MediaSession(readOverlayURL: { "" }, saveOverlayURL: { _ in },
            profile: .hd, persistProfile: { _ in }, authorizeCapture: { false })
        let sample = ExperimentSample()
        try sample.save(in: directory)
        // No movie is opened; a held native owner protects this UUID while the
        // observer independently writes/reads its own small numeric checkpoint.
        media.installWriterFixture(LocalRecorder(), sample: sample, directory: directory)
        media.beginQualificationFixture(transport: QualificationTransportCounter())
        var nativeCallback: CheckedContinuation<LocalRecorder.Metrics, Never>?
        let waiting = Task {
            try await media.holdNativeFinalizationFixture(id: sample.id) {
                await withCheckedContinuation { nativeCallback = $0 }
            }
        }
        defer { nativeCallback?.resume(returning: LocalRecorder.Metrics()) }
        try await until { nativeCallback != nil }
        await #expect(throws: BroadcastDeadlineError.self) { try await waiting.value }
        await media.checkpointQualificationFixture()
        let checkpoint = QualificationCheckpoint()
        let held = try await checkpoint.load(id: sample.id, directory: directory)
        #expect(held.nativeFinalizationOutstanding == true)
        #expect(held.recording == .pending && held.end == .checkpoint)
        #expect(media.protectedRecordingID == sample.id && !media.canDeleteSamples)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(sample.fileName).path))
        #expect(try held.sanitizedData().count < QualificationCheckpoint.maximumBytes)
        nativeCallback?.resume(returning: LocalRecorder.Metrics())
        nativeCallback = nil
        var released = false
        for _ in 0..<100 {
            await media.checkpointQualificationFixture()
            if try await checkpoint.load(id: sample.id, directory: directory).nativeFinalizationOutstanding == false {
                released = true; break
            }
            await Task.yield()
        }
        #expect(released)
        await media.stopRecording()
        let stopped = try await checkpoint.load(id: sample.id, directory: directory)
        #expect(stopped.end == .stopped && stopped.recording == .failed)
        #expect(stopped.nativeFinalizationOutstanding == false)
    }

    @Test func structuralCompletionCannotPersistDecodedStartClaim() throws {
        var sample = ExperimentSample(status: .completed)
        sample.review = .readable
        sample.recordStructuralValidation(duration: 12, byteCount: 100)
        let persisted = try JSONDecoder().decode(ExperimentSample.self, from: JSONEncoder().encode(sample))
        #expect(persisted.status == .completed)
        #expect(persisted.duration == 12 && persisted.byteCount == 100)
        #expect(persisted.review == nil)
    }

    private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<300 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(condition())
    }
}
