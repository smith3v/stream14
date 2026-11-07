import SwiftUI
import UIKit

struct YouTubeConnectionView: View {
    let authorization: YouTubeAuthorization
    @State private var confirmingRevoke = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YouTube").font(.headline)
            Text(authorization.message).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("youtubeAuthorizationStatus")
            if authorization.isConfigured {
                if authorization.isAuthorized {
                    Button("Switch Google account") {
                        guard let presenter = presenter else { return }
                        Task { await authorization.connect(presenting: presenter) }
                    }
                    Button("Sign out on this iPhone") { authorization.signOut() }
                    Button("Revoke Google access", role: .destructive) { confirmingRevoke = true }
                } else {
                    Button("Connect YouTube") {
                        guard let presenter = presenter else { return }
                        Task { await authorization.connect(presenting: presenter) }
                    }
                    Button("Restore saved connection") { Task { await authorization.restore() } }
                }
            }
        }
        .disabled(authorization.isWorking)
        .confirmationDialog("Revoke stream14’s Google access?", isPresented: $confirmingRevoke,
                            titleVisibility: .visible) {
            Button("Revoke Google access", role: .destructive) { Task { await authorization.disconnect() } }
        } message: {
            Text("Disconnect this Google authorization. Local recordings and the saved overlay remain on this iPhone.")
        }
    }

    private var presenter: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = scenes.first(where: { $0.activationState == .foregroundActive })?.windows.first(where: \.isKeyWindow),
              var controller = window.rootViewController else { return nil }
        while let presented = controller.presentedViewController { controller = presented }
        return controller
    }
}
