import Foundation
import Darwin
import Synchronization

/// This is also the export allowlist. No free-form strings, errors, URLs, dates,
/// paths, account identifiers or media can be represented by this schema.
nonisolated struct QualificationReport: Codable, Sendable {
    enum Profile: String, Codable, Sendable { case fullHD, hd }
    enum Codec: String, Codable, Sendable { case h264AACMP4 }
    enum Thermal: Int, Codable, Sendable { case nominal, fair, serious, critical, unknown }
    enum End: String, Codable, Sendable { case checkpoint, stopped }
    struct Observation: Codable, Sendable {
        let elapsedSeconds: Double
        let chargedFootprintBytes: UInt64?
        let residentMappingBytes: UInt64?
        let thermal: Thermal
    }
    struct Encoder: Codable, Sendable {
        var admittedVideo = 0
        var admittedPCMFrames = 0
        var rejectedVideo = 0
        var rejectedPCMFrames = 0
        var highWaterBytes = 0
        var highWaterVideo = 0
        var highWaterPCMFrames = 0
    }
    struct File: Codable, Sendable {
        var offeredVideo = 0
        var offeredAudioPackets = 0
        var writtenVideo = 0
        var writtenAudioPackets = 0
        var rejectedVideo = 0
        var rejectedAudioPackets = 0
        var estimatedMissing30HzIntervals = 0
        var videoGapsAtLeast500ms = 0
        var largestVideoGapSeconds = 0.0
        var startupHighWaterBytes = 0
        var startupHighWaterPackets = 0
    }
    struct Transport: Codable, Sendable {
        var generations = 0
        var admittedPackets = 0
        var acknowledgedPackets = 0
        var skippedBeforeOrigin = 0
        var rejectedPackets = 0
        var discardedAdmittedPackets = 0
        var highWaterBytes = 0
        var highWaterPackets = 0
        mutating func add(_ other: Self) {
            generations += other.generations
            admittedPackets += other.admittedPackets
            acknowledgedPackets += other.acknowledgedPackets
            skippedBeforeOrigin += other.skippedBeforeOrigin
            rejectedPackets += other.rejectedPackets
            discardedAdmittedPackets += other.discardedAdmittedPackets
            highWaterBytes = max(highWaterBytes, other.highWaterBytes)
            highWaterPackets = max(highWaterPackets, other.highWaterPackets)
        }
    }
    var schema = 1
    var diagnosticSession = UUID()
    let profile: Profile
    var codec = Codec.h264AACMP4
    var end = End.checkpoint
    var elapsedSeconds = 0.0
    var observationCount = 0
    var peakChargedFootprintBytes: UInt64?
    var peakResidentMappingBytes: UInt64?
    var worstThermal = Thermal.unknown
    var encoder = Encoder()
    var file = File()
    var transport = Transport()
    var firstObservation: Observation?
    // Online lifetime regression survives the bounded recent window. Units: bytes/second.
    var chargedObservationCount = 0
    var chargedMeanSeconds = 0.0
    var chargedMeanBytes = 0.0
    var chargedTimeSquaredDeviation = 0.0
    var chargedTimeByteCovariance = 0.0
    var chargedSlopeBytesPerSecond: Double?
    var observations: [Observation] = []
    static let observationLimit = 120

    init(profile: SessionProfile) { self.profile = profile == .fullHD ? .fullHD : .hd }

    mutating func observe(_ observation: Observation) {
        // Reject invalid clocks rather than poisoning JSON or going backwards.
        guard observation.elapsedSeconds.isFinite, observation.elapsedSeconds >= elapsedSeconds else { return }
        elapsedSeconds = observation.elapsedSeconds
        observationCount += 1
        if firstObservation == nil { firstObservation = observation }
        if let value = observation.chargedFootprintBytes {
            peakChargedFootprintBytes = max(peakChargedFootprintBytes ?? 0, value)
            chargedObservationCount += 1
            let dx = observation.elapsedSeconds - chargedMeanSeconds
            let dy = Double(value) - chargedMeanBytes
            chargedMeanSeconds += dx / Double(chargedObservationCount)
            chargedMeanBytes += dy / Double(chargedObservationCount)
            chargedTimeSquaredDeviation += dx * (observation.elapsedSeconds - chargedMeanSeconds)
            chargedTimeByteCovariance += dx * (Double(value) - chargedMeanBytes)
            chargedSlopeBytesPerSecond = chargedTimeSquaredDeviation > 0 ? chargedTimeByteCovariance / chargedTimeSquaredDeviation : nil
        }
        if let value = observation.residentMappingBytes {
            peakResidentMappingBytes = max(peakResidentMappingBytes ?? 0, value)
        }
        if observation.thermal != .unknown,
           worstThermal == .unknown || observation.thermal.rawValue > worstThermal.rawValue {
            worstThermal = observation.thermal
        }
        if observations.count == Self.observationLimit { observations.removeFirst() }
        observations.append(observation)
    }

    func sanitizedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func memory(elapsed: Double) -> Observation {
        var vm = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return Observation(elapsedSeconds: elapsed,
            chargedFootprintBytes: result == KERN_SUCCESS ? vm.phys_footprint : nil,
            residentMappingBytes: result == KERN_SUCCESS ? vm.resident_size : nil,
            thermal: Thermal(rawValue: ProcessInfo.processInfo.thermalState.rawValue) ?? .unknown)
    }
}

/// A single finite file per recording, atomically replaced outside callbacks.
/// The actor serializes writes and reads; the parent directory excludes backup.
actor QualificationCheckpoint {
    enum Failure: Error { case unavailable }
    static let maximumBytes = 128 * 1024
    static func url(id: UUID, directory: URL) -> URL {
        directory.appendingPathComponent(id.uuidString + ".qualification.json")
    }
    func save(_ report: QualificationReport, id: UUID, directory: URL) throws {
        let data = try report.sanitizedData()
        guard data.count <= Self.maximumBytes else { throw Failure.unavailable }
        var url = Self.url(id: id, directory: directory)
        try data.write(to: url, options: .atomic)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
    func load(id: UUID, directory: URL) throws -> QualificationReport {
        let url = Self.url(id: id, directory: directory)
        guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= Self.maximumBytes else { throw Failure.unavailable }
        let report = try JSONDecoder().decode(QualificationReport.self, from: Data(contentsOf: url))
        guard report.schema == 1, report.observations.count <= QualificationReport.observationLimit,
              report.elapsedSeconds.isFinite, report.elapsedSeconds >= 0 else { throw Failure.unavailable }
        return report
    }
}

/// Fixed-size aggregate across all reconnect generations; retains no publisher,
/// samples, errors or generation dictionary. Existing publisher locks serialize
/// deltas; this lock only adds integers, never performs I/O.
nonisolated final class QualificationTransportCounter: Sendable {
    private let totals = Mutex(QualificationReport.Transport())
    func begin() { totals.withLock { $0.generations += 1 } }
    func update(from old: RTMPSPublisher.Metrics, to new: RTMPSPublisher.Metrics) {
        totals.withLock { value in
            value.admittedPackets += new.acceptedPackets - old.acceptedPackets
            value.acknowledgedPackets += new.acknowledgedPackets - old.acknowledgedPackets
            value.skippedBeforeOrigin += new.skippedBeforeOrigin - old.skippedBeforeOrigin
            value.rejectedPackets += new.rejectedPackets - old.rejectedPackets
            value.discardedAdmittedPackets += new.discardedAdmittedPackets - old.discardedAdmittedPackets
            value.highWaterBytes = max(value.highWaterBytes, new.highWaterBytes)
            value.highWaterPackets = max(value.highWaterPackets, new.highWaterPackets)
        }
    }
    var snapshot: QualificationReport.Transport { totals.withLock { $0 } }
}
