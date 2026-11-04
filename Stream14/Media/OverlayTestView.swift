import SwiftUI

struct OverlayTestView: View {
    @State private var renderer = WebOverlayRenderer()
    @State private var url = ""
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AttachedOverlayView(renderer: renderer)
                    .frame(height: 96)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .accessibilityHidden(true)
                Form {
                    Section("Source") {
                        TextField("HTTPS overlay URL", text: $url)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .privacySensitive()
                            .accessibilityLabel("HTTPS overlay URL")
                            .accessibilityIdentifier("overlayURL")
                            .textFieldStyle(.roundedBorder)
                        Button("Load overlay") { renderer.load(url) }
                        Button("Use reference URL") { url = "https://heren14-overlay.smith3v.com/overlay.html" }
                    }
                    Section("Browser rendering") {
                        Text("This screen tests the browser renderer. Camera samples still use the synthetic counter; saved web-overlay composition is the next stage.")
                        Text("Attached browser · live rendering").font(.caption)
                        Text(renderer.status).accessibilityIdentifier("overlayStatus")
                        Text(renderer.viewport).font(.caption)
                        Text("Last capture: \(renderer.captureMilliseconds, specifier: "%.1f") ms").font(.caption)
                        Toggle("Hide overlay manually", isOn: Binding(
                            get: { renderer.health.manuallyHidden },
                            set: { renderer.setManuallyHidden($0) }))
                        Button("Reload source") { renderer.reload() }
                        Text("Current output raster · respects automatic and manual hiding").font(.caption)
                        ZStack {
                            Rectangle().fill(.blue.opacity(0.3))
                            if renderer.visible, let image = renderer.image {
                                Image(decorative: image, scale: 1).resizable().scaledToFit()
                            }
                        }
                        .aspectRatio(16 / 9, contentMode: .fit)
                        Text("Document refreshes confirm source access; pages without their own refresh are reloaded after eight seconds. Cached snapshots do not prove network health. In-place scoring APIs require a separate verified heartbeat before backend health can be claimed.")
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Overlay")
            .toolbar {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close overlay test")
            }
            .onDisappear { renderer.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { renderer.stop() }
            }
        }
    }
}
