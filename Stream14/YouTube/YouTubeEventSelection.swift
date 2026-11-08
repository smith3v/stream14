import Foundation
import Observation

@MainActor @Observable final class YouTubeEventSelection {
    let authorization: YouTubeAuthorization
    @ObservationIgnored private let client: YouTubeClient
    private var loadedGeneration: UInt64?
    private var operation: UInt64 = 0
    private var handledGeneration: UInt64
    private var storedChannel: YouTubeChannel?
    private var storedEvents: [YouTubeBroadcast] = []
    private var selectedID: String?
    private(set) var isRefreshing = false
    private(set) var message = "Refresh after connecting to load the authorized YouTube channel and scheduled events."

    init(authorization: YouTubeAuthorization, client: YouTubeClient? = nil) {
        self.authorization = authorization
        handledGeneration = authorization.generation
        self.client = client ?? YouTubeClient(authorization: authorization)
    }

    #if DEBUG
    func installInterfaceFixture(channel: YouTubeChannel, event: YouTubeBroadcast) {
        loadedGeneration = authorization.generation
        storedChannel = channel; storedEvents = [event]; selectedID = event.id
        message = "Fixture event selected. Nothing is being uploaded."
    }
    #endif

    // Computed guards hide stale metadata immediately, even before SwiftUI's
    // account-change callback has had a chance to clear the stored values.
    var channel: YouTubeChannel? { isCurrent ? storedChannel : nil }
    var events: [YouTubeBroadcast] { isCurrent ? storedEvents : [] }
    var selected: YouTubeBroadcast? {
        guard let channel, let event = events.first(where: { $0.id == selectedID }),
              event.ineligibility(channelID: channel.id) == nil else { return nil }
        return event
    }
    private var isCurrent: Bool { loadedGeneration == authorization.generation && authorization.isAuthorized }

    func accountChanged() {
        if handledGeneration != authorization.generation { invalidate() }
    }

    func invalidate() {
        handledGeneration = authorization.generation
        operation &+= 1
        loadedGeneration = nil; storedChannel = nil; storedEvents = []; selectedID = nil
        isRefreshing = false
        message = "Refresh after connecting to load the authorized YouTube channel and scheduled events."
    }

    func refresh() async {
        guard authorization.isAuthorized else { invalidate(); return }
        operation &+= 1
        let request = operation
        let generation = authorization.generation
        isRefreshing = true
        message = "Reading YouTube channel and scheduled events…"
        defer { if operation == request { isRefreshing = false } }
        do {
            let channel = try await client.authorizedChannel(generation: generation)
            let events = try await client.upcomingBroadcasts(channelID: channel.id, generation: generation)
            guard accepts(request, generation) else { return }
            loadedGeneration = generation; storedChannel = channel; storedEvents = events
            if selected == nil { selectedID = nil }
            message = events.isEmpty ? "No upcoming events. Schedule an encoder event in YouTube Studio with auto-stop disabled, then refresh." :
                "Choose an upcoming event. Selecting it does not publish media."
        } catch is CancellationError {
            if request == operation, generation == authorization.generation { message = "YouTube refresh cancelled." }
        } catch {
            guard accepts(request, generation) else { return }
            fail(error)
        }
    }

    func select(_ id: String) {
        guard !isRefreshing else { return }
        operation &+= 1
        guard let channel, let event = events.first(where: { $0.id == id }) else { selectedID = nil; return }
        guard let reason = event.ineligibility(channelID: channel.id) else {
            selectedID = id
            message = "Selected \(event.title). Nothing is being uploaded."
            return
        }
        selectedID = nil; message = reason
    }

    /// F5/F7 call this immediately before using a selection. The returned snapshot
    /// still belongs to this account generation; later mutating stages must keep
    /// checking generation and reconcile remote state independently.
    func recheckSelected() async throws -> YouTubeBroadcast {
        guard let channel, let selected else { throw YouTubeReadError.missingEvent }
        let generation = authorization.generation
        let request = operation
        var explainedIneligibility = false
        do {
            let current = try await client.broadcast(id: selected.id, channelID: channel.id, generation: generation)
            guard accepts(request, generation) else { throw CancellationError() }
            if let reason = current.ineligibility(channelID: channel.id) {
                selectedID = nil
                storedEvents = storedEvents.map { $0.id == current.id ? current : $0 }
                message = reason
                explainedIneligibility = true
                throw YouTubeReadError.missingEvent
            }
            storedEvents = storedEvents.map { $0.id == current.id ? current : $0 }
            return current
        } catch {
            if accepts(request, generation), !(error is CancellationError) {
                selectedID = nil
                if !explainedIneligibility { fail(error) }
            }
            throw error
        }
    }

    private func accepts(_ request: UInt64, _ generation: UInt64) -> Bool {
        request == operation && generation == authorization.generation && authorization.isAuthorized && !Task.isCancelled
    }

    private func fail(_ error: any Error) {
        let safe = error as? YouTubeReadError ?? .unavailable
        storedEvents = []; selectedID = nil
        if [.authorizationRequired, .insufficientPermission].contains(safe) {
            storedChannel = nil; loadedGeneration = nil
            authorization.signOut()
            handledGeneration = authorization.generation
        }
        message = safe.localizedDescription
    }
}
