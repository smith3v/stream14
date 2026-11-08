import AVFoundation
import Synchronization
import Testing
@testable import Stream14

@Suite(.serialized)
struct SharedMediaEncoderTests {
    @Test func bothProfilesUseOneEncoderAndOwnedAACPackets() throws {
        for profile in SessionProfile.allCases {
            let codec = try SharedMediaCodec(profile: profile)
            var video: [CMSampleBuffer] = []
            var audio: [CMSampleBuffer] = []
            for index in 30..<60 {
                video += try codec.append(LocalRecorderTests.video(index, profile: profile))
                audio += try codec.append(LocalRecorderTests.audio(index))
            }
            audio += try codec.finish()
            codec.invalidate()
            #expect(video.count == 30)
            #expect(audio.count >= 43 && audio.count <= 48)
            #expect(video.allSatisfy { $0.formatDescription?.mediaSubType.rawValue == kCMVideoCodecType_H264 })
            #expect(audio.allSatisfy { $0.formatDescription?.mediaSubType.rawValue == kAudioFormatMPEG4AAC })
            #expect(video.first?.presentationTimeStamp == CMTime(value: 1, timescale: 1))
            #expect(zip(audio, audio.dropFirst()).allSatisfy { $0.presentationTimeStamp < $1.presentationTimeStamp })
            let first = try #require(audio.first)
            let leading = try trim(first, key: kCMSampleBufferAttachmentKey_TrimDurationAtStart)
            #expect(leading.seconds > 0)
            #expect(first.presentationTimeStamp < CMTime(value: 1, timescale: 1))
            #expect(try bytes(first).count > 0)
            // Packets remain independently owned after converter/session teardown.
            #expect(audio.allSatisfy { $0.totalSampleSize > 0 })
        }
    }

    @Test func callbackSizesPreserveFrameClockAndEncoderDelay() throws {
        let codec = try SharedMediaCodec(profile: .hd)
        var packets: [CMSampleBuffer] = []
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        var frames = 0
        for count in [113, 1000, 17, 2048, 777, 4096, 2048, 1024, 4096] {
            let pcm = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)))
            pcm.frameLength = AVAudioFrameCount(count)
            for channel in 0..<2 { memset(pcm.floatChannelData![channel], 0, count * MemoryLayout<Float>.size) }
            let sample = try #require(LocalRecorder.audioSample(pcm, when: AVAudioTime(hostTime:
                AVAudioTime.hostTime(forSeconds: 1 + Double(frames) / 44_100))))
            packets += try codec.append(sample)
            frames += count
        }
        packets += try codec.finish()
        #expect(!packets.isEmpty)
        for pair in zip(packets, packets.dropFirst()) {
            #expect(abs((pair.1.presentationTimeStamp - pair.0.presentationTimeStamp).seconds - 1024 / 44_100) < 0.000001)
        }
        let first = try #require(packets.first)
        let last = try #require(packets.last)
        let leadingPTS = 1 - first.presentationTimeStamp.seconds
        let trailing = try trim(last, key: kCMSampleBufferAttachmentKey_TrimDurationAtEnd).seconds
        #expect(abs(Double(packets.count * 1024) / 44_100 - leadingPTS - trailing - Double(frames) / 44_100) < 0.000001)
    }

    @Test func invalidOrderingAndAudioDiscontinuityFailExplicitly() throws {
        let codec = try SharedMediaCodec(profile: .hd)
        _ = try codec.append(LocalRecorderTests.video(30, profile: .hd))
        #expect(throws: SharedMediaEncoder.Failure.self) { try codec.append(LocalRecorderTests.video(30, profile: .hd)) }
        _ = try codec.append(LocalRecorderTests.audio(30))
        #expect(throws: SharedMediaEncoder.Failure.self) { try codec.append(LocalRecorderTests.audio(32)) }
        codec.invalidate()
    }

    @Test func rawAdmissionBoundsIncludeItemsBeforeWorkerStarts() async throws {
        let errors = Mutex([SharedMediaEncoder.Failure]())
        let encoder = try SharedMediaEncoder(profile: .hd, output: { _ in }, failed: { failure in
            errors.withLock { $0.append(failure) }
        })
        #expect(encoder.offer(try LocalRecorderTests.video(30, profile: .hd)))
        #expect(encoder.offer(try LocalRecorderTests.video(31, profile: .hd)))
        #expect(!encoder.offer(try LocalRecorderTests.video(32, profile: .hd)))
        #expect(encoder.metrics.highWaterVideoFrames == 2)
        #expect(encoder.metrics.rejectedVideoFrames == 1)
        #expect(encoder.metrics.highWaterBytes <= 16 * 1024 * 1024)
        try await encoder.finish()
        #expect(!encoder.offer(try LocalRecorderTests.video(33, profile: .hd)))
        #expect(errors.withLock { $0.isEmpty })
    }

    @Test func audioOverflowIsTerminalAndDoesNotRetainExtraBuffers() async throws {
        let errors = Mutex([SharedMediaEncoder.Failure]())
        let encoder = try SharedMediaEncoder(profile: .hd, limits: .init(audioFrames: 1470), output: { _ in }, failed: { failure in
            errors.withLock { $0.append(failure) }
        })
        #expect(encoder.offer(try LocalRecorderTests.audio(30)))
        #expect(!encoder.offer(try LocalRecorderTests.audio(31)))
        #expect(encoder.metrics.highWaterAudioFrames == 1470)
        #expect(encoder.metrics.rejectedAudioFrames == 1470)
        await #expect(throws: SharedMediaEncoder.Failure.self) { try await encoder.finish() }
        #expect(errors.withLock { $0.count } == 1)
    }

    private func trim(_ sample: CMSampleBuffer, key: CFString) throws -> CMTime {
        let dictionary = try #require(CMGetAttachment(sample, key: key, attachmentModeOut: nil) as? [String: Any])
        return CMTimeMakeFromDictionary(dictionary as CFDictionary)
    }
    private func bytes(_ sample: CMSampleBuffer) throws -> Data {
        let block = try #require(sample.dataBuffer)
        var result = Data(count: CMBlockBufferGetDataLength(block))
        let status = result.withUnsafeMutableBytes {
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!)
        }
        #expect(status == noErr)
        return result
    }
}
