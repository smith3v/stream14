import AVFoundation
import Foundation
import Testing
@testable import Stream14

@MainActor
struct RecordingRecoveryTests {
    private func fixture() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func legacyPendingRelaunchNeverCompletesAndActiveIsExcluded() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sample = ExperimentSample()
        let legacy = "{\"id\":\"\(sample.id.uuidString)\",\"created\":0,\"status\":\"pending\"}"
        try Data(legacy.utf8).write(to: directory.appendingPathComponent(sample.id.uuidString + ".json"))
        let inactive = try #require(ExperimentSample.loadAll(in: directory).first)
        #expect(inactive.status == .interrupted)
        #expect(inactive.version == nil)
        #expect(inactive.review == nil)
        #expect(try ExperimentSample.loadAll(in: directory, activeID: sample.id).first?.status == .pending)
    }

    @Test func malformedAndMissingMetadataKeepOriginalsVisible() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let corrupt = ExperimentSample(), orphan = ExperimentSample()
        let raw = Data("broken original metadata".utf8)
        let sidecar = directory.appendingPathComponent(corrupt.id.uuidString + ".json")
        try raw.write(to: sidecar)
        for sample in [corrupt, orphan] {
            try Data("movie".utf8).write(to: directory.appendingPathComponent(sample.fileName))
        }
        let loaded = try ExperimentSample.loadAll(in: directory)
        #expect(loaded.count == 2)
        #expect(loaded.allSatisfy { $0.status == .needsInspection })
        var reviewed = try #require(loaded.first { $0.id == corrupt.id })
        reviewed.review = .unreadable
        try reviewed.save(in: directory)
        #expect(try Data(contentsOf: sidecar) == raw)
        let reloaded = try #require(ExperimentSample.loadAll(in: directory).first { $0.id == corrupt.id })
        #expect(reloaded.review == .unreadable)
        #expect(reloaded.status == .needsInspection)
    }

    @Test func interruptedRecoveryAttemptsAndOrphanCopiesRemainVisible() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        var sample = ExperimentSample(status: .failed)
        let pending = ExperimentSample.Recovery()
        let orphan = ExperimentSample.Recovery()
        sample.recoveries = [pending]
        try sample.save(in: directory)
        try Data("partial remux".utf8).write(to: directory.appendingPathComponent(sample.recoveryFileName(orphan)))
        let loaded = try #require(ExperimentSample.loadAll(in: directory).first)
        #expect(loaded.status == .failed)
        #expect(loaded.recoveries?.count == 2)
        #expect(loaded.recoveries?.allSatisfy { $0.status == .failed } == true)
        try loaded.delete(in: directory)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test func deletingOneRecoveryPreservesOriginalOtherCopiesAndRetryMetadata() throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        var sample = ExperimentSample(status: .interrupted)
        let selected = ExperimentSample.Recovery(), other = ExperimentSample.Recovery()
        sample.recoveries = [selected, other]
        try sample.save(in: directory)
        for name in [sample.fileName, sample.recoveryFileName(selected), sample.recoveryFileName(other)] {
            try Data("fixture".utf8).write(to: directory.appendingPathComponent(name))
        }
        let updated = try sample.deletingRecovery(selected, in: directory)
        #expect(updated.recoveries?.map(\.id) == [other.id])
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(sample.fileName).path))
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(sample.recoveryFileName(other)).path))
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(sample.recoveryFileName(selected)).path))
        #expect(try ExperimentSample.loadAll(in: directory).first?.recoveries?.map(\.id) == [other.id])
        let unexpected = directory.appendingPathComponent(sample.recoveryFileName(other))
        try FileManager.default.removeItem(at: unexpected) // Only this synthetic fixture.
        try FileManager.default.createDirectory(at: unexpected, withIntermediateDirectories: false)
        let child = unexpected.appendingPathComponent("retained.txt")
        try Data("keep".utf8).write(to: child)
        #expect(throws: ExperimentSample.DeletionError.self) {
            try updated.deletingRecovery(other, in: directory)
        }
        #expect(FileManager.default.fileExists(atPath: child.path))
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(sample.fileName).path))
        #expect(try ExperimentSample.loadAll(in: directory).first?.recoveries?.map(\.id) == [other.id])
    }

    @Test func failedInspectionAndRecoveryRetainUnreadableOriginal() async throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("original.mp4")
        let target = directory.appendingPathComponent("recovered.mp4")
        let bytes = Data("unreadable footage".utf8)
        try bytes.write(to: source)
        let recovery = RecordingRecovery()
        await #expect(throws: (any Error).self) { try await recovery.inspect(source) }
        await #expect(throws: (any Error).self) { try await recovery.recover(original: source, destination: target) }
        #expect(try Data(contentsOf: source) == bytes)
        #expect(!FileManager.default.fileExists(atPath: target.path))
    }

    @Test func nativePassthroughRecoveryRetainsProductionOriginalAndProvenance() async throws {
        let directory = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        var manifest = ExperimentSample(status: .interrupted)
        manifest.profile = SessionProfile.hd.rawValue
        try manifest.save(in: directory)
        let source = directory.appendingPathComponent(manifest.fileName)
        let attempt = ExperimentSample.Recovery()
        let target = directory.appendingPathComponent(manifest.recoveryFileName(attempt))
        let recorder = LocalRecorder()
        try recorder.start(source, profile: .hd)
        let codec = try SharedMediaCodec(profile: .hd)
        for index in 0..<20 {
            for packet in try codec.append(LocalRecorderTests.video(index + 30, profile: .hd)) { recorder.append(packet) }
            for packet in try codec.append(LocalRecorderTests.audio(index + 30)) { recorder.append(packet) }
            try await Task.sleep(for: .milliseconds(34))
        }
        for packet in try codec.finish() { recorder.append(packet) }
        _ = try await recorder.finish()
        let bytes = try Data(contentsOf: source)
        let recovery = RecordingRecovery()
        let inspection = try await recovery.recover(original: source, destination: target)
        #expect(inspection.duration > 0.5)
        #expect(try Data(contentsOf: source) == bytes)
        #expect(try ExperimentSample.loadAll(in: directory).first?.status == .interrupted)
        // An existing target must never be overwritten, even when it is unusable.
        await #expect(throws: RecordingRecovery.Failure.self) { try await recovery.recover(original: source, destination: target) }
        #expect(try Data(contentsOf: source) == bytes)
    }
}
