import AVKit
import HaishinKit
import SwiftUI

struct SetupView: View {
    @State private var experiment = MediaSession()
    @State private var pendingDeletion: ExperimentSample?
    @State private var playback: PlaybackSelection?
    @State private var showingNotices = false
    @State private var showingOverlayTest = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stable attached source surface; never place WebKit in a lazy row.
                AttachedOverlayView(renderer: experiment.renderer)
                    .frame(height: 60)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .accessibilityHidden(true)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Local recording")
                        .font(.headline)
                        .accessibilityIdentifier("setupStatus")
                    Text("Record camera, microphone and a transparent web overlay. Keep the phone in landscape with the rear camera upright.")
                        .accessibilityIdentifier("setupExplanation")
                    if experiment.phase != .idle {
                        ExperimentPreview(view: experiment.preview)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .background(.black)
                            .accessibilityLabel("Composed camera preview with web overlay")
                    }
                    Text(experiment.renderer.status).font(.caption)
                    Toggle("Hide overlay manually", isOn: Binding(
                        get: { experiment.renderer.health.manuallyHidden },
                        set: { experiment.renderer.setManuallyHidden($0) }))
                    if !experiment.thermalWarning.isEmpty { Text(experiment.thermalWarning).accessibilityLabel("Thermal warning: " + experiment.thermalWarning) }
                    Text(experiment.message)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("mediaStatus")
                    if let started = experiment.startedAt {
                        Text(started, style: .timer)
                            .monospacedDigit()
                            .accessibilityLabel("Recording duration")
                    }
                    if experiment.phase == .idle {
                        Button("Open camera", systemImage: "camera") {
                            Task { await experiment.openPreview() }
                        }
                        .accessibilityIdentifier("openExperiment")
                    } else {
                        Button(experiment.isRecording ? "Stop recording" : "Record",
                               systemImage: experiment.isRecording ? "stop.circle" : "record.circle") {
                            Task {
                                if experiment.isRecording { await experiment.stopRecording() }
                                else { await experiment.record() }
                            }
                        }
                        .disabled(!experiment.canRecord && !experiment.isRecording)
                        .accessibilityIdentifier("recordSample")
                        Button("Close camera", systemImage: "xmark.circle") { experiment.requestStop() }
                            .disabled(experiment.phase == .stopping)
                    }
                    ForEach(experiment.savedSamples) { sample in
                        RecordingRow(sample: sample, canDelete: experiment.canDeleteSamples,
                                     play: { playback = PlaybackSelection(url: $0) },
                                     delete: { pendingDeletion = sample })
                    }
                    Text("Export to keep a copy outside the app. Deleting the app removes its local samples.")
                        .font(.footnote)
                    Text("1080p30 · H.264/AAC · local MP4 · no media upload")
                        .font(.footnote)
                    footerLayout { footerLinks }
                }
                .padding()
                .buttonStyle(.bordered)
                .tint(Color.primary)
                .controlSize(.large)
            }
            }
            .navigationTitle("stream14")
            .toolbar {
                Button("Overlay", systemImage: "globe") { showingOverlayTest = true }
                    .accessibilityLabel("Overlay settings")
                    .accessibilityIdentifier("testWebOverlay")
                    .disabled(experiment.phase != .idle && experiment.phase != .preview)
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
                        TextField("HTTPS overlay URL", text: $experiment.overlayURL)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL).textInputAutocapitalization(.never)
                            .autocorrectionDisabled().privacySensitive()
                            .accessibilityLabel("HTTPS overlay URL").accessibilityIdentifier("overlayURL")
                        Button("Load overlay") { experiment.loadOverlay() }
                        Button("Use reference URL") { experiment.overlayURL = "https://heren14-overlay.smith3v.com/overlay.html" }
                        Text(experiment.urlMessage)
                        Text("An empty URL disables the overlay. Load starts network access. URLs are stored securely on this device. Source document access does not verify a separate scoring backend.")
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
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { experiment.requestStop(interruption: true) }
            }
        }
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
