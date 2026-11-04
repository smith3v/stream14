import Foundation

/// No “complete” state: the upstream recorder does not expose its final writer status.
struct ExperimentSample: Codable, Identifiable {
    enum Status: String, Codable {
        case pending, needsInspection, interrupted, failed
    }

    let id: UUID
    let created: Date
    var status: Status
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
