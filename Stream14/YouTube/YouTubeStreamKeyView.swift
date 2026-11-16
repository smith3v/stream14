import SwiftUI

struct YouTubeStreamKeyView: View {
    let broadcast: BroadcastSession
    @State private var editing = false
    @State private var confirmingRemoval = false
    @State private var draftName = ""
    @State private var draftKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stream key").font(.headline).accessibilityAddTraits(.isHeader)
            Text("Use a stream key if you manage the channel in YouTube Studio or have a key for a prepared event. Google sign-in is optional.")
            Text("In YouTube Studio, choose Create → Go live. In Live Control Room, open Stream settings → Stream key and create a reusable key for this iPhone. Assign it to one upcoming encoder event with Auto-start and Auto-stop enabled.")
                .font(.footnote)
            if let key = broadcast.streamKeySettings.saved {
                VStack(alignment: .leading, spacing: 4) {
                    Text(key.name).font(.subheadline)
                    Label("Saved on this iPhone", systemImage: "lock.fill")
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("savedStreamKey")
            }
            if broadcast.streamKeyConfigurationLocked {
                Text("Finish or dismiss the current stream-key session to change the key.").font(.footnote)
            } else if editing || broadcast.streamKeySettings.saved == nil {
                TextField("Display name (optional)", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("streamKeyName")
                SecureField("Stream key", text: $draftKey)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .privacySensitive()
                    .accessibilityIdentifier("streamKeyField")
                Button("Save") {
                    if broadcast.saveStreamKey(name: draftName, key: draftKey) { clearDraft() }
                }
                .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("saveStreamKey")
                if editing { Button("Cancel replacement") { clearDraft() } }
            } else {
                Button("Replace stream key") {
                    draftName = broadcast.streamKeySettings.saved?.name ?? ""
                    editing = true
                }
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
        draftKey = ""
        draftName = ""
        editing = false
    }
}
