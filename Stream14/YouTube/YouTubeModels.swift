import Foundation

nonisolated struct YouTubePage<Item: Decodable & Sendable>: Decodable, Sendable {
    let items: [Item]
    let nextPageToken: String?
}

nonisolated struct YouTubeChannel: Codable, Equatable, Identifiable, Sendable {
    nonisolated struct Snippet: Codable, Equatable, Sendable { let title: String? }
    let id: String
    let snippet: Snippet?
    var title: String { snippet?.title?.isEmpty == false ? snippet!.title! : "Unnamed YouTube channel" }
}

nonisolated struct YouTubeBroadcast: Codable, Equatable, Identifiable, Sendable {
    nonisolated struct Snippet: Codable, Equatable, Sendable {
        let channelId: String?
        let title: String?
        let scheduledStartTime: String?
        let isDefaultBroadcast: Bool?
    }
    nonisolated struct Status: Codable, Equatable, Sendable {
        let lifeCycleStatus: String?
        let privacyStatus: String?
    }
    nonisolated struct ContentDetails: Codable, Equatable, Sendable {
        nonisolated struct MonitorStream: Codable, Equatable, Sendable { let enableMonitorStream: Bool? }
        let boundStreamId: String?
        let enableAutoStart: Bool?
        let enableAutoStop: Bool?
        var monitorStream: MonitorStream? = nil
    }
    let id: String
    let snippet: Snippet?
    let status: Status?
    let contentDetails: ContentDetails?

    var title: String { snippet?.title?.isEmpty == false ? snippet!.title! : "Untitled event" }
    var scheduledStart: Date? {
        guard let value = snippet?.scheduledStartTime else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
    var visibility: String {
        switch status?.privacyStatus {
        case "public": "Public"
        case "unlisted": "Unlisted"
        case "private": "Private"
        default: "Visibility unavailable"
        }
    }
    func ineligibility(channelID: String) -> String? {
        guard snippet?.channelId == channelID else { return "This event belongs to a different or unknown YouTube channel." }
        guard snippet?.isDefaultBroadcast != true else { return "Choose a scheduled encoder event in YouTube Studio." }
        guard ["created", "ready"].contains(status?.lifeCycleStatus ?? "") else {
            return "This event is no longer upcoming, or its YouTube state is unavailable."
        }
        guard snippet?.title?.isEmpty == false, scheduledStart != nil else {
            return "The event title or scheduled time is unavailable. Refresh or check YouTube Studio."
        }
        guard ["public", "unlisted", "private"].contains(status?.privacyStatus ?? "") else {
            return "The event visibility is unavailable. Refresh before selecting it."
        }
        guard contentDetails?.enableAutoStop == false else {
            return "Disable auto-stop for this event in YouTube Studio, then refresh."
        }
        guard contentDetails?.enableAutoStart != nil else { return "The auto-start setting is unavailable. Refresh or check YouTube Studio." }
        return nil
    }
}

/// F3 intentionally does not retain ingestion addresses/stream keys from responses.
/// F5 owns their short-lived use when resolving a confirmed event binding.
nonisolated struct YouTubeStream: Codable, Equatable, Identifiable, Sendable {
    nonisolated struct Snippet: Codable, Equatable, Sendable { let channelId: String?; let title: String? }
    nonisolated struct CDN: Codable, Equatable, Sendable {
        let ingestionType: String?
        let resolution: String?
        let frameRate: String?
    }
    nonisolated struct Status: Codable, Equatable, Sendable { let streamStatus: String? }
    let id: String
    let snippet: Snippet?
    let cdn: CDN?
    let status: Status?
}

nonisolated enum YouTubeReadError: Error, Equatable, LocalizedError {
    case authorizationRequired, insufficientPermission, liveDisabled, wrongChannel, missingChannel, ambiguousChannel
    case missingEvent, missingStream, quotaExceeded, rateLimited, unavailable, network, malformedResponse, pagination
    case rejected(Int)

    var errorDescription: String? {
        switch self {
        case .authorizationRequired: "YouTube authorization expired or was revoked. Connect YouTube again."
        case .insufficientPermission: "YouTube permission is missing. Reconnect and allow YouTube access for the intended channel."
        case .liveDisabled: "Live streaming is not enabled for this YouTube channel. Enable it in YouTube Studio and try again."
        case .wrongChannel: "YouTube returned a different channel. Reconnect using the intended channel or Brand Account."
        case .missingChannel: "No YouTube channel was returned. Create or select the intended channel, then reconnect."
        case .ambiguousChannel: "More than one channel was returned. Reconnect and choose the intended YouTube channel or Brand Account."
        case .missingEvent: "The selected event is unavailable. Refresh and choose an upcoming event in this channel."
        case .missingStream: "The bound ingestion stream is unavailable. Check the event in YouTube Studio."
        case .quotaExceeded: "YouTube API quota is exhausted. Wait for the quota to reset; repeatedly refreshing will not help."
        case .rateLimited: "YouTube is limiting requests. Wait before refreshing again."
        case .unavailable: "YouTube is temporarily unavailable. Try refreshing later."
        case .network: "YouTube could not be reached. Check your internet connection and refresh."
        case .malformedResponse: "YouTube returned incomplete or unsupported information. Refresh or check YouTube Studio."
        case .pagination: "YouTube's event list could not be read completely. Refresh before selecting an event."
        case .rejected(let status): "YouTube rejected this request (HTTP \(status)). Check channel access and try again."
        }
    }
}

nonisolated enum YouTubeBroadcastTransition: String, Codable, Sendable { case testing, live, complete }
