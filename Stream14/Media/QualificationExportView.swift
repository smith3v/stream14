import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct QualificationExport: Transferable {
    let report: QualificationReport
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { try $0.report.sanitizedData() }
            .suggestedFileName("stream14-qualification.json")
    }

}

/// Reads only the allowlisted checkpoint, never the recording manifest or errors.
struct QualificationExportView: View {
    let sampleID: UUID
    @State private var report: QualificationReport?
    @State private var unavailable = false
    @State private var loading = false
    var body: some View {
        VStack(alignment: .leading) {
            if let report {
                ShareLink(item: QualificationExport(report: report), preview: SharePreview("Qualification summary")) {
                    Label("Export qualification summary", systemImage: "chart.xyaxis.line")
                        .frame(minHeight: 44)
                }
                Button("Refresh qualification summary", action: load).frame(minHeight: 44).disabled(loading)
                Text("Numeric media and memory summary only. Last checkpoint: \(report.elapsedSeconds.formatted(.number.precision(.fractionLength(0)))) seconds; \(report.end == .stopped ? "stopped" : "may be incomplete").")
                    .font(.caption)
            } else {
                Button("Load qualification summary", action: load).frame(minHeight: 44).disabled(loading)
                if unavailable { Text("No readable qualification summary is available for this recording.").font(.caption) }
            }
        }
    }
    private func load() {
        guard !loading else { return }
        loading = true
        Task {
            defer { loading = false }
            do {
                report = try await QualificationCheckpoint().load(id: sampleID, directory: ExperimentSample.directory())
                unavailable = false
            } catch { report = nil; unavailable = true }
        }
    }
}
