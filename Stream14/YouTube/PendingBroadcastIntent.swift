import Foundation

/// Resource identifiers only. Never add tokens, ingestion addresses or keys here.
nonisolated struct PendingBroadcastIntent: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable { case notCreated, inserting, unresolvedInsert, created, binding, prepared }
    let operationID: UUID
    let channelID: String
    let broadcastID: String
    let profile: String
    var phase: Phase
    var createdStreamID: String?

    init(channelID: String, broadcastID: String, profile: SessionProfile) {
        operationID = UUID()
        self.channelID = channelID
        self.broadcastID = broadcastID
        self.profile = profile.rawValue
        phase = .notCreated
    }

    func matches(channelID: String, broadcastID: String, profile: SessionProfile) -> Bool {
        self.channelID == channelID && self.broadcastID == broadcastID && self.profile == profile.rawValue
    }
}

@MainActor final class PendingBroadcastIntentStore {
    private let directory: URL?
    private let write: (Data, URL) throws -> Void

    init(directory: URL? = nil, write: @escaping (Data, URL) throws -> Void = {
        try $0.write(to: $1, options: [.atomic, .completeFileProtectionUnlessOpen])
    }) {
        self.directory = directory
        self.write = write
    }

    func load() throws -> PendingBroadcastIntent? {
        let url = try location()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= 8_192 else { throw YouTubeBindingError.intentUnavailable }
        return try JSONDecoder().decode(PendingBroadcastIntent.self, from: Data(contentsOf: url))
    }

    func save(_ intent: PendingBroadcastIntent) throws {
        try write(JSONEncoder().encode(intent), location())
    }

    private func location() throws -> URL {
        var directory = try directory ?? FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("PendingYouTube", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory.appendingPathComponent("binding-intent.json")
    }
}
