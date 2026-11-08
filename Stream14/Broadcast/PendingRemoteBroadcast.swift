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
}

@MainActor final class PendingRemoteBroadcastStore {
    private let url: URL
    init(url: URL? = nil) {
        self.url = url ?? URL.applicationSupportDirectory.appendingPathComponent("PendingRemoteBroadcast.json")
    }
    func load() throws -> PendingRemoteBroadcast? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(PendingRemoteBroadcast.self, from: Data(contentsOf: url))
    }
    func save(_ pending: PendingRemoteBroadcast?) throws {
        guard let pending else {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            return
        }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = url
        try JSONEncoder().encode(pending).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
    }
}
