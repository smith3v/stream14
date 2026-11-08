import AVFoundation
import CryptoKit
import Synchronization
import Testing
@testable import Stream14

#if DEBUG
/// Explicit laptop-only fixture: no camera, microphone, Google API or real key.
/// Destination is fixed inside the Debug-only adapter seam, never environment-supplied.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["STREAM14_PRIVATE_RECEIVER"] == "1"))
struct PrivateRTMPSReceiverTests {
    @Test @MainActor func realTLSReceiverAndReconnectKeepOneLocalOriginal() async throws {
        RTMPPrivacy.configure()
        let sender = RTMPSConnection()
        if ProcessInfo.processInfo.environment["STREAM14_EXPECT_UNTRUSTED"] == "1" {
            await #expect(throws: RTMPSConnection.Failure.self) { try await sender.connectPrivateFixture(profile: .hd) }
            await sender.close()
            return
        }
        let root = try #require(ProcessInfo.processInfo.environment["STREAM14_RECEIVER_ARTIFACTS"])
        let directory = URL(fileURLWithPath: root, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let local = directory.appendingPathComponent("local.mp4")
        let recorder = LocalRecorder()
        try recorder.start(local, profile: .hd)
        let destinations = SharedMediaDestinations(recorder: recorder)
        let failures = Mutex(0)
        let records = Mutex([PrivateReceiverRawPacket]())
        defer {
            do {
                let data = try JSONEncoder().encode(records.withLock { $0 })
                try data.write(to: directory.appendingPathComponent("encoded-packets.json"), options: .atomic)
            } catch { Issue.record("Could not retain synthetic raw packet manifest") }
        }
        let encoder = try SharedMediaEncoder(profile: .hd, output: { sample in
            if let record = PrivateReceiverRawPacket(sample) { records.withLock { $0.append(record) } }
            destinations.append(sample)
        }, failed: { reason in
            print("PRIVATE_RECEIVER: encoder failure \(reason)")
            failures.withLock { $0 += 1 }
        })
        await encoder.start()
        try await sender.connectPrivateFixture(profile: .hd)
        let first = publisher(sender, failed: { failures.withLock { $0 += 1 } })
        destinations.attachPublisher(first)
        try await generate(0..<180, encoder: encoder)
        try await drained(first)
        destinations.detachPublisher()
        await first.stop()
        // Actual disconnected transport interval; same encoder/writer continue.
        try await generate(180..<210, encoder: encoder)
        #expect(recorder.hasStarted)
        let secondSender = RTMPSConnection()
        try await secondSender.connectPrivateFixture(profile: .hd)
        let second = publisher(secondSender, failed: { failures.withLock { $0 += 1 } })
        destinations.attachPublisher(second)
        await encoder.requestKeyframe()
        try await generate(210..<390, encoder: encoder)
        try await encoder.finish()
        try await drained(second)
        destinations.detachPublisher()
        await second.stop()
        let metrics = try await recorder.finish()
        #expect(metrics.videoWritten == 390)
        #expect(failures.withLock { $0 } == 0)
        #expect(encoder.metrics.rejectedVideoFrames == 0)
        #expect(first.metrics.acknowledgedPackets > 100)
        #expect(second.metrics.acknowledgedPackets > 100)
        #expect(first.metrics.acknowledgedPackets == first.metrics.acceptedPackets)
        #expect(second.metrics.acknowledgedPackets == second.metrics.acceptedPackets)
        #expect(first.metrics.highWaterPackets <= 128)
        #expect(second.metrics.highWaterPackets <= 128)
        #expect(first.metrics.highWaterBytes <= 2 * 1024 * 1024)
        #expect(second.metrics.highWaterBytes <= 2 * 1024 * 1024)
        let markers = try await decodedSharedMediaMarkers(local)
        #expect(abs(markers.video - 4.5) < 0.005)
        #expect(abs(markers.video - markers.audio) < 0.035)
        #expect(try await AVURLAsset(url: local).load(.duration).seconds >= 12.99)
        // Local artifact intentionally retained. Independent receiver decode is
        // performed on the host after MediaMTX has finalized both generations.
        print("PRIVATE_RECEIVER: 390 local video frames; two acknowledged socket generations; marker checks passed")
    }

    private func publisher(_ sender: RTMPSConnection, failed: @escaping @Sendable () -> Void) -> RTMPSPublisher {
        let result = RTMPSPublisher(send: { sample, origin in try await sender.send(sample, origin: origin) },
            close: { await sender.close() }, failed: { reason in print("PRIVATE_RECEIVER: publisher failure \(reason)"); failed() })
        result.activate()
        return result
    }

    private func drained(_ publisher: RTMPSPublisher) async throws {
        for _ in 0..<500 {
            if publisher.metrics.retainedPackets == 0 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(!publisher.hasFailed)
        try #require(publisher.metrics.retainedPackets == 0)
    }

    private func generate(_ range: Range<Int>, encoder: SharedMediaEncoder) async throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        for index in range {
            // MediaMTX analyzes the first two media seconds before exposing
            // tracks. Supply a deterministic later keyframe for receiver files.
            if index % 210 == 120 { await encoder.requestKeyframe() }
            let video = try LocalRecorderTests.video(index + 30, profile: .hd)
            let image = try #require(video.imageBuffer)
            CVPixelBufferLockBaseAddress(image, [])
            memset(CVPixelBufferGetBaseAddress(image), index % 210 < 135 ? 90 : 255, CVPixelBufferGetDataSize(image))
            CVPixelBufferUnlockBaseAddress(image, [])
            try #require(encoder.offer(video))
            let pcm = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1470))
            pcm.frameLength = 1470
            for channel in 0..<2 {
                for frame in 0..<1470 {
                    let position = index * 1470 + frame
                    pcm.floatChannelData![channel][frame] = position % 308_700 < 198_450 ? 0 :
                        Float(sin(Double(position) * 2 * .pi * 440 / 44_100) * 0.1)
                }
            }
            let audio = try #require(LocalRecorder.audioSample(pcm,
                when: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: 1 + Double(index) / 30))))
            try #require(encoder.offer(audio))
            try await Task.sleep(for: .milliseconds(67))
        }
    }
}

nonisolated private struct PrivateReceiverRawPacket: Codable, Sendable {
    let media: String
    let sha256: String
    let pts: Double
    let dts: Double?
    let duration: Double
    let trimStart: Double
    let trimEnd: Double

    init?(_ sample: CMSampleBuffer) {
        guard let block = sample.dataBuffer else { return nil }
        var bytes = Data(count: CMBlockBufferGetDataLength(block))
        guard bytes.withUnsafeMutableBytes({ CMBlockBufferCopyDataBytes(block, atOffset: 0,
            dataLength: $0.count, destination: $0.baseAddress!) }) == noErr else { return nil }
        media = sample.formatDescription?.mediaType == .video ? "video" : "audio"
        sha256 = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        pts = sample.presentationTimeStamp.seconds
        dts = sample.decodeTimeStamp.isNumeric ? sample.decodeTimeStamp.seconds : nil
        duration = sample.duration.seconds
        trimStart = Self.trim(sample, key: kCMSampleBufferAttachmentKey_TrimDurationAtStart)
        trimEnd = Self.trim(sample, key: kCMSampleBufferAttachmentKey_TrimDurationAtEnd)
    }
    private static func trim(_ sample: CMSampleBuffer, key: CFString) -> Double {
        guard let dictionary = CMGetAttachment(sample, key: key, attachmentModeOut: nil) as? [String: Any] else { return 0 }
        return CMTimeMakeFromDictionary(dictionary as CFDictionary).seconds
    }
}
#endif
