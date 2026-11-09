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
            Text("YouTube").font(.headline)
            Text(authorization.message).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("youtubeAuthorizationStatus")
            Group {
                Link("Privacy policy", destination: URL(string: "https://github.com/smith3v/stream14/blob/main/docs/privacy.md")!)
                Link("stream14 service terms", destination: URL(string: "https://github.com/smith3v/stream14/blob/main/docs/terms.md")!)
                Link("YouTube Terms of Service", destination: URL(string: "https://www.youtube.com/t/terms")!)
                Link("Google Account access settings", destination: URL(string: "https://security.google.com/settings/security/permissions")!)
            }.frame(minHeight: 44, alignment: .leading)
            if !authorization.policyAccepted {
                Text("YouTube is optional. Read the privacy policy and service terms before connecting. Using YouTube features means agreeing to the YouTube Terms of Service. Local preview and recording remain available.")
                Button("Agree to privacy policy and YouTube terms") { authorization.acceptYouTubePolicy() }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("acceptYouTubePolicy")
            }
            if broadcastActive { Text("End the broadcast before changing YouTube accounts.").font(.caption) }
            Group {
                if authorization.isConfigured && authorization.policyAccepted {
                    if authorization.isAuthorized {
                        Button("Switch Google account") { connect() }
                        Button("Sign out on this iPhone") { authorization.signOut(broadcastActive: broadcastActive) }
                        Button("Revoke Google access", role: .destructive) { confirmingRevoke = true }
                    } else {
                        Button("Connect YouTube") { connect() }
                        Button("Restore saved connection") { Task { await authorization.restore(broadcastActive: broadcastActive) } }
                    }
                }
                Button("Delete saved YouTube data", role: .destructive) { confirmingDeletion = true }
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
        .confirmationDialog("Delete saved YouTube data?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
            Button("Delete saved YouTube data", role: .destructive) { authorization.deleteYouTubeData(broadcastActive: !broadcast.canDeleteYouTubeData) }
        } message: {
            Text("Sign out locally and delete saved channel, event and stream identifiers. This does not revoke Google access, end an event or delete YouTube media. A nonidentifying Studio-resolution guard blocks publishing until you explicitly resolve previous requests. Local recordings, recovery copies and overlay settings remain.")
        }
        .confirmationDialog("Have you resolved previous YouTube requests?", isPresented: $confirmingStudioResolution, titleVisibility: .visible) {
            Button("Confirm Studio resolution") { broadcast.confirmDeletedDataResolvedInStudio() }
        } message: {
            Text("In YouTube Studio, finish any previous live event and resolve pending stream creation/bindings. Only confirm after no previous request needs reconciliation. The app has deleted those identifiers and cannot check them for you. This action sends no YouTube request.")
        }
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
