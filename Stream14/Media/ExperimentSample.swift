import Foundation

/// Pending and legacy inspection files are never promoted on relaunch.
nonisolated struct ExperimentSample: Codable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable {
        case pending, needsInspection, interrupted, failed, completed
    }

    enum Review: String, Codable, Sendable { case readable, unreadable, missing }
    struct Recovery: Codable, Identifiable, Sendable {
        enum Status: String, Codable, Sendable { case pending, recovered, failed }
        let id: UUID
        var status: Status
        var duration: Double?
        init(id: UUID = UUID(), status: Status = .pending) { self.id = id; self.status = status }
    }

    var version: Int? = 2
    var profile: String?
    var duration: Double?
    var byteCount: Int64?
    var review: Review?
    var recoveries: [Recovery]?
    // A separate review manifest preserves an unreadable legacy sidecar verbatim.
    var preservesMalformedMetadata: Bool?
    let id: UUID
    let created: Date
    var status: Status
    var metrics: LocalRecorder.Metrics?
    var fileName: String { id.uuidString + ".mp4" }

    init(id: UUID = UUID(), created: Date = Date(), status: Status = .pending) {
        self.id = id
        self.created = created
        self.status = status
    }

    func recoveryFileName(_ recovery: Recovery) -> String {
        id.uuidString + ".recovered." + recovery.id.uuidString + ".mp4"
    }

    func save(in directory: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: directory.appendingPathComponent(id.uuidString + (preservesMalformedMetadata == true ? ".review.json" : ".json")), options: .atomic)
    }

    /// Read the original video's current logical size, never a sidecar or estimate.
    /// Missing/unreadable artifacts and unexpected file types have no known size.
    func fileSize(in directory: URL) -> Int64? {
        Self.fileSize(at: directory.appendingPathComponent(fileName))
    }

    func recoveryFileSize(_ recovery: Recovery, in directory: URL) -> Int64? {
        Self.fileSize(at: directory.appendingPathComponent(recoveryFileName(recovery)))
    }

    private static func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.int64Value >= 0 else { return nil }
        return size.int64Value
    }

    /// Remove only this recording's artifacts. Keep status last so failures leave
    /// a visible entry that can be retried. Never recursively remove a directory.
    func delete(in directory: URL) throws {
        let names = [fileName] + (recoveries ?? []).map(recoveryFileName) +
            [id.uuidString + ".observations.json", id.uuidString + ".json", id.uuidString + ".review.json"]
        for name in names {
            let url = directory.appendingPathComponent(name)
            let attributes: [FileAttributeKey: Any]
            do { attributes = try FileManager.default.attributesOfItem(atPath: url.path) }
            catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
                continue
            }
            let type = attributes[.type] as? FileAttributeType
            guard type == .typeRegular || type == .typeSymbolicLink else {
                throw DeletionError.unexpectedArtifact
            }
            try FileManager.default.removeItem(at: url)
        }
    }

    func deletingRecovery(_ recovery: Recovery, in directory: URL) throws -> Self {
        guard (recoveries ?? []).contains(where: { $0.id == recovery.id }) else { return self }
        let url = directory.appendingPathComponent(recoveryFileName(recovery))
        if FileManager.default.fileExists(atPath: url.path) {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular ||
                    attributes[.type] as? FileAttributeType == .typeSymbolicLink else {
                throw DeletionError.unexpectedArtifact
            }
            try FileManager.default.removeItem(at: url)
        }
        var updated = self
        updated.recoveries?.removeAll { $0.id == recovery.id }
        try updated.save(in: directory)
        return updated
    }

    enum DeletionError: Error { case unexpectedArtifact }

    static func loadAll(in suppliedDirectory: URL? = nil, activeID: UUID? = nil) throws -> [ExperimentSample] {
        let directory = try suppliedDirectory ?? Self.directory()
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var ids = Set<UUID>()
        for file in files {
            let pieces = file.lastPathComponent.split(separator: ".")
            guard let first = pieces.first, let id = UUID(uuidString: String(first)),
                  file.pathExtension == "mp4" || file.lastPathComponent == first + ".json" ||
                  file.lastPathComponent == first + ".review.json" else { continue }
            ids.insert(id)
        }
        return ids.map { id in
            let original = directory.appendingPathComponent(id.uuidString + ".json")
            let reviewURL = directory.appendingPathComponent(id.uuidString + ".review.json")
            let decode: (URL) -> Self? = { url in
                guard let data = try? Data(contentsOf: url),
                      let value = try? JSONDecoder().decode(Self.self, from: data), value.id == id else { return nil }
                return value
            }
            var sample = decode(reviewURL) ?? decode(original) ?? Self(id: id,
                created: (try? FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(id.uuidString + ".mp4").path)[.creationDate] as? Date) ?? Date(),
                status: .needsInspection)
            if decode(original) == nil, FileManager.default.fileExists(atPath: original.path) {
                sample.preservesMalformedMetadata = true
            }
            if sample.status == .pending, id != activeID { sample.status = .interrupted }
            // Include partial recovery artifacts even if the process died before saving status.
            var attempts = sample.recoveries ?? []
            for file in files {
                let parts = file.lastPathComponent.split(separator: ".")
                guard parts.count == 4, parts[0] == id.uuidString, parts[1] == "recovered",
                      parts[3] == "mp4", let recoveryID = UUID(uuidString: String(parts[2])) else { continue }
                if !attempts.contains(where: { $0.id == recoveryID }) {
                    attempts.append(Recovery(id: recoveryID, status: .failed))
                }
            }
            for index in attempts.indices where attempts[index].status == .pending { attempts[index].status = .failed }
            sample.recoveries = attempts.isEmpty ? nil : attempts
            return sample
        }.sorted { $0.created > $1.created }
    }

    static func directory() throws -> URL {
        var directory = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("MediaExperiments", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory
    }
}
