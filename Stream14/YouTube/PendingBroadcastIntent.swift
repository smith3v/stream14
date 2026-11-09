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
    var verifiedAt: Date?

    init(channelID: String, broadcastID: String, profile: SessionProfile) {
        operationID = UUID()
        self.channelID = channelID
        self.broadcastID = broadcastID
        self.profile = profile.rawValue
        phase = .notCreated
        verifiedAt = Date()
    }

    func matches(channelID: String, broadcastID: String, profile: SessionProfile) -> Bool {
        self.channelID == channelID && self.broadcastID == broadcastID && self.profile == profile.rawValue
    }
}

@MainActor final class PendingBroadcastIntentStore {
    private let directory: URL?
    private let now: () -> Date
    private let write: (Data, URL) throws -> Void

    init(directory: URL? = nil, now: @escaping () -> Date = Date.init, write: @escaping (Data, URL) throws -> Void = {
        try $0.write(to: $1, options: [.atomic, .completeFileProtectionUnlessOpen])
    }) {
        self.directory = directory
        self.now = now
        self.write = write
    }

    func load(channelID: String? = nil, broadcastID: String? = nil) throws -> PendingBroadcastIntent? {
        guard !requiresStudioResolution else { throw YouTubeBindingError.studioResolutionRequired }
        if try expireIfNeeded() { throw YouTubeBindingError.studioResolutionRequired }
        let intents = try journal()
        guard let channelID, let broadcastID else { return intents.last }
        return intents.first { $0.channelID == channelID && $0.broadcastID == broadcastID }
    }

    private func journal() throws -> [PendingBroadcastIntent] {
        let url = try location()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= 1_048_576 else { throw YouTubeBindingError.intentUnavailable }
        let data = try Data(contentsOf: url)
        // Preserve the early, undistributed single-intent checkpoint on upgrade.
        let intents: [PendingBroadcastIntent]
        if let entries = try? JSONDecoder().decode([PendingBroadcastIntent].self, from: data) { intents = entries }
        else { intents = [try JSONDecoder().decode(PendingBroadcastIntent.self, from: data)] }
        let contexts = intents.map { [$0.channelID, $0.broadcastID] }
        guard Set(contexts).count == intents.count else { throw YouTubeBindingError.intentUnavailable }
        return intents
    }

    func save(_ intent: PendingBroadcastIntent) throws {
        guard !requiresStudioResolution else { throw YouTubeBindingError.studioResolutionRequired }
        if try expireIfNeeded() { throw YouTubeBindingError.studioResolutionRequired }
        guard isFresh(intent.verifiedAt) else {
            try eraseAPIData()
            throw YouTubeBindingError.studioResolutionRequired
        }
        var intents = try journal()
        if let index = intents.firstIndex(where: { $0.channelID == intent.channelID && $0.broadcastID == intent.broadcastID }) {
            var update = intent
            update.verifiedAt = intents[index].verifiedAt
            intents[index] = update
        } else { intents.append(intent) }
        let encoded = try JSONEncoder().encode(intents)
        guard encoded.count <= 1_048_576 else { throw YouTubeBindingError.intentUnavailable }
        try write(encoded, location())
    }

    func expireIfNeeded() throws -> Bool {
        guard !requiresStudioResolution else { return true }
        guard try journal().contains(where: { !isFresh($0.verifiedAt) }) else { return false }
        try eraseAPIData()
        return true
    }

    private func isFresh(_ date: Date?) -> Bool {
        guard let date else { return false }
        let age = now().timeIntervalSince(date)
        return age >= 0 && age < 30 * 24 * 60 * 60
    }

    // Persist the nonidentifying guard before removing IDs. Late mutation callbacks
    // cannot recreate API data or enable a new write after deletion.
    var requiresStudioResolution: Bool { (try? FileManager.default.fileExists(atPath: barrier().path)) ?? true }

    var hasSavedAPIData: Bool { (try? FileManager.default.fileExists(atPath: location().path)) ?? true }
    func eraseAPIData(requiringStudioResolution: Bool = true) throws {
        if requiringStudioResolution { try write(Data("Studio resolution required".utf8), barrier()) }
        let url = try location()
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    func confirmStudioResolution() throws {
        let url = try barrier()
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    private func barrier() throws -> URL { try location().deletingLastPathComponent().appendingPathComponent("studio-resolution-required") }

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
