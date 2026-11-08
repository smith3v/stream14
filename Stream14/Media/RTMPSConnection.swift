import AVFoundation
import HaishinKit
import Logboard
import RTMPHaishinKit

/// Library-specific sender for one independently owned transport generation.
/// Only compressed append APIs are used: never attach this stream to the mixer.
actor RTMPSConnection {
    enum Failure: Error, Sendable { case connection, cancelled, invalidPacket }
    private let connection = RTMPConnection(timeout: 10, requestTimeout: 10_000,
        maximumPendingOutputBytes: 4 * 1024 * 1024, maximumPendingOutputMessages: 128)
    private var stream: RTMPStream?
    private var closed = false
    private var origin: CMTime?

    func connect(_ destination: YouTubeIngestionDestination, profile: SessionProfile, canPublish: @Sendable () -> Bool) async throws {
        guard !closed, stream == nil else { throw Failure.cancelled }
        let stream = RTMPStream(connection: connection)
        self.stream = stream
        do {
            // Configure the requested profile, without appending raw samples to
            // the stream's codecs or creating a second encoder. In this pinned
            // compressed-only path onMetaData is duration-only; sequence headers
            // carry actual formats. Full profile metadata needs receiver evidence.
            try await stream.setVideoSettings(VideoCodecSettings(videoSize: profile.size,
                bitRate: profile.videoBitRate, maxKeyFrameIntervalDuration: Int32(profile.keyframeSeconds),
                allowFrameReordering: false, expectedFrameRate: profile.frameRate))
            try await stream.setAudioSettings(AudioCodecSettings(bitRate: profile.audioBitRate,
                downmix: false, sampleRate: profile.audioSampleRate))
            guard !closed, !Task.isCancelled, canPublish() else { throw Failure.cancelled }
            _ = try await connection.connect(destination.endpoint.absoluteString)
            guard !closed, !Task.isCancelled, canPublish() else { throw Failure.cancelled }
            _ = try await stream.publish(destination.streamName)
            guard !closed, !Task.isCancelled else { throw Failure.cancelled }
        } catch {
            await close()
            // Never propagate SDK errors/status strings: server responses can
            // contain the stream name or complete destination.
            throw closed && Task.isCancelled ? Failure.cancelled : Failure.connection
        }
    }

    func send(_ sample: CMSampleBuffer, origin: CMTime) async throws {
        guard !closed, let stream else { throw Failure.cancelled }
        do {
            if self.origin == nil {
                try await stream.setCompressedTimestampOrigin(origin)
                self.origin = origin
            }
            guard self.origin == origin else { throw Failure.invalidPacket }
            if sample.formatDescription?.mediaType == .video {
                try await stream.sendCompressedVideo(sample)
            } else {
                let audio = try Self.audioPacket(sample)
                // The SDK audio API accepts host ticks. Round up one tick from
                // its truncating conversion so an exactly-on-epoch packet is
                // not rejected as pre-origin by floating point/tick rounding.
                let ticks = AVAudioTime.hostTime(forSeconds: sample.presentationTimeStamp.seconds)
                guard ticks < UInt64.max else { throw Failure.invalidPacket }
                try await stream.sendCompressedAudio(audio, when: AVAudioTime(hostTime: ticks + 1))
            }
        } catch {
            await close()
            throw Task.isCancelled ? Failure.cancelled : Failure.connection
        }
    }

    func close() async {
        guard !closed else { return }
        closed = true
        // Connection close owns stream/socket cleanup. A separate stream.close
        // request could wait for a remote command on an already failed socket.
        try? await connection.close()
        stream = nil
    }

    nonisolated static func audioPacket(_ sample: CMSampleBuffer) throws -> AVAudioCompressedBuffer {
        guard let description = sample.formatDescription, description.mediaType == .audio,
              description.mediaSubType.rawValue == kAudioFormatMPEG4AAC,
              let block = sample.dataBuffer else { throw Failure.invalidPacket }
        var descriptions: UnsafePointer<AudioStreamPacketDescription>?
        var size = 0
        guard CMSampleBufferGetAudioStreamPacketDescriptionsPtr(sample,
            packetDescriptionsPointerOut: &descriptions, sizeOut: &size) == noErr,
              let descriptions, size > 0 else { throw Failure.invalidPacket }
        let count = size / MemoryLayout<AudioStreamPacketDescription>.size
        let length = CMBlockBufferGetDataLength(block)
        guard count == 1, sample.numSamples == 1, length > 0, length <= 2 * 1024 * 1024 else { throw Failure.invalidPacket }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        let buffer = AVAudioCompressedBuffer(format: format, packetCapacity: AVAudioPacketCount(count), maximumPacketSize: length)
        guard CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: buffer.data) == noErr,
              let target = buffer.packetDescriptions else { throw Failure.invalidPacket }
        for index in 0..<count {
            let packet = descriptions[index]
            guard packet.mStartOffset >= 0, packet.mDataByteSize > 0,
                  packet.mStartOffset <= Int64(length) - Int64(packet.mDataByteSize) else { throw Failure.invalidPacket }
            target[index] = packet
        }
        buffer.packetCount = AVAudioPacketCount(count)
        buffer.byteLength = UInt32(length)
        return buffer
    }
}

@MainActor enum RTMPPrivacy {
    static func configure() {
        // Configure once at app startup, before connections exist. Retaining raw
        // library diagnostics could expose credentials at any logger level.
        LBLogger.with(kRTMPHaishinKitIdentifier).appender = DiscardSDKTransportLogs()
    }
}
nonisolated private final class DiscardSDKTransportLogs: LBLoggerAppender {
    func append(_ logboard: LBLogger, level: LBLogger.Level, message: [Any],
                file: StaticString, function: StaticString, line: Int) {}
    func append(_ logboard: LBLogger, level: LBLogger.Level, format: String, arguments: any CVarArg,
                file: StaticString, function: StaticString, line: Int) {}
}
