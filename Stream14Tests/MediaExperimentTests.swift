import CoreGraphics
import Foundation
import HaishinKit
import Testing
@testable import Stream14

struct MediaExperimentTests {
    @Test @MainActor func pendingAndFailedSamplesSurviveReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var sample = ExperimentSample()
        let movie = directory.appendingPathComponent(sample.fileName)
        let footage = Data("partial footage fixture".utf8)
        try footage.write(to: movie)
        try sample.save(in: directory)
        let sidecar = directory.appendingPathComponent(sample.id.uuidString + ".json")
        let pending = try JSONDecoder().decode(ExperimentSample.self, from: Data(contentsOf: sidecar))
        #expect(pending.status == .pending)
        sample.status = .failed
        try sample.save(in: directory)
        let failed = try JSONDecoder().decode(ExperimentSample.self, from: Data(contentsOf: sidecar))
        #expect(failed.status == .failed)
        #expect(failed.id == pending.id)
        #expect(try Data(contentsOf: movie) == footage)
    }

    @Test @MainActor func launchDoesNotCaptureOrRecord() {
        let experiment = MediaSession()
        // Macro failure diagnostics must not reflect the URL-bearing session.
        let initiallyIdle = experiment.phase == .idle
        let initiallyCannotRecord = !experiment.canRecord
        let initiallyHasNoSample = experiment.sampleURL == nil
        #expect(initiallyIdle)
        #expect(initiallyCannotRecord)
        #expect(initiallyHasNoSample)
        experiment.requestStop(interruption: true)
        let remainsIdle = experiment.phase == .idle
        #expect(remainsIdle)
    }

    @Test @ScreenActor func repeatedOverlayInstallDoesNotAccumulateLayers() async throws {
        let mixer = MediaMixer(captureSessionMode: .manual)
        let overlay = SyntheticOverlay()
        try overlay.install(on: mixer)
        #expect(mixer.screen.childCounts == 2)
        try overlay.install(on: mixer)
        #expect(mixer.screen.childCounts == 2)
    }

    @Test @ScreenActor func syntheticLayerHasFullCanvasAlphaAndChanges() throws {
        let first = SyntheticOverlay.makeImage(counter: 0)
        let second = SyntheticOverlay.makeImage(counter: 1)
        #expect(first.width == 1920)
        #expect(first.height == 1080)
        func pixels(_ image: CGImage) throws -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 1920 * 1080 * 4)
            try bytes.withUnsafeMutableBytes { data in
                let context = try #require(CGContext(data: data.baseAddress, width: 1920, height: 1080,
                    bitsPerComponent: 8, bytesPerRow: 1920 * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: 1920, height: 1080))
            }
            return bytes
        }
        let a = try pixels(first)
        let b = try pixels(second)
        #expect(a[3] == 0)
        let alphas = stride(from: 3, to: a.count, by: 4).map { a[$0] }
        #expect(alphas.contains(128))
        #expect(alphas.contains(255))
        #expect(a != b)
    }
}
