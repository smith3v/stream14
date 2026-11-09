import Foundation

/// Only unresolved remote identity and transition ambiguity are durable. No credentials, user metadata,
/// overlay URLs or generation-specific readiness survive a process restart.
nonisolated struct PendingRemoteBroadcast: Codable, Equatable, Sendable {
    let channelID: String
    let eventID: String
    var interrupted: Bool? = nil
    var streamID: String? = nil
    var profileName: String? = nil
    var transition: YouTubeBroadcastTransition? = nil
    var mutationID: UUID? = nil
    var verifiedAt: Date? = Date()
}

@MainActor final class PendingRemoteBroadcastStore {
    private let url: URL
    private let now: () -> Date
    private let remove: (URL) throws -> Void
    init(url: URL? = nil, now: @escaping () -> Date = Date.init,
         remove: @escaping (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) {
        self.remove = remove
        self.now = now
        self.url = url ?? URL.applicationSupportDirectory.appendingPathComponent("PendingRemoteBroadcast.json")
    }
    var requiresStudioResolution: Bool { FileManager.default.fileExists(atPath: barrier.path) }
    private var barrier: URL { url.deletingLastPathComponent().appendingPathComponent("youtube-studio-resolution-required") }
    var hasSavedAPIData: Bool { FileManager.default.fileExists(atPath: url.path) }
    func eraseAPIData(requiringStudioResolution: Bool = true) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if requiringStudioResolution {
            try Data("Studio resolution required".utf8).write(to: barrier, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            var marker = barrier
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try marker.setResourceValues(values)
        }
        try save(nil)
    }
    func confirmStudioResolution() throws {
        if requiresStudioResolution { try remove(barrier) }
    }
    func expireIfNeeded() throws -> Bool {
        guard !requiresStudioResolution else { return true }
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let pending = try JSONDecoder().decode(PendingRemoteBroadcast.self, from: Data(contentsOf: url))
        guard !isFresh(pending.verifiedAt) else { return false }
        try eraseAPIData()
        return true
    }
    private func isFresh(_ date: Date?) -> Bool {
        guard let date else { return false }
        let age = now().timeIntervalSince(date)
        return age >= 0 && age < 30 * 24 * 60 * 60
    }
    func load() throws -> PendingRemoteBroadcast? {
        if try expireIfNeeded() { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(PendingRemoteBroadcast.self, from: Data(contentsOf: url))
    }
    func save(_ pending: PendingRemoteBroadcast?) throws {
        guard let pending else {
            if FileManager.default.fileExists(atPath: url.path) { try remove(url) }
            return
        }
        guard !requiresStudioResolution else { throw YouTubeBindingError.studioResolutionRequired }
        if try expireIfNeeded() { throw YouTubeBindingError.studioResolutionRequired }
        guard isFresh(pending.verifiedAt) else {
            try eraseAPIData()
            throw YouTubeBindingError.studioResolutionRequired
        }
        // Phase/state updates never refresh the acquisition age of these IDs.
        var value = pending
        if let previous = try load(), previous.channelID == pending.channelID, previous.eventID == pending.eventID {
            value.verifiedAt = previous.verifiedAt
        }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = url
        try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
    }
}
