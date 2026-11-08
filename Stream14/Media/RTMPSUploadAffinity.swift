import Foundation

/// Retry readiness belongs to one already-admitted ingestion context. Resource
/// identifiers and the validated nonsecret endpoint stay in RAM only. Stream
/// names, access tokens and other credentials are never copied into this value.
nonisolated struct RTMPSUploadContext: Equatable, Sendable,
    CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let channelID: String
    let eventID: String
    let streamID: String
    let profile: SessionProfile
    let authorizationGeneration: UInt64
    let endpoint: URL

    init?(_ prepared: PreparedYouTubeIngestion) {
        guard let channelID = prepared.broadcast.snippet?.channelId, !channelID.isEmpty else { return nil }
        self.channelID = channelID
        eventID = prepared.broadcast.id
        streamID = prepared.streamID
        profile = prepared.profile
        authorizationGeneration = prepared.generation
        endpoint = prepared.destination.endpoint
    }
    var description: String { "RTMPS upload context (redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: ["context": "<redacted>"]) }
}

nonisolated struct RTMPSUploadAffinity: Sendable {
    private(set) var context: RTMPSUploadContext?
    var hasAdmittedTransport: Bool { context != nil }

    func permits(_ prepared: PreparedYouTubeIngestion) -> Bool {
        guard let candidate = RTMPSUploadContext(prepared) else { return false }
        return context == nil || context == candidate
    }
    @discardableResult
    mutating func admit(_ prepared: PreparedYouTubeIngestion) -> Bool {
        guard permits(prepared), let candidate = RTMPSUploadContext(prepared) else { return false }
        if context == nil { context = candidate }
        return true
    }
    mutating func beginRecordingSession(keepingTransportEpoch: Bool) {
        // A file-only restart must not erase the already admitted context.
        if !keepingTransportEpoch { context = nil }
    }
    mutating func endCaptureSession() { context = nil }
}
