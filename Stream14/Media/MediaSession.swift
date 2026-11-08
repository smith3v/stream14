import AVFoundation
import HaishinKit
import Observation
import UIKit

@MainActor
@Observable
final class MediaSession {
    enum Phase { case idle, preparing, preview, starting, recording, stopping }
    private(set) var phase: Phase = .idle
    private(set) var message = "Open the camera to prepare a local recording."
    private(set) var sampleURL: URL?
    private(set) var startedAt: Date?
    private(set) var availableLenses: [RearCameraLens] = []
    private(set) var selectedLens: RearCameraLens = .wide
    let mixer = MediaMixer(captureSessionMode: .single)
    let preview = MTHKView(frame: .zero)

    let renderer: WebOverlayRenderer
    private(set) var profile: SessionProfile
    var canSelectProfile: Bool { phase == .idle && !busy && !stopRequested }
    private let authorizeCapture: @MainActor () async -> Bool
    private let persistProfile: @MainActor (SessionProfile) -> Void
    private(set) var microphoneMuted = false
    private(set) var microphoneLevel = 0.0
    private(set) var audioRoute = "Microphone not active"
    private(set) var cameraZoom = CameraZoom()
    var canAdjustMedia: Bool { !busy && !stopRequested && (phase == .preview || phase == .recording) }
    private let microphoneMeter = MicrophoneMeter()
    private var routeTask: Task<Void, Never>?

    private(set) var savedSamples: [ExperimentSample] = []
    private(set) var urlMessage = ""
    private(set) var overlayURL = ""
    private let saveOverlayURL: @MainActor (String) throws -> Void
    private var overlayForeground = false
    var canEditOverlayURL: Bool { !busy && !stopRequested && (phase == .idle || phase == .preview) }
    private var recorder: LocalRecorder?
    private var sharedEncoder: SharedMediaEncoder?
    private var mediaDestinations: SharedMediaDestinations?
    private var publisher: RTMPSPublisher?
    private var publisherErrorTask: Task<Void, Never>?
    private var encoderErrorTask: Task<Void, Never>?
    private var transportWasStarted = false
    private var pendingWriterFailure = false
    private(set) var recordingFailed = false
    enum UploadState { case idle, connecting, connected, failed }
    private(set) var uploadState: UploadState = .idle
    private(set) var uploadMessage = "Upload not started"
    var hasUpload: Bool { publisher != nil }
    private var overlay: WebOverlayLayer?
    private var overlayTask: Task<Void, Never>?
    private var errorTask: Task<Void, Never>?
    private var interruptionTask: Task<Void, Never>?
    private(set) var thermalWarning = ""
    private var thermalTask: Task<Void, Never>?
    private var runtimeErrorTask: Task<Void, Never>?
    private var audioInterruptionTask: Task<Void, Never>?
    private var sample: ExperimentSample?
    private var directory: URL?
    private var busy = false
    private var stopRequested = false
    private var failure = false
    private var interrupted = false
    private var previousIdleTimerDisabled: Bool?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var canSelectLens: Bool { !busy && !stopRequested && (phase == .idle || phase == .preview) }
    var canRecord: Bool { phase == .preview && !busy && !stopRequested }
    var canDeleteSamples: Bool { !busy && (phase == .idle || phase == .preview) }
    var recordingID: UUID? { recorder == nil ? nil : sample?.id }
    var recordingMetrics: LocalRecorder.Metrics? { recorder?.metrics }
    var isRecording: Bool { phase == .recording && recorder != nil && !recordingFailed }

    init(readOverlayURL: @MainActor () throws -> String = OverlayURLStore.read,
         saveOverlayURL: @escaping @MainActor (String) throws -> Void = OverlayURLStore.save,
         profile: SessionProfile = .fullHD,
         persistProfile: @escaping @MainActor (SessionProfile) -> Void = {
             UserDefaults.standard.set($0.rawValue, forKey: SessionProfile.preferenceKey)
         },
         authorizeCapture: @escaping @MainActor () async -> Bool = {
             guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
             return await AVCaptureDevice.requestAccess(for: .audio)
         }) {
        self.profile = profile
        self.persistProfile = persistProfile
        self.authorizeCapture = authorizeCapture
        renderer = WebOverlayRenderer(profile: profile)
        self.saveOverlayURL = saveOverlayURL
        do { overlayURL = try readOverlayURL() }
        catch { urlMessage = "Could not read the saved URL. Enter it again while the device is unlocked." }
        refreshSamples()
    }

    func selectProfile(_ profile: SessionProfile) {
        guard canSelectProfile, profile != self.profile else { return }
        self.profile = profile
        persistProfile(profile)
        availableLenses = []
        renderer.setProfile(profile)
        reconcileOverlay()
    }

    func setMicrophoneMuted(_ muted: Bool) async {
        guard canAdjustMedia else { return }
        busy = true
        defer { finishOperation() }
        await mixer.setAudioMixerSettings(profile.audioSettings(muted: muted))
        microphoneMuted = muted
        if muted { microphoneLevel = 0 }
    }

    func setCameraZoom(_ value: Double) async {
        guard canAdjustMedia else { return }
        busy = true
        defer { finishOperation() }
        do { cameraZoom = try await mixer.configureZoom(value) }
        catch { message = "Camera zoom could not change. Capture continues with the current zoom." }
    }

    private func updateAudioRoute() {
        let inputs = AVAudioSession.sharedInstance().currentRoute.inputs
        audioRoute = inputs.isEmpty ? "Microphone unavailable" : inputs.map(\.portName).joined(separator: ", ")
    }

    func refreshSamples() {
        do { savedSamples = try ExperimentSample.loadAll() }
        catch { message = "Saved recordings could not be listed. Files are retained." }
    }

    func deleteSample(_ sample: ExperimentSample) {
        guard canDeleteSamples else { return }
        do {
            let directory = try ExperimentSample.directory()
            try sample.delete(in: directory)
            if sampleURL?.lastPathComponent == sample.fileName { sampleURL = nil }
            refreshSamples()
            message = "Recording deleted from this iPhone. Exported copies are unchanged."
        } catch {
            if let sampleURL, !FileManager.default.fileExists(atPath: sampleURL.path) { self.sampleURL = nil }
            refreshSamples()
            message = "Could not delete all recording files. Remaining files are kept; you can retry."
        }
    }

    /// The settings sheet owns its draft. Commit only after validation and persistence.
    @discardableResult
    func applyOverlayURL(_ draft: String) -> Bool {
        guard canEditOverlayURL else {
            urlMessage = "URL changes are unavailable while recording or changing capture state."
            return false
        }
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty || WebOverlayRenderer.validatedURL(value) != nil else {
            urlMessage = "Enter an HTTPS URL without username or password."
            return false
        }
        do {
            try saveOverlayURL(value)
            overlayURL = value
            urlMessage = value.isEmpty ? "Overlay disabled" : "URL saved securely on this device"
            if value.isEmpty { renderer.disable() }
            else if overlayForeground { renderer.load(value) }
            return true
        } catch {
            urlMessage = "Could not save the overlay URL. Try again while the device is unlocked."
            return false
        }
    }

    func setOverlayForeground(_ foreground: Bool) {
        overlayForeground = foreground
        if foreground { reconcileOverlay() }
        else { renderer.stop() }
    }

    /// Invoked independently of renderer completion by the foreground view task.
    func reconcileOverlay() {
        guard overlayForeground else { return }
        if overlayURL.isEmpty { renderer.disable() }
        else if WebOverlayRenderer.validatedURL(overlayURL) != nil {
            renderer.ensureRunning(overlayURL)
        } else {
            renderer.disable()
            urlMessage = "The saved overlay URL is invalid. Enter an HTTPS URL."
        }
    }

    func openPreview() async {
        guard phase == .idle, !busy else { return }
        busy = true
        phase = .preparing
        stopRequested = false
        failure = false
        interrupted = false
        defer { finishOperation() }
        do {
            guard await authorizeCapture() else {
                throw ExperimentError.permissions
            }
            guard !stopRequested else { phase = .idle; return }
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker])
            guard try await audioSession.activate(options: []) else { throw ExperimentError.devices }
            let profile = self.profile
            availableLenses = await Task.detached { RearCameraLens.available(profile: profile) }.value
            guard availableLenses.contains(selectedLens) else {
                selectedLens = availableLenses.contains(.wide) ? .wide : (availableLenses.first ?? .wide)
                throw RearCameraLens.ConfigurationError.unavailable
            }
            await mixer.setSessionPreset(.inputPriority)
            await mixer.setVideoOrientation(.landscapeRight)
            await mixer.setVideoMixerSettings(VideoMixerSettings(mode: .offscreen))
            try await mixer.setDynamicRangeMode(.sdr)
            await mixer.setAudioMixerSettings(profile.audioSettings(muted: microphoneMuted))
            guard let microphone = AVCaptureDevice.default(for: .audio) else { throw ExperimentError.devices }
            try await attachLens(selectedLens)
            try await mixer.attachAudio(microphone)
            try await mixer.setFrameRate(profile.frameRate)
            let overlay: WebOverlayLayer
            if let existing = self.overlay { overlay = existing }
            else { overlay = await WebOverlayLayer(); self.overlay = overlay }
            try await overlay.install(on: mixer, profile: profile)
            preview.videoGravity = .resizeAspect
            await mixer.addOutput(preview)
            await mixer.addOutput(microphoneMeter)
            updateAudioRoute()
            routeTask = Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: AVAudioSession.routeChangeNotification) {
                    guard !Task.isCancelled else { return }
                    self?.updateAudioRoute()
                }
            }
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
            runtimeErrorTask = Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: AVCaptureSession.runtimeErrorNotification) {
                    guard !Task.isCancelled else { return }
                    self?.failure = true
                    self?.message = "Camera capture failed. The recording is retained; reopen the camera to retry."
                    self?.requestStop()
                }
            }
            updateThermalState()
            thermalTask = Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: ProcessInfo.thermalStateDidChangeNotification) {
                    guard !Task.isCancelled else { return }
                    self?.updateThermalState()
                }
            }
            await mixer.startRunning()
            overlayTask = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { return }
                    self.microphoneLevel = self.microphoneMuted ? 0 : self.microphoneMeter.level
                    await overlay.update(image: self.renderer.image, visible: self.renderer.visible)
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                }
            }
            phase = .preview
            message = "Preview ready · landscape \(profile.rawValue). Check the picture and overlay before recording."
        } catch {
            failure = true
            message = error is RearCameraLens.ConfigurationError ?
                "The selected lens is unavailable for \(profile.rawValue). Open the camera again to retry with an available lens." :
                ((error as? ExperimentError)?.description ?? "Camera/audio setup failed. Open the camera again to retry.")
            stopRequested = true
        }
    }

    private func attachLens(_ lens: RearCameraLens) async throws {
        try await mixer.attachRearCamera(lens, profile: profile)
        cameraZoom = try await mixer.configureZoom(1)
    }

    enum LensChangeInjection { case none, configuration, restoration, interruption }

    func selectLens(_ lens: RearCameraLens, injection: LensChangeInjection = .none) async {
        guard canSelectLens, availableLenses.contains(lens), lens != selectedLens else { return }
        guard phase == .preview else { selectedLens = lens; return }
        busy = true
        phase = .preparing
        let previous = selectedLens
        defer { finishOperation() }
        await mixer.stopRunning()
        do {
            try await attachLens(lens)
            if injection == .configuration || injection == .restoration {
                throw RearCameraLens.ConfigurationError.unavailable
            }
            if injection == .interruption { requestStop(interruption: true) }
            selectedLens = lens
            message = "Preview ready · \(lens.label) · landscape \(profile.rawValue)."
        } catch {
            do {
                if injection == .restoration { throw RearCameraLens.ConfigurationError.unavailable }
                try await attachLens(previous)
                message = "Could not use that lens. The previous camera has been restored."
            } catch {
                failure = true
                message = "Camera change failed. Capture stopped; reopen the camera to retry."
                stopRequested = true
            }
        }
        if !stopRequested { await mixer.startRunning() }
        phase = .preview
    }

    private func updateThermalState() {
        switch ProcessInfo.processInfo.thermalState {
        case .serious:
            thermalWarning = "Device is hot. Overlay captures are reduced to protect camera recording."
            renderer.captureInterval = 3
        case .critical:
            thermalWarning = "Device is too hot. Recording is stopping; let it cool before restarting."
            requestStop(interruption: true)
        default:
            thermalWarning = ""
            renderer.captureInterval = 1
        }
    }

    func record(injection: LocalRecorder.Injection = .none) async {
        guard canRecord else { return }
        busy = true
        phase = .starting
        failure = false
        recordingFailed = false
        pendingWriterFailure = false
        transportWasStarted = false
        uploadState = .idle
        uploadMessage = "Upload not started"
        sampleURL = nil
        defer { finishOperation() }
        do {
            let directory = try ExperimentSample.directory()
            self.directory = directory
            let sample = ExperimentSample()
            self.sample = sample
            try sample.save(in: directory)
            let recorder = LocalRecorder()
            self.recorder = recorder
            errorTask = Task { [weak self] in
                for await _ in recorder.failures {
                    guard !Task.isCancelled else { return }
                    await self?.handleRecorderFailure()
                }
            }
            try recorder.start(directory.appendingPathComponent(sample.fileName), injection: injection, profile: profile)
            let destinations = SharedMediaDestinations(recorder: recorder)
            mediaDestinations = destinations
            let encoder = try SharedMediaEncoder(profile: profile, output: { sample in
                destinations.append(sample)
            }, failed: { _ in destinations.encoderFailed() })
            sharedEncoder = encoder
            encoderErrorTask = Task { [weak self] in
                for await _ in destinations.encoderFailures {
                    guard !Task.isCancelled else { return }
                    self?.failure = true
                    self?.message = "Media encoding failed. Saved footage is retained as incomplete."
                    self?.requestStop()
                }
            }
            await encoder.start()
            await mixer.addOutput(encoder)
            previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
            startedAt = Date()
            phase = .recording
            message = "Recording locally · camera, microphone and composed overlay."
        } catch {
            failure = true
            message = "Recording could not start. Any partial sample is retained."
            stopRequested = true
        }
    }

    /// Background/interruption wins over in-flight setup/start without racing writer state.
    func requestStop(interruption: Bool = false) {
        if interruption { renderer.stop() }
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
        guard phase == .recording, !busy, recorder != nil else { return }
        busy = true
        phase = .stopping
        if publisher != nil {
            await finishRecording(keepEncoding: true)
            phase = .recording
            message = "Local recording stopped. Upload continues."
        } else {
            await finishRecording()
            phase = .preview
        }
        finishOperation()
    }

    private func handleRecorderFailure() async {
        guard recorder != nil else { return }
        failure = true
        recordingFailed = true
        message = "Recording failed. The file is retained as incomplete."
        if publisher != nil || transportWasStarted {
            guard !busy else { pendingWriterFailure = true; return }
            busy = true
            // A failed file consumer never gains ownership of a healthy upload.
            await finishRecording(keepEncoding: true)
            message = publisher != nil ? "Backup failed. Upload continues; saved footage is retained." :
                "Backup failed; upload unavailable. Saved footage is retained. Retry the same event or end."
            finishOperation()
        } else { requestStop() }
    }

    /// Explicit F7 integration entry point; no setup/preview action invokes it.
    func startUpload(_ prepared: PreparedYouTubeIngestion) async throws {
        guard phase == .recording, !busy, !stopRequested, publisher == nil,
              prepared.profile == profile, let sharedEncoder, let mediaDestinations else {
            throw RTMPSPublisher.StartupFailure.recordingNotReady
        }
        let recorder = self.recorder
        let retry = transportWasStarted
        guard retry || recorder?.hasStarted == true else { throw RTMPSPublisher.StartupFailure.recordingNotReady }
        busy = true
        uploadState = .connecting
        uploadMessage = "Connecting upload"
        defer {
            if publisher == nil, uploadState == .connecting { uploadState = Task.isCancelled ? .idle : .failed }
            finishOperation()
        }
        let recordingID = sample?.id
        let (failures, continuation) = AsyncStream<RTMPSPublisher.Failure>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let publisher = try await RTMPSPublisher.connected(to: prepared,
            canPublish: { retry || recorder?.hasStarted == true },
            failed: { failure in continuation.yield(failure); continuation.finish() })
        guard !Task.isCancelled, !stopRequested, phase == .recording, sample?.id == recordingID else {
            await publisher.stop()
            throw RTMPSPublisher.StartupFailure.cancelled
        }
        self.publisher = publisher
        transportWasStarted = true
        mediaDestinations.attachPublisher(publisher)
        await sharedEncoder.requestKeyframe()
        guard !Task.isCancelled, !stopRequested else {
            mediaDestinations.detachPublisher()
            self.publisher = nil
            await publisher.stop()
            uploadState = .idle
            throw RTMPSPublisher.StartupFailure.cancelled
        }
        uploadState = .connected
        uploadMessage = "Upload connected; waiting for YouTube confirmation"
        publisherErrorTask = Task { [weak self, weak publisher] in
            for await _ in failures {
                guard !Task.isCancelled, let self, let publisher, self.publisher === publisher else { return }
                self.mediaDestinations?.detachPublisher()
                self.publisher = nil
                self.uploadState = .failed
                self.uploadMessage = "Upload failed. Local recording continues while healthy."
                await publisher.stop()
                if self.recorder == nil {
                    self.uploadMessage = "Upload failed; backup unavailable. Retry the same event or end."
                }
            }
        }
    }

    func stopUpload() async {
        guard !busy else { return }
        busy = true
        defer { finishOperation() }
        let publisher = self.publisher
        self.publisher = nil
        mediaDestinations?.detachPublisher()
        publisherErrorTask?.cancel(); publisherErrorTask = nil
        await publisher?.stop()
        uploadState = .idle
        uploadMessage = "Upload stopped"
        if recorder == nil, sharedEncoder != nil {
            await finishRecording()
            phase = .preview
        }
    }

    private func finishOperation() {
        busy = false
        if stopRequested { Task { await close() } }
        else if pendingWriterFailure {
            pendingWriterFailure = false
            Task { await handleRecorderFailure() }
        }
    }

    private func finishRecording(keepEncoding: Bool = false) async {
        if !keepEncoding, let sharedEncoder {
            await mixer.removeOutput(sharedEncoder)
            do { try await sharedEncoder.finish() }
            catch { failure = true }
            self.sharedEncoder = nil
            encoderErrorTask?.cancel(); encoderErrorTask = nil
        }
        guard let recorder else {
            if !keepEncoding { restoreIdleTimer() }
            return
        }
        mediaDestinations?.detachRecorder()
        do {
            let metrics = try await recorder.finish()
            sample?.metrics = metrics
            guard let sample, let directory else { throw ExperimentError.emptySample }
            let url = directory.appendingPathComponent(sample.fileName)
            // Final writer success plus structural validation is required for completion.
            let asset = AVURLAsset(url: url)
            let videos = try await asset.loadTracks(withMediaType: .video)
            let audios = try await asset.loadTracks(withMediaType: .audio)
            let duration = try await asset.load(.duration)
            guard !videos.isEmpty, !audios.isEmpty, duration.seconds > 0 else {
                throw ExperimentError.emptySample
            }
            sampleURL = url
            if !failure {
                message = interrupted ? "Interrupted recording finalized. Inspect playback before using it." :
                    "Recording saved. Play or export the original file."
            }
        } catch {
            failure = true
            message = "Sample did not finish or has missing audio/video. Partial files are retained."
        }
        sample?.metrics = recorder.metrics
        sample?.status = failure ? .failed : (interrupted ? .interrupted : .completed)
        if let sample, let directory {
            do { try sample.save(in: directory) } catch {
                failure = true
                message = "Could not save sample status. Files remain pending and are retained."
            }
        }
        errorTask?.cancel()
        errorTask = nil
        self.recorder = nil
        refreshSamples()
        startedAt = nil
        if !keepEncoding { restoreIdleTimer() }
    }

    private func restoreIdleTimer() {
        if let previousIdleTimerDisabled { UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled }
        previousIdleTimerDisabled = nil
    }

    private func close() async {
        guard !busy else { return }
        busy = true
        stopRequested = false
        phase = .stopping
        let publisher = self.publisher
        self.publisher = nil
        mediaDestinations?.detachPublisher()
        publisherErrorTask?.cancel(); publisherErrorTask = nil
        // Socket shutdown never delays file finalization. This is one control
        // task per stop operation, not a retained task per media callback.
        let uploadClosing = publisher.map { publisher in Task { await publisher.stop() } }
        await finishRecording()
        mediaDestinations = nil
        overlayTask?.cancel()
        overlayTask = nil
        interruptionTask?.cancel()
        interruptionTask = nil
        thermalTask?.cancel()
        thermalTask = nil
        runtimeErrorTask?.cancel()
        runtimeErrorTask = nil
        audioInterruptionTask?.cancel()
        audioInterruptionTask = nil
        await mixer.stopRunning()
        await mixer.removeOutput(preview)
        await mixer.removeOutput(microphoneMeter)
        routeTask?.cancel()
        routeTask = nil
        microphoneLevel = 0
        audioRoute = "Microphone not active"
        try? await mixer.attachVideo(nil)
        try? await mixer.attachAudio(nil)
        _ = try? await AVAudioSession.sharedInstance().deactivate(options: [.notifyOthersOnDeactivation])
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        await uploadClosing?.value
        uploadState = .idle
        phase = .idle
        if interrupted && !failure { message = "Capture stopped after an interruption. Open the camera explicitly to resume." }
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
