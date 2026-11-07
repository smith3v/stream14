import SwiftUI

@main
struct Stream14App: App {
    @State private var authorization: YouTubeAuthorization
    @State private var youtubeEvents: YouTubeEventSelection

    init() {
        let authorization = YouTubeAuthorization()
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
