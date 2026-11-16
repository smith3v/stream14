import SwiftUI
import UIKit

struct YouTubeConnectionView: View {
    let authorization: YouTubeAuthorization
    let broadcast: BroadcastSession
    var broadcastActive = false
    @State private var confirmingRevoke = false
    @State private var confirmingDeletion = false
    @State private var confirmingStudioResolution = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connect YouTube").font(.headline).accessibilityAddTraits(.isHeader)
            Text("Connect a Google account that can authorize your YouTube channel. Choose an upcoming event and control it from Stream14.")
                .font(.footnote)
            Text(authorization.message).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("youtubeAuthorizationStatus")
            Group {
                Link("Privacy policy", destination: URL(string: "https://stream14.app/privacy/")!)
                Link("stream14 service terms", destination: URL(string: "https://stream14.app/terms/")!)
                Link("YouTube Terms of Service", destination: URL(string: "https://www.youtube.com/t/terms")!)
                Link("Google Account access settings", destination: URL(string: "https://security.google.com/settings/security/permissions")!)
            }.frame(minHeight: 44, alignment: .leading)
            if !authorization.policyAccepted {
                Text("Read the privacy policy and service terms before connecting or streaming with a saved key. Using YouTube features means agreeing to the YouTube Terms of Service.")
                Button("Agree to privacy policy and YouTube terms") { authorization.acceptYouTubePolicy() }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("acceptYouTubePolicy")
            }
            if broadcastActive { Text("End the broadcast before changing YouTube accounts.").font(.caption) }
            Group {
                if authorization.isConfigured && authorization.policyAccepted {
                    if authorization.isAuthorized {
                        authorizationButton("Switch Google account")
                        Button("Sign out on this iPhone") { authorization.signOut(broadcastActive: broadcastActive) }
                        Button("Revoke Google access", role: .destructive) { confirmingRevoke = true }
                    } else {
                        authorizationButton("Connect YouTube")
                        Button("Restore saved connection") { Task { await authorization.restore(broadcastActive: broadcastActive) } }
                    }
                }
                Button("Delete saved YouTube API data", role: .destructive) { confirmingDeletion = true }
                    .disabled(!broadcast.canDeleteYouTubeData)
                if broadcast.requiresStudioResolution {
                    Text("Saved YouTube identifiers were removed. Previous requests may still exist in Studio; publishing stays blocked until you resolve them there.")
                    Link("Open YouTube Studio", destination: URL(string: "https://studio.youtube.com/")!)
                    Button("I resolved previous requests in Studio…") { confirmingStudioResolution = true }
                        .disabled(broadcast.journalUnavailable || broadcast.hasUnsettledMutation)
                }
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
            .disabled(authorization.isWorking || broadcastActive)
        }
        .confirmationDialog("Revoke stream14’s Google access?", isPresented: $confirmingRevoke,
                            titleVisibility: .visible) {
            Button("Revoke Google access", role: .destructive) { Task { await authorization.disconnect(broadcastActive: broadcastActive) } }
        } message: {
            Text("Revoke authorization and delete saved YouTube data on this iPhone. Resolve any previous event/stream requests in Studio before publishing again. Recordings and overlay settings remain.")
        }
        .confirmationDialog("Delete saved YouTube API data?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
            Button("Delete saved YouTube API data", role: .destructive) { authorization.deleteYouTubeData(broadcastActive: !broadcast.canDeleteYouTubeData) }
        } message: {
            Text("Sign out locally and delete saved channel, event and stream identifiers. This does not revoke Google access, end an event or delete YouTube media. A nonidentifying Studio-resolution guard blocks publishing until you explicitly resolve previous requests. Local recordings, recovery copies, overlay settings and your Studio stream key remain.")
        }
        .confirmationDialog("Have you resolved previous YouTube requests?", isPresented: $confirmingStudioResolution, titleVisibility: .visible) {
            Button("Confirm Studio resolution") { broadcast.confirmDeletedDataResolvedInStudio() }
        } message: {
            Text("In YouTube Studio, finish any previous live event and resolve pending stream creation/bindings. Only confirm after no previous request needs reconciliation. The app has deleted those identifiers and cannot check them for you. This action sends no YouTube request.")
        }
    }

    private func authorizationButton(_ title: LocalizedStringKey) -> some View {
        Button(action: connect) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    YouTubeBrandLogo()
                    Text(title)
                }
                VStack(spacing: 0) {
                    YouTubeBrandLogo()
                    Text(title)
                }
            }
            .multilineTextAlignment(.center)
        }
        .accessibilityLabel(Text(title))
    }

    private func connect() {
        guard let presenter else { return }
        Task { await authorization.connect(presenting: presenter, broadcastActive: broadcastActive) }
    }

    private var presenter: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = scenes.first(where: { $0.activationState == .foregroundActive })?.windows.first(where: \.isKeyWindow),
              var controller = window.rootViewController else { return nil }
        while let presented = controller.presentedViewController { controller = presented }
        return controller
    }
}
