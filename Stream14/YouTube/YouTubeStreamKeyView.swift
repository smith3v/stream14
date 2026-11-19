import SwiftUI

struct YouTubeStreamKeyView: View {
    let broadcast: BroadcastSession
    @State private var editing = false
    @State private var confirmingRemoval = false
    @State private var draftKey = ""
    @FocusState private var keyFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stream key").font(.headline).accessibilityAddTraits(.isHeader)
            Text("Stream14 uses the saved key when no YouTube account is connected.")
            Text("In YouTube Studio, choose Create → Go live. In Live Control Room, open Stream settings → Stream key and create a key for this iPhone. Assign it to one upcoming encoder event. Use Auto-start to go live on ingest. Keep Auto-stop off to leave the event open during an outage, then end the event in Studio.")
                .font(.footnote)
            if broadcast.streamKeySettings.saved != nil {
                Label("Saved on this iPhone", systemImage: "lock.fill")
                    .accessibilityIdentifier("savedStreamKey")
            }
            if broadcast.streamKeyConfigurationLocked {
                Text("Finish or dismiss the current stream-key session to change the key.").font(.footnote)
            } else if editing || broadcast.streamKeySettings.saved == nil {
                SecureField("Stream key", text: $draftKey)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .privacySensitive()
                    .focused($keyFocused)
                    .submitLabel(.done)
                    .onSubmit { keyFocused = false }
                    .accessibilityIdentifier("streamKeyField")
                Button("Save") {
                    if broadcast.saveStreamKey(key: draftKey) { clearDraft() }
                }
                .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("saveStreamKey")
                if editing { Button("Cancel replacement") { clearDraft() } }
            } else {
                Button("Replace stream key") { editing = true }
                Button("Remove stream key", role: .destructive) { confirmingRemoval = true }
                    .accessibilityIdentifier("removeStreamKey")
            }
            if let feedback = broadcast.streamKeySettings.feedback {
                Text(feedback).font(.footnote).accessibilityIdentifier("streamKeySettingsStatus")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .confirmationDialog("Remove the stream key from this iPhone?", isPresented: $confirmingRemoval,
            titleVisibility: .visible) {
            Button("Remove stream key", role: .destructive) { broadcast.removeStreamKey() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove the saved key from Stream14. Manage or reset the key in YouTube Studio.")
        }
        .onChange(of: broadcast.streamKeyConfigurationLocked) {
            if broadcast.streamKeyConfigurationLocked { clearDraft() }
        }
    }

    private func clearDraft() {
        keyFocused = false
        draftKey = ""
        editing = false
    }
}
