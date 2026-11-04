import AVKit
import HaishinKit
import SwiftUI

struct SetupView: View {
    @State private var experiment = MediaExperiment()
    @State private var showingPlayback = false
    @State private var showingNotices = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Local media experiment")
                        .font(.headline)
                        .accessibilityIdentifier("setupStatus")
                    Text("Tests camera, microphone and a synthetic transparent layer. Web overlays are not available yet. Keep the phone in landscape with the rear camera upright.")
                        .accessibilityIdentifier("setupExplanation")
                    if experiment.phase != .idle {
                        ExperimentPreview(view: experiment.preview)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .background(.black)
                            .accessibilityLabel("Composed camera preview with synthetic alpha counter")
                    }
                    Text(experiment.message)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("mediaStatus")
                    if let started = experiment.startedAt {
                        Text(started, style: .timer)
                            .monospacedDigit()
                            .accessibilityLabel("Recording duration")
                    }
                    if experiment.phase == .idle {
                        Button("Open camera experiment", systemImage: "camera") {
                            Task { await experiment.openPreview() }
                        }
                        .accessibilityIdentifier("openExperiment")
                    } else {
                        Button(experiment.isRecording ? "Stop recording" : "Record sample",
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
                        Text("Inspection sample · writer completion is not yet qualified")
                            .font(.callout)
                        Button("Play sample", systemImage: "play.circle") { showingPlayback = true }
                        ShareLink(item: url) { Label("Export original sample", systemImage: "square.and.arrow.up") }
                        Text("Export to keep a copy outside the app. Deleting the app removes its local samples.")
                            .font(.footnote)
                    }
                    Text("1080p30 · H.264/AAC · local MP4 · no server")
                        .font(.footnote)
                    Button("Third-party notices") { showingNotices = true }
                }
                .padding()
                .buttonStyle(.bordered)
                .tint(Color.primary)
                .controlSize(.large)
            }
            .navigationTitle("stream14")
            .sheet(isPresented: $showingPlayback) {
                if let url = experiment.sampleURL { SamplePlayback(url: url) }
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
