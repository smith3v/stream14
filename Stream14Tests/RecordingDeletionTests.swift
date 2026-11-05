import Foundation
import Testing
@testable import Stream14

@MainActor
struct RecordingDeletionTests {
    @Test func deletesOnlySelectedRecordingAndItsSidecars() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let selected = ExperimentSample()
        let other = ExperimentSample()
        try selected.save(in: directory)
        try other.save(in: directory)
        for sample in [selected, other] {
            try Data("private test fixture".utf8).write(to: directory.appendingPathComponent(sample.fileName))
            try Data("[]".utf8).write(to: directory.appendingPathComponent(sample.id.uuidString + ".observations.json"))
        }
        try selected.delete(in: directory)
        for suffix in [".mp4", ".json", ".observations.json"] {
            #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(selected.id.uuidString + suffix).path))
            #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(other.id.uuidString + suffix).path))
        }
        try selected.delete(in: directory) // A repeated request and missing files are harmless.
    }

    @Test func missingVideoCanStillRemovePendingEntry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pending = ExperimentSample()
        try pending.save(in: directory)
        try pending.delete(in: directory)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test func partialFailureKeepsEntryRetryableAndNeverRecurses() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sample = ExperimentSample()
        try sample.save(in: directory)
        let movie = directory.appendingPathComponent(sample.fileName)
        try Data("footage".utf8).write(to: movie)
        let unexpectedDirectory = directory.appendingPathComponent(sample.id.uuidString + ".observations.json")
        try FileManager.default.createDirectory(at: unexpectedDirectory, withIntermediateDirectories: true)
        let child = unexpectedDirectory.appendingPathComponent("must-survive.txt")
        try Data("keep".utf8).write(to: child)
        #expect(throws: ExperimentSample.DeletionError.self) { try sample.delete(in: directory) }
        #expect(!FileManager.default.fileExists(atPath: movie.path))
        #expect(FileManager.default.fileExists(atPath: child.path))
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(sample.id.uuidString + ".json").path))
        // Repair only this test fixture, then verify retry completes the remaining removal.
        try FileManager.default.removeItem(at: child)
        try FileManager.default.removeItem(at: unexpectedDirectory)
        try sample.delete(in: directory)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }
}
