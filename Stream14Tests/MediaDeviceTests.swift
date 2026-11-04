import AVFoundation
import Darwin
import Foundation
import Testing
import UIKit
import WebKit
@testable import Stream14

/// Explicit opt-in: captures private camera/microphone media on the connected phone.
@Suite(.serialized)
struct MediaDeviceTests {
    struct Observation: Codable {
        let elapsed: Int
        let residentBytes: UInt64
        let physicalFootprintBytes: UInt64
        let thermal: Int
        let metrics: LocalRecorder.Metrics?
        let overlayVisible: Bool
        let overlayCaptureMilliseconds: Double
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["STREAM14_DEVICE_FAILURES"] == "1"))
    @MainActor func deviceWriterFailuresAndInterruption() async throws {
        let session = MediaSession()
        let previousIdle = UIApplication.shared.isIdleTimerDisabled
        defer { session.requestStop() }
        for injection in [LocalRecorder.Injection.initialization, .append, .finalization] {
            await session.openPreview()
            try #require(session.canRecord)
            await session.record(injection: injection)
            if injection == .finalization {
                try await Task.sleep(for: .seconds(2))
                await session.stopRecording()
                session.requestStop()
            }
            for _ in 0..<150 {
                if session.phase == .idle { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            #expect(session.phase == .idle)
            #expect(session.savedSamples.first?.status == .failed)
            #expect(UIApplication.shared.isIdleTimerDisabled == previousIdle)
            #expect(!session.canRecord)
        }
        // Interrupt an established new recording; do not infer ordering from Task.yield.
        let previousIDs = Set(session.savedSamples.map(\.id))
        await session.openPreview()
        try #require(session.canRecord)
        await session.record()
        try #require(session.isRecording)
        try await Task.sleep(for: .seconds(2))
        session.requestStop(interruption: true)
        for _ in 0..<150 {
            if session.phase == .idle { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(session.phase == .idle)
        #expect(!session.isRecording)
        let interrupted = try #require(session.savedSamples.first)
        #expect(!previousIDs.contains(interrupted.id))
        #expect(interrupted.status == .interrupted)
        #expect(UIApplication.shared.isIdleTimerDisabled == previousIdle)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["STREAM14_DEVICE_RECORDING"] == "1"))
    @MainActor func combinedDeviceRecording() async throws {
        let session = MediaSession()
        let previousIdle = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = previousIdle }
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        controller.view.backgroundColor = .black
        let host = OverlayViewport(webView: session.renderer.webView)
        host.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        controller.view.addSubview(host)
        session.preview.frame = CGRect(x: 0, y: 180, width: 320, height: 180)
        controller.view.addSubview(session.preview)
        window.makeKeyAndVisible()
        host.layoutIfNeeded()
        defer { session.requestStop(); window.isHidden = true }
        session.renderer.load("https://heren14-overlay.smith3v.com/overlay.html")
        for _ in 0..<150 {
            if session.renderer.visible { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        print("Device browser viewport: \(String(describing: try? await session.renderer.webView.evaluateJavaScript("({w:innerWidth,h:innerHeight,ready:document.readyState,children:document.body?.children.length,resources:[...document.images].every(i=>i.complete),fonts:document.fonts.status})")))")
        print("Device overlay readiness: \(session.renderer.status); \(session.renderer.viewport)")
        try #require(session.renderer.visible)
        await session.openPreview()
        #expect(session.canRecord)
        await session.record()
        #expect(session.isRecording)
        let seconds = Int(ProcessInfo.processInfo.environment["STREAM14_RECORDING_SECONDS"] ?? "30") ?? 30
        let outageRules = try await WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "stream14-device-outage", encodedContentRuleList:
                #"[{"trigger":{"url-filter":".*","resource-type":["document"]},"action":{"type":"block"}}]"#)
        var observations: [Observation] = []
        for second in 1...max(seconds, 1) {
            try await Task.sleep(for: .seconds(1))
            try #require(session.isRecording)
            // Reject actual WebKit document requests for two minutes, without
            // changing phone radios, certificates or the renderer's last image.
            if seconds >= 180, second == 30, let outageRules {
                session.renderer.webView.configuration.userContentController.add(outageRules)
                session.renderer.reload()
                print("Injected WebKit request outage started")
            }
            if seconds >= 180, second == 150 {
                session.renderer.webView.configuration.userContentController.removeAllContentRuleLists()
                session.renderer.reload()
                print("Injected WebKit request outage ended")
            }
            if seconds >= 180, second == 145 { #expect(!session.renderer.visible) }
            if seconds >= 180, second == 175 { #expect(session.renderer.visible) }
            if second.isMultiple(of: 10) || second == seconds {
                var info = mach_task_basic_info()
                var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
                let result = withUnsafeMutablePointer(to: &info) { pointer in
                    pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                    }
                }
                var vm = task_vm_info_data_t()
                var vmCount = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
                let vmResult = withUnsafeMutablePointer(to: &vm) { pointer in
                    pointer.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &vmCount)
                    }
                }
                observations.append(Observation(elapsed: second, residentBytes: result == KERN_SUCCESS ? info.resident_size : 0,
                    physicalFootprintBytes: vmResult == KERN_SUCCESS ? vm.phys_footprint : 0,
                    thermal: ProcessInfo.processInfo.thermalState.rawValue, metrics: session.recordingMetrics,
                    overlayVisible: session.renderer.visible,
                    overlayCaptureMilliseconds: session.renderer.captureMilliseconds))
                print("Device recording elapsed \(second)s, frames \(session.recordingMetrics?.videoWritten ?? 0), overlay \(session.renderer.visible)")
            }
        }
        await session.stopRecording()
        let url = try #require(session.sampleURL)
        let sample = try #require(session.savedSamples.first { $0.fileName == url.lastPathComponent })
        #expect(sample.status == .completed)
        let directory = try ExperimentSample.directory()
        try JSONEncoder().encode(observations).write(to: directory.appendingPathComponent(sample.id.uuidString + ".observations.json"))
        print("Device sample ID: \(sample.id); metrics: \(String(describing: sample.metrics))")
        // A changing HTML fixture proves live raster replacement in the saved file.
        let fixtureURL = try #require(Bundle(for: DeviceFixtureBundle.self).url(forResource: "overlay", withExtension: "html", subdirectory: "Fixtures")
            ?? Bundle(for: DeviceFixtureBundle.self).url(forResource: "overlay", withExtension: "html"))
        session.renderer.loadFixture(try String(contentsOf: fixtureURL, encoding: .utf8))
        for _ in 0..<100 {
            if session.renderer.visible { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        try #require(session.renderer.visible)
        // Repeat start/stop on the same camera session.
        await session.record()
        try await Task.sleep(for: .seconds(6))
        await session.stopRecording()
        #expect(session.savedSamples.first?.status == .completed)
        // Inject a real capture notification through the app's observer.
        await session.record()
        try await Task.sleep(for: .seconds(2))
        NotificationCenter.default.post(name: AVCaptureSession.runtimeErrorNotification, object: nil)
        for _ in 0..<100 {
            if session.phase == .idle { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(session.phase == .idle)
        #expect(session.savedSamples.first?.status == .failed)
    }
}

private final class DeviceFixtureBundle: NSObject {}
