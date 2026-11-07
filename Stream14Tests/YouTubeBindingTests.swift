import Foundation
import Testing
@testable import Stream14

@MainActor @Suite(.timeLimit(.minutes(1))) struct YouTubeBindingTests {
    @Test func dedicatedExistingBindingIsReadOnlyAndSecretsAreNotPersistedOrReflected() async throws {
        let server = BindingFixtureServer(bound: "existing-stream")
        let (binding, store, _) = try makeBinding(server)
        let prepared = try await prepare(binding)
        #expect(prepared.streamID == "existing-stream")
        #expect(prepared.destination.endpoint.scheme == "rtmps")
        #expect(prepared.destination.streamName == "fixture-stream-key")
        #expect(!String(reflecting: prepared).contains("fixture-stream-key"))
        #expect(!String(reflecting: prepared.destination).contains("youtube.com"))
        #expect(try store.load() == nil)
        let requests = await server.requests
        #expect(requests.allSatisfy { $0.httpMethod == "GET" })
        #expect(requests.contains { bindingQuery($0)["broadcastStatus"] == "all" && bindingQuery($0)["broadcastType"] == "all" })
        #expect(requests.filter { $0.url?.path.hasSuffix("liveStreams") == true }.allSatisfy { bindingQuery($0)["id"] == "existing-stream" })
    }

    @Test func sharedSecondPageUnknownAndActiveBindingsFailClosedWithoutWrites() async throws {
        for scenario in ["shared", "unknown", "active", "health", "missingReuse", "incompatible"] {
            let server = BindingFixtureServer(bound: "existing-stream", scenario: scenario)
            let (binding, _, _) = try makeBinding(server)
            do { _ = try await prepare(binding); Issue.record("Unsafe fixture unexpectedly prepared: \(scenario)") }
            catch { #expect(error is YouTubeBindingError) }
            #expect(await server.requests.allSatisfy { $0.httpMethod == "GET" })
            if scenario == "shared" {
                #expect(await server.requests.contains { bindingQuery($0)["pageToken"] == "fixture-next-page" })
            }
        }
    }

    @Test func terminalHistoricalBindingDoesNotBlockDedicatedReuse() async throws {
        let server = BindingFixtureServer(bound: "existing-stream", scenario: "completed")
        let (binding, _, _) = try makeBinding(server)
        #expect(try await prepare(binding).streamID == "existing-stream")
        #expect(await server.requests.allSatisfy { $0.httpMethod == "GET" })
    }

    @Test func autoStopAndWrongChannelAreRejectedBeforeMutation() async throws {
        for scenario in ["autoStop", "wrongChannel"] {
            let server = BindingFixtureServer(bound: nil, scenario: scenario)
            let (binding, _, _) = try makeBinding(server)
            do { _ = try await prepare(binding); Issue.record("Invalid event prepared") }
            catch { #expect(error is YouTubeBindingError || error is YouTubeReadError) }
            #expect(await server.requests.allSatisfy { $0.httpMethod == "GET" })
        }
    }

    @Test func unboundEventCreatesOneNonReusableVariableStreamAndReadsBackBinding() async throws {
        let server = BindingFixtureServer(bound: nil)
        let (binding, store, directory) = try makeBinding(server)
        let prepared = try await prepare(binding)
        #expect(prepared.streamID == "created-stream")
        #expect(prepared.broadcast.contentDetails?.boundStreamId == "created-stream")
        #expect(try store.load()?.createdStreamID == "created-stream")
        #expect(try store.load()?.phase == .prepared)
        let requests = await server.requests
        let insert = try #require(requests.first { $0.httpMethod == "POST" && $0.url?.path.hasSuffix("liveStreams") == true })
        let encodedBody = try #require(insert.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: encodedBody) as? [String: Any])
        #expect((body["cdn"] as? [String: String]) == ["ingestionType": "rtmp", "resolution": "variable", "frameRate": "variable"])
        #expect((body["contentDetails"] as? [String: Bool])?["isReusable"] == false)
        #expect((body["snippet"] as? [String: String])?["title"]?.hasPrefix("stream14 ") == true)
        let bind = try #require(requests.first { $0.url?.path.hasSuffix("liveBroadcasts/bind") == true })
        #expect(bind.httpBody == nil)
        #expect(bindingQuery(bind)["id"] == "fixture-event")
        #expect(bindingQuery(bind)["streamId"] == "created-stream")
        _ = try await prepare(binding)
        #expect(await server.inserts == 1)
        #expect(await server.binds == 1)
        let persisted = try String(contentsOf: directory.appendingPathComponent("binding-intent.json"), encoding: .utf8)
        #expect(!persisted.contains("fixture-stream-key") && !persisted.contains("rtmps") && !persisted.contains("Bearer"))
    }

    @Test func ambiguousInsertAndRelaunchNeverBlindlyInsertAgain() async throws {
        for mode in [BindingFixtureServer.InsertMode.timeoutBefore, .timeoutAfter, .malformed] {
            let server = BindingFixtureServer(bound: nil, insertMode: mode)
            let (binding, store, _) = try makeBinding(server)
            await #expect(throws: YouTubeBindingError.unresolvedInsert) { try await prepare(binding) }
            #expect(try store.load()?.phase == .unresolvedInsert)
            let resumed = YouTubeBinding(client: makeClient(server), store: store)
            await #expect(throws: YouTubeBindingError.unresolvedInsert) { try await prepare(resumed) }
            #expect(await server.inserts == 1)
            #expect(await server.binds == 0)
            #expect(await server.createdResources == (mode == .timeoutBefore ? 0 : 1))
        }
    }

    @Test func knownCreatedIDSurvivesBindFailureAndRelaunchWithoutDuplicateInsert() async throws {
        let server = BindingFixtureServer(bound: nil, bindMode: .timeoutBefore)
        let (binding, store, _) = try makeBinding(server)
        await #expect(throws: YouTubeBindingError.bindingUnconfirmed) { try await prepare(binding) }
        #expect(try store.load()?.createdStreamID == "created-stream")
        #expect(try store.load()?.phase == .binding)
        await server.setBindMode(.success)
        let resumed = YouTubeBinding(client: makeClient(server), store: store)
        #expect(try await prepare(resumed).streamID == "created-stream")
        #expect(await server.inserts == 1)
        #expect(await server.binds == 2)
    }

    @Test func timedOutAppliedBindIsReconciledWithoutAnotherPost() async throws {
        let server = BindingFixtureServer(bound: nil, bindMode: .timeoutAfter)
        let (binding, store, _) = try makeBinding(server)
        #expect(try await prepare(binding).streamID == "created-stream")
        #expect(try store.load()?.phase == .prepared)
        #expect(await server.inserts == 1)
        #expect(await server.binds == 1)
    }

    @Test func repeatedTapAndCancellationRetainCreatedIDBeforeRejectingReadiness() async throws {
        let server = BindingFixtureServer(bound: nil, holdInsert: true)
        let (binding, store, _) = try makeBinding(server)
        let first = Task { try await prepare(binding) }
        await server.waitForInsert()
        await #expect(throws: YouTubeBindingError.busy) { try await prepare(binding) }
        first.cancel()
        await server.releaseInsert()
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(try store.load()?.createdStreamID == "created-stream")
        #expect(try store.load()?.phase == .created)
        #expect(await server.inserts == 1)
        #expect(await server.binds == 0)
        let resumed = YouTubeBinding(client: makeClient(server), store: store)
        #expect(try await prepare(resumed).streamID == "created-stream")
        #expect(await server.inserts == 1)
    }

    @Test func accountChangeDuringInsertCannotBindButKeepsKnownOutcome() async throws {
        let server = BindingFixtureServer(bound: nil, holdInsert: true)
        let access = BindingAccess()
        let (binding, store, _) = try makeBinding(server, access: access)
        let first = Task { try await prepare(binding) }
        await server.waitForInsert()
        access.generation = 2
        await server.releaseInsert()
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(try store.load()?.createdStreamID == "created-stream")
        #expect(await server.binds == 0)
        #expect(await server.inserts == 1)
    }

    @Test func aSecondWorkflowInstanceCannotDuplicateThePersistedInsertionClaim() async throws {
        let server = BindingFixtureServer(bound: nil, holdInsert: true)
        let (binding, store, _) = try makeBinding(server)
        let first = Task { try await prepare(binding) }
        await server.waitForInsert()
        let other = YouTubeBinding(client: makeClient(server), store: store)
        await #expect(throws: YouTubeBindingError.unresolvedInsert) { try await prepare(other) }
        await server.releaseInsert()
        _ = try await first.value
        #expect(await server.inserts == 1)
    }

    @Test func failedCredentialPreflightDoesNotBecomeAnAmbiguousRemoteInsert() async throws {
        let server = BindingFixtureServer(bound: nil)
        let access = BindingAccess()
        access.failTokenAt = 3
        let (binding, store, _) = try makeBinding(server, access: access)
        await #expect(throws: YouTubeReadError.authorizationRequired) { try await prepare(binding) }
        #expect(try store.load()?.phase == .notCreated)
        #expect(await server.inserts == 0)
        access.failTokenAt = nil
        _ = try await prepare(binding)
        #expect(await server.inserts == 1)
    }

    @Test func profileContextAndOtherPendingEventCannotCreateAnotherResource() async throws {
        let server = BindingFixtureServer(bound: nil, bindMode: .timeoutBefore)
        let (binding, store, _) = try makeBinding(server)
        await #expect(throws: YouTubeBindingError.bindingUnconfirmed) { try await prepare(binding) }
        await #expect(throws: YouTubeBindingError.pendingOtherContext) {
            try await binding.prepareConfirmed(eventID: "fixture-event", channelID: "fixture-channel", profile: .hd, generation: 1)
        }
        #expect(try store.load()?.profile == SessionProfile.fullHD.rawValue)
        #expect(await server.inserts == 1)
    }

    @Test func missingDestinationKeepsKnownIDAndNeverFallsBackToRTMP() async throws {
        let server = BindingFixtureServer(bound: nil, scenario: "missingDestination")
        let (binding, store, _) = try makeBinding(server)
        await #expect(throws: YouTubeBindingError.invalidDestination) { try await prepare(binding) }
        #expect(try store.load()?.createdStreamID == "created-stream")
        await #expect(throws: YouTubeBindingError.invalidDestination) { try await prepare(binding) }
        #expect(await server.inserts == 1)
        for address in ["rtmp://a.rtmp.youtube.com/live2", "rtmps://example.org/live2", "rtmps://a.rtmps.youtube.com:444/live2",
                        "rtmps://user:password@a.rtmps.youtube.com/live2", "rtmps://a.rtmps.youtube.com/live2?key=private", "rtmps://a.rtmps.youtube.com/"] {
            #expect(throws: YouTubeBindingError.invalidDestination) { try YouTubeIngestionDestination(address: address, streamName: "fixture-key") }
        }
    }

    @Test func persistenceFailurePreventsDispatchAndPostResponseFailurePreservesDuplicateGuard() async throws {
        for failureAt in [1, 2] {
            let server = BindingFixtureServer(bound: nil)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let writer = BindingWriteFailure(failureAt: failureAt)
            let store = PendingBroadcastIntentStore(directory: directory, write: { try writer.write($0, to: $1) })
            let binding = YouTubeBinding(client: makeClient(server), store: store)
            await #expect(throws: YouTubeBindingError.intentUnavailable) { try await prepare(binding) }
            #expect(await server.inserts == failureAt - 1)
            if failureAt == 2 {
                #expect(try store.load()?.phase == .inserting)
                let resumed = YouTubeBinding(client: makeClient(server), store: store)
                await #expect(throws: YouTubeBindingError.unresolvedInsert) { try await prepare(resumed) }
                #expect(await server.inserts == 1)
            }
        }
    }

    @Test func definiteWriteRejectionHasNoAutomaticRetryAndAllowsExplicitRetry() async throws {
        let server = BindingFixtureServer(bound: nil, insertMode: .rejected)
        let (binding, store, _) = try makeBinding(server)
        await #expect(throws: YouTubeReadError.insufficientPermission) { try await prepare(binding) }
        #expect(await server.inserts == 1)
        #expect(try store.load()?.phase == .notCreated)
        await server.setInsertMode(.success)
        #expect(try await prepare(binding).streamID == "created-stream")
        #expect(await server.inserts == 2)
    }

    @Test func overallDeadlineCancelsReadsBeforeAnyMutation() async throws {
        let server = BindingFixtureServer(bound: nil, delayReads: true)
        let (binding, _, _) = try makeBinding(server, timeout: .milliseconds(30))
        await #expect(throws: YouTubeBindingError.deadline) { try await prepare(binding) }
        #expect(await server.inserts == 0)
        #expect(!binding.isPreparing)
    }

    private func prepare(_ binding: YouTubeBinding) async throws -> PreparedYouTubeIngestion {
        try await binding.prepareConfirmed(eventID: "fixture-event", channelID: "fixture-channel", profile: .fullHD, generation: 1)
    }
    private func makeBinding(_ server: BindingFixtureServer, access: BindingAccess? = nil, timeout: Duration = .seconds(45)) throws -> (YouTubeBinding, PendingBroadcastIntentStore, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PendingBroadcastIntentStore(directory: directory)
        return (YouTubeBinding(client: makeClient(server, access: access), store: store, timeout: timeout), store, directory)
    }
    private func makeClient(_ server: BindingFixtureServer, access: BindingAccess? = nil) -> YouTubeClient {
        let access = access ?? BindingAccess()
        return YouTubeClient(token: { _ in
            access.tokenCalls += 1
            if access.tokenCalls == access.failTokenAt { throw YouTubeAuthorizationError.authorizationRequired }
            return "fixture-token"
        }, current: { access.generation == $0 }, send: { try await server.send($0) }, sleep: { _ in })
    }
}

@MainActor private final class BindingAccess {
    var generation: UInt64 = 1
    var tokenCalls = 0
    var failTokenAt: Int?
}
@MainActor private final class BindingWriteFailure {
    let failureAt: Int
    var calls = 0
    init(failureAt: Int) { self.failureAt = failureAt }
    func write(_ data: Data, to url: URL) throws {
        calls += 1
        if calls == failureAt { throw CocoaError(.fileWriteOutOfSpace) }
        try data.write(to: url, options: .atomic)
    }
}

nonisolated private func bindingQuery(_ request: URLRequest) -> [String: String] {
    Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
}

private actor BindingFixtureServer {
    nonisolated enum InsertMode: Sendable { case success, timeoutBefore, timeoutAfter, malformed, rejected }
    nonisolated enum BindMode: Sendable { case success, timeoutBefore, timeoutAfter }
    var requests: [URLRequest] = []
    var inserts = 0
    var binds = 0
    var createdResources = 0
    private var bound: String?
    private let scenario: String
    private var insertMode: InsertMode
    private var bindMode: BindMode
    private var holdInsert: Bool
    private let delayReads: Bool
    private var insertWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    init(bound: String?, scenario: String = "normal", insertMode: InsertMode = .success, bindMode: BindMode = .success,
         holdInsert: Bool = false, delayReads: Bool = false) {
        self.bound = bound; self.scenario = scenario; self.insertMode = insertMode; self.bindMode = bindMode
        self.holdInsert = holdInsert; self.delayReads = delayReads
    }
    func setBindMode(_ value: BindMode) { bindMode = value }
    func setInsertMode(_ value: InsertMode) { insertMode = value }
    func waitForInsert() async {
        if inserts > 0 { return }
        await withCheckedContinuation { insertWaiter = $0 }
    }
    func releaseInsert() { holdInsert = false; releaseWaiter?.resume(); releaseWaiter = nil }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let query = bindingQuery(request)
        let path = request.url!.path
        var status = 200
        let object: Any
        if request.httpMethod == "GET", delayReads { try await Task.sleep(for: .seconds(2)) }
        if path.hasSuffix("channels") {
            object = ["items": [["id": "fixture-channel", "snippet": ["title": "Fixture Channel"]]]]
        } else if path.hasSuffix("liveBroadcasts/bind") {
            binds += 1
            if bindMode == .timeoutBefore { throw URLError(.timedOut) }
            bound = query["streamId"]
            if bindMode == .timeoutAfter { throw URLError(.timedOut) }
            object = event()
        } else if path.hasSuffix("liveStreams"), request.httpMethod == "POST" {
            inserts += 1
            insertWaiter?.resume(); insertWaiter = nil
            if holdInsert { await withCheckedContinuation { releaseWaiter = $0 } }
            switch insertMode {
            case .timeoutBefore: throw URLError(.timedOut)
            case .timeoutAfter: createdResources += 1; throw URLError(.timedOut)
            case .malformed: createdResources += 1; return (Data("{not-json".utf8), response(request, 200))
            case .rejected:
                status = 403
                object = ["error": ["message": "fixture-private-upstream-detail", "errors": [["reason": "insufficientPermissions"]]]]
            case .success: createdResources += 1; object = stream(id: "created-stream")
            }
        } else if path.hasSuffix("liveStreams") {
            object = ["items": [stream(id: query["id"] ?? "missing")]]
        } else if path.hasSuffix("liveBroadcasts") {
            if query["id"] != nil { object = ["items": [event()]] }
            else if scenario == "shared", query["pageToken"] == nil {
                object = ["items": [event()], "nextPageToken": "fixture-next-page"]
            } else if scenario == "shared" {
                object = ["items": [event(id: "other-event", bound: "existing-stream")]]
            } else if scenario == "unknown" {
                object = ["items": [event(), event(id: "other-event", state: "futureUnknown", bound: "another-stream")]]
            } else if scenario == "completed" {
                object = ["items": [event(), event(id: "past-event", state: "complete", bound: "existing-stream")]]
            } else { object = ["items": [event()]] }
        } else { throw YouTubeReadError.malformedResponse }
        return (try JSONSerialization.data(withJSONObject: object), response(request, status))
    }

    private func response(_ request: URLRequest, _ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
    }
    private func event(id: String = "fixture-event", state: String = "ready", bound: String? = nil) -> [String: Any] {
        var details: [String: Any] = ["enableAutoStart": false, "enableAutoStop": scenario == "autoStop"]
        if let binding = id == "fixture-event" ? self.bound : bound { details["boundStreamId"] = binding }
        return ["id": id, "snippet": ["channelId": scenario == "wrongChannel" ? "different-channel" : "fixture-channel",
                "title": "Fixture Match", "scheduledStartTime": "2026-11-10T12:00:00Z", "isDefaultBroadcast": false],
                "status": ["lifeCycleStatus": state, "privacyStatus": "unlisted"], "contentDetails": details]
    }
    private func stream(id: String) -> [String: Any] {
        var info: [String: String] = ["rtmpsIngestionAddress": "rtmps://a.rtmps.youtube.com/live2", "streamName": "fixture-stream-key"]
        if scenario == "missingDestination" { info.removeValue(forKey: "rtmpsIngestionAddress") }
        var value: [String: Any] = ["id": id, "snippet": ["channelId": "fixture-channel"],
            "cdn": ["ingestionType": "rtmp", "resolution": scenario == "incompatible" ? "720p" : "variable",
                    "frameRate": scenario == "incompatible" ? "30fps" : "variable", "ingestionInfo": info],
            "status": ["streamStatus": scenario == "active" ? "active" : "ready",
                       "healthStatus": ["status": scenario == "health" ? "bad" : "noData"]]]
        if scenario != "missingReuse" { value["contentDetails"] = ["isReusable": id != "created-stream"] }
        return value
    }
}
