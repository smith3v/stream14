import Foundation

/// Retry readiness belongs to one already-admitted ingestion context. Resource
/// identifiers and the validated nonsecret endpoint stay in RAM only. Stream
/// names, access tokens and other credentials are never copied into this value.
nonisolated struct RTMPSUploadContext: Equatable, Sendable,
    CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    enum Identity: Equatable, Sendable {
        case connectedEvent(channelID: String, eventID: String, streamID: String, authorizationGeneration: UInt64)
        case streamKey(sessionID: UUID)
    }

    let identity: Identity
    let profile: SessionProfile
    let endpoint: URL

    init(identity: Identity, profile: SessionProfile, endpoint: URL) {
        self.identity = identity
        self.profile = profile
        self.endpoint = endpoint
    }

    init?(_ prepared: PreparedYouTubeIngestion) {
        guard let channelID = prepared.broadcast.snippet?.channelId, !channelID.isEmpty else { return nil }
        self.init(identity: .connectedEvent(channelID: channelID, eventID: prepared.broadcast.id,
            streamID: prepared.streamID, authorizationGeneration: prepared.generation),
            profile: prepared.profile, endpoint: prepared.destination.endpoint)
    }
    var description: String { "RTMPS upload context (redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: ["context": "<redacted>"]) }
}

nonisolated struct RTMPSUploadAffinity: Sendable {
    private(set) var context: RTMPSUploadContext?
    var hasAdmittedTransport: Bool { context != nil }

    func permits(_ candidate: RTMPSUploadContext) -> Bool {
        context == nil || context == candidate
    }
    @discardableResult
    mutating func admit(_ candidate: RTMPSUploadContext) -> Bool {
        guard permits(candidate) else { return false }
        if context == nil { context = candidate }
        return true
    }
    mutating func beginRecordingSession(keepingTransportEpoch: Bool) {
        // A file-only restart must not erase the already admitted context.
        if !keepingTransportEpoch { context = nil }
    }
    mutating func endCaptureSession() { context = nil }
}

/// An admitted RTMPS target carries a credential and the nonsecret retry identity.
nonisolated struct RTMPSUpload: Sendable {
    let context: RTMPSUploadContext
    let destination: YouTubeIngestionDestination
    var profile: SessionProfile { context.profile }
    var usesStreamKey: Bool {
        if case .streamKey = context.identity { return true }
        return false
    }

    init?(_ prepared: PreparedYouTubeIngestion) {
        guard let context = RTMPSUploadContext(prepared) else { return nil }
        self.context = context
        destination = prepared.destination
    }

    init(streamKey: SavedYouTubeStreamKey, profile: SessionProfile, sessionID: UUID) {
        destination = streamKey.destination
        context = RTMPSUploadContext(identity: .streamKey(sessionID: sessionID), profile: profile,
            endpoint: destination.endpoint)
    }
}
