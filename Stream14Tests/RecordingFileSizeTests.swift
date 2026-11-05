import Foundation
import Testing
@testable import Stream14

@MainActor
struct RecordingFileSizeTests {
    @Test func readsCurrentVideoSizeWithoutCountingSidecars() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sample = ExperimentSample()
        try sample.save(in: directory)
        #expect(sample.fileSize(in: directory) == nil)
        let video = directory.appendingPathComponent(sample.fileName)
        try Data(repeating: 1, count: 128_000).write(to: video)
        #expect(sample.fileSize(in: directory) == 128_000)
        try Data(repeating: 1, count: 256_000).write(to: video)
        #expect(sample.fileSize(in: directory) == 256_000)
        try FileManager.default.removeItem(at: video)
        #expect(sample.fileSize(in: directory) == nil)
    }

    @Test func distinguishesEmptyVideoFromUnexpectedDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sample = ExperimentSample()
        let video = directory.appendingPathComponent(sample.fileName)
        try Data().write(to: video)
        #expect(sample.fileSize(in: directory) == 0)
        try FileManager.default.removeItem(at: video)
        try FileManager.default.createDirectory(at: video, withIntermediateDirectories: true)
        #expect(sample.fileSize(in: directory) == nil)
    }
}
