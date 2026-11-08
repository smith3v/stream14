import SwiftUI

@main
struct Stream14App: App {
    @State private var authorization: YouTubeAuthorization
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
        _authorization = State(initialValue: authorization)
        _youtubeEvents = State(initialValue: YouTubeEventSelection(authorization: authorization))
    }

    var body: some Scene {
        WindowGroup {
            SetupView(authorization: authorization, youtubeEvents: youtubeEvents)
                .onOpenURL { authorization.handle($0) }
                .onChange(of: authorization.generation) { youtubeEvents.accountChanged() }
        }
    }
}
