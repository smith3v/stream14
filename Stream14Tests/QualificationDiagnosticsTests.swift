import Foundation
import Testing
@testable import Stream14

struct QualificationDiagnosticsTests {
    @Test func boundedWindowRetainsLifetimeTrendAndPeaks() throws {
        var report = QualificationReport(profile: .fullHD)
        for index in 0...1080 {
            report.observe(.init(elapsedSeconds: Double(index * 10),
                chargedFootprintBytes: UInt64(1000 + index * 20), residentMappingBytes: UInt64(index), thermal: .nominal))
        }
        #expect(report.observationCount == 1081)
        #expect(report.observations.count == 120)
        #expect(report.firstObservation?.elapsedSeconds == 0)
        #expect(report.elapsedSeconds == 10_800)
        #expect(report.peakChargedFootprintBytes == 22_600)
        #expect(abs((report.chargedSlopeBytesPerSecond ?? 0) - 2) < 0.00001)
        #expect(try report.sanitizedData().count < QualificationCheckpoint.maximumBytes)
        report.observe(.init(elapsedSeconds: -1, chargedFootprintBytes: nil, residentMappingBytes: nil, thermal: .unknown))
        #expect(report.observationCount == 1081)
    }

    @Test func unsupportedMemoryIsUnknownRatherThanZero() {
        var report = QualificationReport(profile: .hd)
        report.observe(.init(elapsedSeconds: 1, chargedFootprintBytes: nil, residentMappingBytes: nil, thermal: .unknown))
        #expect(report.chargedObservationCount == 0)
        #expect(report.peakChargedFootprintBytes == nil)
        #expect(report.chargedSlopeBytesPerSecond == nil)
    }

    @Test func checkpointRecoveryAndAllowlistExcludesUnknownSecrets() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID()
        let checkpoint = QualificationCheckpoint()
        var report = QualificationReport(profile: .hd)
        report.observe(.init(elapsedSeconds: 10, chargedFootprintBytes: 123, residentMappingBytes: 456, thermal: .fair))
        try await checkpoint.save(report, id: id, directory: directory)
        let loaded = try await QualificationCheckpoint().load(id: id, directory: directory)
        #expect(loaded.elapsedSeconds == 10)
        #expect(loaded.end == .checkpoint)
        #expect(try QualificationCheckpoint.url(id: id, directory: directory)
            .resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)

        // Do not interpolate payload/error/data into expectations or print them:
        // failing assertions must expose only the static boolean expression.
        let secrets = ["https://overlay.example/private?token=SECRET", "Bearer oauth-secret",
            "rtmps://private.example/app/stream-key", "/private/tester/name/movie.mp4",
            "channel-private", "event-private", "SDKError(Authorization=secret)"]
        var object = try #require(JSONSerialization.jsonObject(with: report.sanitizedData()) as? [String: Any])
        object["rawError"] = secrets.joined(separator: " ")
        object["overlayURL"] = secrets[0]
        let dirty = try JSONSerialization.data(withJSONObject: object)
        try dirty.write(to: QualificationCheckpoint.url(id: id, directory: directory), options: .atomic)
        let safe = try await checkpoint.load(id: id, directory: directory)
        let exported = try safe.sanitizedData()
        let hasSecret = secrets.contains { exported.range(of: Data($0.utf8)) != nil }
        #expect(!hasSecret)
        object["schema"] = 999
        try JSONSerialization.data(withJSONObject: object).write(to: QualificationCheckpoint.url(id: id, directory: directory))
        var rejected = false
        do { _ = try await checkpoint.load(id: id, directory: directory) } catch { rejected = true }
        #expect(rejected)
        object["schema"] = 1
        object["profile"] = secrets[0]
        try JSONSerialization.data(withJSONObject: object).write(to: QualificationCheckpoint.url(id: id, directory: directory))
        rejected = false
        do { _ = try await checkpoint.load(id: id, directory: directory) } catch { rejected = true }
        #expect(rejected)
        try Data(repeating: 32, count: QualificationCheckpoint.maximumBytes + 1)
            .write(to: QualificationCheckpoint.url(id: id, directory: directory))
        rejected = false
        do { _ = try await checkpoint.load(id: id, directory: directory) } catch { rejected = true }
        #expect(rejected)
        try Data("malformed".utf8).write(to: QualificationCheckpoint.url(id: id, directory: directory))
        rejected = false
        do { _ = try await checkpoint.load(id: id, directory: directory) } catch { rejected = true }
        #expect(rejected)
    }

    @Test func transportTotalsAreCumulativeAcrossGenerations() {
        let totals = QualificationTransportCounter()
        totals.begin()
        var first = RTMPSPublisher.Metrics()
        first.acceptedPackets = 7; first.acknowledgedPackets = 2
        first.highWaterBytes = 300; first.highWaterPackets = 5
        totals.update(from: .init(), to: first)
        var terminal = first
        terminal.discardedAdmittedPackets = 5
        totals.update(from: first, to: terminal)
        totals.begin()
        var second = RTMPSPublisher.Metrics()
        second.acceptedPackets = 3; second.highWaterBytes = 200
        second.rejectedPackets = 1
        totals.update(from: .init(), to: second)
        #expect(totals.snapshot.generations == 2)
        #expect(totals.snapshot.admittedPackets == 10)
        #expect(totals.snapshot.acknowledgedPackets == 2)
        #expect(totals.snapshot.discardedAdmittedPackets == 5)
        #expect(totals.snapshot.rejectedPackets == 1)
        #expect(totals.snapshot.highWaterBytes == 300)
    }
}
