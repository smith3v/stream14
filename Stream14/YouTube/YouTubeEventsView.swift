import SwiftUI

struct YouTubeEventsView: View {
    let selection: YouTubeEventSelection
    private var authorization: YouTubeAuthorization { selection.authorization }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scheduled YouTube event").font(.headline)
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await selection.refresh() } }
                    .disabled(!authorization.isAuthorized || selection.isRefreshing)
                    .accessibilityIdentifier("refreshYouTubeEvents")
            }
            if selection.isRefreshing { ProgressView("Reading YouTube…") }
            if let channel = selection.channel {
                Text("Channel: \(channel.title)").font(.headline)
                Text(channel.id).font(.caption).textSelection(.enabled)
                    .accessibilityLabel("YouTube channel identifier: " + channel.id)
            }
            Text(selection.message).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("youTubeEventStatus")
            ForEach(selection.events) { event in
                eventRow(event)
            }
            if let event = selection.selected {
                Text("Selected: \(event.title) · \(event.visibility)")
                    .font(.subheadline).accessibilityIdentifier("selectedYouTubeEvent")
                if event.contentDetails?.enableAutoStart == true {
                    Text("Auto-start is enabled in YouTube Studio. A later confirmed Go Live action may start this event as soon as media arrives.")
                        .font(.footnote)
                }
            }
            Link("Schedule an encoder event in YouTube Studio", destination: URL(string: "https://studio.youtube.com/")!)
                .font(.footnote)
        }
    }

    private func eventRow(_ event: YouTubeBroadcast) -> some View {
        let reason = selection.channel.flatMap { event.ineligibility(channelID: $0.id) }
        return Button { selection.select(event.id) } label: {
            HStack(alignment: .top) {
                Image(systemName: selection.selected?.id == event.id ? "checkmark.circle.fill" : "circle")
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).font(.body)
                    if let date = event.scheduledStart {
                        Text(date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline)
                    } else { Text("Scheduled time unavailable").font(.subheadline) }
                    Text(event.visibility).font(.subheadline)
                    if let reason { Text(reason).font(.footnote) }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .multilineTextAlignment(.leading)
        }
        .disabled(reason != nil || selection.isRefreshing)
        .accessibilityLabel(event.title + ", " + event.visibility)
        .accessibilityValue(selection.selected?.id == event.id ? "Selected" : reason ?? "Eligible")
        .accessibilityHint(event.scheduledStart?.formatted(date: .abbreviated, time: .shortened) ?? "Scheduled time unavailable")
    }
}
