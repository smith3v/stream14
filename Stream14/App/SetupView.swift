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
                    if let url = experiment.sampleURL {
                        Text("Latest recording")
                            .font(.callout)
                        Button("Play sample", systemImage: "play.circle") { playback = PlaybackSelection(url: url) }
                        ShareLink(item: url) { Label("Export original sample", systemImage: "square.and.arrow.up") }
                        Text("Export to keep a copy outside the app. Deleting the app removes its local samples.")
                            .font(.footnote)
                    }
                    ForEach(experiment.savedSamples) { sample in
                        VStack(alignment: .leading) {
                            Text(sample.created, format: .dateTime.month().day().hour().minute().second())
                            Text(sample.status.rawValue).font(.caption)
                            if let directory = try? ExperimentSample.directory() {
                                let url = directory.appendingPathComponent(sample.fileName)
                                if FileManager.default.fileExists(atPath: url.path) {
                                    Button("Play saved file") { playback = PlaybackSelection(url: url) }
                                    ShareLink("Export original file", item: url)
                                }
                            }
                            Button("Delete recording", systemImage: "trash", role: .destructive) {
                                pendingDeletion = sample
                            }
                            .disabled(!experiment.canDeleteSamples)
                            .accessibilityLabel("Delete recording from " + sample.created.formatted(date: .abbreviated, time: .standard))
                            .accessibilityIdentifier("deleteRecording-" + sample.id.uuidString)
                        }
                    }
                    Text("1080p30 · H.264/AAC · local MP4 · no media upload")
                        .font(.footnote)
                    Button("Third-party notices") { showingNotices = true }
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
