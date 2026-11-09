import Foundation
import Observation

/// Intentionally not Codable. Diagnostic descriptions and reflection redact credentials.
nonisolated struct YouTubeIngestionDestination: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let endpoint: URL
    let streamName: String
    var description: String { "YouTube RTMPS destination (redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: ["credentials": "<redacted>"]) }

    init(address: String?, streamName: String?) throws {
        guard let address, let parts = URLComponents(string: address), parts.scheme == "rtmps",
              let host = parts.host?.lowercased(), host == "rtmps.youtube.com" || host.hasSuffix(".rtmps.youtube.com"),
              parts.port == nil || parts.port == 443, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil, !parts.path.isEmpty, parts.path != "/",
              let endpoint = parts.url, let streamName, !streamName.isEmpty, streamName.utf8.count <= 4_096,
              !streamName.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }) else {
            throw YouTubeBindingError.invalidDestination
        }
        self.endpoint = endpoint
        self.streamName = streamName
    }
}

/// Distinct from F3's read-only model, which deliberately discards ingestion secrets.
nonisolated struct YouTubeIngestionStream: Decodable, Sendable, CustomReflectable {
    struct Snippet: Decodable, Sendable { let channelId: String? }
    struct CDN: Decodable, Sendable {
        struct IngestionInfo: Decodable, Sendable { let rtmpsIngestionAddress: String?; let streamName: String? }
        let ingestionType: String?
        let resolution: String?
        let frameRate: String?
        let ingestionInfo: IngestionInfo?
    }
    struct Status: Decodable, Sendable {
        struct Health: Decodable, Sendable {
            struct Issue: Decodable, Sendable { let severity: String? }
            let status: String?
            let configurationIssues: [Issue]?
        }
        let streamStatus: String?
        let healthStatus: Health?
    }
    struct ContentDetails: Decodable, Sendable { let isReusable: Bool? }
    let id: String
    let snippet: Snippet?
    let cdn: CDN?
    let status: Status?
    let contentDetails: ContentDetails?
    var customMirror: Mirror { Mirror(self, children: ["id": id, "credentials": "<redacted>"]) }

    func destination(channelID: String, profile: SessionProfile, appCreated: Bool) throws -> YouTubeIngestionDestination {
        guard snippet?.channelId == channelID else { throw YouTubeReadError.wrongChannel }
        guard ["inactive", "ready"].contains(status?.streamStatus ?? ""),
              let reusable = contentDetails?.isReusable, !appCreated || !reusable,
              cdn?.ingestionType == "rtmp" else { throw YouTubeBindingError.unsafeStream }
        let resolution = profile == .hd ? "720p" : "1080p"
        guard (cdn?.resolution == "variable" && cdn?.frameRate == "variable") ||
                (cdn?.resolution == resolution && cdn?.frameRate == "30fps") else { throw YouTubeBindingError.incompatibleStream }
        guard let health = status?.healthStatus,
              ["good", "ok", "noData"].contains(health.status ?? ""),
              !(health.configurationIssues ?? []).contains(where: { $0.severity == "error" || $0.severity == nil }) else {
            throw YouTubeBindingError.unsafeStream
        }
        return try YouTubeIngestionDestination(address: cdn?.ingestionInfo?.rtmpsIngestionAddress,
                                               streamName: cdn?.ingestionInfo?.streamName)
    }
}

nonisolated struct PreparedYouTubeIngestion: Sendable, CustomReflectable {
    let broadcast: YouTubeBroadcast
    let streamID: String
    let profile: SessionProfile
    let generation: UInt64
    let destination: YouTubeIngestionDestination
    var customMirror: Mirror { Mirror(self, children: ["broadcastID": broadcast.id, "streamID": streamID, "credentials": "<redacted>"]) }
}

nonisolated enum YouTubeMutationError: Error, Equatable { case rejected(YouTubeReadError), uncertain }

nonisolated enum YouTubeBindingError: Error, Equatable, LocalizedError {
    case studioResolutionRequired
    case busy, deadline, ineligibleEvent, unsafeStream, incompatibleStream, sharedStream, dedicationUnknown
    case invalidDestination, intentUnavailable, pendingOtherContext, unresolvedInsert, bindingConflict, bindingUnconfirmed
    var errorDescription: String? {
        switch self {
        case .studioResolutionRequired: "YouTube data was deleted. Check YouTube Studio for previous requests and explicitly confirm resolution before publishing again."
        case .busy: "YouTube preparation is already running. Wait for it to finish."
        case .deadline: "YouTube preparation timed out. Retry to reconcile the existing request; no duplicate stream will be created."
        case .ineligibleEvent: "The event is no longer eligible. Check its state and disable auto-stop in YouTube Studio, then refresh."
        case .unsafeStream: "The ingestion stream is active, unhealthy or incomplete. Configure a dedicated inactive stream in YouTube Studio."
        case .incompatibleStream: "The event's stream does not match this session profile. Correct its resolution/frame rate in YouTube Studio."
        case .sharedStream: "Another unfinished event uses this stream. Choose a dedicated stream in YouTube Studio."
        case .dedicationUnknown: "The app could not establish that this stream is dedicated. Check the event and stream in YouTube Studio."
        case .invalidDestination: "YouTube did not return a supported secure ingestion destination. Check the stream in YouTube Studio."
        case .intentUnavailable: "The pending YouTube request could not be saved or read. No new stream will be created; resolve local storage before retrying."
        case .pendingOtherContext: "This event has a pending request with another media profile. Resolve its binding in YouTube Studio before changing that profile."
        case .unresolvedInsert: "A stream creation request has an unknown outcome. Inspect streams in YouTube Studio and bind the intended stream manually; the app will not create another blindly."
        case .bindingConflict: "The event is now bound to a different stream. The app will not replace it. Check YouTube Studio and refresh."
        case .bindingUnconfirmed: "The binding could not be confirmed. Retry to read the event and reuse the same known stream; no new stream will be created."
        }
    }
}

/// F7 owns one instance and calls this only after confirmed Go Live. No startup,
/// selection or preview hook invokes writes. Credentials are never persisted here.
@MainActor @Observable final class YouTubeBinding {
    private(set) var isPreparing = false
    @ObservationIgnored private let client: YouTubeClient
    @ObservationIgnored private let store: PendingBroadcastIntentStore
    private let timeout: Duration

    init(client: YouTubeClient, store: PendingBroadcastIntentStore = PendingBroadcastIntentStore(), timeout: Duration = .seconds(45)) {
        self.client = client; self.store = store; self.timeout = timeout
    }

    var requiresStudioResolution: Bool { store.requiresStudioResolution }
    func eraseAPIData() throws { try store.eraseAPIData() }
    func confirmStudioResolution() throws { try store.confirmStudioResolution() }

    func prepareConfirmed(eventID: String, channelID: String, profile: SessionProfile, generation: UInt64) async throws -> PreparedYouTubeIngestion {
        guard !requiresStudioResolution else { throw YouTubeBindingError.studioResolutionRequired }
        guard !isPreparing else { throw YouTubeBindingError.busy }
        isPreparing = true
        defer { isPreparing = false }
        do {
            return try await withThrowingTaskGroup(of: PreparedYouTubeIngestion.self) { group in
                group.addTask {
                    try await self.resolve(eventID: eventID, channelID: channelID, profile: profile, generation: generation)
                }
                group.addTask { [timeout] in try await Task.sleep(for: timeout); throw YouTubeBindingError.deadline }
                defer { group.cancelAll() }
                guard let result = try await group.next() else { throw YouTubeBindingError.deadline }
                return result
            }
        } catch is CancellationError { throw CancellationError() }
        catch let error as YouTubeBindingError { throw error }
        catch let error as YouTubeReadError { throw error }
        catch let error as YouTubeMutationError {
            switch error { case .rejected(let error): throw error; case .uncertain: throw YouTubeBindingError.bindingUnconfirmed }
        } catch { throw YouTubeBindingError.intentUnavailable }
    }

    /// Resume never creates/rebinds resources. Inactive ingestion is required so
    /// a different encoder cannot silently share the original event's stream.
    func prepareResumeConfirmed(context: PendingRemoteBroadcast, profile: SessionProfile,
                                generation: UInt64) async throws -> PreparedYouTubeIngestion {
        guard !requiresStudioResolution else { throw YouTubeBindingError.studioResolutionRequired }
        guard context.transition == nil, let streamID = context.streamID,
              context.profileName == profile.rawValue else { throw YouTubeBindingError.bindingConflict }
        let channel = try await client.authorizedChannel(generation: generation)
        guard channel.id == context.channelID else { throw YouTubeReadError.wrongChannel }
        let event = try await client.broadcast(id: context.eventID, channelID: context.channelID, generation: generation)
        guard ["created", "ready", "testing", "live"].contains(event.status?.lifeCycleStatus ?? ""),
              event.contentDetails?.enableAutoStop == false, event.contentDetails?.enableAutoStart != nil,
              event.contentDetails?.boundStreamId == streamID,
              event.snippet?.isDefaultBroadcast != true, event.snippet?.title?.isEmpty == false,
              event.scheduledStart != nil, ["public", "unlisted", "private"].contains(event.status?.privacyStatus ?? "") else {
            throw YouTubeBindingError.ineligibleEvent
        }
        try await dedicated(streamID: streamID, eventID: event.id, channelID: channel.id, generation: generation)
        let stream = try await checkedStream(streamID, channel.id, profile, generation, appCreated: false)
        let latest = try await client.broadcast(id: event.id, channelID: channel.id, generation: generation)
        guard latest == event else { throw YouTubeBindingError.bindingConflict }
        return PreparedYouTubeIngestion(broadcast: event, streamID: streamID, profile: profile, generation: generation,
            destination: try stream.destination(channelID: channel.id, profile: profile, appCreated: false))
    }

    private func resolve(eventID: String, channelID: String, profile: SessionProfile, generation: UInt64) async throws -> PreparedYouTubeIngestion {
        let channel = try await client.authorizedChannel(generation: generation)
        guard channel.id == channelID else { throw YouTubeReadError.wrongChannel }
        var event = try await eligible(eventID, channelID, generation)
        let saved = try loadIntent(channelID: channelID, eventID: eventID)
        if let streamID = event.contentDetails?.boundStreamId, !streamID.isEmpty {
            if let saved, saved.matches(channelID: channelID, broadcastID: eventID, profile: profile),
               let created = saved.createdStreamID, created != streamID { throw YouTubeBindingError.bindingConflict }
            let result = try await prepared(event: event, streamID: streamID, channelID: channelID, profile: profile,
                                           generation: generation, appCreated: saved?.createdStreamID == streamID)
            if var saved, saved.matches(channelID: channelID, broadcastID: eventID, profile: profile) {
                // Studio may have resolved an ambiguous insertion by binding an
                // existing stream. Keep the original guard/IDs, but record that
                // the event's current binding has now been verified.
                saved.phase = .prepared
                try save(saved)
                try await client.checkBindingGeneration(generation)
            }
            return result
        }
        var intent = saved ?? PendingBroadcastIntent(channelID: channelID, broadcastID: eventID, profile: profile)
        guard intent.matches(channelID: channelID, broadcastID: eventID, profile: profile) else { throw YouTubeBindingError.pendingOtherContext }
        if intent.createdStreamID == nil {
            guard intent.phase == .notCreated else { throw YouTubeBindingError.unresolvedInsert }
            // Claim synchronously immediately before dispatch. A second workflow
            // instance cannot reuse an earlier nil/notCreated snapshot to insert.
            if let latest = try loadIntent(channelID: channelID, eventID: eventID),
               latest.operationID != intent.operationID || latest.phase != .notCreated {
                throw YouTubeBindingError.unresolvedInsert
            }
            intent.phase = .inserting
            try save(intent)
            do {
                let created = try await client.insertDedicatedStream(marker: intent.operationID, generation: generation)
                // Persist known mutation outcome BEFORE rejecting cancellation or
                // a changed account. The earlier inserting intent survives failure.
                intent.createdStreamID = created.id
                intent.phase = .created
                try save(intent)
                try await client.checkBindingGeneration(generation)
            } catch let error as YouTubeMutationError {
                if case .rejected = error { intent.phase = .notCreated }
                else { intent.phase = .unresolvedInsert }
                try save(intent)
                try await client.checkBindingGeneration(generation)
                if case .uncertain = error { throw YouTubeBindingError.unresolvedInsert }
                throw error
            } catch let error as YouTubeReadError {
                // Credential preflight failed before writeOnce dispatched a POST.
                intent.phase = .notCreated
                try save(intent)
                throw error
            } catch {
                if intent.createdStreamID == nil { intent.phase = .unresolvedInsert; try save(intent) }
                throw error
            }
        }
        guard let streamID = intent.createdStreamID, !streamID.isEmpty else { throw YouTubeBindingError.unresolvedInsert }
        _ = try await checkedStream(streamID, channelID, profile, generation, appCreated: true)
        try await dedicated(streamID: streamID, eventID: eventID, channelID: channelID, generation: generation)
        event = try await eligible(eventID, channelID, generation)
        if let bound = event.contentDetails?.boundStreamId, !bound.isEmpty {
            guard bound == streamID else { throw YouTubeBindingError.bindingConflict }
        } else {
            intent.phase = .binding
            try save(intent)
            do { _ = try await client.bindBroadcast(eventID: eventID, streamID: streamID, generation: generation) }
            catch {
                // A failed write is reconciled by ID; never retry the POST here.
                try await client.checkBindingGeneration(generation)
                guard let reconciled = try? await client.broadcast(id: eventID, channelID: channelID, generation: generation),
                      reconciled.contentDetails?.boundStreamId == streamID else { throw YouTubeBindingError.bindingUnconfirmed }
            }
        }
        let result = try await prepared(event: event, streamID: streamID, channelID: channelID, profile: profile,
                                        generation: generation, appCreated: true)
        intent.phase = .prepared
        try save(intent)
        try await client.checkBindingGeneration(generation)
        return result
    }

    private func eligible(_ eventID: String, _ channelID: String, _ generation: UInt64) async throws -> YouTubeBroadcast {
        let event = try await client.broadcast(id: eventID, channelID: channelID, generation: generation)
        guard event.ineligibility(channelID: channelID) == nil else { throw YouTubeBindingError.ineligibleEvent }
        return event
    }

    private func prepared(event: YouTubeBroadcast, streamID: String, channelID: String, profile: SessionProfile,
                          generation: UInt64, appCreated: Bool) async throws -> PreparedYouTubeIngestion {
        try await dedicated(streamID: streamID, eventID: event.id, channelID: channelID, generation: generation)
        let stream = try await checkedStream(streamID, channelID, profile, generation, appCreated: appCreated)
        let latest = try await eligible(event.id, channelID, generation)
        guard latest.contentDetails?.boundStreamId == streamID else { throw YouTubeBindingError.bindingConflict }
        return PreparedYouTubeIngestion(broadcast: latest, streamID: streamID, profile: profile, generation: generation,
                                        destination: try stream.destination(channelID: channelID, profile: profile, appCreated: appCreated))
    }

    private func checkedStream(_ id: String, _ channelID: String, _ profile: SessionProfile,
                               _ generation: UInt64, appCreated: Bool) async throws -> YouTubeIngestionStream {
        let stream = try await client.ingestionStream(id: id, channelID: channelID, generation: generation)
        _ = try stream.destination(channelID: channelID, profile: profile, appCreated: appCreated)
        return stream
    }

    private func dedicated(streamID: String, eventID: String, channelID: String, generation: UInt64) async throws {
        let events = try await client.allBroadcasts(channelID: channelID, generation: generation)
        guard events.contains(where: { $0.id == eventID }) else { throw YouTubeBindingError.dedicationUnknown }
        for other in events where other.id != eventID {
            if ["complete", "revoked"].contains(other.status?.lifeCycleStatus ?? "") { continue }
            guard ["created", "ready", "testStarting", "testing", "liveStarting", "live"].contains(other.status?.lifeCycleStatus ?? ""),
                  let details = other.contentDetails else { throw YouTubeBindingError.dedicationUnknown }
            if details.boundStreamId == streamID { throw YouTubeBindingError.sharedStream }
        }
    }

    private func loadIntent(channelID: String, eventID: String) throws -> PendingBroadcastIntent? {
        do { return try store.load(channelID: channelID, broadcastID: eventID) } catch { throw YouTubeBindingError.intentUnavailable }
    }
    private func save(_ intent: PendingBroadcastIntent) throws {
        do { try store.save(intent) } catch { throw YouTubeBindingError.intentUnavailable }
    }
}
