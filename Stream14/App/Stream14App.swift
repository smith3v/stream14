import SwiftUI

@main
struct Stream14App: App {
    @State private var authorization: YouTubeAuthorization
    @State private var media: MediaSession
    @State private var broadcast: BroadcastSession
    @State private var youtubeEvents: YouTubeEventSelection

    init() {
        RTMPPrivacy.configure()
        #if DEBUG
        // Hosted camera smoke must not construct Google's SDK/Keychain driver,
        // even when a real public client ID is present in the signed candidate.
        let authorization = ProcessInfo.processInfo.environment["STREAM14_SHORT_DEVICE_SMOKE"] == "1" ?
            YouTubeAuthorization(driver: nil, configured: false) : YouTubeAuthorization()
        #else
        let authorization = YouTubeAuthorization()
        #endif
        let media = Self.makeMediaSession()
        _media = State(initialValue: media)
        _broadcast = State(initialValue: BroadcastSession(authorization: authorization, media: media))
        _authorization = State(initialValue: authorization)
        _youtubeEvents = State(initialValue: YouTubeEventSelection(authorization: authorization))
    }

    /// The hosted smoke owns a separate no-network session/window. Never read
    /// the owner's saved overlay or request capture in the root test host.
    private static func makeMediaSession() -> MediaSession {
        #if DEBUG
        if ProcessInfo.processInfo.environment["STREAM14_SHORT_DEVICE_SMOKE"] == "1" {
            return MediaSession(readOverlayURL: { "" },
                saveOverlayURL: { _ in throw CocoaError(.featureUnsupported) },
                profile: .fullHD, persistProfile: { _ in }, authorizeCapture: { false })
        }
        #endif
        return MediaSession(profile: SessionProfile.saved())
    }

    var body: some Scene {
        WindowGroup {
            SetupView(authorization: authorization, youtubeEvents: youtubeEvents, experiment: media, broadcast: broadcast)
                .onOpenURL { authorization.handle($0) }
                .onChange(of: authorization.generation) {
                    youtubeEvents.accountChanged()
                    broadcast.accountChanged()
                }
        }
    }
}
