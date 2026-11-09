import SwiftUI

struct BroadcastControlsView: View {
    let broadcast: BroadcastSession
    let media: MediaSession
    let selection: YouTubeEventSelection
    let authorization: YouTubeAuthorization
    var allowStart = true
    @State private var confirmingEnd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YouTube: " + broadcast.message).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("broadcastStatus")
            if broadcast.reconnectStatus == .exhausted {
                Button("Retry upload to same event") { broadcast.retryUpload() }
                    .frame(minHeight: 44)
            }
            if broadcast.reconnectStatus == .waiting || broadcast.reconnectStatus == .connecting {
                Button("Cancel upload recovery") { broadcast.cancelReconnect() }
                    .frame(minHeight: 44)
            }
            if broadcast.canResume {
                Button("Resume same event…") { broadcast.requestResumeConfirmation() }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("resumeBroadcast")
            }
            if allowStart && broadcast.canStart && broadcast.state != .ended {
                Button("Start recording and streaming", systemImage: "dot.radiowaves.left.and.right") {
                    broadcast.requestConfirmation(channel: selection.channel, event: selection.selected)
                }
                .frame(minHeight: 44)
                .buttonStyle(.borderedProminent)
                .disabled(selection.selected == nil || !media.broadcastCaptureReady || !media.broadcastOverlayReady ||
                          !(media.canRecord || media.hasStartedWriting))
                .accessibilityIdentifier("goLive")
            }
            if broadcast.isWorking && broadcast.state != .ending {
                Button("Cancel YouTube startup") { broadcast.cancelStartup() }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("cancelBroadcastStartup")
            }
            if broadcast.activeIntent != nil || broadcast.pendingRemote != nil {
                Button("End session", role: .destructive) { confirmingEnd = true }
                    .frame(minHeight: 44)
                    .disabled(broadcast.state == .ending)
                    .accessibilityIdentifier("endBroadcast")
            }
            if broadcast.state == .needsReconciliation {
                Button("Reconcile YouTube status") { broadcast.reconcile() }
                    .frame(minHeight: 44)
                    .disabled(broadcast.isWorking || broadcast.hasUnsettledMutation || !authorization.isAuthorized)
                    .accessibilityIdentifier("reconcileBroadcast")
                Link("Open YouTube Studio", destination: URL(string: "https://studio.youtube.com")!)
                    .frame(minHeight: 44)
            }
        }
            .confirmationDialog("Start recording and streaming?", isPresented: Binding(
                get: { broadcast.confirmation != nil },
                set: { if !$0 { broadcast.dismissConfirmation() } }), titleVisibility: .visible,
                presenting: broadcast.confirmation) { intent in
                    Button((intent.isResume ? "Resume — " : "Go Live — ") + intent.event.visibility) { broadcast.confirmStart(intent) }
                    Button("Cancel", role: .cancel) { broadcast.dismissConfirmation() }
                } message: { intent in
                    Text("Channel: \(intent.channel.title) (\(intent.channel.id))\nEvent: \(intent.event.title)\nVisibility: \(intent.event.visibility)\nProfile: \(intent.profile.label)\nThis starts local recording and uploads camera and microphone media to this event.")
                }
            .confirmationDialog("End session?", isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button("End session and local recording", role: .destructive) { broadcast.confirmEnd() }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let intent = broadcast.activeIntent {
                    Text("End \(intent.event.title) on \(intent.channel.title) (\(intent.event.visibility))? This ends the YouTube broadcast and stops local recording and capture. Upload and local capture will stop, even if YouTube completion cannot be confirmed.")
                } else if let pending = broadcast.pendingRemote {
                    Text("End event \(pending.eventID) on channel \(pending.channelID)? YouTube state will be read before any completion request. This ends the YouTube broadcast and stops local recording and capture, even if remote completion cannot be confirmed.")
                }
            }
    }

}
