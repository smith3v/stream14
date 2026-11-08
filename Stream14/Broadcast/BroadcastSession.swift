import Foundation
import Observation

nonisolated struct BroadcastIntent: Equatable, Sendable, Identifiable, CustomReflectable {
    let id: UUID
    let generation: UInt64
    let channel: YouTubeChannel
    let event: YouTubeBroadcast
    let profile: SessionProfile
    let overlayURL: String
    var customMirror: Mirror { Mirror(self, children: ["eventID": event.id, "overlay": "<redacted>"]) }
}

/// A narrow fixture boundary, not another capture implementation. The production
/// initializer below captures the exact MediaSession also displayed by SetupView.
@MainActor struct BroadcastMedia {
    struct Snapshot: Equatable {
        var captureReady: Bool
        var canRecord: Bool
        var writerStarted: Bool
        var isRecording: Bool
        var profile: SessionProfile
        var overlayURL: String
        var overlayReady: Bool
        var uploadFailed: Bool
    }
    let snapshot: () -> Snapshot
    let record: () async -> Void
    let startUpload: (PreparedYouTubeIngestion) async throws -> Void
    let stopUpload: () async -> Void
    let stopAll: () -> Void
    let lockConfiguration: (Bool) -> Void

    init(session: MediaSession) {
        snapshot = {
            Snapshot(captureReady: session.broadcastCaptureReady, canRecord: session.canRecord,
                writerStarted: session.hasStartedWriting, isRecording: session.isRecording,
                profile: session.profile, overlayURL: session.overlayURL,
                overlayReady: session.broadcastOverlayReady, uploadFailed: session.uploadState == .failed)
        }
        record = { await session.record() }
        startUpload = { try await session.startUpload($0) }
        stopUpload = { await session.stopUpload() }
        stopAll = { session.requestStop() }
        lockConfiguration = { session.broadcastConfigurationLocked = $0 }
    }

    init(snapshot: @escaping () -> Snapshot, record: @escaping () async -> Void,
         startUpload: @escaping (PreparedYouTubeIngestion) async throws -> Void,
         stopUpload: @escaping () async -> Void, stopAll: @escaping () -> Void,
         lockConfiguration: @escaping (Bool) -> Void) {
        self.snapshot = snapshot; self.record = record; self.startUpload = startUpload
        self.stopUpload = stopUpload; self.stopAll = stopAll; self.lockConfiguration = lockConfiguration
    }
}

@MainActor @Observable final class BroadcastSession {
    enum State: Equatable { case idle, starting, waitingForIngestion, goingLive, live, needsReconciliation, ending, ended }
    private(set) var state: State = .idle
    private(set) var message = "Local rehearsal is available. Go Live requires a selected YouTube event and confirmation."
    private(set) var confirmation: BroadcastIntent?
    private(set) var activeIntent: BroadcastIntent?
    private(set) var pendingRemote: PendingRemoteBroadcast?
    private(set) var isWorking = false
    private(set) var journalUnavailable = false
    @ObservationIgnored private let authorization: YouTubeAuthorization
    @ObservationIgnored private let client: YouTubeClient
    @ObservationIgnored private let binding: YouTubeBinding
    @ObservationIgnored private let media: BroadcastMedia
    @ObservationIgnored private let store: PendingRemoteBroadcastStore
    @ObservationIgnored private var operation: Task<Void, Never>?
    private var epoch: UInt64 = 0
    private var unsettledMutations: Set<UUID> = []
    var hasUnsettledMutation: Bool { !unsettledMutations.isEmpty }
    private let startupSeconds: Double
    private let endSeconds: Double
    private let pollSeconds: Double
    private let writerSeconds: Double

    init(authorization: YouTubeAuthorization, client: YouTubeClient, binding: YouTubeBinding,
         media: BroadcastMedia, store: PendingRemoteBroadcastStore = PendingRemoteBroadcastStore(),
         startupSeconds: Double = 60, endSeconds: Double = 15, pollSeconds: Double = 2, writerSeconds: Double = 5) {
        self.authorization = authorization; self.client = client; self.binding = binding
        self.media = media; self.store = store; self.startupSeconds = startupSeconds
        self.endSeconds = endSeconds; self.pollSeconds = pollSeconds; self.writerSeconds = writerSeconds
        do {
            pendingRemote = try store.load()
            if pendingRemote != nil {
                state = .needsReconciliation
                message = "YouTube status is unknown after the previous session. Reconcile or inspect YouTube Studio before starting."
            }
        } catch {
            journalUnavailable = true
            message = "The pending YouTube session could not be read. Local rehearsal is available; resolve local storage before Go Live."
        }
    }

    convenience init(authorization: YouTubeAuthorization, media: MediaSession) {
        let client = YouTubeClient(authorization: authorization)
        self.init(authorization: authorization, client: client, binding: YouTubeBinding(client: client), media: BroadcastMedia(session: media))
    }

    var locksSelection: Bool { confirmation != nil || isWorking || activeIntent != nil || pendingRemote != nil }
    var requiresEndFirst: Bool { isWorking || [.starting, .waitingForIngestion, .goingLive, .live, .ending].contains(state) }
    var canStart: Bool { !isWorking && activeIntent == nil && pendingRemote == nil && !journalUnavailable && authorization.isAuthorized }
    var canEnd: Bool { !isWorking || state != .ending }

    /// UI calls this before displaying the confirmation. No API/media work here.
    func requestConfirmation(channel: YouTubeChannel?, event: YouTubeBroadcast?) {
        guard canStart, let channel, let event, event.ineligibility(channelID: channel.id) == nil else { return }
        let snapshot = media.snapshot()
        guard snapshot.captureReady, snapshot.canRecord || snapshot.writerStarted else {
            message = "Open the camera and check the preview before Go Live."; return
        }
        guard snapshot.overlayReady else {
            message = "The configured overlay is unavailable. Wait for a fresh render, or explicitly disable its URL and recheck the preview."; return
        }
        confirmation = BroadcastIntent(id: UUID(), generation: authorization.generation, channel: channel, event: event,
                                       profile: snapshot.profile, overlayURL: snapshot.overlayURL)
    }

    func dismissConfirmation() { confirmation = nil }

    /// Only the explicit confirmation button invokes this method.
    func confirmStart(_ intent: BroadcastIntent) {
        guard canStart, confirmation?.id == intent.id else { return }
        confirmation = nil; activeIntent = intent
        epoch &+= 1
        let request = epoch
        isWorking = true; state = .starting
        media.lockConfiguration(true)
        message = "Starting the local backup before YouTube preparation…"
        operation = Task {
            do {
                try await withBroadcastDeadline(seconds: startupSeconds) {
                    do { try await self.start(intent, request: request) }
                    catch {
                        // Includes cancellation while the transport was connecting.
                        // This runs after startUpload unwinds its own guarded attach.
                        if self.activeIntent?.id == intent.id { await self.media.stopUpload() }
                        throw error
                    }
                }
                guard request == epoch else { return }
                state = .live
                message = "YouTube confirmed Live. Check the receiver picture and sound."
            } catch {
                guard request == epoch else { return }
                await media.stopUpload()
                state = pendingRemote == nil ? .idle : .needsReconciliation
                if pendingRemote == nil { activeIntent = nil; media.lockConfiguration(false) }
                message = startupMessage(error)
            }
            if request == epoch { isWorking = false; operation = nil }
        }
    }

    private func start(_ intent: BroadcastIntent, request: UInt64) async throws {
        try check(intent, request)
        if !media.snapshot().writerStarted {
            guard media.snapshot().canRecord else { throw StartError.writer }
            await media.record()
            try check(intent, request)
            let deadline = ContinuousClock.now.advanced(by: .seconds(writerSeconds))
            while !media.snapshot().writerStarted {
                guard media.snapshot().isRecording, ContinuousClock.now < deadline else { throw StartError.writer }
                try await Task.sleep(for: .milliseconds(50))
                try check(intent, request)
            }
        }
        guard media.snapshot().writerStarted else { throw StartError.writer }
        let channel = try await client.authorizedChannel(generation: intent.generation)
        try check(intent, request)
        guard channel == intent.channel else { throw StartError.changed }
        let event = try await client.broadcast(id: intent.event.id, channelID: intent.channel.id, generation: intent.generation)
        try check(intent, request)
        try sameConfirmedEvent(event, intent)
        message = "Backup is writing. Preparing the confirmed YouTube event…"
        let prepared = try await binding.prepareConfirmed(eventID: intent.event.id, channelID: intent.channel.id,
                                                         profile: intent.profile, generation: intent.generation)
        try check(intent, request)
        try sameConfirmedEvent(prepared.broadcast, intent)
        guard media.snapshot().writerStarted else { throw StartError.writer }
        // Persist BEFORE first possible publication, including auto-start. On a
        // crash/relaunch we read state rather than publishing or assuming idle.
        try setPending(PendingRemoteBroadcast(channelID: intent.channel.id, eventID: intent.event.id))
        message = "Connecting upload; YouTube has not confirmed Live."
        try await media.startUpload(prepared)
        try check(intent, request)
        state = .waitingForIngestion
        var transitionSent = false
        while true {
            try check(intent, request)
            guard !media.snapshot().uploadFailed else { throw StartError.upload }
            let current = try await client.broadcast(id: intent.event.id, channelID: intent.channel.id, generation: intent.generation)
            try check(intent, request)
            try sameBoundEvent(current, intent, streamID: prepared.streamID)
            switch current.status?.lifeCycleStatus {
            case "live":
                try setPending(PendingRemoteBroadcast(channelID: intent.channel.id, eventID: intent.event.id))
                return
            case "complete", "revoked": throw StartError.ended
            case "ready", "created", "testing", "testStarting", "liveStarting": break
            default: throw StartError.remoteUnknown
            }
            let stream = try await client.stream(id: prepared.streamID, channelID: intent.channel.id, generation: intent.generation)
            try check(intent, request)
            if stream.status?.streamStatus == "error" { throw StartError.upload }
            if intent.event.contentDetails?.enableAutoStart == false, stream.status?.streamStatus == "active",
               !transitionSent, ["ready", "testing"].contains(current.status?.lifeCycleStatus ?? "") {
                transitionSent = true // claim before awaiting; ambiguous writes are never resent here
                state = .goingLive; message = "Ingestion active. Requesting Live; waiting for YouTube confirmation…"
                do {
                    _ = try await transition(PendingRemoteBroadcast(channelID: intent.channel.id, eventID: intent.event.id),
                                             to: .live, generation: intent.generation)
                } catch {
                    try check(intent, request)
                    // A rejection or lost response can race a remote transition.
                    // Read on the next iteration, never repeat the POST blindly.
                    if case YouTubeMutationError.rejected(let error) = error { message = error.localizedDescription }
                }
            }
            try await Task.sleep(for: .seconds(pollSeconds))
        }
    }

    /// Startup cancellation preserves a healthy recording. It is not End broadcast.
    func cancelStartup() {
        guard isWorking, state != .ending else { return }
        epoch &+= 1
        let request = epoch
        let previous = operation
        previous?.cancel()
        confirmation = nil
        state = pendingRemote == nil ? .idle : .needsReconciliation
        message = "YouTube startup cancelled. Healthy local recording continues. Reconcile any attempted upload in YouTube Studio."
        operation = Task {
            await previous?.value
            await media.stopUpload()
            guard request == epoch else { return }
            isWorking = false; operation = nil
            if pendingRemote == nil { activeIntent = nil; media.lockConfiguration(false) }
        }
    }

    /// Invoked only by the confirmation dialog naming the frozen/pending event.
    /// Whole-session stop is dispatched before remote work and never awaits it.
    func confirmEnd() {
        guard state != .ending, let context = pendingRemote ?? activeIntent.map({ PendingRemoteBroadcast(channelID: $0.channel.id, eventID: $0.event.id) }) else { return }
        epoch &+= 1
        let request = epoch
        operation?.cancel()
        confirmation = nil
        media.stopAll()
        state = .ending; isWorking = true
        message = "Stopping local capture and finalizing the file. Checking YouTube completion…"
        let generation = authorization.generation
        operation = Task {
            do {
                // Retain the identity even when startup had not reached publish.
                if pendingRemote == nil { try setPending(context) }
                try await withBroadcastDeadline(seconds: endSeconds) {
                    try await self.endRemote(context, generation: generation, request: request)
                }
                guard request == epoch else { return }
                try setPending(nil)
                activeIntent = nil; state = .ended
                message = "YouTube confirmed the event ended. Local file status is shown separately."
            } catch {
                guard request == epoch else { return }
                state = .needsReconciliation
                message = "YouTube end not confirmed. Local capture is stopping independently. Check YouTube Studio, then reconcile before retrying End."
            }
            if request == epoch { isWorking = false; operation = nil; media.lockConfiguration(false) }
        }
    }

    private func endRemote(_ context: PendingRemoteBroadcast, generation: UInt64, request: UInt64) async throws {
        try await checkRemote(context, generation: generation, request: request)
        let before = try await client.broadcast(id: context.eventID, channelID: context.channelID, generation: generation)
        try checkGeneration(request, generation)
        if before.status?.lifeCycleStatus == "complete" { return }
        guard ["live", "liveStarting", "testing", "testStarting"].contains(before.status?.lifeCycleStatus ?? "") else { throw StartError.remoteUnknown }
        guard !hasUnsettledMutation else { throw StartError.remoteUnknown }
        do {
            _ = try await transition(context, to: .complete, generation: generation)
        } catch { try checkGeneration(request, generation) }
        // A successful mutation response is not final confirmation. Always read.
        while true {
            let current = try await client.broadcast(id: context.eventID, channelID: context.channelID, generation: generation)
            try checkGeneration(request, generation)
            if current.status?.lifeCycleStatus == "complete" { return }
            guard ["live", "liveStarting", "testing", "testStarting"].contains(current.status?.lifeCycleStatus ?? "") else { throw StartError.remoteUnknown }
            try await Task.sleep(for: .seconds(pollSeconds))
        }
    }

    /// Read only, including after relaunch. Never retries a mutation or reconnects.
    func reconcile() {
        guard !isWorking, let context = pendingRemote, authorization.isAuthorized else { return }
        guard !hasUnsettledMutation else {
            message = "A previous YouTube transition is still awaiting an outcome. Wait for it to settle, then reconcile; no new request was sent."
            return
        }
        epoch &+= 1
        let request = epoch; let generation = authorization.generation
        isWorking = true
        operation = Task {
            do {
                let result = try await withBroadcastDeadline(seconds: endSeconds) {
                    try await self.checkRemote(context, generation: generation, request: request)
                    let event = try await self.client.broadcast(id: context.eventID, channelID: context.channelID, generation: generation)
                    try self.checkGeneration(request, generation)
                    if ["created", "ready"].contains(event.status?.lifeCycleStatus ?? "") {
                        guard let streamID = event.contentDetails?.boundStreamId, !streamID.isEmpty else { throw StartError.remoteUnknown }
                        let stream = try await self.client.stream(id: streamID, channelID: context.channelID, generation: generation)
                        try self.checkGeneration(request, generation)
                        guard stream.status?.streamStatus == "inactive" || stream.status?.streamStatus == "ready" else { throw StartError.remoteUnknown }
                    }
                    return event
                }
                guard request == epoch else { return }
                switch result.status?.lifeCycleStatus {
                case "complete", "revoked":
                    try setPending(nil); activeIntent = nil; state = .ended
                    message = "YouTube confirms this event is finished. No upload was started."
                    media.lockConfiguration(false)
                case "created", "ready":
                    // An uncertain POST can apply after a currently-upcoming read,
                    // including after process death. Keep its durable barrier.
                    guard context.transition == nil else {
                        state = .needsReconciliation
                        message = "A previous YouTube transition has an unknown outcome. The event is currently upcoming; this does not prove the request cannot still apply. Resolve this event in YouTube Studio, then reconcile."
                        break
                    }
                    try setPending(nil); activeIntent = nil; state = .idle
                    message = "YouTube confirms the event is upcoming and ingestion inactive. Review and confirm Go Live again to start."
                    media.lockConfiguration(false)
                case "live":
                    if context.transition == .live {
                        try setPending(PendingRemoteBroadcast(channelID: context.channelID, eventID: context.eventID))
                    }
                    state = .needsReconciliation
                    message = "YouTube confirms the event is still Live. Upload is shown separately; confirm End or inspect YouTube Studio."
                default: throw StartError.remoteUnknown
                }
            } catch {
                guard request == epoch else { return }
                state = .needsReconciliation
                message = "YouTube status is unavailable or still changing. No new upload was started. Check YouTube Studio and reconcile again."
            }
            if request == epoch { isWorking = false; operation = nil }
        }
    }

    func accountChanged() {
        confirmation = nil
        guard let intent = activeIntent, intent.generation != authorization.generation else { return }
        epoch &+= 1
        operation?.cancel()
        isWorking = false
        operation = Task {
            // The cancelled start task owns any in-flight connection; F6 checks
            // cancellation before publishing/attaching. Do not stop a new intent.
            if activeIntent?.id == intent.id { await media.stopUpload() }
        }
        if pendingRemote == nil {
            activeIntent = nil; media.lockConfiguration(false); state = .idle
        } else { state = .needsReconciliation }
        message = "The YouTube account changed. Upload stopped; healthy local recording continues. Reconnect to the original channel and reconcile any attempted upload."
    }

    func waitForOperation() async { await operation?.value }

    private func check(_ intent: BroadcastIntent, _ request: UInt64) throws {
        try checkGeneration(request, intent.generation)
        let snapshot = media.snapshot()
        guard snapshot.captureReady, snapshot.profile == intent.profile, snapshot.overlayURL == intent.overlayURL else { throw StartError.changed }
        guard snapshot.overlayReady else { throw StartError.overlay }
    }
    private func checkGeneration(_ request: UInt64, _ generation: UInt64) throws {
        try Task.checkCancellation()
        guard request == epoch, generation == authorization.generation, authorization.isAuthorized else { throw CancellationError() }
    }
    private func checkRemote(_ context: PendingRemoteBroadcast, generation: UInt64, request: UInt64) async throws {
        try checkGeneration(request, generation)
        let channel = try await client.authorizedChannel(generation: generation)
        try checkGeneration(request, generation)
        guard channel.id == context.channelID else { throw YouTubeReadError.wrongChannel }
    }
    private func sameConfirmedEvent(_ event: YouTubeBroadcast, _ intent: BroadcastIntent) throws {
        guard event.ineligibility(channelID: intent.channel.id) == nil,
              event.title == intent.event.title, event.status?.privacyStatus == intent.event.status?.privacyStatus,
              event.contentDetails?.enableAutoStart == intent.event.contentDetails?.enableAutoStart else { throw StartError.changed }
    }
    private func sameBoundEvent(_ event: YouTubeBroadcast, _ intent: BroadcastIntent, streamID: String) throws {
        guard event.contentDetails?.boundStreamId == streamID, event.contentDetails?.enableAutoStop == false,
              event.title == intent.event.title, event.status?.privacyStatus == intent.event.status?.privacyStatus,
              event.contentDetails?.enableAutoStart == intent.event.contentDetails?.enableAutoStart else { throw StartError.changed }
    }
    /// Claim both a durable ambiguity marker and a RAM outstanding-request gate
    /// before dispatch. A deadline cancels the caller but does not settle this
    /// request; only its actual return removes the RAM gate. Unknown live writes
    /// remain durable until a read observes live/terminal, even after relaunch.
    private func transition(_ context: PendingRemoteBroadcast, to target: YouTubeBroadcastTransition,
                            generation: UInt64) async throws -> YouTubeBroadcast {
        guard !hasUnsettledMutation else { throw StartError.remoteUnknown }
        let id = UUID()
        var claimed = context
        claimed.transition = target; claimed.mutationID = id
        try setPending(claimed)
        unsettledMutations.insert(id)
        defer { unsettledMutations.remove(id) }
        do {
            return try await client.transitionBroadcast(eventID: context.eventID, channelID: context.channelID,
                                                        to: target, generation: generation)
        } catch {
            if case YouTubeMutationError.rejected = error, pendingRemote?.mutationID == id {
                // A definite HTTP rejection did not apply this write. An unknown
                // outcome (timeout, lost response or cancelled read) keeps it.
                try setPending(PendingRemoteBroadcast(channelID: context.channelID, eventID: context.eventID))
            }
            throw error
        }
    }

    private func setPending(_ context: PendingRemoteBroadcast?) throws {
        do { try store.save(context); pendingRemote = context; journalUnavailable = false }
        catch { journalUnavailable = true; throw StartError.journal }
    }
    private enum StartError: Error { case writer, changed, overlay, upload, ended, remoteUnknown, journal }
    private func startupMessage(_ error: any Error) -> String {
        let suffix = " Healthy local recording continues while available; Stop recording remains available."
        if error is BroadcastDeadlineError { return "YouTube startup timed out. Upload stopped; reconcile before trying again." + suffix }
        if let error = error as? YouTubeReadError { return error.localizedDescription + suffix }
        if let error = error as? YouTubeBindingError { return error.localizedDescription + suffix }
        switch error as? StartError {
        case .writer: return "The local backup did not initialize. No media was published. Inspect the local recording status."
        case .changed: return "The confirmed account, event or media settings changed. Review and confirm again." + suffix
        case .overlay: return "The configured overlay is unavailable. Explicitly disable it or wait for recovery, then review again." + suffix
        case .journal: return "The pending session could not be saved. No new upload can start until local storage is available." + suffix
        case .ended: return "YouTube reports the event has finished. Upload stopped; choose no replacement automatically." + suffix
        default: return "YouTube startup could not be confirmed. Check YouTube Studio and reconcile any attempted upload." + suffix
        }
    }
}
