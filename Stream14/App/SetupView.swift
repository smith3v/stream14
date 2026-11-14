import AVKit
import HaishinKit
import SwiftUI

struct SetupView: View {
    let authorization: YouTubeAuthorization
    let youtubeEvents: YouTubeEventSelection
    let experiment: MediaSession
    let broadcast: BroadcastSession
    private enum Destination: Hashable { case session, recordings }
    @State private var destination = Destination.session
    @State private var pendingDeletion: ExperimentSample?
    @State private var playback: PlaybackSelection?
    @State private var confirmingLocalEnd = false
    @State private var showingSettings = false
    @State private var showingEvents = false
    @State private var showingConnection = false
    @State private var sessionHasRun = false
    @State private var showingLensChoices = false
    @State private var showingProfileChoices = false
    @State private var showingOverlayTest = false
    @State private var overlayURLDraft = ""
    @State private var zoomDraft = 1.0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .top) {
            // Anchor the overlay's hidden snapshot window in this scene.
            AttachedOverlayView(renderer: experiment.renderer)
                .frame(height: 60)
                .accessibilityHidden(true)
            GeometryReader { geometry in
                let landscape = geometry.size.width > geometry.size.height
                TabView(selection: $destination) {
                    Tab("Session", systemImage: "video", value: Destination.session) {
                        if destination == .session {
                            navigationScreen(sessionScreen, landscape: landscape)
                                .toolbarVisibility(landscape ? .hidden : .visible, for: .tabBar)
                        }
                    }
                    Tab("Recordings", systemImage: "film.stack", value: Destination.recordings) {
                        if destination == .recordings {
                            navigationScreen(recordingsScreen, landscape: landscape)
                                .toolbarVisibility(landscape ? .hidden : .visible, for: .tabBar)
                        }
                    }
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
            .sheet(isPresented: $showingSettings) { settingsScreen }
            .sheet(isPresented: $showingEvents) {
                NavigationStack {
                    ScrollView {
                        YouTubeEventsView(selection: youtubeEvents)
                            .disabled(broadcast.locksSelection).padding()
                    }
                    .navigationTitle("Choose event")
                    .toolbar { Button("Done") { showingEvents = false } }
                }
            }
            .sheet(isPresented: $showingConnection) {
                NavigationStack {
                    ScrollView {
                        YouTubeConnectionView(authorization: authorization, broadcast: broadcast,
                            broadcastActive: broadcast.requiresEndFirst).padding()
                    }
                    .navigationTitle("YouTube")
                    .toolbar { Button("Done") { showingConnection = false } }
                }
            }
            .sheet(isPresented: $showingOverlayTest) {
                NavigationStack {
                    overlaySettingsForm
                        .navigationTitle("Overlay")
                        .toolbar { Button("Close overlay settings") { showingOverlayTest = false } }
                }
            }
            .task {
                guard !runsIsolatedMediaHarness else { return }
                experiment.setOverlayForeground(scenePhase != .background)
                experiment.setCaptureForeground(scenePhase != .background)
                if scenePhase == .active { activateYouTube() }
                while !Task.isCancelled {
                    experiment.reconcileOverlay()
                    do { try await Task.sleep(for: .seconds(1)) } catch { break }
                }
                experiment.setOverlayForeground(false)
            }
            .onChange(of: experiment.phase) { _, phase in
                if phase == .starting || phase == .recording { sessionHasRun = true }
            }
            .onChange(of: experiment.cameraZoom.value) { _, value in zoomDraft = value }
            .onChange(of: authorization.isAuthorized) { _, isAuthorized in
                if isAuthorized && scenePhase == .active && !runsIsolatedMediaHarness {
                    broadcast.foregroundReturned()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard !runsIsolatedMediaHarness else { return }
                if phase == .active {
                    experiment.setOverlayForeground(true)
                    experiment.setCaptureForeground(true)
                    activateYouTube()
                }
                if phase == .background {
                    experiment.setOverlayForeground(false)
                    experiment.setCaptureForeground(false)
                }
            }
    }

    private func activateYouTube() {
        broadcast.foregroundReturned()
        // Let the SDK finish across brief inactive transitions. The authorization
        // owner serializes the one launch attempt and rejects stale callbacks.
        Task {
            guard UIApplication.shared.applicationState == .active else { return }
            await authorization.restoreOnLaunchIfAvailable(broadcastActive: broadcast.requiresEndFirst)
        }
    }

    private func navigationScreen<Content: View>(_ content: Content, landscape: Bool) -> some View {
        NavigationStack {
            content
                .background(Color(uiColor: .systemBackground))
                .navigationTitle("stream14")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(id: "workspace-more", placement: .topBarTrailing) {
                        WorkspaceMoreMenu(landscape: landscape, destination: $destination,
                            showingSettings: $showingSettings, renderer: experiment.renderer,
                            overlayManuallyHidden: experiment.renderer.health.manuallyHidden,
                            overlayConfigured: !experiment.overlayURL.isEmpty)
                    }
                }
        }
    }

    /// Keep the native dropdown's identity and observations separate from the
    /// frequently changing meter/status content in the workspace.
    private struct WorkspaceMoreMenu: View {
        let landscape: Bool
        @Binding var destination: Destination
        @Binding var showingSettings: Bool
        let renderer: WebOverlayRenderer
        let overlayManuallyHidden: Bool
        let overlayConfigured: Bool

        var body: some View {
            Menu {
                if landscape {
                    Menu("Navigate", systemImage: "arrow.left.arrow.right") {
                        Button("Session", systemImage: "video") { destination = .session }
                        Button("Recordings", systemImage: "film.stack") { destination = .recordings }
                    }
                }
                Button("Settings", systemImage: "gearshape") { showingSettings = true }
                    .accessibilityIdentifier("openSettings")
                if destination == .session {
                    Button(overlayManuallyHidden ? "Show overlay" : "Hide overlay manually",
                           systemImage: "eye") {
                        renderer.setManuallyHidden(!renderer.health.manuallyHidden)
                    }
                    .accessibilityValue(overlayManuallyHidden ? "Hidden" : "Shown")
                    .accessibilityIdentifier("manualOverlayVisibility")
                    Button("Reload overlay", systemImage: "arrow.clockwise") { renderer.reload() }
                        .disabled(!overlayConfigured)
                }
            } label: {
                Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
            }
            .accessibilityLabel("More")
            .accessibilityIdentifier("sessionMore")
        }
    }

    private var overlaySettingsForm: some View {
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
    }

    private var settingsScreen: some View {
        NavigationStack {
            Form {
                NavigationLink("YouTube") {
                    ScrollView {
                        YouTubeConnectionView(authorization: authorization, broadcast: broadcast,
                            broadcastActive: broadcast.requiresEndFirst).padding()
                    }.navigationTitle("YouTube")
                        .toolbar { Button("Done") { showingSettings = false } }
                }
                NavigationLink("Overlay") {
                    overlaySettingsForm.navigationTitle("Overlay")
                        .toolbar { Button("Done") { showingSettings = false } }
                        .onAppear { overlayURLDraft = experiment.overlayURL }
                }.accessibilityIdentifier("testWebOverlay")
                NavigationLink("About & Legal") {
                    Form {
                        footerLinks
                        Link("stream14 service terms", destination: URL(string: "https://github.com/smith3v/stream14/blob/main/docs/terms.md")!)
                        Link("YouTube Terms of Service", destination: URL(string: "https://www.youtube.com/t/terms")!)
                    }.navigationTitle("About & Legal")
                        .toolbar { Button("Done") { showingSettings = false } }
                }
                NavigationLink("Help") {
                    Form {
                        Text("Check camera and sound before starting. Setup sends no camera media. Upload and local saving operate independently. Backgrounding stops capture. A preview-only camera returns on foreground; interrupted recording or upload requires an explicit restart and review of Resume for the same event. Resolve unknown YouTube state before preparing another session.")
                        Link("Documentation", destination: URL(string: "https://github.com/smith3v/stream14/blob/main/docs/ios-development-guide.md")!)
                    }.navigationTitle("Help")
                        .toolbar { Button("Done") { showingSettings = false } }
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { showingSettings = false } }
        }
    }

    private func openOverlaySettings() {
        overlayURLDraft = experiment.overlayURL
        showingOverlayTest = true
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
            if [.preview, .starting, .recording].contains(experiment.phase) {
                ExperimentPreview(view: experiment.preview)
                    .id(ObjectIdentifier(experiment.preview))
                    .frame(width: fittedWidth, height: fittedWidth * 9.0 / 16.0)
                    .background(.black)
                    .accessibilityLabel("Composed camera preview with web overlay")
                    .accessibilityIdentifier("cameraPreview")
                    .clipped()

            }
            if experiment.phase == .preparing || experiment.phase == .stopping {
                ProgressView(experiment.phase == .preparing ? "Opening camera…" : "Closing camera…")
                    .frame(width: fittedWidth, height: fittedWidth * 9.0 / 16.0)
                    .accessibilityIdentifier("cameraTransition")
            }
            if experiment.phase == .idle {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Camera closed", systemImage: "video.slash")
                        .font(.headline).symbolRenderingMode(.monochrome)
                    Text("Check camera and sound to rehearse or record. This does not publish to YouTube.")
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
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

    private var finished: Bool {
        broadcast.state == .ended || (sessionHasRun && !broadcast.locksSelection &&
            (experiment.phase == .idle || experiment.phase == .preview))
    }

    private var sessionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(finished ? "Session finished" : (sessionHasRun || broadcast.locksSelection ? "Active session" : "Next session"))
                .font(.headline).accessibilityIdentifier("setupStatus")
            if !authorization.isAuthorized {
                Text(authorization.isConfigured ? authorization.message :
                    "YouTube connection is unavailable in this build. Record only is available; open Settings → Help for setup guidance.")
                    .font(.footnote)
                if !authorization.isWorking {
                    Button("Connect / reconnect YouTube") { showingConnection = true }
                        .frame(minHeight: 44).accessibilityIdentifier("fixYouTube")
                }
            }
            eventSummary
            outputStatuses
            overlayRecovery
            backupFailureWarning
            if !experiment.thermalWarning.isEmpty {
                Text(experiment.thermalWarning).accessibilityLabel("Thermal warning: " + experiment.thermalWarning)
            }
            if let started = experiment.startedAt {
                Text(started, style: .timer).monospacedDigit().accessibilityLabel("Recording duration")
            }
            if finished || broadcast.state == .needsReconciliation {
                finishControls
            } else {
                readinessControls
            }
            if experiment.phase == .idle {
                Button("Check camera and sound", systemImage: "camera") { Task { await experiment.openPreview() } }
                    .frame(minHeight: 44).accessibilityIdentifier("openExperiment")
            } else if experiment.phase == .preview && !experiment.hasUpload &&
                        !broadcast.requiresEndFirst && broadcast.confirmation == nil {
                Button("Close camera", systemImage: "xmark.circle") { experiment.requestStop() }
                    .frame(minHeight: 44)
                    .disabled(!experiment.canAdjustMedia)
                    .accessibilityIdentifier("closeCamera")
            }
            if !sessionHasRun && !broadcast.locksSelection {
                profileControls
                lensControls
                Text("Quality: \(experiment.profile.label) · Camera: \(experiment.selectedLens.label)")
                    .font(.caption).accessibilityIdentifier("sessionConfiguration")
            }
            broadcastControls
            localActions
            mediaControls
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var eventSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let intent = broadcast.activeIntent ?? broadcast.confirmation {
                Text("Channel: " + intent.channel.title)
                eventDetails(intent.event)
                Text("Quality: " + intent.profile.label)
            } else if let event = youtubeEvents.selected, let channel = youtubeEvents.channel {
                Text("Channel: " + channel.title)
                eventDetails(event)
            } else {
                Text("No scheduled event selected")
            }
            if authorization.isAuthorized && !broadcast.locksSelection && !finished {
                Button(youtubeEvents.selected == nil ? "Choose event" : "Change event") { showingEvents = true }
                    .frame(minHeight: 44).accessibilityIdentifier("chooseEvent")
            }
        }.accessibilityElement(children: .contain)
    }

    private func eventDetails(_ event: YouTubeBroadcast) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title).font(.headline)
            Text(event.scheduledStart?.formatted(date: .abbreviated, time: .shortened) ?? "Scheduled time unavailable")
            Text("Visibility: " + event.visibility)
        }
    }

    private var outputStatuses: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Upload: " + uploadStatus).accessibilityIdentifier("uploadStatus")
            Text("Local saving: " + experiment.localSavingStatus)
                .accessibilityIdentifier("localSavingStatus")
            Text(experiment.message).font(.caption).accessibilityIdentifier("mediaStatus")
            Text("Overlay: " + (experiment.overlayURL.isEmpty ? "Disabled" : experiment.renderer.status))
                .font(.caption).accessibilityIdentifier("overlayStatus")
        }
    }

    private var uploadStatus: String {
        switch broadcast.reconnectStatus {
        case .waiting: return "Reconnecting · attempt \(broadcast.reconnectAttempts)/12. " + experiment.uploadMessage
        case .connecting: return "Reconnecting · connecting to the same event"
        case .exhausted: return "Failed · recovery exhausted. Retry upload to the same event or End session."
        case .authorizationRequired: return "Authorization needs attention. " + experiment.uploadMessage
        default: return experiment.uploadMessage
        }
    }

    @ViewBuilder private var overlayRecovery: some View {
        if !experiment.broadcastOverlayReady {
            Text(experiment.canEditOverlayURL ?
                "Configured overlay unavailable. Wait, retry, or open Overlay settings and apply an empty URL to explicitly disable it. Manual hide does not disable it." :
                "Configured overlay unavailable. Retry while the session continues. To disable its URL, end the session, then open Overlay settings. Manual hide does not disable it.")
                .font(.footnote).accessibilityIdentifier("overlayWarning")
            Button("Retry overlay") { experiment.renderer.reload() }
                .frame(minHeight: 44).accessibilityIdentifier("retryOverlay")
            Button("Overlay settings") { openOverlaySettings() }.frame(minHeight: 44)
        }
    }

    @ViewBuilder private var readinessControls: some View {
        if !broadcast.requiresEndFirst {
            if !experiment.broadcastCaptureReady {
                Text("Check camera and sound before starting. Allow camera and microphone access when asked.")
                    .font(.footnote).accessibilityIdentifier("cameraReadiness")
                if experiment.capturePermissionDenied {
                    Link("Open iPhone Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                        .frame(minHeight: 44)
                }
            }
            if broadcast.requiresStudioResolution || broadcast.journalUnavailable {
                Text(broadcast.message).font(.footnote)
                Button("Resolve YouTube setup") { showingConnection = true }.frame(minHeight: 44)
            }
            if youtubeEvents.selected == nil && authorization.isAuthorized && !broadcast.locksSelection {
                Text("Choose an eligible scheduled event. Its channel must support streaming and auto-stop must be disabled in Studio.")
                    .font(.footnote)
            }
            if experiment.previewNeedsLandscape {
                Text("Turn your iPhone to landscape to record or stream.")
                    .font(.footnote).accessibilityIdentifier("landscapeReadiness")
            } else if experiment.phase == .preview && experiment.previewOrientationSettling {
                Text("Adjusting camera orientation…")
                    .font(.footnote).accessibilityIdentifier("landscapeReadiness")
            } else if experiment.broadcastCaptureReady && !experiment.canRecord && !experiment.hasStartedWriting {
                Text("Local saving is not ready. Wait for finalization or recording recovery to finish, then retry. Streaming has not started.")
                    .font(.footnote).accessibilityIdentifier("writerReadiness")
            }
            if experiment.broadcastCaptureReady && experiment.broadcastOverlayReady &&
                (experiment.canRecord || experiment.hasStartedWriting) && youtubeEvents.selected != nil && broadcast.canStart {
                Text("Ready to confirm recording and streaming").font(.subheadline)
                    .accessibilityIdentifier("sessionReady")
            }
        }
    }

    @ViewBuilder private var localActions: some View {
        if experiment.isRecording && broadcast.activeIntent == nil && broadcast.pendingRemote == nil && !broadcast.isWorking {
            Button("End session", role: .destructive) { confirmingLocalEnd = true }
                .buttonStyle(SessionActionButtonStyle.stop)
                .confirmationDialog("End local session?", isPresented: $confirmingLocalEnd, titleVisibility: .visible) {
                    Button("Stop local recording and capture", role: .destructive) { experiment.requestStop() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Stop local recording and capture, then finalize the file. YouTube status is shown separately.")
                }
        }
        if experiment.isRecording {
            Button("Stop recording", systemImage: "stop.circle") { Task { await experiment.stopRecording() } }
                .buttonStyle(SessionActionButtonStyle.stop)
                .disabled(!experiment.canAdjustMedia)
                .accessibilityIdentifier("recordSample")
        } else if experiment.canRecord && !finished {
            Button("Record only", systemImage: "record.circle") { Task { await experiment.record() } }
                .frame(minHeight: 44).accessibilityIdentifier("recordSample")
        }
        if experiment.recordingFailed {
            Text("Local saving cannot recover in this session. Saved footage is incomplete; export or review it in Recordings. After outputs stop, prepare the next session and check the camera to start a new file. Upload continues while healthy; the recording gap is not recovered.")
                .font(.footnote).accessibilityIdentifier("localRecoveryGuidance")
        }
    }

    private var finishControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = experiment.sampleURL {
                Button("Play", systemImage: "play") { playback = PlaybackSelection(url: url) }.frame(minHeight: 44)
                ShareLink(item: url) { Label("Export original", systemImage: "square.and.arrow.up").frame(minHeight: 44) }
            }
            Button("Prepare next session") {
                guard experiment.canPrepareNextSession, broadcast.prepareNextSession(), experiment.prepareNextSession() else { return }
                youtubeEvents.invalidate()
                sessionHasRun = false
            }
            .frame(minHeight: 44)
            .disabled(!experiment.canPrepareNextSession || !broadcast.canPrepareNextSession)
            .accessibilityIdentifier("prepareNextSession")
            if !experiment.canPrepareNextSession || !broadcast.canPrepareNextSession {
                Text("Wait for local finalization and resolve YouTube status before preparing another session.").font(.footnote)
            }
        }
    }

    private var broadcastControls: some View {
        BroadcastControlsView(broadcast: broadcast, media: experiment, selection: youtubeEvents,
            authorization: authorization, allowStart: !finished)
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
                if !experiment.qualificationWarning.isEmpty {
                    Text(experiment.qualificationWarning).font(.footnote)
                }
                if !experiment.recordingsMessage.isEmpty {
                    Text(experiment.recordingsMessage).accessibilityIdentifier("recordingsStatus")
                }
                if experiment.savedSamples.isEmpty { Text("No recordings on this iPhone.") }
                ForEach(experiment.savedSamples) { sample in
                    RecordingRow(sample: sample, canDelete: experiment.canDeleteSamples,
                                 protected: experiment.protectedRecordingID == sample.id,
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
                        Text("Close the camera to change quality, then check the new picture and sound.").font(.caption)
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

    @ViewBuilder private var footerLinks: some View {
        Link(destination: URL(string: "https://github.com/smith3v/stream14/blob/main/docs/privacy.md")!) {
            Text("Privacy policy")
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44)
        }
            .buttonStyle(.plain)
            .accessibilityIdentifier("privacyPolicy")
        NavigationLink { ScrollView { Text(notices).font(.footnote).padding() }.navigationTitle("Third-party notices") } label: {
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
