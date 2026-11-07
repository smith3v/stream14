import AVFoundation
import HaishinKit
import Testing
@testable import Stream14

@Suite(.serialized)
struct LocalRecorderTests {
    static func video(_ index: Int, profile: SessionProfile = .fullHD) throws -> CMSampleBuffer {
        var optionalPixel: CVPixelBuffer?
        #expect(CVPixelBufferCreate(nil, profile.width, profile.height, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &optionalPixel) == kCVReturnSuccess)
        let pixel = try #require(optionalPixel)
        CVPixelBufferLockBaseAddress(pixel, [])
        memset(CVPixelBufferGetBaseAddress(pixel), 90, CVPixelBufferGetDataSize(pixel))
        CVPixelBufferUnlockBaseAddress(pixel, [])
        var format: CMVideoFormatDescription?
        #expect(CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixel,
            formatDescriptionOut: &format) == noErr)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(value: Int64(index), timescale: 30), decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        #expect(CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixel,
            formatDescription: try #require(format), sampleTiming: &timing, sampleBufferOut: &sample) == noErr)
        return try #require(sample)
    }

    static func audio(_ index: Int) throws -> CMSampleBuffer {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let pcm = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1470))
        pcm.frameLength = 1470
        for channel in 0..<2 { memset(pcm.floatChannelData![channel], 0, 1470 * MemoryLayout<Float>.size) }
        return try #require(LocalRecorder.audioSample(pcm,
            when: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: Double(index) / 30))))
    }

    @Test func repeatedWritingAndInjectedFailures() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for injection in [LocalRecorder.Injection.none, .none, .append, .finalization] {
            let recorder = LocalRecorder()
            let url = directory.appendingPathComponent(UUID().uuidString + ".mp4")
            try recorder.start(url, injection: injection)
            for index in 0..<30 {
                recorder.append(try Self.video(index))
                recorder.append(try Self.audio(index))
                try await Task.sleep(for: .milliseconds(34))
            }
            if injection == .none {
                let metrics = try await recorder.finish()
                #expect(metrics.videoWritten > 0)
                let asset = AVURLAsset(url: url)
                #expect(try await asset.load(.duration).seconds > 0.5)
                #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
                #expect(try await asset.loadTracks(withMediaType: .audio).count == 1)
            } else {
                await #expect(throws: LocalRecorder.Failure.self) { try await recorder.finish() }
                #expect(FileManager.default.fileExists(atPath: url.path))
            }
        }
        let recorder = LocalRecorder()
        #expect(throws: LocalRecorder.Failure.self) {
            try recorder.start(directory.appendingPathComponent("injected.mp4"), injection: .initialization)
        }
        // A genuine path initialization error, without exhausting storage.
        #expect(throws: (any Error).self) {
            try recorder.start(directory.appendingPathComponent("missing/recording.mp4"))
        }
    }

    @Test func lowerProfileWritesOriginal720pH264AAC() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = LocalRecorder()
        try recorder.start(url, profile: .hd)
        for index in 0..<20 {
            recorder.append(try Self.video(index, profile: .hd))
            recorder.append(try Self.audio(index))
            try await Task.sleep(for: .milliseconds(34))
        }
        _ = try await recorder.finish()
        let asset = AVURLAsset(url: url)
        let videos = try await asset.loadTracks(withMediaType: .video)
        let audios = try await asset.loadTracks(withMediaType: .audio)
        let video = try #require(videos.first)
        let audio = try #require(audios.first)
        #expect(try await video.load(.naturalSize) == SessionProfile.hd.size)
        #expect(try await video.load(.preferredTransform) == .identity)
        let videoFormats = try await video.load(.formatDescriptions)
        let audioFormats = try await audio.load(.formatDescriptions)
        #expect(videoFormats.first.map { CMFormatDescriptionGetMediaSubType($0) } == kCMVideoCodecType_H264)
        #expect(audioFormats.first.map { CMFormatDescriptionGetMediaSubType($0) } == kAudioFormatMPEG4AAC)
    }

    @Test func missingCadenceIntervalsAndLegacyMetrics() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = LocalRecorder()
        try recorder.start(url)
        recorder.append(try Self.video(0))
        recorder.append(try Self.video(1))
        recorder.append(try Self.video(4))
        #expect(recorder.metrics.missingOutputFrames == 2)
        await #expect(throws: LocalRecorder.Failure.self) { try await recorder.finish() }
        let legacy = Data(#"{"videoReceived":1,"videoWritten":1,"videoDropped":0,"audioDropped":0,"videoStalls":0,"largestVideoGap":0}"#.utf8)
        let metrics = try JSONDecoder().decode(LocalRecorder.Metrics.self, from: legacy)
        #expect(metrics.missingOutputFrames == nil)
    }

    @Test func emptyRecordingNeverCompletes() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = LocalRecorder()
        try recorder.start(url)
        await #expect(throws: LocalRecorder.Failure.self) { try await recorder.finish() }
    }
}
