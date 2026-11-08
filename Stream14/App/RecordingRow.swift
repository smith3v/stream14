import SwiftUI

/// One original file, one set of actions. Reuse this contract in the full-app list.
struct RecordingRow: View {
    let sample: ExperimentSample
    let canDelete: Bool
    let play: (URL) -> Void
    let delete: () -> Void
    let recovering: Bool
    let recover: () -> Void
    let deleteRecovery: (ExperimentSample.Recovery) -> Void
    @State private var pendingRecoveryDeletion: ExperimentSample.Recovery?

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
            Text(sample.status == .needsInspection ? "Metadata needs inspection" : sample.status.rawValue).font(.caption)
                .accessibilityIdentifier("recordingStatus-" + sample.id.uuidString)
            if let duration = sample.duration {
                Text("Duration: " + duration.formatted(.number.precision(.fractionLength(1))) + " seconds")
            }
            if let profile = sample.profile { Text(profile).font(.caption) }
            Text(reviewLabel).font(.caption)
                .accessibilityIdentifier("recordingReview-" + sample.id.uuidString)
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
            if sample.status != .completed || sample.review != .readable {
                Button(recovering ? "Recovering separate copy…" : "Try recovery to separate copy", action: recover)
                    .frame(minHeight: 44)
                    .disabled(!canDelete || size == nil || recovering)
                    .accessibilityIdentifier("recoverRecording-" + sample.id.uuidString)
                Text("Recovery may omit unfinished fragments or trim the tail. The original is kept; inspect playback.")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            QualificationExportView(sampleID: sample.id)
            ForEach(sample.recoveries ?? []) { recovery in
                if let directory { recoveryRow(recovery, directory: directory) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordingRow-" + sample.id.uuidString)
        .alert("Delete this recovery copy?", isPresented: Binding(
            get: { pendingRecoveryDeletion != nil },
            set: { if !$0 { pendingRecoveryDeletion = nil } }), presenting: pendingRecoveryDeletion) { recovery in
                Button("Delete recovery copy", role: .destructive) {
                    deleteRecovery(recovery)
                    pendingRecoveryDeletion = nil
                }
                Button("Cancel", role: .cancel) { pendingRecoveryDeletion = nil }
            } message: { _ in
                Text("Permanently delete only this recovery copy? The original and other copies are kept. This cannot be undone.")
            }
    }

    private var reviewLabel: String {
        switch sample.review {
        case .readable: "Audio and video start readable. Inspect playback; full integrity is not checked."
        case .unreadable: "Original unreadable. Retained for export or a recovery attempt."
        case .missing: "Original file missing. Metadata and recovery copies are retained."
        case nil: "Original awaiting native review."
        }
    }

    private func recoveryRow(_ recovery: ExperimentSample.Recovery, directory: URL) -> some View {
        let size = sample.recoveryFileSize(recovery, in: directory)
        let url = directory.appendingPathComponent(sample.recoveryFileName(recovery))
        return VStack(alignment: .leading, spacing: 4) {
            Text(recovery.status == .recovered ? "Recovered copy · inspect playback" : "Incomplete recovery attempt")
                .font(.headline)
                .accessibilityIdentifier("recoveryStatus-" + recovery.id.uuidString)
            if let duration = recovery.duration {
                Text("Duration: " + duration.formatted(.number.precision(.fractionLength(1))) + " seconds · may be truncated")
            }
            Text(size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "Copy file unavailable")
            HStack(spacing: 12) { recoveryActions(recovery, url: url, available: size != nil) }
                .labelStyle(.iconOnly)
        }
        .padding(.top, 8)
    }

    @ViewBuilder private func recoveryActions(_ recovery: ExperimentSample.Recovery, url: URL, available: Bool) -> some View {
        Button { play(url) } label: {
            Label("Play recovery copy", systemImage: "play.circle").frame(minWidth: 44, minHeight: 44)
        }
        .disabled(!available)
        .accessibilityIdentifier("playRecovery-" + recovery.id.uuidString)
        ShareLink(item: url) {
            Label("Export recovery copy", systemImage: "square.and.arrow.up").frame(minWidth: 44, minHeight: 44)
        }
        .disabled(!available)
        .accessibilityIdentifier("exportRecovery-" + recovery.id.uuidString)
        Button(role: .destructive) { pendingRecoveryDeletion = recovery } label: {
            Label("Delete recovery copy", systemImage: "trash").frame(minWidth: 44, minHeight: 44)
        }
        .disabled(!canDelete)
        .accessibilityIdentifier("deleteRecovery-" + recovery.id.uuidString)
    }
}

