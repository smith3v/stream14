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
        NavigationStack {
            ZStack(alignment: .top) {
                // Keep WebKit attached at a nonzero size for snapshots, covered by
                // the opaque scroll surface so it takes no separate layout space.
                AttachedOverlayView(renderer: experiment.renderer)
                    .frame(height: 60)
                    .accessibilityHidden(true)
                TabView(selection: $destination) {
                    Tab("Preparation", systemImage: "checklist", value: Destination.preparation) {
                        preparationScreen
                    }
                    Tab("Session", systemImage: "video", value: Destination.session) {
                        sessionScreen
                    }
                    Tab("Recordings", systemImage: "film.stack", value: Destination.recordings) {
                        recordingsScreen
                    }
                }
                .background(Color(uiColor: .systemBackground))
                .buttonStyle(.bordered)
                .tint(Color.primary)
                .controlSize(.large)
            }
            .navigationTitle("stream14")
            .toolbar {
                Button("Overlay", systemImage: "globe") {
                    overlayURLDraft = experiment.overlayURL
                    showingOverlayTest = true
                }
                    .accessibilityLabel("Overlay settings")
                    .accessibilityIdentifier("testWebOverlay")

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
                    Text("Permanently remove the recording from \(sample.created.formatted(date: .abbreviated, time: .standard)) and its metadata from this iPhone? This cannot be undone. Copies already exported to Files are kept.")
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
    }

    private var preparationScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Prepare your session").font(.headline).accessibilityIdentifier("setupStatus")
                Text("Record locally without Google, or choose a scheduled YouTube event before confirming Go Live. Keep the phone in landscape with the rear camera upright.")
                    .accessibilityIdentifier("setupExplanation")
                profileControls
                Text(experiment.phase == .idle ? "Camera and microphone: not open" : "Camera and microphone: open")
                Text("Input: " + experiment.audioRoute)
                overlayControls
                Button("Open session", systemImage: "video") { destination = .session }
                    .frame(minHeight: 44).accessibilityIdentifier("openSession")
                YouTubeConnectionView(authorization: authorization, broadcastActive: broadcast.requiresEndFirst)
                YouTubeEventsView(selection: youtubeEvents).disabled(broadcast.locksSelection)
                broadcastControls
                Text("Opening settings or choosing an event does not publish. Go Live requires camera readiness, a healthy or explicitly disabled overlay, and confirmation of the channel, event, visibility and profile.")
                    .font(.footnote)
                footerLayout { footerLinks }
            }.padding()
        }
    }

    private var sessionScreen: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height && !dynamicTypeSize.isAccessibilitySize
            if wide {
                HStack(alignment: .top, spacing: 12) {
                    previewPanel.frame(maxWidth: .infinity)
                    ScrollView { sessionControls.padding(.trailing) }
                        .frame(width: max(260, geometry.size.width * 0.4))
                }.padding(.leading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) { previewPanel; sessionControls }.padding()
                }
            }
        }
    }

    @ViewBuilder private var previewPanel: some View {
                    if experiment.phase != .idle {
                        ExperimentPreview(view: experiment.preview)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .background(.black)
                            .accessibilityLabel("Composed camera preview with web overlay")
                            .accessibilityIdentifier("cameraPreview")
                        if !experiment.availableLenses.isEmpty {
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
        if experiment.phase == .idle {
            ContentUnavailableView("Camera closed", systemImage: "video.slash", description: Text("Open the camera to rehearse or record. This does not publish to YouTube."))
        }
    }

    private var sessionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session").font(.headline)
            if let intent = broadcast.activeIntent ?? broadcast.confirmation {
                Text("Channel: " + intent.channel.title)
                Text("Event: " + intent.event.title)
                Text("Visibility: " + intent.event.visibility)
                Text("Profile: " + intent.profile.label)
            }
            Text("Recording: " + experiment.message)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("mediaStatus")
            if let started = experiment.startedAt {
                Text(started, style: .timer).monospacedDigit().accessibilityLabel("Recording duration")
            }
            if !experiment.thermalWarning.isEmpty {
                Text(experiment.thermalWarning).accessibilityLabel("Thermal warning: " + experiment.thermalWarning)
            }
            if !experiment.backupWarning.isEmpty {
                Text(experiment.backupWarning).accessibilityIdentifier("backupWarning")
            }
            cameraActions
            mediaControls
            overlayControls
            broadcastControls
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
            Toggle("Hide overlay manually", isOn: Binding(
                get: { experiment.renderer.health.manuallyHidden },
                set: { experiment.renderer.setManuallyHidden($0) })).frame(minHeight: 44)
            if !experiment.overlayURL.isEmpty {
                Button("Reload overlay", systemImage: "arrow.clockwise") { experiment.renderer.reload() }
                    .frame(minHeight: 44).accessibilityIdentifier("reloadOverlay")
            }
        }
    }

    private var broadcastControls: some View {
        BroadcastControlsView(broadcast: broadcast, media: experiment, selection: youtubeEvents, authorization: authorization)
    }

    private var recordingsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recordings").font(.headline)
                if experiment.savedSamples.isEmpty { Text("No recordings on this iPhone.") }
                ForEach(experiment.savedSamples) { sample in
                    RecordingRow(sample: sample, canDelete: experiment.canDeleteSamples,
                                 play: { playback = PlaybackSelection(url: $0) },
                                 delete: { pendingDeletion = sample })
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
                        Toggle("Mute microphone", isOn: Binding(
                            get: { experiment.microphoneMuted },
                            set: { value in Task { await experiment.setMicrophoneMuted(value) } }))
                            .disabled(!experiment.canAdjustMedia)
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
        Self.runsShortPhoneSmoke
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

/// One original file, one set of actions. Reuse this contract in the full-app list.
private struct RecordingRow: View {
    let sample: ExperimentSample
    let canDelete: Bool
    let play: (URL) -> Void
    let delete: () -> Void

    var body: some View {
        let directory = try? ExperimentSample.directory()
        let size = directory.flatMap { sample.fileSize(in: $0) }
        let url = directory?.appendingPathComponent(sample.fileName)
        let date = sample.created.formatted(date: .abbreviated, time: .standard)
        let sizeLabel = size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
            ?? "File size unavailable"
        VStack(alignment: .leading, spacing: 8) {
            Text("\(date) · \(sizeLabel)")
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("recordingMetadata-" + sample.id.uuidString)
            Text(sample.status.rawValue).font(.caption)
            HStack(spacing: 12) {
                Button { if let url { play(url) } } label: {
                    Label("Play recording", systemImage: "play.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(size == nil)
                .accessibilityLabel("Play recording from " + date)
                .accessibilityIdentifier("playRecording-" + sample.id.uuidString)
                if let url {
                    ShareLink(item: url) {
                        Label("Export original recording", systemImage: "square.and.arrow.up")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(size == nil)
                    .accessibilityLabel("Export original recording from " + date)
                    .accessibilityIdentifier("exportRecording-" + sample.id.uuidString)
                }
                Button(role: .destructive, action: delete) {
                    Label("Delete recording", systemImage: "trash")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(!canDelete)
                .accessibilityLabel("Delete recording from " + date)
                .accessibilityIdentifier("deleteRecording-" + sample.id.uuidString)
            }
            .labelStyle(.iconOnly)
        }
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
