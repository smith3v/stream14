import AVFoundation
import Testing
@testable import Stream14

private actor IntegrationSink {
    var sends = 0
    var closes = 0
    let reject: Bool
    init(reject: Bool = false) { self.reject = reject }
    func send() throws {
        if reject { throw CancellationError() }
        sends += 1
    }
    func close() { closes += 1 }
}

@Suite(.serialized)
struct SharedMediaIntegrationTests {
    @Test func failedWriterDoesNotStopHealthyCompressedUpload() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = LocalRecorder()
        try recorder.start(url, injection: .append, profile: .hd)
        let sink = IntegrationSink()
        let publisher = RTMPSPublisher(send: { _, _ in try await sink.send() },
            close: { await sink.close() }, failed: { _ in })
        publisher.activate()
        let destinations = SharedMediaDestinations(recorder: recorder)
        destinations.attachPublisher(publisher)
        try await generate(into: destinations)
        try await eventually { publisher.metrics.retainedPackets == 0 }
        #expect(await sink.sends > 20)
        #expect(!publisher.hasFailed)
        #expect(!recorder.hasStarted)
        await #expect(throws: LocalRecorder.Failure.self) { try await recorder.finish() }
        #expect(FileManager.default.fileExists(atPath: url.path))
        await publisher.stop()
    }

    @Test func failedUploadLeavesOneEncoderAndPlayableOriginalRecording() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = LocalRecorder()
        try recorder.start(url, profile: .hd)
        let sink = IntegrationSink(reject: true)
        let publisher = RTMPSPublisher(send: { _, _ in try await sink.send() },
            close: { await sink.close() }, failed: { _ in })
        publisher.activate()
        let destinations = SharedMediaDestinations(recorder: recorder)
        destinations.attachPublisher(publisher)
        try await generate(into: destinations)
        #expect(publisher.hasFailed)
        #expect(recorder.hasStarted)
        let metrics = try await recorder.finish()
        #expect(metrics.videoWritten == 20)
        #expect(try await AVURLAsset(url: url).load(.duration).seconds > 0.5)
        await publisher.stop()
        #expect(publisher.metrics.retainedPackets == 0)
    }

    @Test @MainActor func unstartedWriterBlocksActualConnectionFactoryBeforeSocketCreation() async throws {
        let url = temporaryURL()
        let recorder = LocalRecorder()
        try recorder.start(url, profile: .hd)
        #expect(!recorder.hasStarted)
        let prepared = PreparedYouTubeIngestion(
            broadcast: YouTubeBroadcast(id: "fixture", snippet: nil, status: nil, contentDetails: nil),
            streamID: "fixture", profile: .hd, generation: 1,
            destination: try YouTubeIngestionDestination(address: "rtmps://rtmps.youtube.com:443/live2", streamName: "fixture-not-a-key"))
        await #expect(throws: RTMPSPublisher.StartupFailure.self) {
            _ = try await RTMPSPublisher.connected(to: prepared,
                canPublish: { recorder.hasStarted }, failed: { _ in })
        }
        await #expect(throws: LocalRecorder.Failure.self) { try await recorder.finish() }
        // No output is expected for a writer with no samples, but retain any
        // synthetic native artifact until this explicitly disposable fixture ends.
        try? FileManager.default.removeItem(at: url)
    }

    @Test func actualLibraryAudioAdapterPreservesSingleAACPacketAndRejectsPCM() throws {
        let codec = try SharedMediaCodec(profile: .hd)
        var packets: [CMSampleBuffer] = []
        for index in 30..<34 { packets += try codec.append(LocalRecorderTests.audio(index)) }
        packets += try codec.finish()
        let sample = try #require(packets.first)
        let buffer = try RTMPSConnection.audioPacket(sample)
        #expect(buffer.packetCount == 1)
        #expect(buffer.format.sampleRate == 44_100)
        #expect(buffer.format.channelCount == 2)
        let block = try #require(sample.dataBuffer)
        var source = Data(count: CMBlockBufferGetDataLength(block))
        try source.withUnsafeMutableBytes {
            try #require(CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!) == noErr)
        }
        #expect(source == Data(bytes: buffer.data, count: Int(buffer.byteLength)))
        #expect(throws: RTMPSConnection.Failure.self) { try RTMPSConnection.audioPacket(LocalRecorderTests.audio(30)) }
    }

    private func generate(into destinations: SharedMediaDestinations) async throws {
        let codec = try SharedMediaCodec(profile: .hd)
        for index in 30..<50 {
            for packet in try codec.append(LocalRecorderTests.video(index, profile: .hd)) { destinations.append(packet) }
            for packet in try codec.append(LocalRecorderTests.audio(index)) { destinations.append(packet) }
            try await Task.sleep(for: .milliseconds(34))
        }
        for packet in try codec.finish() { destinations.append(packet) }
    }
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
    }
    private func eventually(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(await condition())
    }
}
