import Foundation
import Testing
import UIKit
@testable import Stream14

@MainActor @Suite(.serialized, .timeLimit(.minutes(1))) struct BroadcastSessionTests {
    @Test func reconnectDelayIsPositiveCappedAndJitterBounded() {
        #expect(ReconnectClock.delay(attempt: 0, jitter: 0) == 0.8)
        #expect(ReconnectClock.delay(attempt: 1, jitter: 10) == 2.4)
        #expect(ReconnectClock.delay(attempt: 40, jitter: 1.2) == 30)
    }

    @Test func twoMinuteOutageRecoversSameEventWithoutRepeatingLiveOrStoppingFile() async throws {
        let h = try await Harness(fastClock: true)
        defer { h.cleanup() }
        h.start(); await h.session.waitForOperation()
        h.snapshot.uploadFailed = true; h.uploaded = false
        h.rejectUntil = 120
        try await h.until { h.timeline.filter { $0 == "upload" }.count > 1 && h.uploaded }
        #expect(h.elapsed >= 120 && h.elapsed < 180)
        #expect(h.snapshot.writerStarted && h.snapshot.isRecording)
        #expect(!h.timeline.contains("stopAll"))
        #expect(h.server.transitions == ["live"])
        #expect(h.session.reconnectStatus == .monitoring)
        #expect(h.server.requests.filter { $0.httpMethod == "POST" }.count == 1)
    }

    @Test func exhaustedRecoveryPreservesFileAndExplicitRetryOnlyUsesOriginalEvent() async throws {
        let h = try await Harness(fastClock: true)
        defer { h.cleanup() }
        h.start(); await h.session.waitForOperation()
        h.snapshot.uploadFailed = true; h.uploaded = false; h.rejectUpload = true
        try await h.until { h.session.reconnectStatus == .exhausted }
        #expect(h.elapsed >= 180)
        #expect(h.session.reconnectAttempts <= 12)
        #expect(h.snapshot.isRecording && !h.timeline.contains("stopAll"))
        h.rejectUpload = false
        h.session.retryUpload()
        try await h.until { h.uploaded }
        #expect(h.server.transitions == ["live"])
    }

    @Test func supervisionStopsChangedOrCompletedEventButPreservesFile() async throws {
        for change in ["complete", "binding", "missing"] {
            let h = try await Harness(fastClock: true)
            defer { h.cleanup() }
            h.start(); await h.session.waitForOperation()
            if change == "complete" { h.server.remoteState = "complete" }
            if change == "binding" { h.server.boundStreamID = "replacement" }
            if change == "missing" { h.server.failure = "missing" }
            try await h.until { h.session.reconnectStatus == .stopped }
            #expect(!h.uploaded && h.snapshot.isRecording)
            #expect(!h.timeline.contains("stopAll"))
            #expect(h.server.transitions == ["live"])
        }
    }

    @Test func failedStatusReadAndAuthorizationAttentionPreserveHealthyTransport() async throws {
        for failure in ["network", "auth"] {
            let h = try await Harness(fastClock: true)
            defer { h.cleanup() }
            h.start(); await h.session.waitForOperation()
            h.server.failure = failure
            try await h.until { h.elapsed > 30 || h.session.reconnectStatus == .authorizationRequired }
            #expect(h.uploaded && h.snapshot.isRecording)
            #expect(!h.timeline.contains("stopAll"))
            if failure == "auth" { #expect(h.session.reconnectStatus == .authorizationRequired) }
        }
    }

    @Test func heldFileFinalizationDoesNotEndActualPipelineSupervision() async throws {
        let h = try await Harness(fastClock: true)
        defer { h.cleanup() }
        try h.installActualMediaFixture()
        h.start(); await h.session.waitForOperation()
        h.hold = "file"
        let finalization = Task { await h.actualMedia!.holdFileFinalizationFixture { await h.pause("file") } }
        try await h.until { h.pending != nil }
        let start = h.elapsed
        try await h.until { h.elapsed >= start + 25 }
        #expect(h.actualMedia?.phase == .stopping)
        #expect(h.actualMedia?.broadcastPipelineRunning == true)
        #expect(h.actualMedia?.hasUpload == true)
        #expect(h.session.reconnectStatus == .monitoring)
        #expect(h.snapshot.isRecording && !h.timeline.contains("stopAll"))
        h.release(); await finalization.value
        await h.actualMedia?.stopUpload()
    }

    @Test func remoteCompletionDetachesActualPublisherWhileFileFinalizationIsHeld() async throws {
        let h = try await Harness(fastClock: true)
        defer { h.cleanup() }
        try h.installActualMediaFixture()
        h.start(); await h.session.waitForOperation()
        h.hold = "file"
        let finalization = Task { await h.actualMedia!.holdFileFinalizationFixture { await h.pause("file") } }
        try await h.until { h.pending != nil }
        h.server.remoteState = "complete"
        try await h.until { h.session.reconnectStatus == .stopped }
        #expect(h.actualMedia?.phase == .stopping)
        #expect(h.actualMedia?.hasUpload == false)
        #expect(h.fixturePublisherCloses == 1)
        #expect(h.snapshot.isRecording && !h.timeline.contains("stopAll"))
        h.release(); await finalization.value
        try await h.until { h.actualMedia?.broadcastPipelineRunning == false }
        #expect(h.fixturePublisherCloses == 1)
        #expect(h.server.transitions == ["live"])
    }

    @Test func overlayAndBackupFailureDoNotStopAdmittedUpload() async throws {
        let h = try await Harness(fastClock: true)
        defer { h.cleanup() }
        h.start(); await h.session.waitForOperation()
        h.snapshot.overlayReady = false; h.snapshot.writerStarted = false
        h.snapshot.isRecording = false; h.snapshot.captureReady = false
        try await h.until { h.elapsed >= 25 }
        #expect(h.uploaded && h.session.reconnectStatus == .monitoring)
        #expect(!h.timeline.contains("stopAll"))
    }

    @Test func longRetryAfterCannotBeBypassedByExplicitRetry() async throws {
        let h = try await Harness(fastClock: true)
        defer { h.cleanup() }
        h.start(); await h.session.waitForOperation()
        h.server.failure = "backoff"
        h.snapshot.uploadFailed = true; h.uploaded = false
        try await h.until { h.session.reconnectStatus == .exhausted }
        let requests = h.server.requests.count
        h.session.retryUpload()
        try await Task.sleep(for: .milliseconds(5))
        #expect(h.server.requests.count == requests)
        #expect(h.session.message.contains("longer wait"))
        #expect(h.snapshot.isRecording)
    }

    @Test func cancelRecoveryRejectsHeldLateReadAndNeverReconnects() async throws {
        let h = try await Harness(fastClock: true)
        defer { h.cleanup() }
        h.start(); await h.session.waitForOperation()
        h.snapshot.uploadFailed = true; h.uploaded = false; h.hold = "channels"
        try await h.until { h.pending != nil }
        h.session.cancelReconnect(); h.release()
        try await Task.sleep(for: .milliseconds(10))
        #expect(h.timeline.filter { $0 == "upload" }.count == 1)
        #expect(h.snapshot.isRecording && !h.timeline.contains("stopAll"))
    }

    @Test func confirmationIsRequiredAndDoesNotStartMediaOrAPI() async throws {
        let h = try await Harness()
        defer { h.cleanup() }
        #expect(h.server.requests.isEmpty && h.timeline.isEmpty)
        h.session.requestConfirmation(channel: h.channel, event: h.server.event)
        #expect(h.session.confirmation?.event.visibility == "Unlisted")
        #expect(h.server.requests.isEmpty && h.timeline.isEmpty)
        h.session.dismissConfirmation()
        #expect(h.session.confirmation == nil)
    }

    @Test func manualStartInitializesWriterBeforeAnyAPIAndTransitionsOnceAfterActiveIngestion() async throws {
        let h = try await Harness()
        defer { h.cleanup() }
        h.start()
        await h.session.waitForOperation()
        #expect(h.session.state == .live)
        #expect(h.timeline.firstIndex(of: "record")! < h.timeline.firstIndex(of: "GET channels")!)
        #expect(h.timeline.firstIndex(of: "writer")! < h.timeline.firstIndex(of: "GET channels")!)
        #expect(h.timeline.firstIndex(of: "upload")! < h.timeline.firstIndex(of: "transition live")!)
        #expect(h.server.transitions == ["live"])
        #expect(h.snapshot.writerStarted && h.snapshot.isRecording)
        #expect(h.server.requests.allSatisfy { $0.httpMethod != "POST" || $0.url?.path.hasSuffix("transition") == true })
    }

    @Test func autoStartPollsWithoutLiveTransitionAndSocketConnectionIsNotLive() async throws {
        let h = try await Harness(auto: true)
        defer { h.cleanup() }
        h.server.stallAuto = true
        h.start()
        try await h.until { h.uploaded }
        #expect(h.session.state != .live)
        #expect(h.server.transitions.isEmpty)
        h.server.stallAuto = false
        await h.session.waitForOperation()
        #expect(h.session.state == .live)
        #expect(h.server.transitions.isEmpty)
    }

    @Test func unreadyOverlayCaptureOrChangedSettingsCannotPublish() async throws {
        for issue in ["overlay", "capture", "profile", "url", "metadata"] {
            let h = try await Harness()
            defer { h.cleanup() }
            if issue == "overlay" { h.snapshot.overlayReady = false }
            if issue == "capture" { h.snapshot.captureReady = false }
            h.session.requestConfirmation(channel: h.channel, event: h.server.event)
            if issue == "overlay" || issue == "capture" {
                #expect(h.session.confirmation == nil)
            } else {
                let intent = try #require(h.session.confirmation)
                if issue == "profile" { h.snapshot.profile = .fullHD }
                if issue == "url" { h.snapshot.overlayURL = "https://example.invalid/private?token=fixture" }
                if issue == "metadata" { h.server.eventTitle = "Changed event" }
                h.session.confirmStart(intent)
                await h.session.waitForOperation()
            }
            #expect(!h.uploaded)
            #expect(h.server.transitions.isEmpty)
        }
    }

    @Test func writerInitializationAndReadinessFailuresSendZeroMediaAndZeroAPIMutations() async throws {
        for failure in ["init", "noSamples"] {
            let h = try await Harness()
            defer { h.cleanup() }
            h.writerMode = failure
            h.start()
            await h.session.waitForOperation()
            #expect(h.session.state == .idle)
            #expect(!h.uploaded)
            #expect(h.server.requests.isEmpty)
            #expect(h.session.message.contains("backup did not initialize"))
        }
    }

    @Test func everyStartupFailureKeepsHealthyFileAndNeverRequestsWholeStop() async throws {
        for failure in ["channel", "event", "binding", "upload", "transition", "unknown", "late", "ingestion"] {
            let h = try await Harness(startup: 0.16)
            defer { h.cleanup() }
            h.server.failure = failure
            if failure == "upload" { h.rejectUpload = true }
            h.start()
            await h.session.waitForOperation()
            #expect(h.snapshot.isRecording && h.snapshot.writerStarted)
            #expect(!h.timeline.contains("stopAll"))
            #expect(h.session.state != .live)
            #expect(!h.uploaded)
            #expect(h.server.transitions.filter { $0 == "live" }.count <= 1)
        }
    }

    @Test func timedOutTransitionIsReconciledByReadAndNeverBlindlyRetried() async throws {
        let h = try await Harness()
        defer { h.cleanup() }
        h.server.failure = "mutationTimeoutAfter"
        h.start()
        await h.session.waitForOperation()
        #expect(h.session.state == .live)
        #expect(h.server.transitions == ["live"])
        #expect(h.timeline.suffix(1) == ["GET liveBroadcasts"])
    }

    @Test func duplicateStartAndEndActionsDispatchOneMutationEach() async throws {
        let h = try await Harness()
        defer { h.cleanup() }
        h.session.requestConfirmation(channel: h.channel, event: h.server.event)
        let intent = try #require(h.session.confirmation)
        h.session.confirmStart(intent); h.session.confirmStart(intent)
        await h.session.waitForOperation()
        #expect(h.timeline.filter { $0 == "record" }.count == 1)
        h.session.confirmEnd(); h.session.confirmEnd()
        await h.session.waitForOperation()
        #expect(h.server.transitions == ["live", "complete"])
        #expect(h.timeline.filter { $0 == "stopAll" }.count == 1)
        #expect(h.session.state == .ended && h.session.pendingRemote == nil)
    }

    @Test func startupTimeoutBlocksRestartUntilReadOnlyReconciliation() async throws {
        let h = try await Harness(auto: true, startup: 0.1)
        defer { h.cleanup() }
        h.server.stallAuto = true
        h.start()
        await h.session.waitForOperation()
        #expect(h.session.state == .needsReconciliation)
        #expect(h.snapshot.writerStarted && !h.uploaded)
        #expect(!h.session.canStart)
        let count = h.server.requests.count
        h.session.reconcile()
        await h.session.waitForOperation()
        #expect(h.session.state == .idle)
        #expect(h.session.canStart)
        #expect(h.server.requests.dropFirst(count).allSatisfy { $0.httpMethod == "GET" })
    }

    @Test func cancellationAtEverySuspensionCannotPublishLaterOrStopHealthyWriter() async throws {
        for phase in ["record", "channels", "binding", "upload", "transition"] {
            let h = try await Harness()
            defer { h.cleanup() }
            h.hold = phase
            h.start()
            try await h.until { h.pending != nil }
            h.session.cancelStartup()
            h.release()
            await h.session.waitForOperation()
            try await Task.sleep(for: .milliseconds(10))
            #expect(h.session.state != .live)
            #expect(!h.uploaded)
            #expect(!h.timeline.contains("stopAll"))
            #expect(h.snapshot.writerStarted)
            #expect(h.server.transitions.filter { $0 == "live" }.count <= 1)
        }
    }

    @Test func staleAccountResponseCannotAdvanceOrPublishAndReauthorizationIsPossibleAfterStop() async throws {
        let h = try await Harness()
        defer { h.cleanup() }
        h.hold = "channels"
        h.start()
        try await h.until { h.pending != nil }
        h.authorization.signOut()
        h.session.accountChanged()
        h.release()
        try await Task.sleep(for: .milliseconds(30))
        #expect(!h.uploaded && h.session.state != .live)
        #expect(h.snapshot.writerStarted)
        #expect(!h.session.requiresEndFirst)
    }

    @Test func endStopsLocalImmediatelyEvenIfRemoteRequestIgnoresCancellationAndLateResultIsIgnored() async throws {
        let h = try await Harness(end: 0.05)
        defer { h.cleanup() }
        h.start(); await h.session.waitForOperation()
        h.hold = "complete"
        h.session.confirmEnd()
        #expect(h.timeline.last == "stopAll")
        #expect(!h.snapshot.isRecording)
        try await h.until { h.pending != nil }
        await h.session.waitForOperation()
        #expect(h.session.state == .needsReconciliation)
        #expect(h.session.message.contains("end not confirmed"))
        #expect(h.session.pendingRemote != nil)
        h.release()
        try await Task.sleep(for: .milliseconds(15))
        #expect(h.session.state == .needsReconciliation)
        let posts = h.server.transitions.count
        h.session.reconcile(); await h.session.waitForOperation()
        #expect(h.session.state == .ended)
        #expect(h.server.transitions.count == posts)
    }

    @Test func endRetryReadsBeforeWritingAndRemoteFailureDoesNotPreventLocalStop() async throws {
        let h = try await Harness(end: 0.08)
        defer { h.cleanup() }
        h.start(); await h.session.waitForOperation()
        h.server.failure = "endReject"
        h.session.confirmEnd(); await h.session.waitForOperation()
        #expect(!h.uploaded && !h.snapshot.isRecording)
        #expect(h.session.state == .needsReconciliation)
        h.server.failure = ""
        h.timeline = []
        h.session.confirmEnd(); await h.session.waitForOperation()
        #expect(h.session.state == .ended)
        let read = try #require(h.timeline.firstIndex(of: "GET liveBroadcasts"))
        let write = try #require(h.timeline.firstIndex(of: "transition complete"))
        #expect(read < write)
    }

    @Test func relaunchIsReadOnlyAndUnknownCompletionRemainsDurable() async throws {
        let h = try await Harness(auto: true, startup: 0.08)
        defer { h.cleanup() }
        h.server.stallAuto = true
        h.start(); await h.session.waitForOperation()
        let saved = try String(contentsOf: h.directory.appendingPathComponent("remote.json"), encoding: .utf8)
        #expect(!saved.contains("fixture-key") && !saved.contains("rtmps") && !saved.contains("token"))
        let resumed = h.makeSession()
        #expect(resumed.state == .needsReconciliation)
        #expect(!resumed.canStart)
        let count = h.server.requests.count
        resumed.reconcile(); await resumed.waitForOperation()
        #expect(resumed.state == .idle)
        #expect(h.server.requests.dropFirst(count).allSatisfy { $0.httpMethod == "GET" })
    }

    @Test func endDuringConnectingCancelsOwnedTaskBeforeAnyLateAttach() async throws {
        let h = try await Harness(end: 0.08)
        defer { h.cleanup() }
        h.hold = "upload"
        h.start(); try await h.until { h.pending != nil }
        h.session.confirmEnd()
        h.release()
        await h.session.waitForOperation()
        try await Task.sleep(for: .milliseconds(15))
        #expect(!h.uploaded && !h.snapshot.isRecording)
        #expect(h.server.transitions.isEmpty)
        #expect(h.session.state != .live)
    }

    @Test func heldLiveMutationCannotBeClearedByAnEarlyUpcomingReconciliation() async throws {
        let h = try await Harness()
        defer { h.cleanup() }
        h.hold = "transition"
        h.start(); try await h.until { h.pending != nil }
        h.session.cancelStartup(); await h.session.waitForOperation()
        #expect(h.session.hasUnsettledMutation)
        let reads = h.server.requests.count
        h.session.reconcile(); await h.session.waitForOperation()
        #expect(h.server.requests.count == reads)
        #expect(h.session.pendingRemote?.transition == .live && !h.session.canStart)
        h.release()
        try await h.until { !h.session.hasUnsettledMutation }
        h.session.reconcile(); await h.session.waitForOperation()
        #expect(h.server.remoteState == "live")
        #expect(h.session.pendingRemote != nil && !h.session.canStart)
        #expect(h.session.state == .needsReconciliation)
    }

    @Test func heldCompleteMutationCannotBeRetriedWhileOriginalRequestIsOutstanding() async throws {
        let h = try await Harness(end: 0.03)
        defer { h.cleanup() }
        h.start(); await h.session.waitForOperation()
        h.hold = "complete"
        h.session.confirmEnd(); try await h.until { h.pending != nil }
        await h.session.waitForOperation()
        #expect(h.session.hasUnsettledMutation)
        h.session.confirmEnd(); await h.session.waitForOperation()
        #expect(h.server.transitions == ["live", "complete"])
        #expect(h.session.pendingRemote?.transition == .complete)
        h.session.reconcile(); await h.session.waitForOperation()
        #expect(h.session.pendingRemote != nil)
        h.release(); try await h.until { !h.session.hasUnsettledMutation }
        h.session.reconcile(); await h.session.waitForOperation()
        #expect(h.session.state == .ended && h.session.pendingRemote == nil)
    }

    @Test func ambiguousLiveMutationRetainsDurableBarrierEvenWhenReadIsStillUpcomingAfterRelaunch() async throws {
        let h = try await Harness(startup: 0.07)
        defer { h.cleanup() }
        h.server.failure = "mutationTimeoutBefore"
        h.start(); await h.session.waitForOperation()
        #expect(h.server.remoteState == "ready")
        #expect(h.session.pendingRemote?.transition == .live)
        h.session.reconcile(); await h.session.waitForOperation()
        #expect(!h.session.canStart && h.session.pendingRemote?.transition == .live)
        let resumed = h.makeSession()
        resumed.reconcile(); await resumed.waitForOperation()
        #expect(!resumed.canStart && resumed.pendingRemote?.transition == .live)
        #expect(h.server.transitions == ["live"])
        h.server.remoteState = "complete"
        resumed.reconcile(); await resumed.waitForOperation()
        #expect(resumed.state == .ended && resumed.pendingRemote == nil)
    }

    @Test func cancelledLateReadCannotStopASeparatelyConfirmedNewIntent() async throws {
        let h = try await Harness()
        defer { h.cleanup() }
        h.hold = "channels"
        h.start(); try await h.until { h.pending != nil }
        h.session.cancelStartup()
        await h.session.waitForOperation()
        h.start(); await h.session.waitForOperation()
        #expect(h.uploaded && h.session.state == .live)
        h.release()
        try await Task.sleep(for: .milliseconds(20))
        #expect(h.uploaded && h.snapshot.writerStarted && h.session.state == .live)
    }

    @Test func unreadablePendingJournalFailsClosedWithoutOverwritingOrPublishing() async throws {
        let h = try await Harness()
        defer { h.cleanup() }
        let url = h.directory.appendingPathComponent("remote.json")
        let original = Data("not-a-valid-session-journal".utf8)
        try original.write(to: url)
        let resumed = h.makeSession()
        #expect(resumed.journalUnavailable && !resumed.canStart)
        resumed.requestConfirmation(channel: h.channel, event: h.server.event)
        #expect(resumed.confirmation == nil)
        #expect(try Data(contentsOf: url) == original)
        #expect(h.server.requests.isEmpty && !h.uploaded)
    }

    @Test func transitionClientUsesBodylessPOSTWithNoRetriesAndRejectsWrongIdentity() async throws {
        let h = try await Harness()
        defer { h.cleanup() }
        h.server.failure = "mutationTimeoutAfter"
        await #expect(throws: YouTubeMutationError.uncertain) {
            _ = try await h.client.transitionBroadcast(eventID: "event", channelID: "channel", to: .live, generation: h.authorization.generation)
        }
        let request = try #require(h.server.requests.last)
        let query = Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
        #expect(request.httpMethod == "POST" && request.httpBody == nil)
        #expect(query == ["id": "event", "broadcastStatus": "live", "part": "snippet,status,contentDetails"])
        #expect(h.server.transitions == ["live"])
        h.server.failure = "wrongTransitionIdentity"
        await #expect(throws: YouTubeMutationError.uncertain) {
            _ = try await h.client.transitionBroadcast(eventID: "event", channelID: "channel", to: .complete, generation: h.authorization.generation)
        }
    }
}

@MainActor private final class Harness {
    var timeline: [String] = []
    var snapshot = BroadcastMedia.Snapshot(captureReady: true, canRecord: true, writerStarted: false,
        isRecording: false, profile: .hd, overlayURL: "", overlayReady: true, uploadFailed: false)
    var actualMedia: MediaSession?
    var fixturePublisherCloses = 0
    var uploaded = false
    var rejectUpload = false
    var writerMode = ""
    var hold = ""
    var pending: CheckedContinuation<Void, Never>?
    let directory: URL
    let authorization: YouTubeAuthorization
    var server: BroadcastFixtureServer!
    var client: YouTubeClient!
    var session: BroadcastSession!
    var elapsed: Double = 0
    var rejectUntil: Double = 0
    let fastClock: Bool
    let startup: Double
    let end: Double
    let channel = YouTubeChannel(id: "channel", snippet: .init(title: "Fixture channel"))

    init(auto: Bool = false, startup: Double = 0.7, end: Double = 0.3, fastClock: Bool = false) async throws {
        self.fastClock = fastClock
        self.startup = startup; self.end = end
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("broadcast-fixture-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        authorization = YouTubeAuthorization(driver: BroadcastAuthDriver(), configured: true)
        await authorization.restore()
        server = BroadcastFixtureServer(auto: auto)
        server.harness = self
        client = YouTubeClient(token: { _ in "fixture-token" }, current: { [authorization] in $0 == authorization.generation && authorization.isAuthorized },
            send: { [server = server!] in try await server.respond($0) }, sleep: { _ in })
        session = makeSession()
    }
    func makeSession() -> BroadcastSession {
        let media = BroadcastMedia(snapshot: {
            var snapshot = self.snapshot
            if let actualMedia = self.actualMedia { snapshot.pipelineRunning = actualMedia.broadcastPipelineRunning }
            return snapshot
        }, record: {
            self.timeline.append("record")
            await self.pause("record")
            if self.writerMode == "init" { return }
            self.snapshot.isRecording = true; self.snapshot.canRecord = false
            if self.writerMode != "noSamples" { self.snapshot.writerStarted = true; self.timeline.append("writer") }
        }, startUpload: { _ in
            self.timeline.append("upload")
            await self.pause("upload")
            try Task.checkCancellation()
            guard !self.rejectUpload, self.elapsed >= self.rejectUntil else { throw URLError(.cannotConnectToHost) }
            self.uploaded = true; self.snapshot.uploadFailed = false
        }, stopUpload: {
            self.timeline.append("stopUpload"); self.uploaded = false
            await self.actualMedia?.stopUpload()
        }, stopAll: {
            self.timeline.append("stopAll"); self.uploaded = false
            self.snapshot.isRecording = false; self.snapshot.writerStarted = false
        }, lockConfiguration: { self.timeline.append($0 ? "lock" : "unlock") })
        return BroadcastSession(authorization: authorization, client: client,
            binding: YouTubeBinding(client: client, store: PendingBroadcastIntentStore(directory: directory.appendingPathComponent("bindings"))),
            media: media, store: PendingRemoteBroadcastStore(url: directory.appendingPathComponent("remote.json")),
            startupSeconds: startup, endSeconds: end, pollSeconds: 0.005, writerSeconds: 0.05,
            reconnectClock: fastClock ? ReconnectClock(now: { self.elapsed }, sleep: { seconds in
                try await Task.sleep(for: .milliseconds(1))
                self.elapsed += seconds
            }, jitter: { 0.8 }) : ReconnectClock())
    }
    func installActualMediaFixture() throws {
        let media = MediaSession(readOverlayURL: { "" }, saveOverlayURL: { _ in },
                                 persistProfile: { _ in }, authorizeCapture: { false })
        let encoder = try SharedMediaEncoder(profile: .hd, output: { _ in }, failed: { _ in })
        let publisher = RTMPSPublisher(send: { _, _ in }, close: {
            await MainActor.run { self.fixturePublisherCloses += 1 }
        }, failed: { _ in })
        publisher.activate()
        media.installBroadcastFixture(encoder: encoder, publisher: publisher)
        actualMedia = media
    }
    func start() {
        session.requestConfirmation(channel: channel, event: server.event)
        if let intent = session.confirmation { session.confirmStart(intent) }
    }
    func pause(_ phase: String) async {
        guard hold == phase else { return }
        hold = ""
        await withCheckedContinuation { pending = $0 }
    }
    func release() { let continuation = pending; pending = nil; continuation?.resume() }
    func until(_ condition: () -> Bool) async throws {
        for _ in 0..<300 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(2))
        }
        try #require(condition())
    }
    func cleanup() { session.cancelReconnect(); release(); try? FileManager.default.removeItem(at: directory) }
}

@MainActor private final class BroadcastFixtureServer {
    weak var harness: Harness?
    let auto: Bool
    var failure = ""
    var stallAuto = false
    var boundStreamID = "stream"
    var eventTitle = "Fixture scheduled event"
    var remoteState = "ready"
    var requests: [URLRequest] = []
    var transitions: [String] = []
    init(auto: Bool) { self.auto = auto }
    var event: YouTubeBroadcast {
        YouTubeBroadcast(id: "event", snippet: .init(channelId: "channel", title: eventTitle,
            scheduledStartTime: "2026-11-08T12:00:00Z", isDefaultBroadcast: false),
            status: .init(lifeCycleStatus: remoteState, privacyStatus: "unlisted"),
            contentDetails: .init(boundStreamId: boundStreamID, enableAutoStart: auto, enableAutoStop: false))
    }
    func respond(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let resource = request.url!.lastPathComponent
        let query = Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
        let h = harness!
        h.timeline.append("\(request.httpMethod ?? "GET") \(resource)")
        if resource == "channels" { await h.pause("channels") }
        if resource == "liveStreams" && !h.uploaded { await h.pause("binding") }
        if failure == "network" { throw URLError(.notConnectedToInternet) }
        if failure == "auth" { throw YouTubeReadError.authorizationRequired }
        if failure == "missing" { throw YouTubeReadError.missingEvent }
        var status = 200
        let data: Data
        switch resource {
        case "channels":
            if failure == "channel" { status = 403 }
            data = try JSONEncoder().encode(["items": [h.channel]])
        case "liveBroadcasts":
            if h.uploaded, auto, !stallAuto { remoteState = "live" }
            if h.uploaded && failure == "unknown" { remoteState = "unknown-future-state" }
            if failure == "event" { status = 403 }
            data = try JSONEncoder().encode(["items": [event]])
        case "liveStreams":
            if failure == "binding" { status = 403 }
            let streamState = h.uploaded && failure != "ingestion" ? "active" : "inactive"
            data = try JSONSerialization.data(withJSONObject: ["items": [[
                "id": "stream", "snippet": ["channelId": "channel"],
                "cdn": ["ingestionType": "rtmp", "resolution": "variable", "frameRate": "variable",
                        "ingestionInfo": ["rtmpsIngestionAddress": "rtmps://rtmps.youtube.com:443/live2", "streamName": "fixture-key"]],
                "status": ["streamStatus": streamState, "healthStatus": ["status": "good", "configurationIssues": []]],
                "contentDetails": ["isReusable": true]
            ]]])
        case "transition":
            let target = query["broadcastStatus"]!
            transitions.append(target); h.timeline.append("transition " + target)
            await h.pause(target == "live" ? "transition" : "complete")
            if failure == "mutationTimeoutBefore" { throw URLError(.timedOut) }
            if failure == "transition" || failure == "endReject" { status = 403 }
            else { remoteState = failure == "late" ? "liveStarting" : target }
            if failure == "mutationTimeoutAfter" { throw URLError(.timedOut) }
            if failure == "wrongTransitionIdentity" {
                data = Data("{\"id\":\"wrong\",\"snippet\":{\"channelId\":\"channel\"}}".utf8)
            } else { data = try JSONEncoder().encode(event) }
        default: throw YouTubeReadError.malformedResponse
        }
        if failure == "backoff" { status = 503 }
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
            headerFields: failure == "backoff" ? ["Retry-After": "3600"] : nil)!)
    }
}

@MainActor private final class BroadcastAuthDriver: GoogleAuthorizationDriving {
    func connect(presenting: UIViewController) async throws -> GoogleAuthorizationAccount { try await restore() }
    func restore() async throws -> GoogleAuthorizationAccount {
        GoogleAuthorizationAccount(id: "fixture-account", grantedScopes: [YouTubeAuthorization.requiredScope])
    }
    func accessToken(accountID: String) async throws -> String { "fixture-token" }
    func signOut() {}
    func disconnect() async throws {}
    func handle(_ url: URL) -> Bool { false }
}
