import AVFoundation
import Testing
import UIKit
@testable import Stream14

@MainActor @Suite(.serialized, .timeLimit(.minutes(1))) struct SessionInterruptionTests {
    @Test func thermalPolicyReducesOverlayWithoutChangingProfileAndCriticalRequiresRestart() async throws {
        let media = session()
        var reasons: [SessionInterruption] = []
        media.onInterruption = { reasons.append($0) }
        media.applyThermalState(.serious)
        #expect(media.renderer.captureInterval == 3 && !media.thermalWarning.isEmpty)
        #expect(media.profile == .hd && reasons.isEmpty)
        media.applyThermalState(.nominal)
        #expect(media.renderer.captureInterval == 1 && media.thermalWarning.isEmpty)
        media.applyThermalState(.critical)
        #expect(reasons == [.criticalHeat] && media.phase == .idle)
        #expect(media.profile == .hd)
    }

    @Test func everyInterruptionDetachesBusyUploadAndRepeatedStopsFinalizeOnce() async throws {
        for reason in SessionInterruption.allCases {
            let media = session()
            var reasons: [SessionInterruption] = []
            var closes = 0
            media.onInterruption = { reasons.append($0) }
            let encoder = try SharedMediaEncoder(profile: .hd, output: { _ in }, failed: { _ in })
            let publisher = RTMPSPublisher(send: { _, _ in }, close: { await MainActor.run { closes += 1 } }, failed: { _ in })
            publisher.activate()
            media.installBroadcastFixture(encoder: encoder, publisher: publisher)
            var waiter: CheckedContinuation<Void, Never>?
            let held = Task { await media.holdFileFinalizationFixture { await withCheckedContinuation { waiter = $0 } } }
            try await until { waiter != nil }
            media.interrupt(reason); media.interrupt(reason)
            #expect(!media.broadcastPipelineRunning)
            #expect(reasons == [reason])
            waiter?.resume(); await held.value
            try await until { media.phase == .idle }
            #expect(!media.hasUpload && closes == 1)
        }
    }

    @Test func writerAppendAndFinalizationFailuresPreservePublisherAndPersistentWarning() async throws {
        for injection in [LocalRecorder.Injection.append, .finalization] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let media = session()
            let publisher = RTMPSPublisher(send: { _, _ in }, close: {}, failed: { _ in })
            publisher.activate()
            let encoder = try SharedMediaEncoder(profile: .hd, output: { _ in }, failed: { _ in })
            media.installBroadcastFixture(encoder: encoder, publisher: publisher)
            let sample = ExperimentSample()
            try sample.save(in: directory)
            let recorder = try await recorder(sample: sample, directory: directory, injection: injection)
            media.installWriterFixture(recorder, sample: sample, directory: directory)
            if injection == .append { await media.failWriterFixture() }
            else { await media.stopRecording() }
            #expect(media.hasUpload && media.broadcastPipelineRunning)
            #expect(media.recordingFailed && !media.backupWarning.isEmpty)
            let retained = try JSONDecoder().decode(ExperimentSample.self,
                from: Data(contentsOf: directory.appendingPathComponent(sample.id.uuidString + ".json")))
            #expect(retained.status == .failed)
            #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(sample.fileName).path))
            media.interrupt(.camera)
            try await until { media.phase == .idle }
        }
    }

    @Test func backgroundExpiryPersistsIncompleteAndRestoresPriorIdleTimerBeforeLateFinish() async throws {
        for previous in [false, true] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let original = UIApplication.shared.isIdleTimerDisabled
            defer { UIApplication.shared.isIdleTimerDisabled = original }
            UIApplication.shared.isIdleTimerDisabled = previous
            let media = session()
            let publisher = RTMPSPublisher(send: { _, _ in }, close: {}, failed: { _ in })
            publisher.activate()
            let encoder = try SharedMediaEncoder(profile: .hd, output: { _ in }, failed: { _ in })
            media.installBroadcastFixture(encoder: encoder, publisher: publisher)
            let sample = ExperimentSample()
            try sample.save(in: directory)
            let writer = try await recorder(sample: sample, directory: directory, injection: .none)
            media.installWriterFixture(writer, sample: sample, directory: directory)
            var waiter: CheckedContinuation<Void, Never>?
            let held = Task { await media.holdFileFinalizationFixture { await withCheckedContinuation { waiter = $0 } } }
            try await until { waiter != nil }
            media.interrupt(.background)
            media.backgroundTimeExpired()
            #expect(UIApplication.shared.isIdleTimerDisabled == previous)
            let retained = try JSONDecoder().decode(ExperimentSample.self,
                from: Data(contentsOf: directory.appendingPathComponent(sample.id.uuidString + ".json")))
            #expect(retained.status == .failed)
            waiter?.resume(); await held.value
            try await until { media.phase == .idle }
            #expect(UIApplication.shared.isIdleTimerDisabled == previous)
            let final = try JSONDecoder().decode(ExperimentSample.self,
                from: Data(contentsOf: directory.appendingPathComponent(sample.id.uuidString + ".json")))
            #expect(final.status == .failed)
        }
    }

    private func session() -> MediaSession {
        MediaSession(readOverlayURL: { "" }, saveOverlayURL: { _ in }, profile: .hd,
            persistProfile: { _ in }, authorizeCapture: { false })
    }
    private func recorder(sample: ExperimentSample, directory: URL, injection: LocalRecorder.Injection) async throws -> LocalRecorder {
        let writer = LocalRecorder()
        try writer.start(directory.appendingPathComponent(sample.fileName), injection: injection, profile: .hd)
        let codec = try SharedMediaCodec(profile: .hd)
        for index in 30..<42 {
            for packet in try codec.append(LocalRecorderTests.video(index, profile: .hd)) { writer.append(packet) }
            for packet in try codec.append(LocalRecorderTests.audio(index)) { writer.append(packet) }
            try await Task.sleep(for: .milliseconds(15))
        }
        for packet in try codec.finish() { writer.append(packet) }
        return writer
    }
    private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<300 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(condition())
    }
}
