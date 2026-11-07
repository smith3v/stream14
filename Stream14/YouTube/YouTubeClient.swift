import Foundation

/// Only idempotent reads. Every retry gets a current SDK-managed token, and every
/// response is checked against the account generation before decoding/returning.
nonisolated struct YouTubeClient: Sendable {
    typealias Send = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    typealias Token = @MainActor @Sendable (UInt64) async throws -> String
    typealias Current = @MainActor @Sendable (UInt64) -> Bool
    private let send: Send
    private let token: Token
    private let current: Current
    private let sleep: @Sendable (Double) async throws -> Void

    init(authorization: YouTubeAuthorization) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration, delegate: YouTubeReadSessionDelegate(), delegateQueue: nil)
        self.init(token: { try await authorization.freshAccessToken(expectedGeneration: $0) },
                  current: { authorization.generation == $0 && authorization.isAuthorized },
                  send: { request in
                      let (data, response) = try await session.data(for: request)
                      guard let response = response as? HTTPURLResponse else { throw YouTubeReadError.malformedResponse }
                      return (data, response)
                  })
    }

    init(token: @escaping Token, current: @escaping Current, send: @escaping Send,
         sleep: @escaping @Sendable (Double) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) {
        self.token = token; self.current = current; self.send = send; self.sleep = sleep
    }

    func authorizedChannel(generation: UInt64) async throws -> YouTubeChannel {
        let channels: [YouTubeChannel] = try await pages("channels", query: ["part": "snippet", "mine": "true"], generation: generation)
        guard let channel = channels.first else { throw YouTubeReadError.missingChannel }
        guard channels.count == 1 else { throw YouTubeReadError.ambiguousChannel }
        guard !channel.id.isEmpty else { throw YouTubeReadError.malformedResponse }
        return channel
    }

    func upcomingBroadcasts(channelID: String, generation: UInt64) async throws -> [YouTubeBroadcast] {
        let events: [YouTubeBroadcast] = try await pages("liveBroadcasts", query: [
            "part": "snippet,status,contentDetails", "broadcastStatus": "upcoming", "broadcastType": "event"
        ], generation: generation)
        guard events.allSatisfy({ $0.snippet?.channelId == channelID }) else { throw YouTubeReadError.wrongChannel }
        var identifiers = Set<String>()
        return try events.filter { event in
            guard !event.id.isEmpty else { throw YouTubeReadError.malformedResponse }
            return identifiers.insert(event.id).inserted
        }.sorted { ($0.scheduledStart ?? .distantFuture) < ($1.scheduledStart ?? .distantFuture) }
    }

    func broadcast(id: String, channelID: String, generation: UInt64) async throws -> YouTubeBroadcast {
        let page: YouTubePage<YouTubeBroadcast> = try await read("liveBroadcasts", query: ["part": "snippet,status,contentDetails", "id": id], generation: generation)
        guard page.items.count == 1, let event = page.items.first, event.id == id else { throw YouTubeReadError.missingEvent }
        guard event.snippet?.channelId == channelID else { throw YouTubeReadError.wrongChannel }
        return event
    }

    func stream(id: String, channelID: String, generation: UInt64) async throws -> YouTubeStream {
        let page: YouTubePage<YouTubeStream> = try await read("liveStreams", query: ["part": "snippet,cdn,status", "id": id], generation: generation)
        guard page.items.count == 1, let stream = page.items.first, stream.id == id else { throw YouTubeReadError.missingStream }
        guard stream.snippet?.channelId == channelID else { throw YouTubeReadError.wrongChannel }
        return stream
    }

    private func pages<Item: Decodable & Sendable>(_ resource: String, query: [String: String], generation: UInt64) async throws -> [Item] {
        var values: [Item] = []
        var next: String?
        var seen = Set<String>()
        for _ in 0..<100 {
            var query = query
            query["maxResults"] = "50"
            query["pageToken"] = next
            let page: YouTubePage<Item> = try await read(resource, query: query, generation: generation)
            values.append(contentsOf: page.items)
            guard let token = page.nextPageToken, !token.isEmpty else { return values }
            guard seen.insert(token).inserted else { throw YouTubeReadError.pagination }
            next = token
        }
        // Never hand off a silently truncated selection list.
        throw YouTubeReadError.pagination
    }

    private func read<Value: Decodable & Sendable>(_ resource: String, query: [String: String], generation: UInt64) async throws -> Value {
        var retries = 0
        var refreshed = false
        while true {
            try await check(generation)
            let accessToken: String
            do { accessToken = try await token(generation) }
            catch {
                if error is CancellationError || (error as? YouTubeAuthorizationError) == .cancelled { throw CancellationError() }
                throw YouTubeReadError.authorizationRequired
            }
            try await check(generation)
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/" + resource)!
            components.queryItems = query.sorted(by: { $0.key < $1.key }).map { URLQueryItem(name: $0.key, value: $0.value) }
            var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.httpMethod = "GET"
            request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let data: Data
            let response: HTTPURLResponse
            do { (data, response) = try await send(request) }
            catch {
                try await check(generation)
                if error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
                let retryable: Set<URLError.Code> = [.timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed]
                if let code = (error as? URLError)?.code, retryable.contains(code), retries < 2 {
                    try await sleep(pow(2, Double(retries))); retries += 1
                    continue
                }
                throw error is YouTubeReadError ? error : YouTubeReadError.network
            }
            try await check(generation)
            guard response.url?.scheme == "https", response.url?.host == "www.googleapis.com" else { throw YouTubeReadError.malformedResponse }
            if (200..<300).contains(response.statusCode) {
                guard data.count <= 2_000_000 else { throw YouTubeReadError.malformedResponse }
                do { return try JSONDecoder().decode(Value.self, from: data) }
                catch { throw YouTubeReadError.malformedResponse }
            }
            if response.statusCode == 401, !refreshed {
                // The provider calls the SDK-supported refresh-if-needed operation;
                // never manually refresh/persist SDK credentials or retry forever.
                refreshed = true
                continue
            }
            let failure = Self.failure(status: response.statusCode, data: data, resource: resource)
            if [.rateLimited, .unavailable].contains(failure), retries < 2 {
                let delay = Self.retryDelay(response, fallback: pow(2, Double(retries)))
                // Respect a longer server delay by returning a wait message; do not
                // shorten Retry-After or leave an unbounded sleeping request.
                if delay <= 10 {
                    try await sleep(delay); retries += 1
                    continue
                }
            }
            throw failure
        }
    }

    private func check(_ generation: UInt64) async throws {
        try Task.checkCancellation()
        guard await current(generation) else { throw CancellationError() }
    }

    private nonisolated struct ErrorEnvelope: Decodable {
        nonisolated struct Detail: Decodable { let reason: String? }
        nonisolated struct Body: Decodable { let errors: [Detail]? }
        let error: Body?
    }
    private static func failure(status: Int, data: Data, resource: String) -> YouTubeReadError {
        let reasons = Set((try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error?.errors?.compactMap(\.reason) ?? [])
        if status == 401 { return .authorizationRequired }
        if !reasons.isDisjoint(with: ["quotaExceeded", "dailyLimitExceeded", "dailyLimitExceededUnreg"]) { return .quotaExceeded }
        if !reasons.isDisjoint(with: ["liveStreamingNotEnabled", "livePermissionBlocked"]) { return .liveDisabled }
        if !reasons.isDisjoint(with: ["insufficientPermissions", "insufficientLivePermissions", "youtubeSignupRequired"]) { return .insufficientPermission }
        if status == 429 || !reasons.isDisjoint(with: ["rateLimitExceeded", "userRateLimitExceeded"]) { return .rateLimited }
        if [500, 502, 503, 504].contains(status) { return .unavailable }
        if status == 404 { return resource == "liveStreams" ? .missingStream : resource == "channels" ? .missingChannel : .missingEvent }
        return .rejected(status)
    }
    private static func retryDelay(_ response: HTTPURLResponse, fallback: Double) -> Double {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return fallback }
        if let seconds = Double(value), seconds.isFinite { return max(0, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        return formatter.date(from: value).map { max(0, $0.timeIntervalSinceNow) } ?? fallback
    }
}

/// Requests never redirect credentials to another origin, and API bodies have no
/// disk cache or cookie store. Ordinary TLS validation remains unchanged.
private nonisolated final class YouTubeReadSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
