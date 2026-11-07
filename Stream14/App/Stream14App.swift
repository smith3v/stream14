import SwiftUI

@main
struct Stream14App: App {
    @State private var authorization = YouTubeAuthorization()

    var body: some Scene {
        WindowGroup {
            SetupView(authorization: authorization)
                .onOpenURL { authorization.handle($0) }
        }
    }
}
