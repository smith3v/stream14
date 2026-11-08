import AVFoundation
import HaishinKit
import RTMPHaishinKit
import Logboard
import Synchronization
import Testing
import UIKit
@testable import Stream14

/// Test target only: importing the RTMP product does not add it to the shipped app.
private final class RawStreamProbe: StreamOutput, Sendable {
    private let counts = Mutex((raw: 0, compressed: 0))
    var raw: Int { counts.withLock { $0.raw } }
    var compressed: Int { counts.withLock { $0.compressed } }
    func stream(_ stream: some StreamConvertible, didOutput audio: AVAudioBuffer, when: AVAudioTime) {
        counts.withLock { if audio is AVAudioCompressedBuffer { $0.compressed += 1 } else { $0.raw += 1 } }
    }
    func stream(_ stream: some StreamConvertible, didOutput video: CMSampleBuffer) {
        counts.withLock { if video.imageBuffer == nil { $0.compressed += 1 } else { $0.raw += 1 } }
    }
}

/// Logboard's exported NullAppender has an internal initializer in pinned 2.6.0.
private final class DiscardTransportLogs: LBLoggerAppender {
    func append(_ logboard: LBLogger, level: LBLogger.Level, message: [Any],
                file: StaticString, function: StaticString, line: Int) {}
    func append(_ logboard: LBLogger, level: LBLogger.Level, format: String, arguments: any CVarArg,
                file: StaticString, function: StaticString, line: Int) {}
}

@Suite(.serialized)
struct DualOutputFeasibilityTests {
    /// A public stream observer sees raw input even when the transport is idle.
    /// It is therefore not a source of shared H.264/AAC encoded packets.
    @Test func disconnectedObserverIsRawAndLocalWriterIsIndependent() async throws {
        let connection = RTMPConnection()
        let stream = RTMPStream(connection: connection)
        let probe = RawStreamProbe()
        await stream.addOutput(probe)
        await stream.setVideoInputBufferCounts(3)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        let recorder = LocalRecorder()
        try recorder.start(url)
        let codec = try SharedMediaCodec(profile: .fullHD)
        for index in 0..<30 {
            let video = try LocalRecorderTests.video(index + 30)
            for packet in try codec.append(video) { recorder.append(packet) }
            for packet in try codec.append(LocalRecorderTests.audio(index + 30)) { recorder.append(packet) }
            await stream.append(video)
            try await Task.sleep(for: .milliseconds(34))
        }
        for packet in try codec.finish() { recorder.append(packet) }
        let metrics = try await recorder.finish()
        #expect(metrics.videoWritten > 20)
        #expect(await stream.readyState == .idle)
        #expect(probe.raw == 30)
        #expect(probe.compressed == 0)
        #expect(try await AVURLAsset(url: url).loadTracks(withMediaType: .audio).count == 1)
        // Synthetic test artifacts alone are disposable; device originals are retained.
        try FileManager.default.removeItem(at: url)
    }

    /// Prove AVAssetWriter's compressed H.264/AAC passthrough with actual encoded
    /// samples and source-format hints. This is remux evidence, not a live encoder.
    @Test func compressedMP4InputsPreservePacketBytesAndTimestamps() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("source.mp4")
        let copy = directory.appendingPathComponent("passthrough.mp4")
        let recorder = LocalRecorder()
        try recorder.start(source)
        let codec = try SharedMediaCodec(profile: .fullHD)
        for index in 0..<30 {
            for packet in try codec.append(LocalRecorderTests.video(index + 30)) { recorder.append(packet) }
            for packet in try codec.append(LocalRecorderTests.audio(index + 30)) { recorder.append(packet) }
            try await Task.sleep(for: .milliseconds(34))
        }
        for packet in try codec.finish() { recorder.append(packet) }
        _ = try await recorder.finish()
        try await callCompressedOverloadsForCompileCompatibility(source)
        let sourceAsset = AVURLAsset(url: source)
        let writer = try AVAssetWriter(outputURL: copy, fileType: .mp4)
        var tracks: [(AVAssetReader, AVAssetReaderTrackOutput, AVAssetWriterInput)] = []
        for type in [AVMediaType.video, .audio] {
            let track = try #require(try await sourceAsset.loadTracks(withMediaType: type).first)
            let hint = try #require(try await track.load(.formatDescriptions).first)
            let reader = try AVAssetReader(asset: sourceAsset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            reader.add(output)
            let input = AVAssetWriterInput(mediaType: type, outputSettings: nil, sourceFormatHint: hint)
            try #require(writer.canAdd(input))
            writer.add(input)
            tracks.append((reader, output, input))
        }
        try #require(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for (reader, output, input) in tracks {
            try #require(reader.startReading())
            while let sample = output.copyNextSampleBuffer() {
                // This bounded synthetic clip has no real-time admission pressure.
                var waits = 0
                while !input.isReadyForMoreMediaData && writer.status == .writing && waits < 200 {
                    try await Task.sleep(for: .milliseconds(10)); waits += 1
                }
                try #require(input.isReadyForMoreMediaData)
                try #require(input.append(sample))
            }
            #expect(reader.status == .completed)
            input.markAsFinished()
        }
        await writer.finishWriting()
        try #require(writer.status == .completed)
        for type in [AVMediaType.video, .audio] {
            let before = try await packets(source, type)
            let after = try await packets(copy, type)
            #expect(!before.isEmpty)
            #expect(before.map(\.data) == after.map(\.data))
            #expect(before.map(\.pts) == after.map(\.pts))
        }
        try FileManager.default.removeItem(at: directory)
    }

    /// Compile/call compatibility only. append returns Void and catches/logs
    /// timestamp errors; idle state and absent observer callbacks do not establish
    /// acceptance of these media formats. Run 5 logged invalidSequence for the
    /// first zero-timestamp samples. A live adapter needs a common positive input
    /// timeline, strict per-track order, and verified first-origin/A/V handling.
    private func callCompressedOverloadsForCompileCompatibility(_ url: URL) async throws {
        let connection = RTMPConnection()
        let stream = RTMPStream(connection: connection)
        let probe = RawStreamProbe()
        await stream.addOutput(probe)
        let asset = AVURLAsset(url: url)
        for type in [AVMediaType.video, .audio] {
            let track = try #require(try await asset.loadTracks(withMediaType: type).first)
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            reader.add(output)
            try #require(reader.startReading())
            while let sample = output.copyNextSampleBuffer() {
                guard sample.numSamples > 0, let block = sample.dataBuffer else { continue }
                if type == .video {
                    await stream.append(sample)
                } else {
                    let description = try #require(sample.formatDescription)
                    let format = AVAudioFormat(cmAudioFormatDescription: description)
                    var descriptions: UnsafePointer<AudioStreamPacketDescription>?
                    var descriptionBytes = 0
                    try #require(CMSampleBufferGetAudioStreamPacketDescriptionsPtr(sample,
                        packetDescriptionsPointerOut: &descriptions, sizeOut: &descriptionBytes) == noErr)
                    let packetDescriptions = try #require(descriptions)
                    let packetCount = descriptionBytes / MemoryLayout<AudioStreamPacketDescription>.size
                    try #require(packetCount > 0)
                    let count = CMBlockBufferGetDataLength(block)
                    let audio = AVAudioCompressedBuffer(format: format, packetCapacity: AVAudioPacketCount(packetCount),
                        maximumPacketSize: count)
                    audio.packetCount = AVAudioPacketCount(packetCount)
                    audio.byteLength = UInt32(count)
                    try #require(CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count,
                        destination: audio.data) == noErr)
                    let destination = try #require(audio.packetDescriptions)
                    destination.update(from: packetDescriptions, count: packetCount)
                    await stream.append(audio, when: AVAudioTime(hostTime:
                        AVAudioTime.hostTime(forSeconds: sample.presentationTimeStamp.seconds)))
                }
            }
            #expect(reader.status == .completed)
        }
        #expect(await stream.readyState == .idle)
        #expect(probe.raw == 0)
        #expect(probe.compressed == 0)
    }

    private func packets(_ url: URL, _ type: AVMediaType) async throws -> [(data: Data, pts: CMTime)] {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: type).first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        try #require(reader.startReading())
        var result: [(Data, CMTime)] = []
        while let sample = output.copyNextSampleBuffer() {
            // Reader may emit a zero-sample duration/trim marker without data.
            guard sample.numSamples > 0, let block = sample.dataBuffer else { continue }
            var data = Data(count: CMBlockBufferGetDataLength(block))
            let status = data.withUnsafeMutableBytes {
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!)
            }
            try #require(status == noErr)
            if type == .audio {
                // AVAssetReader may coalesce the same AAC packets into different
                // CMSampleBuffer groups after remux. Compare codec packets instead.
                var descriptions: UnsafePointer<AudioStreamPacketDescription>?
                var size = 0
                try #require(CMSampleBufferGetAudioStreamPacketDescriptionsPtr(sample,
                    packetDescriptionsPointerOut: &descriptions, sizeOut: &size) == noErr)
                let packets = try #require(descriptions)
                let format = try #require(sample.formatDescription)
                let asbd = try #require(CMAudioFormatDescriptionGetStreamBasicDescription(format))
                var frames: Int64 = 0
                for index in 0..<(size / MemoryLayout<AudioStreamPacketDescription>.size) {
                    let packet = packets[index]
                    let start = Int(packet.mStartOffset)
                    let end = start + Int(packet.mDataByteSize)
                    try #require(start >= 0 && end <= data.count)
                    let offset = CMTime(value: frames, timescale: CMTimeScale(asbd.pointee.mSampleRate))
                    result.append((data.subdata(in: start..<end), sample.presentationTimeStamp + offset))
                    frames += Int64(packet.mVariableFramesInPacket == 0 ?
                        asbd.pointee.mFramesPerPacket : packet.mVariableFramesInPacket)
                }
            } else {
                result.append((data, sample.presentationTimeStamp))
            }
        }
        #expect(reader.status == .completed)
        return result
    }

    /// Explicitly enabled only on a phone with a private operator-approved RTMPS
    /// destination. The candidate uses TWO encoders and is never production-enabled.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STREAM14_DUAL_OUTPUT"] == "1"))
    @MainActor func privateDeviceDualOutputCandidate() async throws {
        #if targetEnvironment(simulator)
        throw CandidateFailure.physicalDeviceRequired
        #else
        let environment = ProcessInfo.processInfo.environment
        // Never assert/interpolate the raw configuration or underlying network error:
        // Swift Testing reflection and upstream logs may otherwise expose a stream key.
        guard let endpoint = environment["STREAM14_PRIVATE_RTMPS_URL"],
              let url = URL(string: endpoint), url.scheme == "rtmps", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              let key = environment["STREAM14_PRIVATE_STREAM_KEY"], !key.isEmpty else {
            throw CandidateFailure.missingPrivateConfiguration
        }
        let transportLogger = LBLogger.with(kRTMPHaishinKitIdentifier)
        let previousAppender = transportLogger.appender
        transportLogger.appender = DiscardTransportLogs()
        defer { transportLogger.appender = previousAppender }
        // This private candidate has fixed 1080p fixtures/transport settings.
        let session = MediaSession(readOverlayURL: { "" }, saveOverlayURL: { _ in }, profile: .fullHD)
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        controller.view.addSubview(session.preview)
        session.preview.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        window.makeKeyAndVisible()
        defer { session.requestStop(); window.isHidden = true }
        await session.openPreview()
        let ready = session.canRecord
        try #require(ready)
        let overlay = await SyntheticOverlay()
        try await overlay.install(on: session.mixer)
        await session.record()
        let recordingStarted = session.isRecording
        try #require(recordingStarted)
        let recordingID = session.recordingID
        let connection = RTMPConnection()
        let stream = RTMPStream(connection: connection)
        await stream.setVideoInputBufferCounts(3)
        try await stream.setVideoSettings(VideoCodecSettings(videoSize: CGSize(width: 1920, height: 1080),
            bitRate: 14_000_000, maxKeyFrameIntervalDuration: 2, allowFrameReordering: false, expectedFrameRate: 30))
        try await stream.setAudioSettings(AudioCodecSettings(bitRate: 128_000, downmix: false, sampleRate: 44_100))
        await session.mixer.addOutput(stream)
        let seconds = min(max(Int(environment["STREAM14_DUAL_OUTPUT_SECONDS"] ?? "30") ?? 30, 12), 600)
        do {
            _ = try await connection.connect(endpoint)
            _ = try await stream.publish(key)
            for second in 0..<seconds {
                await overlay.update(counter: second)
                if second == seconds / 3 {
                    _ = try await stream.close()
                    try await connection.close()
                    try await Task.sleep(for: .seconds(1))
                    let recordingDuringDisconnect = session.isRecording
                    try #require(recordingDuringDisconnect)
                    _ = try await connection.connect(endpoint)
                    _ = try await stream.publish(key)
                }
                try await Task.sleep(for: .seconds(1))
            }
            _ = try await stream.close()
            try await connection.close()
            await session.mixer.removeOutput(stream)
            await session.stopRecording()
            let completed = session.savedSamples.first { $0.id == recordingID }?.status == .completed
            try #require(completed)
        } catch {
            try? await connection.close()
            await session.mixer.removeOutput(stream)
            await session.stopRecording()
            throw CandidateFailure.transportOrRecording
        }
        // Originals and manifests remain in the app's normal recordings directory.
        #endif
    }

    private enum CandidateFailure: Error {
        case physicalDeviceRequired, missingPrivateConfiguration, transportOrRecording
    }
}
