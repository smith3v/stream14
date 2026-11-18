import SwiftUI

struct BroadcastControlsView: View {
    let broadcast: BroadcastSession
    let media: MediaSession
    let selection: YouTubeEventSelection
    let authorization: YouTubeAuthorization
    var allowStart = true
    @State private var confirmingEnd = false
    @State private var confirmingStreamingStop = false
    @State private var confirmingRetry = false

    private var usesStreamKey: Bool { broadcast.usesStreamKey }
    private var readyToStart: Bool {
        media.canConfirmLandscapeStart && media.broadcastCaptureReady && media.broadcastOverlayReady &&
            (media.canRecord || media.hasStartedWriting)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if usesStreamKey {
                if let message = broadcast.streamKeyMessage {
                    Text(message).accessibilityIdentifier("broadcastStatus")
                }
                if broadcast.streamKeyUploadFailed && !broadcast.isWorking {
                    streamKeyRecovery
                }
            } else {
                Text("YouTube: " + broadcast.message).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("broadcastStatus")
            }
            if broadcast.reconnectStatus == .exhausted {
                Button("Retry upload to same event") { broadcast.retryUpload() }
                    .frame(minHeight: 44)
            }
            if broadcast.canResume {
                Button("Resume same event…") { broadcast.requestResumeConfirmation() }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("resumeBroadcast")
            }
            if allowStart && media.previewNeedsLandscape {
                Text("Turn your iPhone to landscape to record or stream.")
                    .font(.footnote).accessibilityIdentifier("landscapeReadiness")
            }
            if allowStart && readyToStart {
                if usesStreamKey && broadcast.canStartStreamKey {
                    streamKeyStartButton
                } else if broadcast.canStart, let event = selection.selected, let channel = selection.channel {
                    Button("Start recording and streaming", systemImage: "dot.radiowaves.left.and.right") {
                        broadcast.requestConfirmation(channel: channel, event: event)
                    }
                    .buttonStyle(SessionActionButtonStyle.start)
                    .accessibilityIdentifier("goLive")
                }
            }
            if broadcast.isStartingUpload && !broadcast.canStopStreaming && broadcast.activeStreamKey == nil {
                Button("Cancel YouTube startup") { broadcast.cancelStartup() }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("cancelBroadcastStartup")
            }
            if broadcast.showsEndSession {
                Button("End session", systemImage: "stop.circle", role: .destructive) { confirmingEnd = true }
                    .buttonStyle(SessionActionButtonStyle.stop)
                    .disabled(!broadcast.canEnd)
                    .accessibilityIdentifier("endBroadcast")
            }
            if broadcast.hasRemoteEventToFinish {
                Button("Finish YouTube event", systemImage: "stop.circle", role: .destructive) { confirmingEnd = true }
                    .buttonStyle(SessionActionButtonStyle.stop)
                    .accessibilityIdentifier("finishYouTubeEvent")
            }
            if broadcast.state == .needsReconciliation {
                Button("Reconcile YouTube status") { broadcast.reconcile() }
                    .frame(minHeight: 44)
                    .disabled(broadcast.isWorking || broadcast.hasUnsettledMutation || !authorization.isAuthorized)
                    .accessibilityIdentifier("reconcileBroadcast")
                Link("Open YouTube Studio", destination: URL(string: "https://studio.youtube.com")!)
                    .frame(minHeight: 44)
            }
            if broadcast.canStopStreaming {
                Button("Stop streaming only", systemImage: "stop.circle", role: .destructive) { confirmingStreamingStop = true }
                    .buttonStyle(SessionActionButtonStyle.stop)
                    .accessibilityIdentifier("stopStreaming")
                    .alert("Stop streaming only?", isPresented: $confirmingStreamingStop) {
                        Button("Stop upload", role: .destructive) { broadcast.confirmStopStreaming() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        if usesStreamKey {
                            Text("Stop sending video to YouTube. Local recording continues if active. An event with Auto-stop can end when upload stops.")
                        } else if media.isRecording {
                            Text("Stop sending video to YouTube. Local recording continues. Stopping the recording later will finish the YouTube event.")
                        } else {
                            Text("Stop sending video to YouTube and close the camera to finish this session and the YouTube event. If completion cannot be confirmed, check YouTube Studio and reconcile its status.")
                        }
                    }
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
            .alert(broadcast.hasRemoteEventToFinish ? "Finish YouTube event?" : "End session?", isPresented: $confirmingEnd) {
                Button(broadcast.hasRemoteEventToFinish ? "Finish YouTube event" : "End session and local recording",
                       role: .destructive) { broadcast.confirmEnd() }
                Button("Cancel", role: .cancel) {}
            } message: {
                if broadcast.activeStreamKey != nil {
                    Text("Stop sending video to YouTube and finalize local recording? YouTube handles ending the event using Auto-stop. Check its status in YouTube Studio.")
                } else if let intent = broadcast.activeIntent {
                    Text("End \(intent.event.title) on \(intent.channel.title) (\(intent.event.visibility))? This ends the YouTube broadcast and stops local recording and capture. Upload and local capture will stop, even if YouTube completion cannot be confirmed.")
                } else if let pending = broadcast.pendingRemote {
                    Text("End event \(pending.eventID) on channel \(pending.channelID)? YouTube state will be read before any completion request. This ends the YouTube broadcast and stops local recording and capture, even if remote completion cannot be confirmed.")
                }
            }
    }

    private var streamKeyStartButton: some View {
        Button("Start recording and streaming", systemImage: "dot.radiowaves.left.and.right") {
            broadcast.requestStreamKeyConfirmation()
        }
        .buttonStyle(SessionActionButtonStyle.start)
        .accessibilityIdentifier("goLive")
        .confirmationDialog("Start recording and streaming?", isPresented: Binding(
            get: { broadcast.streamKeyConfirmation != nil },
            set: { if !$0 { broadcast.dismissStreamKeyConfirmation() } }), titleVisibility: .visible,
            presenting: broadcast.streamKeyConfirmation) { intent in
                Button("Start upload") { broadcast.confirmStreamKeyStart(intent) }
                Button("Cancel", role: .cancel) { broadcast.dismissStreamKeyConfirmation() }
            } message: { intent in
                Text("Destination: Saved YouTube stream key\nQuality: \(intent.upload.profile.label)\nSending camera and microphone media can start the event assigned to this key in YouTube Studio. Confirm it’s the intended event before starting.")
            }
    }

    private var streamKeyRecovery: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Auto-stop may end the event during an outage. Before retrying, use YouTube Studio on another device to check the event assigned to this key while Stream14 keeps recording.")
                .font(.footnote)
            Button("Retry upload…") { confirmingRetry = true }
                .frame(minHeight: 44)
                .disabled(!broadcast.canRetryStreamKeyUpload)
                .confirmationDialog("Retry upload?", isPresented: $confirmingRetry, titleVisibility: .visible) {
                    Button("Retry upload") { broadcast.confirmStreamKeyRetry() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Check Studio before sending again with the saved key. If Auto-stop ended the event, reconnecting may fail or start another prepared event assigned to this key.")
                }
        }
    }
}
