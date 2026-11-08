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
    var body: some View {
        VStack(alignment: .leading) {
            if let report {
                ShareLink(item: QualificationExport(report: report), preview: SharePreview("Qualification summary")) {
                    Label("Export qualification summary", systemImage: "chart.xyaxis.line")
                        .frame(minHeight: 44)
                }
                Text("Numeric media and memory summary only. Last checkpoint: \(Int(report.elapsedSeconds)) seconds; \(report.end == .stopped ? "stopped" : "may be incomplete").")
                    .font(.caption)
            } else {
                Button("Load qualification summary") {
                    Task {
                        do {
                            report = try await QualificationCheckpoint().load(id: sampleID, directory: ExperimentSample.directory())
                            unavailable = false
                        } catch { unavailable = true }
                    }
                }.frame(minHeight: 44)
                if unavailable { Text("No readable qualification summary is available for this recording.").font(.caption) }
            }
        }
    }
}
