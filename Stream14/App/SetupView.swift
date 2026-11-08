import AVKit
import HaishinKit
import SwiftUI

struct SetupView: View {
    let authorization: YouTubeAuthorization
    let youtubeEvents: YouTubeEventSelection
    let experiment: MediaSession
    let broadcast: BroadcastSession
    private enum Destination: Hashable { case preparation, session, recordings }
    @State private var destination = Destination.preparation
    @State private var pendingDeletion: ExperimentSample?
    @State private var playback: PlaybackSelection?
    @State private var showingNotices = false
    @State private var showingLensChoices = false
    @State private var showingProfileChoices = false
    @State private var showingOverlayTest = false
    @State private var overlayURLDraft = ""
    @State private var zoomDraft = 1.0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .top) {
            // Keep WebKit attached at a nonzero size for snapshots, covered by
            // the opaque scroll surface so it takes no separate layout space.
            AttachedOverlayView(renderer: experiment.renderer)
                .frame(height: 60)
                .accessibilityHidden(true)
            TabView(selection: $destination) {
                Tab("Preparation", systemImage: "checklist", value: Destination.preparation) {
                    if destination == .preparation { navigationScreen(preparationScreen) }
                }
                Tab("Session", systemImage: "video", value: Destination.session) {
                    if destination == .session { navigationScreen(sessionScreen) }
                }
                Tab("Recordings", systemImage: "film.stack", value: Destination.recordings) {
                    if destination == .recordings { navigationScreen(recordingsScreen) }
                }
            }
            .background(Color(uiColor: .systemBackground))
            .buttonStyle(.bordered)
            .tint(Color.primary)
            .controlSize(.large)
        }
            .alert("Delete this recording?", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }),
                presenting: pendingDeletion) { sample in
                    Button("Delete recording", role: .destructive) {
                        experiment.deleteSample(sample)
                        pendingDeletion = nil
                    }
                    Button("Cancel", role: .cancel) { pendingDeletion = nil }
                } message: { sample in
                    Text("Permanently remove the recording from \(sample.created.formatted(date: .abbreviated, time: .standard)) and all its recovery copies and metadata from this iPhone? This cannot be undone. Copies already exported to Files are kept.")
                }
            .sheet(item: $playback) { selection in
                SamplePlayback(url: selection.url)
            }
            .sheet(isPresented: $showingOverlayTest) {
                NavigationStack {
                    Form {
                        if !experiment.canEditOverlayURL { Text("Overlay URL is locked while the session is active or finalizing. Reload and manual visibility remain available in Session.") }
                        TextField("HTTPS overlay URL", text: $overlayURLDraft)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL).textInputAutocapitalization(.never)
                            .autocorrectionDisabled().privacySensitive()
                            .disabled(!experiment.canEditOverlayURL)
                            .accessibilityLabel("HTTPS overlay URL").accessibilityIdentifier("overlayURL")
                        Button("Apply URL") {
                            if experiment.applyOverlayURL(overlayURLDraft) {
                                overlayURLDraft = experiment.overlayURL
                            }
                        }
                        .disabled(!experiment.canEditOverlayURL)
                        .accessibilityIdentifier("applyOverlayURL")
                        Button("Use reference URL") { overlayURLDraft = "https://heren14-overlay.smith3v.com/overlay.html" }
                            .disabled(!experiment.canEditOverlayURL)
                        Text(experiment.urlMessage)
                        Text("Apply saves this URL securely and starts the overlay automatically while the app is active. Apply an empty URL to disable it completely. Closing without applying discards edits. Source document access does not verify a separate scoring backend.")
                    }
                    .navigationTitle("Overlay")
                    .toolbar {
                        Button { showingOverlayTest = false } label: {
                            Image(systemName: "xmark").frame(width: 44, height: 44)
                        }.accessibilityLabel("Close overlay settings")
                    }
                }
            }
            .sheet(isPresented: $showingNotices) {
                NavigationStack {
                    ScrollView { Text(notices).font(.footnote).padding() }
                        .navigationTitle("Third-party notices")
                        .toolbar { Button("Done") { showingNotices = false } }
                }
            }
            .task {
                guard !runsIsolatedMediaHarness else { return }
                experiment.setOverlayForeground(scenePhase != .background)
                if scenePhase == .active { broadcast.foregroundReturned() }
                while !Task.isCancelled {
                    experiment.reconcileOverlay()
                    do { try await Task.sleep(for: .seconds(1)) } catch { break }
                }
                experiment.setOverlayForeground(false)
            }
            .onChange(of: experiment.cameraZoom.value) { _, value in zoomDraft = value }
            .onChange(of: scenePhase) { _, phase in
                guard !runsIsolatedMediaHarness else { return }
                if phase == .active {
                    experiment.setOverlayForeground(true)
                    broadcast.foregroundReturned()
                }
                if phase == .background {
                    experiment.setOverlayForeground(false)
                    experiment.interrupt(.background)
                }
            }
    }

    private func navigationScreen<Content: View>(_ content: Content) -> some View {
        NavigationStack {
            GeometryReader { bounds in
                content
                    .frame(width: bounds.size.width, height: bounds.size.height)
                    .clipped()
            }
                .navigationTitle("stream14")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button {
                        overlayURLDraft = experiment.overlayURL
                        showingOverlayTest = true
                    } label: {
                        Image(systemName: "globe").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Overlay settings")
                    .accessibilityIdentifier("testWebOverlay")
                }
        }
    }

    private var preparationScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Prepare your session").font(.headline).accessibilityIdentifier("setupStatus")
                backupFailureWarning
                Text("Record locally without Google, or choose a scheduled YouTube event before confirming Go Live. Keep the phone in landscape with the rear camera upright.")
                    .accessibilityIdentifier("setupExplanation")
                profileControls
                Text(experiment.broadcastCaptureReady ? "Camera and microphone: ready" : "Camera and microphone: not ready")
                Text(experiment.message).font(.footnote)
                Text("Input: " + experiment.audioRoute)
                overlayControls
                Button("Open session", systemImage: "video") { destination = .session }
                    .frame(minHeight: 44).accessibilityIdentifier("openSession")
                YouTubeConnectionView(authorization: authorization, broadcastActive: broadcast.requiresEndFirst)
                YouTubeEventsView(selection: youtubeEvents).disabled(broadcast.locksSelection)
                if destination == .preparation { broadcastControls }
                Text("Opening settings or choosing an event does not publish. Go Live requires camera readiness, a healthy or explicitly disabled overlay, and confirmation of the channel, event, visibility and profile.")
                    .font(.footnote)
                DisclosureGroup("Session help") {
                    Text("Open Session to rehearse, mute the microphone or record without YouTube. A configured overlay must recover or be explicitly disabled before Go Live. Upload failure leaves a healthy recording running. Backgrounding stops capture; reopen the camera and explicitly review Resume for the same event. If YouTube status is unknown, reconcile or inspect Studio before retrying End.")
                }
                footerLayout { footerLinks }
            }.padding()
        }
    }

    private var sessionScreen: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height && !dynamicTypeSize.isAccessibilitySize
            if wide {
                HStack(alignment: .top, spacing: 12) {
                    previewPanel(width: max(1, geometry.size.width - max(260, geometry.size.width * 0.4) - 28), maximumHeight: geometry.size.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    ScrollView { sessionControls.padding(.trailing) }
                        .frame(width: max(260, geometry.size.width * 0.4))
                }.padding(.leading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        previewPanel(width: max(1, geometry.size.width - 32))
                        sessionControls
                    }.padding()
                }
            }
        }
    }

    private func previewPanel(width: CGFloat, maximumHeight: CGFloat? = nil) -> some View {
        let fittedWidth = min(width, (maximumHeight ?? .greatestFiniteMagnitude) * 16.0 / 9.0)
        return VStack(alignment: .leading, spacing: 8) {
            if experiment.phase != .idle {
                ExperimentPreview(view: experiment.preview)
                    .frame(width: fittedWidth, height: fittedWidth * 9.0 / 16.0)
                    .background(.black)
                    .accessibilityLabel("Composed camera preview with web overlay")
                    .accessibilityIdentifier("cameraPreview")
                    .clipped()

            }
            if experiment.phase == .idle {
                ContentUnavailableView("Camera closed", systemImage: "video.slash", description: Text("Open the camera to rehearse or record. This does not publish to YouTube."))
            }
        }
    }

    @ViewBuilder private var lensControls: some View {
        if experiment.phase != .idle && !experiment.availableLenses.isEmpty {
            Button {
                showingLensChoices = true
            } label: {
                Label(experiment.selectedLens.buttonLabel, systemImage: "camera")
                    .frame(minHeight: 44)
            }
            .controlSize(.small)
            .disabled(!experiment.canSelectLens)
            .accessibilityLabel("Rear camera lens")
            .accessibilityHint("Choose a rear lens before recording. Selection is locked while recording or finalizing.")
            .accessibilityValue(experiment.selectedLens.label)
            .accessibilityIdentifier("cameraLensSelector")
            .confirmationDialog("Choose rear camera", isPresented: $showingLensChoices,
                                titleVisibility: .visible) {
                ForEach(experiment.availableLenses) { lens in
                    Button(lens.label) {
                        Task { await experiment.selectLens(lens) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Current lens: " + experiment.selectedLens.label)
            }
        }
    }

    private var sessionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session").font(.headline)
            backupFailureWarning
            if let intent = broadcast.activeIntent ?? broadcast.confirmation {
                Text("Channel: " + intent.channel.title)
                Text("Event: " + intent.event.title)
                Text("Visibility: " + intent.event.visibility)
                Text("Profile: " + intent.profile.label)
            }
            Text("Recording: " + experiment.message)
            if !experiment.qualificationWarning.isEmpty {
                Text(experiment.qualificationWarning)
                    .font(.footnote).fixedSize(horizontal: false, vertical: true)
            }
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("mediaStatus")
            if let started = experiment.startedAt {
                Text(started, style: .timer).monospacedDigit().accessibilityLabel("Recording duration")
            }
            if !experiment.thermalWarning.isEmpty {
                Text(experiment.thermalWarning).accessibilityLabel("Thermal warning: " + experiment.thermalWarning)
            }
            cameraActions
            lensControls
            mediaControls
            overlayControls
            if destination == .session { broadcastControls }
        }
    }

    @ViewBuilder private var cameraActions: some View {
        if experiment.phase == .idle {
            Button("Open camera", systemImage: "camera") { Task { await experiment.openPreview() } }
                .frame(minHeight: 44).accessibilityIdentifier("openExperiment")
        } else {
            Button(experiment.isRecording ? "Stop recording" : "Record",
                   systemImage: experiment.isRecording ? "stop.circle" : "record.circle") {
                Task {
                    if experiment.isRecording { await experiment.stopRecording() }
                    else { await experiment.record() }
                }
            }
            .frame(minHeight: 44)
            .disabled(experiment.isRecording ? !experiment.canAdjustMedia : !experiment.canRecord)
            .accessibilityIdentifier("recordSample")
            Button("Close camera", systemImage: "xmark.circle") { experiment.requestStop() }
                .frame(minHeight: 44)
                .disabled(experiment.phase == .stopping || broadcast.requiresEndFirst)
        }
    }

    private var overlayControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overlay: " + experiment.renderer.status).font(.caption)
                .accessibilityIdentifier("overlayStatus")
            Button {
                experiment.renderer.setManuallyHidden(!experiment.renderer.health.manuallyHidden)
            } label: {
                Label(experiment.renderer.health.manuallyHidden ? "Show overlay" : "Hide overlay manually",
                      systemImage: experiment.renderer.health.manuallyHidden ? "eye" : "eye.slash")
                    .frame(minHeight: 44)
            }
            .accessibilityLabel("Manual overlay visibility")
            .accessibilityValue(experiment.renderer.health.manuallyHidden ? "Hidden" : "Shown")
            .accessibilityIdentifier("manualOverlayVisibility")
            if !experiment.overlayURL.isEmpty {
                Button("Reload overlay", systemImage: "arrow.clockwise") { experiment.renderer.reload() }
                    .frame(minHeight: 44).accessibilityIdentifier("reloadOverlay")
            }
        }
    }

    private var broadcastControls: some View {
        BroadcastControlsView(broadcast: broadcast, media: experiment, selection: youtubeEvents, authorization: authorization)
    }

    @ViewBuilder private var backupFailureWarning: some View {
        if !experiment.backupWarning.isEmpty {
            Text(experiment.backupWarning)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("backupWarning")
        }
    }

    private var recordingsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recordings").font(.headline)
                backupFailureWarning
                if !experiment.recordingsMessage.isEmpty {
                    Text(experiment.recordingsMessage).accessibilityIdentifier("recordingsStatus")
                }
                if experiment.savedSamples.isEmpty { Text("No recordings on this iPhone.") }
                ForEach(experiment.savedSamples) { sample in
                    RecordingRow(sample: sample, canDelete: experiment.canDeleteSamples,
                                 play: { playback = PlaybackSelection(url: $0) },
                                 delete: { pendingDeletion = sample },
                                 recovering: experiment.recoveringSampleID == sample.id,
                                 recover: { Task { await experiment.recoverSample(sample) } },
                                 deleteRecovery: { experiment.deleteRecovery($0, from: sample) })
                    Divider()
                }
                Text("Export to keep a copy outside the app. Deleting the app removes its local recordings.").font(.footnote)
                Text("Original H.264/AAC MP4 files. Pending and failed recordings are retained for review.").font(.footnote)
            }.padding()
        }
    }

    @ViewBuilder private var profileControls: some View {
                    Button { showingProfileChoices = true } label: {
                        Label(experiment.profile.label, systemImage: "video")
                            .frame(minHeight: 44)
                    }
                    .disabled(!experiment.canSelectProfile)
                    .accessibilityLabel("Session profile")
                    .accessibilityValue(experiment.profile.label)
                    .accessibilityIdentifier("sessionProfile")
                    .confirmationDialog("Session profile", isPresented: $showingProfileChoices, titleVisibility: .visible) {
                        ForEach(SessionProfile.allCases) { profile in
                            Button(profile.label) { experiment.selectProfile(profile) }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                    if !experiment.canSelectProfile {
                        Text("Close the camera to change the session profile.").font(.caption)
                    }
    }

    @ViewBuilder private var mediaControls: some View {
                    if experiment.phase == .preview || experiment.phase == .recording {
                        Button {
                            Task { await experiment.setMicrophoneMuted(!experiment.microphoneMuted) }
                        } label: {
                            Label(experiment.microphoneMuted ? "Unmute microphone" : "Mute microphone",
                                  systemImage: experiment.microphoneMuted ? "mic.slash" : "mic")
                                .frame(minHeight: 44)
                        }
                        .disabled(!experiment.canAdjustMedia)
                        .accessibilityValue(experiment.microphoneMuted ? "Muted" : "On")
                        .accessibilityIdentifier("microphoneMute")
                        ProgressView(value: experiment.microphoneLevel) {
                            Text(experiment.microphoneMuted ? "Microphone muted" : "Microphone level")
                        }
                        .accessibilityValue(experiment.microphoneMuted ? "Muted" : "\(Int(experiment.microphoneLevel * 100)) percent")
                        Text("Input: " + experiment.audioRoute).font(.caption)
                        if experiment.cameraZoom.maximum > experiment.cameraZoom.minimum {
                            Slider(value: $zoomDraft,
                                   in: experiment.cameraZoom.minimum...experiment.cameraZoom.maximum,
                                   onEditingChanged: { editing in
                                if !editing { Task { await experiment.setCameraZoom(zoomDraft) } }
                            }) { Text("Camera zoom") }
                            .frame(minHeight: 44)
                            .disabled(!experiment.canAdjustMedia)
                            .accessibilityIdentifier("cameraZoom")
                            .accessibilityValue("\(experiment.cameraZoom.value.formatted(.number.precision(.fractionLength(1)))) times")
                            .accessibilityAdjustableAction(adjustZoom)
                            Text("Zoom: \(experiment.cameraZoom.value.formatted(.number.precision(.fractionLength(1))))×")
                                .font(.caption)
                        }
                    }
    }

    private func adjustZoom(_ direction: AccessibilityAdjustmentDirection) {
        let step: Double
        switch direction {
        case .increment: step = 0.1
        case .decrement: step = -0.1
        @unknown default: return
        }
        let value = experiment.cameraZoom.value + step
        Task { await experiment.setCameraZoom(value) }
    }

    private static var runsShortPhoneSmoke: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["STREAM14_SHORT_DEVICE_SMOKE"] == "1"
        #else
        false
        #endif
    }

    /// The opt-in hosted media test supplies its own session/window. Do not run
    /// the owner's saved browser alongside it; Release never uses this test hook.
    private var runsIsolatedMediaHarness: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["STREAM14_OVERLAY_RECOVERY_DEVICE"] == "1" ||
        Self.runsShortPhoneSmoke ||
        ProcessInfo.processInfo.environment["STREAM14_INTERFACE_FIXTURE"] != nil
        #else
        false
        #endif
    }

    private var footerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 16))
    }

    @ViewBuilder private var footerLinks: some View {
        Link(destination: URL(string: "https://github.com/smith3v/stream14/blob/main/docs/privacy.md")!) {
            Text("Privacy policy")
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44)
        }
            .buttonStyle(.plain)
            .accessibilityIdentifier("privacyPolicy")
        Button { showingNotices = true } label: {
            Text("Third-party notices")
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44)
        }
            .buttonStyle(.plain)
            .accessibilityIdentifier("thirdPartyNotices")
    }

    private var notices: String {
        guard let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "Notices unavailable." }
        return text
    }
}

private struct ExperimentPreview: UIViewRepresentable {
    let view: MTHKView
    func makeUIView(context: Context) -> MTHKView { view }
    func updateUIView(_ uiView: MTHKView, context: Context) {}
}

private struct PlaybackSelection: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct SamplePlayback: View {
    let url: URL
    @State private var player: AVPlayer?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .toolbar { Button("Done") { dismiss() } }
                .onAppear { player = AVPlayer(url: url); player?.play() }
                .onDisappear { player?.pause(); player = nil }
        }
    }
}
