#if DEBUG
import Foundation

/// Deterministic UI states, compiled out of Release. All service and media
/// closures fail closed; even confirming a fixture cannot publish or capture.
@MainActor enum InterfaceFixture {
    static func make(_ name: String) -> (authorization: YouTubeAuthorization, media: MediaSession,
                                       broadcast: BroadcastSession, events: YouTubeEventSelection) {
        let authorization = name == "policy-unaccepted" ?
            YouTubeAuthorization(driver: nil, configured: true) : YouTubeAuthorization.interfaceFixture()
        let media = MediaSession(readOverlayURL: { "" }, saveOverlayURL: { _ in },
            profile: .fullHD, persistProfile: { _ in }, authorizeCapture: { false })
        media.installInterfaceFixture(name == "policy-unaccepted" ? "idle" : name)
        let client = YouTubeClient(token: { _ in "invented-fixture-token" }, current: { _ in true },
            send: { _ in throw YouTubeReadError.unavailable })
        let events = YouTubeEventSelection(authorization: authorization, client: client)
        let channel = YouTubeChannel(id: "fixture-channel", snippet: .init(title: "Fixture channel"))
        let event = YouTubeBroadcast(id: "fixture-event", snippet: .init(channelId: channel.id,
            title: "Fixture scheduled match", scheduledStartTime: "2026-11-08T20:00:00Z", isDefaultBroadcast: false),
            status: .init(lifeCycleStatus: "ready", privacyStatus: "unlisted"),
            contentDetails: .init(boundStreamId: "fixture-stream", enableAutoStart: false, enableAutoStop: false))
        events.installInterfaceFixture(channel: channel, event: event)
        if name == "no-event" { events.invalidate() }
        let boundary = BroadcastMedia(snapshot: {
            BroadcastMedia.Snapshot(captureReady: media.broadcastCaptureReady, canRecord: media.canRecord,
                writerStarted: false, isRecording: media.isRecording, profile: media.profile, overlayURL: "",
                overlayReady: media.broadcastOverlayReady, uploadFailed: false,
                canPrepareNextSession: media.canPrepareNextSession)
        }, record: {}, startUpload: { _ in throw CancellationError() }, stopUpload: {}, stopAll: {},
            lockConfiguration: { media.broadcastConfigurationLocked = $0 })
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("interface-fixture-" + UUID().uuidString)
        let store = PendingRemoteBroadcastStore(url: directory.appendingPathComponent("remote.json"))
        let broadcast = BroadcastSession(authorization: authorization, client: client,
            binding: YouTubeBinding(client: client, store: PendingBroadcastIntentStore(directory: directory.appendingPathComponent("binding"))), media: boundary, store: store)
        broadcast.installInterfaceFixture(name, intent: BroadcastIntent(id: UUID(), generation: authorization.generation,
            channel: channel, event: event, profile: .fullHD, overlayURL: ""))
        return (authorization, media, broadcast, events)
    }
}
#endif
