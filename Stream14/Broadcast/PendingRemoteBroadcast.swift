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
        if requiresStudioResolution { try FileManager.default.removeItem(at: barrier) }
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
        guard !requiresStudioResolution else { throw YouTubeBindingError.studioResolutionRequired }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = url
        try JSONEncoder().encode(pending).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
    }
}
