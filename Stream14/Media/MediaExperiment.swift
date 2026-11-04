import AVFoundation
import HaishinKit
import Observation
import UIKit

@MainActor
@Observable
final class MediaExperiment {
    enum Phase { case idle, preparing, preview, starting, recording, stopping }
    private(set) var phase: Phase = .idle
    private(set) var message = "Camera and microphone start only when you open the experiment."
    private(set) var sampleURL: URL?
    private(set) var layerCounter = 0
    private(set) var startedAt: Date?
    let mixer = MediaMixer(captureSessionMode: .single)
    let preview = MTHKView(frame: .zero)

    private var recorder: StreamRecorder?
    private var overlay: SyntheticOverlay?
    private var overlayTask: Task<Void, Never>?
    private var errorTask: Task<Void, Never>?
    private var interruptionTask: Task<Void, Never>?
    private var audioInterruptionTask: Task<Void, Never>?
    private var sample: ExperimentSample?
    private var directory: URL?
    private var busy = false
    private var stopRequested = false
    private var failure = false
    private var interrupted = false
    private var previousIdleTimerDisabled = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var canRecord: Bool { phase == .preview && !busy }
    var isRecording: Bool { phase == .recording }

    func openPreview() async {
        guard phase == .idle, !busy else { return }
        busy = true
        phase = .preparing
        stopRequested = false
        failure = false
        interrupted = false
        defer { finishOperation() }
        do {
            guard await AVCaptureDevice.requestAccess(for: .video),
                  await AVCaptureDevice.requestAccess(for: .audio) else {
                throw ExperimentError.permissions
            }
            guard !stopRequested else { phase = .idle; return }
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            await mixer.setSessionPreset(.hd1920x1080)
            await mixer.setVideoOrientation(.landscapeRight)
            await mixer.setVideoMixerSettings(VideoMixerSettings(mode: .offscreen))
            await mixer.setAudioMixerSettings(AudioMixerSettings(sampleRate: 44_100, channels: 2))
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let microphone = AVCaptureDevice.default(for: .audio) else { throw ExperimentError.devices }
            try await mixer.attachVideo(camera) { unit in try unit.setFrameRate(30) }
            try await mixer.attachAudio(microphone)
            try await mixer.setFrameRate(30)
            let overlay: SyntheticOverlay
            if let existing = self.overlay { overlay = existing }
            else { overlay = await SyntheticOverlay(); self.overlay = overlay }
            try await overlay.install(on: mixer)
            layerCounter = 0
            preview.videoGravity = .resizeAspect
            await mixer.addOutput(preview)
            // Register interruption streams before capture begins.
            let interruptions = await mixer.isInterputted
            interruptionTask = Task { [weak self] in
                for await value in interruptions {
                    guard !Task.isCancelled else { return }
                    if value { self?.requestStop(interruption: true) }
                }
            }
            audioInterruptionTask = Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: AVAudioSession.didBecomeInactiveNotification) {
                    guard !Task.isCancelled else { return }
                    self?.requestStop(interruption: true)
                }
            }
            await mixer.startRunning()
            overlayTask = Task { [weak self] in
                var counter = 0
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    guard !Task.isCancelled else { return }
                    counter += 1
                    await overlay.update(counter: counter)
                    self?.layerCounter = counter
                }
            }
            phase = .preview
            message = "Preview ready · fixed landscape canvas. Record a clap and watch the alpha counter change."
        } catch {
            failure = true
            message = (error as? ExperimentError)?.description ?? "Camera/audio setup failed. Close and reopen the experiment to retry."
            stopRequested = true
        }
    }

    func record() async {
        guard canRecord else { return }
        busy = true
        phase = .starting
        failure = false
        sampleURL = nil
        defer { finishOperation() }
        do {
            let directory = try ExperimentSample.directory()
            self.directory = directory
            let sample = ExperimentSample()
            self.sample = sample
            try sample.save(in: directory)
            let recorder = StreamRecorder()
            self.recorder = recorder
            let errors = await recorder.error
            errorTask = Task { [weak self] in
                for await _ in errors {
                    guard !Task.isCancelled else { return }
                    self?.failure = true
                    self?.message = "Recording failed. The sample is retained as incomplete."
                    self?.requestStop()
                }
            }
            try await recorder.startRecording(directory.appendingPathComponent(sample.fileName), settings: [
                .video: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1920,
                    AVVideoHeightKey: 1080, AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 14_000_000,
                        AVVideoMaxKeyFrameIntervalDurationKey: 2,
                        AVVideoExpectedSourceFrameRateKey: 30
                    ]],
                .audio: [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 128_000]
            ])
            await mixer.addOutput(recorder)
            previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
            startedAt = Date()
            phase = .recording
            message = "Recording locally · synthetic alpha layer only."
        } catch {
            failure = true
            message = "Recording could not start. Any partial sample is retained."
            stopRequested = true
        }
    }

    /// Background/interruption wins over in-flight setup/start without racing writer state.
    func requestStop(interruption: Bool = false) {
        guard phase != .idle || busy else { return }
        interrupted = interrupted || interruption
        if UIApplication.shared.applicationState == .background && backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finish local sample") { [weak self] in
                guard let self else { return }
                self.failure = true
                self.message = "Background time expired. Sample remains incomplete."
                if self.backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(self.backgroundTask)
                    self.backgroundTask = .invalid
                }
            }
        }
        stopRequested = true
        if !busy { Task { await close() } }
    }

    func stopRecording() async {
        guard phase == .recording, !busy else { return }
        busy = true
        phase = .stopping
        await finishRecording()
        phase = .preview
        finishOperation()
    }

    private func finishOperation() {
        busy = false
        if stopRequested { Task { await close() } }
    }

    private func finishRecording() async {
        guard let recorder else { return }
        await mixer.removeOutput(recorder)
        do {
            let url = try await recorder.stopRecording()
            // Structural validation is useful evidence, not proof of successful writer completion.
            let asset = AVURLAsset(url: url)
            let videos = try await asset.loadTracks(withMediaType: .video)
            let audios = try await asset.loadTracks(withMediaType: .audio)
            let duration = try await asset.load(.duration)
            guard !videos.isEmpty, !audios.isEmpty, duration.seconds > 0 else {
                throw ExperimentError.emptySample
            }
            sampleURL = url
            if !failure {
                message = interrupted ? "Interrupted sample retained. Inspect playback before using it." :
                    "Sample retained for inspection. Check camera, audio, alpha and counter updates."
            }
        } catch {
            failure = true
            message = "Sample did not finish or has missing audio/video. Partial files are retained."
        }
        sample?.status = failure ? .failed : (interrupted ? .interrupted : .needsInspection)
        if let sample, let directory {
            do { try sample.save(in: directory) } catch {
                failure = true
                message = "Could not save sample status. Files remain pending and are retained."
            }
        }
        errorTask?.cancel()
        errorTask = nil
        self.recorder = nil
        startedAt = nil
        UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
    }

    private func close() async {
        guard !busy else { return }
        busy = true
        stopRequested = false
        phase = .stopping
        await finishRecording()
        overlayTask?.cancel()
        overlayTask = nil
        interruptionTask?.cancel()
        interruptionTask = nil
        audioInterruptionTask?.cancel()
        audioInterruptionTask = nil
        await mixer.stopRunning()
        await mixer.removeOutput(preview)
        try? await mixer.attachVideo(nil)
        try? await mixer.attachAudio(nil)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        phase = .idle
        if interrupted && !failure { message = "Capture stopped after an interruption. Open the experiment explicitly to resume." }
        finishOperation()
    }

    private enum ExperimentError: Error {
        case permissions, devices, emptySample
        var description: String {
            switch self {
            case .permissions: "Camera and microphone permission are required. Enable them in Settings to retry."
            case .devices: "The rear camera or microphone is unavailable. Try again on the testing iPhone."
            case .emptySample: "The sample has no usable audio/video."
            }
        }
    }
}
