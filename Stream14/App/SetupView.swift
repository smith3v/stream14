import SwiftUI

struct SetupView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("App setup ready")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("setupStatus")

                    Text("This build verifies app setup on your iPhone. Recording and web overlays are not available yet.")
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("setupExplanation")
                } header: {
                    Text("Local recording")
                        .foregroundStyle(Color.primary)
                }
            }
            .navigationTitle("stream14")
        }
    }
}

#Preview {
    SetupView()
}
