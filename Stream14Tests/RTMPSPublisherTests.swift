import AVFoundation
import Testing
@testable import Stream14

private actor SendGate {
    var waiting: CheckedContinuation<Void, any Error>?
    var calls = 0
    var closes = 0
    var origins: [CMTime] = []
    func send(_ sample: CMSampleBuffer, origin: CMTime) async throws {
        calls += 1; origins.append(origin)
        try await withCheckedThrowingContinuation { waiting = $0 }
    }
    func close() { closes += 1 }
    func release() { waiting?.resume(throwing: CancellationError()); waiting = nil }
}
private actor ImmediateSend {
    var count = 0
    var closes = 0
    var epochs: [CMTime] = []
    let reject: Bool
    init(reject: Bool = false) { self.reject = reject }
    func send(_ sample: CMSampleBuffer, origin: CMTime) throws {
        if reject { throw CancellationError() }
        count += 1; epochs.append(origin)
    }
    func close() { closes += 1 }
}

@Suite(.serialized)
struct RTMPSPublisherTests {
    @Test func stalledSendOverflowClosesWithoutWaitingAndKeepsInFlightCharged() async throws {
        let samples = try videoPackets(3)
        let gate = SendGate()
        let diagnostics = QualificationTransportCounter()
        let publisher = RTMPSPublisher(limits: .init(bytes: 1_000_000, packets: 2), diagnostics: diagnostics,
            send: { sample, origin in try await gate.send(sample, origin: origin) },
            close: { await gate.close() }, failed: { _ in })
        publisher.activate()
        #expect(publisher.offer(samples[0]))
        try await eventually { await gate.calls == 1 }
        #expect(publisher.offer(samples[1]))
        #expect(!publisher.offer(samples[2]))
        try await eventually { await gate.closes == 1 }
        #expect(publisher.hasFailed)
        #expect(publisher.metrics.highWaterPackets == 2)
        #expect(publisher.metrics.highWaterBytes <= 1_000_000)
        #expect(publisher.metrics.retainedPackets == 1)
        #expect(publisher.metrics.retainedBytes == samples[0].totalSampleSize)
        #expect(publisher.metrics.overflowCount == 1)
        await gate.release()
        await publisher.stop()
        #expect(publisher.metrics.retainedPackets == 0)
        #expect(publisher.metrics.retainedBytes == 0)
        #expect(diagnostics.snapshot.generations == 1)
        #expect(diagnostics.snapshot.admittedPackets == 2)
        #expect(diagnostics.snapshot.rejectedPackets == 1)
        #expect(diagnostics.snapshot.discardedAdmittedPackets == 2)
        #expect(await gate.calls == 1)
        #expect(await gate.closes == 1)
    }

    @Test func cancellationReleasesQueuedPacketsButRetainsStalledAcknowledgment() async throws {
        let samples = try videoPackets(2)
        let gate = SendGate()
        let publisher = RTMPSPublisher(send: { sample, origin in try await gate.send(sample, origin: origin) },
            close: { await gate.close() }, failed: { _ in })
        publisher.activate()
        #expect(publisher.offer(samples[0]))
        try await eventually { await gate.calls == 1 }
        #expect(publisher.offer(samples[1]))
        let stopping = Task { await publisher.stop() }
        try await eventually { await gate.closes == 1 }
        #expect(publisher.metrics.retainedPackets == 1)
        #expect(!publisher.offer(samples[1]))
        await gate.release()
        await stopping.value
        #expect(publisher.metrics.retainedPackets == 0)
        #expect(!publisher.hasFailed)
    }

    @Test func activationWaitsForRandomAccessAndCommonEpochSurvivesTrackArrival() async throws {
        let samples = try videoPackets(2)
        let codec = try SharedMediaCodec(profile: .hd)
        var audio: [CMSampleBuffer] = []
        for index in 30..<34 { audio += try codec.append(LocalRecorderTests.audio(index)) }
        audio += try codec.finish()
        let sink = ImmediateSend()
        let publisher = RTMPSPublisher(send: { sample, origin in try await sink.send(sample, origin: origin) },
            close: { await sink.close() }, failed: { _ in })
        #expect(!publisher.offer(samples[0])) // not connected/activated
        publisher.activate()
        #expect(!publisher.offer(try #require(audio.first)))
        #expect(!publisher.offer(samples[1])) // non-keyframe cannot establish epoch
        #expect(publisher.offer(samples[0]))
        let afterOrigin = try #require(audio.first { $0.presentationTimeStamp >= samples[0].presentationTimeStamp })
        #expect(publisher.offer(afterOrigin))
        try await eventually { await sink.count == 2 }
        #expect(await sink.epochs.allSatisfy { $0 == samples[0].presentationTimeStamp })
        #expect(publisher.metrics.skippedBeforeOrigin == 2)
        await publisher.stop()
    }

    @Test func sendFailureAndRepeatedFreshConnectionsNeverRetainOldQueues() async throws {
        let sample = try #require(videoPackets(1).first)
        for _ in 0..<8 {
            let sink = ImmediateSend(reject: true)
            let publisher = RTMPSPublisher(send: { sample, origin in try await sink.send(sample, origin: origin) },
                close: { await sink.close() }, failed: { _ in })
            publisher.activate()
            #expect(publisher.offer(sample))
            try await eventually { await sink.closes == 1 }
            await publisher.stop()
            #expect(publisher.hasFailed)
            #expect(publisher.metrics.retainedBytes == 0)
            #expect(publisher.metrics.retainedPackets == 0)
        }
    }

    private func videoPackets(_ count: Int) throws -> [CMSampleBuffer] {
        let codec = try SharedMediaCodec(profile: .hd)
        return try (30..<(30 + count)).flatMap { try codec.append(LocalRecorderTests.video($0, profile: .hd)) }
    }
    private func eventually(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(await condition())
    }
}
