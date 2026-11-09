#!/usr/bin/env python3
"""Compile the actual Release report/checkpoint model on macOS without capture.
The small stubs are numeric boundary types only; no model code is duplicated.
Prints only fixed status, never payloads or errors. Output must be a new directory.
"""
from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=False)
(out / 'Boundary.swift').write_text('''import Foundation
nonisolated enum SessionProfile { case fullHD, hd }
nonisolated enum RTMPSPublisher {
    struct Metrics: Sendable {
        var acceptedPackets = 0
        var acknowledgedPackets = 0
        var skippedBeforeOrigin = 0
        var rejectedPackets = 0
        var discardedAdmittedPackets = 0
        var highWaterBytes = 0
        var highWaterPackets = 0
    }
}
''')
(out / 'Probe.swift').write_text('''import Foundation
@main struct Probe {
    static func main() async {
        do {
            let directory = URL(fileURLWithPath: CommandLine.arguments[1])
            let id = UUID()
            var report = QualificationReport(profile: .fullHD)
            for i in 0...1080 {
                report.observe(.init(elapsedSeconds: Double(i * 10), chargedFootprintBytes: UInt64(1000 + i * 20),
                    residentMappingBytes: nil, thermal: .nominal))
            }
            guard report.observations.count == 120, report.observationCount == 1081,
                  report.firstObservation?.elapsedSeconds == 0,
                  abs((report.chargedSlopeBytesPerSecond ?? 0) - 2) < 0.00001 else { fatalError("boundedModelFailed") }
            let checkpoint = QualificationCheckpoint()
            try await checkpoint.save(report, id: id, directory: directory)
            let loaded = try await checkpoint.load(id: id, directory: directory)
            guard loaded.observationCount == 1081 else { fatalError("checkpointFailed") }
            try loaded.sanitizedData().write(to: directory.appendingPathComponent("exported-summary.json"))
            print("boundedModelCheckpointExportPassed")
        } catch { fatalError("modelProbeUnavailable") }
    }
}
''')
subprocess.run(['xcrun', 'swiftc', '-O', '-swift-version', '6', '-module-cache-path', str(out / 'cache'),
    '-parse-as-library', str(root / 'Stream14/Media/QualificationDiagnostics.swift'),
    str(out / 'Boundary.swift'), str(out / 'Probe.swift'), '-o', str(out / 'probe')], check=True)
subprocess.run([str(out / 'probe'), str(out)], check=True)
