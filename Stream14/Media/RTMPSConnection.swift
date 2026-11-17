import AVFoundation
import HaishinKit
import Logboard
import Network
import RTMPHaishinKit

/// Only these fixed categories may leave the connection boundary. An SDK error
/// or server response can include the stream key.
nonisolated enum UploadStartupFailure: String, Error, Codable, Sendable {
    case recordingNotReady, contextChanged, cancelled, configuration
    case networkTimeout, dns, tls, connectTimeout, connectRejected, connectFailed
    case publishTimeout, publishRejected, publishFailed

    var message: String {
        switch self {
        case .recordingNotReady: "Local recording wasn’t ready for upload."
        case .contextChanged: "The recording session changed before upload could start."
        case .cancelled: "Upload startup was interrupted."
        case .configuration: "The RTMPS stream couldn’t be configured."
        case .networkTimeout: "The network connection to YouTube ingest timed out."
        case .dns: "The iPhone couldn’t resolve the YouTube ingest hostname."
        case .tls: "The secure connection to YouTube ingest failed."
        case .connectTimeout: "YouTube ingest didn’t answer the RTMP connection request in time."
        case .connectRejected: "YouTube ingest rejected the RTMP connection."
        case .connectFailed: "The RTMPS connection to YouTube ingest failed."
        case .publishTimeout: "YouTube ingest didn’t answer the publish request in time."
        case .publishRejected: "YouTube ingest rejected the publish request. Check the stream key and assignment in Studio."
        case .publishFailed: "The RTMPS publish request failed."
        }
    }

    static func connecting(_ error: any Error) -> Self {
        guard let error = error as? RTMPConnection.Error else { return .connectFailed }
        switch error {
        case .connectionTimedOut: return .networkTimeout
        case .requestTimedOut: return .connectTimeout
        case .requestFailed(let response):
            return response.status?.code == RTMPConnection.Code.connectRejected.rawValue ? .connectRejected : .connectFailed
        case .socketErrorOccurred(let error):
            switch error as? NWError {
            case .dns: return .dns
            case .tls: return .tls
            default: return .connectFailed
            }
        default: return .connectFailed
        }
    }

    static func publishing(_ error: any Error) -> Self {
        guard let error = error as? RTMPStream.Error else { return .publishFailed }
        switch error {
        case .requestTimedOut: return .publishTimeout
        case .requestFailed(let response):
            return response.status?.code == RTMPStream.Code.publishBadName.rawValue ? .publishRejected : .publishFailed
        default: return .publishFailed
        }
    }
}

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
        try await connect(endpoint: destination.endpoint, streamName: destination.streamName,
            profile: profile, canPublish: canPublish)
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Fixed local synthetic receiver only; never compiled into Release.
    func connectPrivateFixture(profile: SessionProfile) async throws {
        try await connect(endpoint: URL(string: "rtmps://localhost:19360/fixture")!,
            streamName: "synthetic", profile: profile, canPublish: { !Task.isCancelled })
    }
    #endif

    private func connect(endpoint: URL, streamName: String, profile: SessionProfile,
                         canPublish: @Sendable () -> Bool) async throws {
        guard !closed, stream == nil else { throw UploadStartupFailure.cancelled }
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
            guard !closed, !Task.isCancelled, canPublish() else { throw UploadStartupFailure.cancelled }
            do { _ = try await connection.connect(endpoint.absoluteString) }
            catch { throw UploadStartupFailure.connecting(error) }
            guard !closed, !Task.isCancelled, canPublish() else { throw UploadStartupFailure.cancelled }
            do { _ = try await stream.publish(streamName) }
            catch { throw UploadStartupFailure.publishing(error) }
            guard !closed, !Task.isCancelled else { throw UploadStartupFailure.cancelled }
        } catch {
            await close()
            throw Task.isCancelled ? UploadStartupFailure.cancelled :
                ((error as? UploadStartupFailure) ?? .configuration)
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
