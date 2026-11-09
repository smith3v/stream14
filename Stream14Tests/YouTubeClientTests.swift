import Foundation
import Testing
import UIKit
@testable import Stream14

@MainActor @Suite(.timeLimit(.minutes(1))) struct YouTubeClientTests {
    @Test func authorizationRejectionRequestsGenerationBoundDataCleanupForReadsAndWrites() async {
        for mutation in [false, true] {
            let server = ReadFixtureServer([.error(401, "authError"), .error(401, "authError")])
            var rejected: [UInt64] = []
            let client = YouTubeClient(token: { _ in "invented-token" }, current: { _ in true },
                accessDenied: { rejected.append($0) }, send: { try await server.send($0) }, sleep: { _ in })
            if mutation {
                await #expect(throws: YouTubeMutationError.rejected(.authorizationRequired)) {
                    try await client.transitionBroadcast(eventID: "fixture-event", channelID: "fixture-channel", to: .complete, generation: 17)
                }
                #expect(await server.requests.count == 1)
            } else {
                await #expect(throws: YouTubeReadError.authorizationRequired) {
                    try await client.authorizedChannel(generation: 17)
                }
                #expect(await server.requests.count == 2)
            }
            #expect(rejected == [17])
        }
    }

    @Test func channelsAndEveryUpcomingPageUseCorrectReadOnlyFilters() async throws {
        let server = ReadFixtureServer([.fixture("channel"), .fixture("upcoming-first"), .fixture("upcoming-last")])
        let client = makeClient(server)
        let channel = try await client.authorizedChannel(generation: 1)
        #expect(channel.id == "fixture-brand-channel")
        #expect(channel.title == "Fixture Volleyball")
        let events = try await client.upcomingBroadcasts(channelID: channel.id, generation: 1)
        #expect(events.count == 3)
        #expect(events[0].id == "fixture-event-one")
        #expect(events[1].scheduledStart != nil)
        #expect(events[0].ineligibility(channelID: channel.id) == nil)
        #expect(events[2].ineligibility(channelID: channel.id) != nil)
        let requests = await server.requests
        #expect(requests.count == 3)
        #expect(requests.allSatisfy { $0.httpMethod == "GET" && $0.httpBody == nil && $0.url?.scheme == "https" })
        #expect(query(requests[0])["mine"] == "true")
        #expect(query(requests[0])["part"] == "snippet")
        for request in requests.dropFirst() {
            let values = query(request)
            #expect(values["broadcastStatus"] == "upcoming")
            #expect(values["broadcastType"] == "event")
            #expect(values["part"] == "snippet,status,contentDetails")
            #expect(values["mine"] == nil && values["id"] == nil)
            #expect(values["maxResults"] == "50")
            #expect(!request.url!.absoluteString.contains("fixture-access-token"))
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-access-token")
        }
        #expect(query(requests[2])["pageToken"] == "fixture-page-two")
    }

    @Test func byIDBroadcastAndStreamReadsDoNotCombineListFiltersOrRetainKeys() async throws {
        let one = try fixture("upcoming-first")
        let server = ReadFixtureServer([.data(one), .fixture("stream")])
        let client = makeClient(server)
        let event = try await client.broadcast(id: "fixture-event-one", channelID: "fixture-brand-channel", generation: 1)
        #expect(event.contentDetails?.boundStreamId == "fixture-stream")
        let stream = try await client.stream(id: "fixture-stream", channelID: "fixture-brand-channel", generation: 1)
        #expect(stream.cdn?.resolution == "variable")
        #expect(!String(reflecting: stream).contains("fixture-not-a-real-key"))
        let requests = await server.requests
        for request in requests {
            let values = query(request)
            #expect(values["id"] != nil)
            #expect(values["mine"] == nil && values["broadcastStatus"] == nil && values["broadcastType"] == nil)
        }
        #expect(requests[1].url?.path == "/youtube/v3/liveStreams")
    }

    @Test func emptyMissingMalformedAndUnknownMetadataStaySafe() async throws {
        let server = ReadFixtureServer([.json("{\"items\":[]}"), .json("{}"), .json("{\"items\":[]}")])
        let client = makeClient(server)
        #expect(try await client.upcomingBroadcasts(channelID: "fixture-brand-channel", generation: 1).isEmpty)
        await #expect(throws: YouTubeReadError.malformedResponse) { try await client.authorizedChannel(generation: 1) }
        await #expect(throws: YouTubeReadError.missingEvent) {
            try await client.broadcast(id: "missing", channelID: "fixture-brand-channel", generation: 1)
        }
        let unknown = try JSONDecoder().decode(YouTubePage<YouTubeBroadcast>.self, from: fixture("upcoming-last")).items[1]
        #expect(unknown.visibility == "Visibility unavailable")
        #expect(unknown.scheduledStart == nil)
        #expect(unknown.ineligibility(channelID: "fixture-brand-channel") != nil)
    }

    @Test func paginationCyclesAndWrongChannelFailRatherThanHandOffPartialResults() async throws {
        let cycle = "{\"items\":[],\"nextPageToken\":\"repeat\"}"
        let cycleServer = ReadFixtureServer([.json(cycle), .json(cycle)])
        await #expect(throws: YouTubeReadError.pagination) {
            try await makeClient(cycleServer).upcomingBroadcasts(channelID: "fixture-brand-channel", generation: 1)
        }
        #expect(await cycleServer.requests.count == 2)
        let wrong = try fixture("upcoming-first").utf8String.replacingOccurrences(of: "fixture-brand-channel", with: "another-channel")
        let wrongServer = ReadFixtureServer([.json(wrong.replacingOccurrences(of: "\"nextPageToken\":\"fixture-page-two\",", with: ""))])
        await #expect(throws: YouTubeReadError.wrongChannel) {
            try await makeClient(wrongServer).upcomingBroadcasts(channelID: "fixture-brand-channel", generation: 1)
        }
    }

    @Test func errorReasonsDistinguishQuotaScopeDisabledLiveAndForbiddenWithoutLeakingBodies() async throws {
        for (reason, expected) in [("quotaExceeded", YouTubeReadError.quotaExceeded),
                                   ("insufficientPermissions", .insufficientPermission),
                                   ("liveStreamingNotEnabled", .liveDisabled), ("unrecognized", .rejected(403))] {
            let server = ReadFixtureServer([.error(403, reason)])
            await #expect(throws: expected) { try await makeClient(server).authorizedChannel(generation: 1) }
            #expect(await server.requests.count == 1)
            #expect(!expected.localizedDescription.contains("private-upstream-detail"))
        }
    }

    @Test func unauthorizedReadRequestsAtMostOneSupportedTokenRefreshRetry() async throws {
        let server = ReadFixtureServer([.error(401, "authError"), .error(401, "authError")])
        let access = ReadTokenFixture()
        let client = makeClient(server, access: access)
        await #expect(throws: YouTubeReadError.authorizationRequired) { try await client.authorizedChannel(generation: 1) }
        #expect(await server.requests.count == 2)
        #expect(access.calls == 2)
        let recovery = ReadFixtureServer([.error(401, "authError"), .fixture("channel")])
        #expect(try await makeClient(recovery).authorizedChannel(generation: 1).id == "fixture-brand-channel")
    }

    @Test func transientReadsAreBoundedAndRespectRetryAfter() async throws {
        let server = ReadFixtureServer([.error(429, "rateLimitExceeded", retry: "2"), .error(429, "rateLimitExceeded", retry: "2"), .error(429, "rateLimitExceeded", retry: "2")])
        do {
            _ = try await makeClient(server).authorizedChannel(generation: 1)
            Issue.record("Expected rate-limit backoff")
        } catch let error as YouTubeReadBackoff {
            #expect(error.reason == .rateLimited && error.seconds == 2)
        }
        #expect(await server.requests.count == 3)
        #expect(await server.delays == [2, 2])
        let longDelay = ReadFixtureServer([.error(503, "backendError", retry: "30")])
        do {
            _ = try await makeClient(longDelay).authorizedChannel(generation: 1)
            Issue.record("Expected server backoff")
        } catch let error as YouTubeReadBackoff {
            #expect(error.reason == .unavailable && error.seconds == 30)
        }
        #expect(await longDelay.requests.count == 1)
        #expect(await longDelay.delays.isEmpty)
        let network = ReadFixtureServer([.network, .fixture("channel")])
        #expect(try await makeClient(network).authorizedChannel(generation: 1).id == "fixture-brand-channel")
        #expect(await network.delays == [1])
    }

    @Test func cancellationAndAccountSwitchRejectResponsesAndDoNotRetry() async throws {
        let server = ReadFixtureServer([.fixture("channel")], hold: true)
        let access = ReadTokenFixture()
        let client = makeClient(server, access: access)
        let request = Task { try await client.authorizedChannel(generation: 1) }
        while await server.requests.isEmpty { await Task.yield() }
        access.generation = 2
        await server.release()
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(await server.requests.count == 1)
        let cancelled = Task { try await makeClient(ReadFixtureServer([])).authorizedChannel(generation: 1) }
        cancelled.cancel()
        await #expect(throws: CancellationError.self) { try await cancelled.value }
    }

    @Test func selectionRechecksByIDAndClearsWhenEventBecomesIneligible() async throws {
        let first = try fixture("upcoming-first").utf8String.replacingOccurrences(of: "\"nextPageToken\":\"fixture-page-two\",", with: "")
        let ended = first.replacingOccurrences(of: "\"ready\"", with: "\"complete\"")
        let server = ReadFixtureServer([.fixture("channel"), .json(first), .json(ended)])
        let authorization = await authorized()
        let model = YouTubeEventSelection(authorization: authorization, client: makeClient(server))
        await model.refresh()
        model.select("fixture-event-one")
        #expect(model.selected?.id == "fixture-event-one")
        await #expect(throws: YouTubeReadError.missingEvent) { try await model.recheckSelected() }
        #expect(model.selected == nil)
        #expect(model.message.contains("no longer upcoming"))
        #expect(query(await server.requests.last!)["id"] == "fixture-event-one")
    }

    @Test func accountChangeImmediatelyHidesSelectionAndRejectsLateRefresh() async throws {
        let server = ReadFixtureServer([.fixture("channel")], hold: true)
        let authorization = await authorized()
        let client = YouTubeClient(token: { try await authorization.freshAccessToken(expectedGeneration: $0) },
            current: { authorization.generation == $0 && authorization.isAuthorized },
            send: { try await server.send($0) }, sleep: { await server.recordDelay($0) })
        let model = YouTubeEventSelection(authorization: authorization, client: client)
        let refresh = Task { await model.refresh() }
        while await server.requests.isEmpty { await Task.yield() }
        authorization.signOut()
        #expect(model.channel == nil && model.events.isEmpty && model.selected == nil)
        model.invalidate()
        await server.release()
        await refresh.value
        #expect(model.channel == nil && model.events.isEmpty && !model.isRefreshing)
    }

    @Test func refreshClearsDisappearedSelectionAndEmptyListExplainsScheduling() async throws {
        let first = try fixture("upcoming-first").utf8String.replacingOccurrences(of: "\"nextPageToken\":\"fixture-page-two\",", with: "")
        let server = ReadFixtureServer([.fixture("channel"), .json(first), .fixture("channel"), .json("{\"items\":[]}")])
        let model = YouTubeEventSelection(authorization: await authorized(), client: makeClient(server))
        await model.refresh(); model.select("fixture-event-one")
        #expect(model.selected != nil)
        await model.refresh()
        #expect(model.selected == nil && model.events.isEmpty)
        #expect(model.message.contains("Schedule an encoder event"))
    }

    @Test func selectionChangeDuringRecheckRejectsTheOldEvent() async throws {
        let server = ReadFixtureServer([.fixture("channel"), .fixture("upcoming-first"), .fixture("upcoming-last"), .fixture("upcoming-first")])
        let model = YouTubeEventSelection(authorization: await authorized(), client: makeClient(server))
        await model.refresh()
        model.select("fixture-event-one")
        await server.pause()
        let recheck = Task { try await model.recheckSelected() }
        while await server.requests.count < 4 { await Task.yield() }
        model.select("fixture-event-two")
        await server.release()
        await #expect(throws: CancellationError.self) { try await recheck.value }
        #expect(model.selected?.id == "fixture-event-two")
    }

    @Test func missingSelectedEventAndStreamProduceActionableErrors() async throws {
        let first = try fixture("upcoming-first").utf8String.replacingOccurrences(of: "\"nextPageToken\":\"fixture-page-two\",", with: "")
        let server = ReadFixtureServer([.fixture("channel"), .json(first), .error(404, "notFound"), .error(404, "notFound")])
        let client = makeClient(server)
        let model = YouTubeEventSelection(authorization: await authorized(), client: client)
        await model.refresh(); model.select("fixture-event-one")
        await #expect(throws: YouTubeReadError.missingEvent) { try await model.recheckSelected() }
        #expect(model.selected == nil && model.message.contains("selected event is unavailable"))
        await #expect(throws: YouTubeReadError.missingStream) {
            try await client.stream(id: "missing", channelID: "fixture-brand-channel", generation: 1)
        }
    }

    private func makeClient(_ server: ReadFixtureServer, access: ReadTokenFixture? = nil) -> YouTubeClient {
        let access = access ?? ReadTokenFixture()
        return YouTubeClient(token: { generation in
            access.calls += 1
            guard access.generation == generation else { throw CancellationError() }
            return "fixture-access-token"
        }, current: { access.generation == $0 }, send: { try await server.send($0) }, sleep: { await server.recordDelay($0) })
    }
    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
    }
    private func authorized() async -> YouTubeAuthorization {
        let value = YouTubeAuthorization(driver: ReadAuthorizationDriver(), configured: true, policyAccepted: true)
        await value.restore()
        return value
    }
}

@MainActor private final class ReadTokenFixture { var generation: UInt64 = 1; var calls = 0 }
private final class ReadFixtureBundle: NSObject {}
nonisolated private func fixture(_ name: String) throws -> Data {
    let bundle = Bundle(for: ReadFixtureBundle.self)
    let url = try #require(bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/YouTube")
        ?? bundle.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}
private extension Data { var utf8String: String { String(decoding: self, as: UTF8.self) } }

private actor ReadFixtureServer {
    nonisolated enum Reply: Sendable {
        case fixture(String), json(String), data(Data), error(Int, String, retry: String? = nil), network
    }
    var replies: [Reply]
    var requests: [URLRequest] = []
    var delays: [Double] = []
    var hold: Bool
    var waiting: CheckedContinuation<Void, Never>?
    init(_ replies: [Reply], hold: Bool = false) { self.replies = replies; self.hold = hold }
    func pause() { hold = true }
    func release() { hold = false; waiting?.resume(); waiting = nil }
    func recordDelay(_ value: Double) { delays.append(value) }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if hold { await withCheckedContinuation { waiting = $0 } }
        try Task.checkCancellation()
        let reply = try #require(!replies.isEmpty ? replies.removeFirst() : nil)
        var status = 200
        var headers: [String: String] = [:]
        let data: Data
        switch reply {
        case .fixture(let name): data = try fixture(name)
        case .json(let value): data = Data(value.utf8)
        case .data(let value): data = value
        case .error(let code, let reason, let retry):
            status = code
            headers["Retry-After"] = retry
            data = Data("{\"error\":{\"message\":\"private-upstream-detail\",\"errors\":[{\"reason\":\"\(reason)\"}]}}".utf8)
        case .network: throw URLError(.networkConnectionLost)
        }
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!)
    }
}

@MainActor private final class ReadAuthorizationDriver: GoogleAuthorizationDriving {
    func connect(presenting: UIViewController) async throws -> GoogleAuthorizationAccount { try await restore() }
    func restore() async throws -> GoogleAuthorizationAccount {
        GoogleAuthorizationAccount(id: "fixture-account", grantedScopes: [YouTubeAuthorization.requiredScope])
    }
    func accessToken(accountID: String) async throws -> String { "fixture-access-token" }
    func signOut() {}
    func disconnect() async throws {}
    func handle(_ url: URL) -> Bool { false }
}
