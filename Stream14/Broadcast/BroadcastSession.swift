import Foundation
import Observation

nonisolated struct BroadcastIntent: Equatable, Sendable, Identifiable, CustomReflectable {
    let id: UUID
    let generation: UInt64
    let channel: YouTubeChannel
    let event: YouTubeBroadcast
    let profile: SessionProfile
    let overlayURL: String
    var isResume = false
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
        var pipelineRunning: Bool = true
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
                overlayReady: session.broadcastOverlayReady, uploadFailed: session.uploadState == .failed,
                pipelineRunning: session.broadcastPipelineRunning)
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
    private(set) var requiresStudioResolution = false
    enum ReconnectStatus: Equatable { case inactive, monitoring, waiting, connecting, exhausted, authorizationRequired, stopped }
    private(set) var reconnectStatus: ReconnectStatus = .inactive
    private(set) var reconnectAttempts = 0
    @ObservationIgnored private var supervision: Task<Void, Never>?
    @ObservationIgnored private var readNotBefore: Double = 0
    @ObservationIgnored private var admitted: PreparedYouTubeIngestion?
    @ObservationIgnored private let reconnectClock: ReconnectClock
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
         startupSeconds: Double = 60, endSeconds: Double = 15, pollSeconds: Double = 2, writerSeconds: Double = 5, reconnectClock: ReconnectClock = ReconnectClock()) {
        self.authorization = authorization; self.client = client; self.binding = binding
        self.media = media; self.store = store; self.startupSeconds = startupSeconds
        self.endSeconds = endSeconds; self.pollSeconds = pollSeconds; self.writerSeconds = writerSeconds
        self.reconnectClock = reconnectClock
        authorization.onDeleteAPIData = { [weak self] in self?.eraseYouTubeAPIData() ?? false }
        requiresStudioResolution = store.requiresStudioResolution || binding.requiresStudioResolution
        do {
            let bindingExpired = try binding.expireStaleAPIData()
            let remoteExpired = try store.expireIfNeeded()
            requiresStudioResolution = requiresStudioResolution || bindingExpired || remoteExpired
            // Once IDs have been erased, the marker is the only reconciliation context.
            if requiresStudioResolution {
                // Retry an interrupted/failed deletion before permitting acknowledgement.
                try store.eraseAPIData()
                try binding.eraseAPIData()
                pendingRemote = nil
            } else { pendingRemote = try store.load() }
            if var context = pendingRemote {
                context.interrupted = true
                try store.save(context)
                pendingRemote = context
                state = .needsReconciliation
                message = "YouTube status is unknown after the previous session. Reconcile or inspect YouTube Studio before starting."
            }
            if requiresStudioResolution { message = Self.studioResolutionMessage }
        } catch {
            journalUnavailable = true
            message = "The pending YouTube session could not be read. Local rehearsal is available; resolve local storage before Go Live."
        }
    }

    convenience init(authorization: YouTubeAuthorization, media: MediaSession) {
        let client = YouTubeClient(authorization: authorization)
        self.init(authorization: authorization, client: client, binding: YouTubeBinding(client: client), media: BroadcastMedia(session: media))
        media.onInterruption = { [weak self] reason in self?.interrupted(reason) }
    }

    #if DEBUG
    func installInterfaceFixture(_ name: String, intent: BroadcastIntent) {
        switch name {
        case "reconnecting":
            state = .live; activeIntent = intent; reconnectStatus = .waiting
            message = "Reconnecting to the same event. Local recording continues while healthy."
        case "backup-failed":
            state = .live; activeIntent = intent
            message = "Live on YouTube. Local backup is unavailable."
        case "unknown-end":
            state = .needsReconciliation
            pendingRemote = PendingRemoteBroadcast(channelID: intent.channel.id, eventID: intent.event.id)
            message = "YouTube end not confirmed. The event may still be live. Check Studio and reconcile."
        case "ended":
            state = .ended
            message = "The YouTube event ended remotely. Healthy local recording continues. Stop recording when ready."
        default: break
        }
    }
    #endif

    var locksSelection: Bool { confirmation != nil || isWorking || activeIntent != nil || pendingRemote != nil }
    var requiresEndFirst: Bool { isWorking || [.starting, .waitingForIngestion, .goingLive, .live, .ending].contains(state) }
    var canResume: Bool { !isWorking && !hasUnsettledMutation && !journalUnavailable && !requiresStudioResolution && authorization.isAuthorized && pendingRemote?.interrupted == true && pendingRemote?.transition == nil && pendingRemote?.streamID != nil }
    var canStart: Bool { !isWorking && activeIntent == nil && pendingRemote == nil && !journalUnavailable && !requiresStudioResolution && authorization.isAuthorized }
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
        guard (intent.isResume ? canResume : canStart), confirmation?.id == intent.id else { return }
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
                beginSupervision(intent, request: request)
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
        if intent.isResume {
            guard let streamID = pendingRemote?.streamID else { throw StartError.changed }
            try sameBoundEvent(event, intent, streamID: streamID)
        } else { try sameConfirmedEvent(event, intent) }
        message = "Backup is writing. Preparing the confirmed YouTube event…"
        let prepared: PreparedYouTubeIngestion
        if intent.isResume {
            guard let context = pendingRemote, context.transition == nil, !hasUnsettledMutation else { throw StartError.remoteUnknown }
            prepared = try await binding.prepareResumeConfirmed(context: context, profile: intent.profile, generation: intent.generation)
        } else {
            prepared = try await binding.prepareConfirmed(eventID: intent.event.id, channelID: intent.channel.id,
                                                         profile: intent.profile, generation: intent.generation)
        }
        try check(intent, request)
        if intent.isResume { try sameBoundEvent(prepared.broadcast, intent, streamID: prepared.streamID) }
        else { try sameConfirmedEvent(prepared.broadcast, intent) }
        guard media.snapshot().writerStarted else { throw StartError.writer }
        // Persist BEFORE first possible publication, including auto-start. On a
        // crash/relaunch we read state rather than publishing or assuming idle.
        try setPending(PendingRemoteBroadcast(channelID: intent.channel.id, eventID: intent.event.id, interrupted: false, streamID: prepared.streamID, profileName: intent.profile.rawValue))
        message = "Connecting upload; YouTube has not confirmed Live."
        try await media.startUpload(prepared)
        try check(intent, request)
        admitted = prepared
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

    /// Called synchronously before MediaSession closes. Never asks YouTube to
    /// complete: iOS can suspend us and the remote event may remain live.
    func interrupted(_ reason: SessionInterruption) {
        confirmation = nil
        guard activeIntent != nil || pendingRemote != nil || isWorking else { return }
        cancelSupervision()
        epoch &+= 1
        operation?.cancel(); operation = nil; isWorking = false
        if var context = pendingRemote {
            context.interrupted = true
            do { try setPending(context) } catch { /* fail closed through journalUnavailable */ }
        } else { activeIntent = nil; media.lockConfiguration(false) }
        state = pendingRemote == nil ? .idle : .needsReconciliation
        message = reason.message + " Upload stopped and local writing is finalizing. YouTube end is unconfirmed. Reopen the camera explicitly; reconcile before resuming the same event."
    }

    /// Foreground/relaunch performs reads only; no capture, writer or upload.
    func foregroundReturned() {
        if pendingRemote?.interrupted == true, !isWorking { reconcile() }
    }

    /// The operator first reopens/checks preview. This button only reads and
    /// presents a new identity/visibility confirmation; it does not publish.
    func requestResumeConfirmation() {
        guard canResume, let context = pendingRemote else { return }
        let snapshot = media.snapshot()
        guard snapshot.captureReady, snapshot.canRecord, !snapshot.writerStarted,
              snapshot.overlayReady, snapshot.profile.rawValue == context.profileName else {
            message = "Reopen the camera, restore the original profile and check the overlay before resuming. A new backup file is required."
            return
        }
        epoch &+= 1
        let request = epoch; let generation = authorization.generation
        isWorking = true
        operation = Task {
            do {
                let result = try await withBroadcastDeadline(seconds: endSeconds) {
                    let channel = try await self.client.authorizedChannel(generation: generation)
                    guard channel.id == context.channelID else { throw YouTubeReadError.wrongChannel }
                    let prepared = try await self.binding.prepareResumeConfirmed(context: context, profile: snapshot.profile, generation: generation)
                    return (channel, prepared.broadcast)
                }
                try checkGeneration(request, generation)
                let latest = media.snapshot()
                guard latest.captureReady, latest.canRecord, !latest.writerStarted, latest.overlayReady,
                      latest.profile == snapshot.profile, latest.overlayURL == snapshot.overlayURL else { throw StartError.changed }
                confirmation = BroadcastIntent(id: UUID(), generation: generation, channel: result.0, event: result.1,
                    profile: snapshot.profile, overlayURL: snapshot.overlayURL, isResume: true)
                message = "Review the same event and visibility. Resume creates a new local backup before upload."
            } catch {
                guard request == epoch else { return }
                message = "This event cannot safely resume yet. Reconcile YouTube status and check the original inactive binding/profile in YouTube Studio. No media was published."
            }
            if request == epoch { isWorking = false; operation = nil }
        }
    }

    /// Startup cancellation preserves a healthy recording. It is not End broadcast.
    func cancelStartup() {
        guard isWorking, state != .ending else { return }
        cancelSupervision()
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
        cancelSupervision()
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
        cancelSupervision()
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
                    if context.interrupted == true, context.streamID != nil {
                        state = .needsReconciliation
                        message = "The same event is upcoming and ingestion inactive. Reopen the camera and explicitly Resume, or confirm End/check YouTube Studio."
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

    private static let studioResolutionMessage = "Saved YouTube data was deleted. Previous requests may still exist in YouTube Studio. Resolve their events/streams there, then explicitly confirm resolution before publishing again. Local recording remains available."

    /// Called on explicit deletion/revoke or detected access loss. Persist the
    /// global nonidentifying guard before erasing identifiers or cancelling work.
    @discardableResult func eraseYouTubeAPIData() -> Bool {
        let needsGuard = requiresStudioResolution || store.requiresStudioResolution || binding.requiresStudioResolution ||
            store.hasSavedAPIData || binding.hasSavedAPIData || activeIntent != nil || pendingRemote != nil ||
            hasUnsettledMutation || binding.isPreparing
        requiresStudioResolution = needsGuard
        var erased = true
        do { try store.eraseAPIData(requiringStudioResolution: needsGuard) } catch { erased = false }
        do { try binding.eraseAPIData(requiringStudioResolution: needsGuard) } catch { erased = false }
        cancelSupervision(); epoch &+= 1; operation?.cancel()
        confirmation = nil; activeIntent = nil; pendingRemote = nil; admitted = nil
        isWorking = true; state = needsGuard ? .needsReconciliation : .idle
        journalUnavailable = !erased
        media.lockConfiguration(false)
        let request = epoch
        operation = Task {
            await media.stopUpload()
            if request == epoch { isWorking = false; operation = nil }
        }
        message = erased ? (needsGuard ? Self.studioResolutionMessage : "No saved YouTube request remains. Local recording is available.") :
            "YouTube data could not be completely deleted. Publishing is blocked. Resolve local storage and retry deletion; local recordings remain."
        return erased
    }

    /// This explicit owner acknowledgement is the only way to remove the erased
    /// context's guard. Never inferred from reconnecting, selecting, or relaunch.
    func confirmDeletedDataResolvedInStudio() {
        guard requiresStudioResolution, !journalUnavailable, !isWorking,
              !hasUnsettledMutation, !binding.isPreparing else { return }
        do {
            try store.confirmStudioResolution()
            try binding.confirmStudioResolution()
            requiresStudioResolution = false
            state = .idle
            message = "You confirmed previous YouTube requests were resolved in Studio. Refresh and review a new event before Go Live."
        } catch {
            journalUnavailable = true
            message = "The Studio resolution guard could not be cleared. Resolve local storage and retry data deletion."
        }
    }

    /// Called on activation even when the owner uses only local rehearsal.
    func expireStoredYouTubeData() {
        do {
            let bindingExpired = try binding.expireStaleAPIData()
            let remoteExpired = try store.expireIfNeeded()
            if bindingExpired || remoteExpired { eraseYouTubeAPIData() }
        } catch {
            journalUnavailable = true
            message = "Saved YouTube data could not be checked or expired. Publishing is blocked; resolve local storage and retry deletion."
        }
    }

    var canDeleteYouTubeData: Bool { !requiresEndFirst && !hasUnsettledMutation && !binding.isPreparing }

    func accountChanged() {
        confirmation = nil
        guard let intent = activeIntent, intent.generation != authorization.generation else { return }
        cancelSupervision()
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

    /// Explicit retry repeats transport only, with the original frozen identity.
    func retryUpload() {
        guard !isWorking, !hasUnsettledMutation, reconnectStatus == .exhausted,
              let intent = activeIntent, admitted != nil,
              intent.generation == authorization.generation, authorization.isAuthorized else { return }
        guard reconnectClock.now() >= readNotBefore else {
            message = "YouTube requested a longer wait. Upload retry is paused; healthy local recording continues."
            return
        }
        beginSupervision(intent, request: epoch)
    }

    func cancelReconnect() {
        let previous = supervision
        cancelSupervision()
        reconnectStatus = .stopped
        message = "Upload recovery stopped. Healthy local recording continues; End and Stop recording remain available."
        let request = epoch
        supervision = Task {
            await previous?.value
            guard request == epoch else { return }
            await media.stopUpload()
        }
    }

    private func cancelSupervision() {
        supervision?.cancel(); supervision = nil
        reconnectStatus = .inactive
    }

    private func beginSupervision(_ intent: BroadcastIntent, request: UInt64) {
        supervision?.cancel()
        reconnectAttempts = 0
        reconnectStatus = .monitoring
        supervision = Task { await supervise(intent, request: request) }
    }

    private func supervise(_ intent: BroadcastIntent, request: UInt64) async {
        guard let original = admitted else { return }
        var nextRead = reconnectClock.now() + 10
        var outageStart: Double?
        var readFailures = 0
        do {
            while true {
                try checkGeneration(request, intent.generation)
                let snapshot = media.snapshot()
                guard snapshot.pipelineRunning, snapshot.profile == intent.profile,
                      snapshot.overlayURL == intent.overlayURL else { throw StartError.changed }
                let failed = snapshot.uploadFailed
                if failed, outageStart == nil { outageStart = reconnectClock.now() }
                if failed {
                    guard reconnectAttempts < 12, reconnectClock.now() - outageStart! < 180 else {
                        reconnectStatus = .exhausted
                        message = "Upload retries exhausted. Healthy local recording continues. Retry upload to the same event, or stop recording."
                        return
                    }
                    reconnectStatus = .waiting
                    let delay = ReconnectClock.delay(attempt: reconnectAttempts, jitter: reconnectClock.jitter())
                    reconnectAttempts += 1
                    message = "Upload interrupted. Retrying the same YouTube event (\(reconnectAttempts)/12). Healthy local recording continues."
                    try await reconnectClock.sleep(delay)
                    try checkGeneration(request, intent.generation)
                } else if reconnectClock.now() < nextRead {
                    try await reconnectClock.sleep(1)
                    continue
                }
                do {
                    let prepared = try await reconnectDestination(intent, original: original, request: request)
                    readFailures = 0
                    if failed {
                        guard reconnectClock.now() - outageStart! < 180 else { continue }
                        reconnectStatus = .connecting
                        try await media.startUpload(prepared)
                        try checkGeneration(request, intent.generation)
                        outageStart = nil; reconnectAttempts = 0
                        message = "Upload reconnected to the same event. YouTube status was read separately; check the receiver."
                    }
                    reconnectStatus = .monitoring
                    nextRead = reconnectClock.now() + 10
                } catch {
                    try checkGeneration(request, intent.generation)
                    if isPermanentSupervisionError(error) { throw error }
                    readFailures += 1
                    let serverDelay = (error as? YouTubeReadBackoff)?.seconds ?? 0
                    readNotBefore = reconnectClock.now() + serverDelay
                    let delay = max(serverDelay, min(60, 10 * pow(2, Double(min(readFailures - 1, 3)))))
                    message = "YouTube status is temporarily unavailable. Healthy upload and local recording continue independently."
                    // Respect server delay without an unbounded automatic reconnect.
                    if failed, reconnectClock.now() + delay - outageStart! >= 180 {
                        try await reconnectClock.sleep(max(0, 180 - (reconnectClock.now() - outageStart!)))
                        reconnectAttempts = 12
                    } else {
                        try await reconnectClock.sleep(delay)
                    }
                    nextRead = reconnectClock.now()
                }
            }
        } catch is CancellationError { return }
        catch {
            guard request == epoch else { return }
            let auth = (error as? YouTubeReadError) == .authorizationRequired
            reconnectStatus = auth ? .authorizationRequired : .stopped
            if !auth || media.snapshot().uploadFailed { await media.stopUpload() }
            guard request == epoch else { return }
            state = .needsReconciliation
            message = auth
                ? "YouTube authorization needs attention. Automatic retries stopped; an existing healthy upload and local recording are preserved. No sign-in opens automatically."
                : "The original YouTube event ended, disappeared or changed. Upload stopped; healthy local recording continues. Inspect YouTube Studio and reconcile."
        }
    }

    private func reconnectDestination(_ intent: BroadcastIntent, original: PreparedYouTubeIngestion,
                                      request: UInt64) async throws -> PreparedYouTubeIngestion {
        try await checkRemote(PendingRemoteBroadcast(channelID: intent.channel.id, eventID: intent.event.id),
                              generation: intent.generation, request: request)
        let event = try await client.broadcast(id: intent.event.id, channelID: intent.channel.id, generation: intent.generation)
        try checkGeneration(request, intent.generation)
        if ["complete", "revoked"].contains(event.status?.lifeCycleStatus ?? "") { throw StartError.ended }
        try sameBoundEvent(event, intent, streamID: original.streamID)
        guard ["ready", "testing", "testStarting", "liveStarting", "live"].contains(event.status?.lifeCycleStatus ?? "") else { throw StartError.remoteUnknown }
        let stream = try await client.ingestionStream(id: original.streamID, channelID: intent.channel.id, generation: intent.generation)
        try checkGeneration(request, intent.generation)
        // This is an already-admitted stream. Active ingestion is expected during
        // recovery; the initial preparation's inactive-only gate is inappropriate.
        guard ["inactive", "ready", "active"].contains(stream.status?.streamStatus ?? ""),
              stream.cdn?.ingestionType == "rtmp",
              (stream.cdn?.resolution == "variable" && stream.cdn?.frameRate == "variable") ||
                (stream.cdn?.resolution == (intent.profile == .hd ? "720p" : "1080p") && stream.cdn?.frameRate == "30fps") else { throw StartError.changed }
        let destination = try YouTubeIngestionDestination(address: stream.cdn?.ingestionInfo?.rtmpsIngestionAddress,
                                                         streamName: stream.cdn?.ingestionInfo?.streamName)
        guard destination.endpoint == original.destination.endpoint, destination.streamName == original.destination.streamName else { throw StartError.changed }
        // A socket never establishes Live. This value comes only from this read.
        if event.status?.lifeCycleStatus == "live" { state = .live }
        else { state = .waitingForIngestion }
        return PreparedYouTubeIngestion(broadcast: event, streamID: original.streamID, profile: intent.profile,
                                        generation: intent.generation, destination: destination)
    }

    private func isPermanentSupervisionError(_ error: any Error) -> Bool {
        if let error = error as? StartError { return error == .ended || error == .changed }
        if let error = error as? YouTubeBindingError { return error == .invalidDestination }
        guard let error = error as? YouTubeReadError else { return false }
        return ![.network, .rateLimited, .unavailable, .malformedResponse].contains(error)
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
        var context = context
        if var next = context, let previous = pendingRemote,
           next.channelID == previous.channelID, next.eventID == previous.eventID {
            next.streamID = next.streamID ?? previous.streamID
            next.profileName = next.profileName ?? previous.profileName
            next.interrupted = next.interrupted ?? previous.interrupted
            context = next
        }
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

/// Focused monotonic scheduling seam. No wall-clock persistence or retry framework.
@MainActor struct ReconnectClock {
    var now: () -> Double = { ProcessInfo.processInfo.systemUptime }
    var sleep: (Double) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
    var jitter: () -> Double = { Double.random(in: 0.8...1.2) }
    nonisolated static func delay(attempt: Int, jitter: Double) -> Double {
        min(30, pow(2, Double(min(max(0, attempt), 5))) * min(1.2, max(0.8, jitter)))
    }
}
