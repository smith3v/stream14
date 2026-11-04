import Foundation

/// Pending and legacy inspection files are never promoted on relaunch.
struct ExperimentSample: Codable, Identifiable {
    enum Status: String, Codable {
        case pending, needsInspection, interrupted, failed, completed
    }

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

    func save(in directory: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: directory.appendingPathComponent(id.uuidString + ".json"), options: .atomic)
    }

    static func loadAll() throws -> [ExperimentSample] {
        let directory = try directory()
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Self.self, from: Data(contentsOf: $0)) }
            .sorted { $0.created > $1.created }
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
