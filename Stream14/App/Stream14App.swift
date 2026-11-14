import SwiftUI

@main
struct Stream14App: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var authorization: YouTubeAuthorization
    @State private var media: MediaSession
    @State private var broadcast: BroadcastSession
    @State private var youtubeEvents: YouTubeEventSelection

    init() {
        RTMPPrivacy.configure()
        #if DEBUG
        // Hosted camera smoke must not construct Google's SDK/Keychain driver,
        // even when a real public client ID is present in the signed candidate.
        if let fixture = ProcessInfo.processInfo.environment["STREAM14_INTERFACE_FIXTURE"] {
            let models = InterfaceFixture.make(fixture)
            _authorization = State(initialValue: models.authorization)
            _media = State(initialValue: models.media)
            _broadcast = State(initialValue: models.broadcast)
            _youtubeEvents = State(initialValue: models.events)
            return
        }
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
        return MediaSession(profile: SessionProfile.saved(), interfaceOrientation: {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            // Permission prompts can leave the app's scene temporarily inactive.
            let scene = scenes.first { $0.activationState == .foregroundActive } ??
                scenes.first { $0.activationState == .foregroundInactive }
            return scene?.effectiveGeometry.interfaceOrientation ?? .unknown
        })
    }

    #if DEBUG
    /// Appearance is overridden only for isolated, fail-closed interface fixtures.
    private var interfaceFixtureColorScheme: ColorScheme? {
        let environment = ProcessInfo.processInfo.environment
        guard environment["STREAM14_INTERFACE_FIXTURE"] != nil else { return nil }
        switch environment["STREAM14_INTERFACE_COLOR_SCHEME"] {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            SetupView(authorization: authorization, youtubeEvents: youtubeEvents, experiment: media, broadcast: broadcast)
                #if DEBUG
                .preferredColorScheme(interfaceFixtureColorScheme)
                #endif
                .onOpenURL { authorization.handle($0) }
                .onChange(of: scenePhase) {
                    if scenePhase == .active { broadcast.expireStoredYouTubeData() }
                }
                .onChange(of: authorization.generation) {
                    youtubeEvents.accountChanged()
                    broadcast.accountChanged()
                }
        }
    }
}
