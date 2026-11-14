import AVFoundation
import HaishinKit
import Observation
import UIKit

nonisolated enum SessionInterruption: CaseIterable {
    case background, camera, audio, captureFailure, encoderFailure, criticalHeat, audioUnavailable
    var message: String {
        switch self {
        case .background: "The app left the foreground."
        case .camera: "Camera capture was interrupted."
        case .audio: "Audio capture was interrupted."
        case .captureFailure: "Camera capture failed."
        case .encoderFailure: "Media encoding failed."
        case .criticalHeat: "The device is too hot."
        case .audioUnavailable: "The microphone input is unavailable."
        }
    }
}

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
    private(set) var mixer = MediaMixer(captureSessionMode: .single)
    private(set) var preview = MTHKView(frame: .zero)

    let renderer: WebOverlayRenderer
    private(set) var profile: SessionProfile
    var broadcastConfigurationLocked = false {
        didSet { if broadcastConfigurationLocked { clearPreviewIntent() } }
    }
    var canSelectProfile: Bool { !broadcastConfigurationLocked && phase == .idle && !busy && !stopRequested }
    private let authorizeCapture: @MainActor () async -> Bool
    private let interfaceOrientation: @MainActor () -> UIInterfaceOrientation
    private var previewOrientation: UIInterfaceOrientation = .unknown
    private(set) var previewOrientationSettling = false
    var previewNeedsLandscape: Bool { phase == .preview && !previewOrientation.isLandscape }
    var canConfirmLandscapeStart: Bool {
        #if DEBUG
        if interfaceFixtureMode { return true }
        #endif
        return interfaceOrientation().isLandscape
    }
    private let persistProfile: @MainActor (SessionProfile) -> Void
    private(set) var microphoneMuted = false
    private(set) var microphoneLevel = 0.0
    private(set) var audioRoute = "Microphone not active"
    private(set) var cameraZoom = CameraZoom()
    var canAdjustMedia: Bool { !busy && !stopRequested && (phase == .preview || phase == .recording) }
    private let microphoneMeter = MicrophoneMeter()
    private var routeTask: Task<Void, Never>?

    private(set) var savedSamples: [ExperimentSample] = []
    private(set) var recordingsMessage = ""
    private(set) var urlMessage = ""
    private(set) var overlayURL = ""
    private let saveOverlayURL: @MainActor (String) throws -> Void
    private var overlayForeground = false
    var canEditOverlayURL: Bool { !broadcastConfigurationLocked && !busy && !stopRequested && (phase == .idle || phase == .preview) }
    private var qualificationTask: Task<Void, Never>?
    private let qualificationCheckpoint = QualificationCheckpoint()
    private var qualificationReport: QualificationReport?
    private var qualificationStart: ContinuousClock.Instant?
    private var qualificationTransport = QualificationTransportCounter()
    var qualificationWarning = ""
    private var recorder: LocalRecorder?
    private let fileFinalization = RecordingFinalization()
    var protectedRecordingID: UUID? { recordingID ?? fileFinalization.recordingID }
    private var sharedEncoder: SharedMediaEncoder?
    private var mediaDestinations: SharedMediaDestinations?
    private var publisher: RTMPSPublisher?
    private var publisherErrorTask: Task<Void, Never>?
    private var encoderErrorTask: Task<Void, Never>?
    private var uploadAffinity = RTMPSUploadAffinity()
    private var pendingWriterFailure = false
    private var pendingUploadCleanup = false
    private var uploadStopGeneration: UInt64 = 0
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
    var onInterruption: (@MainActor (SessionInterruption) -> Void)?
    private var interruptionReported = false
    private var captureForeground = true
    private var previewRequested = false
    private var previewResumePending = false
    private var previewResumeScheduled = false
    private var captureGeneration: UInt64 = 0
    private var previewFrameReadiness = PreviewFrameReadiness()
    #if DEBUG
    private var previewStartFixture: (@MainActor () async throws -> Void)?
    private var previewCloseFixture: (@MainActor () async -> Void)?
    private var previewReadyFixture: (@MainActor () -> Bool)?
    private var previewFrameTimeout: Duration = .seconds(5)
    #endif
    var backupWarning: String { recordingFailed ? "Backup failed. Saved footage is retained as incomplete; healthy upload continues independently." : "" }
    private var previousIdleTimerDisabled: Bool?
    private var interruptedUploadClosing: Task<Void, Never>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var canSelectLens: Bool { !broadcastConfigurationLocked && !busy && !stopRequested && (phase == .idle || phase == .preview) }
    var canRecord: Bool {
        #if DEBUG
        if interfaceFixtureName == "writer-pending" { return false }
        #endif
        #if DEBUG
        let landscape = interfaceFixtureMode || previewOrientation.isLandscape
        #else
        let landscape = previewOrientation.isLandscape
        #endif
        return phase == .preview && landscape && !previewOrientationSettling && !busy && !stopRequested &&
            recoveringSampleID == nil && fileFinalization.recordingID == nil
    }
    var canDeleteSamples: Bool { !busy && recoveringSampleID == nil && fileFinalization.recordingID == nil && (phase == .idle || phase == .preview) }
    var recordingID: UUID? { recorder == nil ? nil : sample?.id }
    var recordingMetrics: LocalRecorder.Metrics? { recorder?.metrics }
    var isRecording: Bool {
        #if DEBUG
        if interfaceFixtureMode { return phase == .recording && !recordingFailed }
        #endif
        return phase == .recording && recorder != nil && !recordingFailed
    }

    /// AVAssetWriter.startWriting/startSession must have accepted actual media;
    /// record() returning by itself is not the backup-admission signal.
    var hasStartedWriting: Bool { isRecording && recorder?.hasStarted == true }
    var broadcastCaptureReady: Bool {
        #if DEBUG
        if interfaceFixtureMode { return phase == .preview || phase == .recording }
        #endif
        return (phase == .preview || phase == .recording) && !busy && !stopRequested &&
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized &&
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    var broadcastPipelineRunning: Bool { sharedEncoder != nil && !stopRequested }
    var broadcastOverlayReady: Bool {
        #if DEBUG
        if interfaceFixtureMode { return !["overlay-unavailable", "active-overlay-unavailable"].contains(interfaceFixtureName) }
        #endif
        return overlayURL.isEmpty || (renderer.healthy && renderer.image != nil)
    }

    var capturePermissionDenied: Bool {
        #if DEBUG
        if interfaceFixtureName == "permission-denied" { return true }
        #endif
        return [.denied, .restricted].contains(AVCaptureDevice.authorizationStatus(for: .video)) ||
        [.denied, .restricted].contains(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    var canPrepareNextSession: Bool {
        !busy && !stopRequested && !hasUpload && fileFinalization.recordingID == nil &&
        (phase == .idle || phase == .preview)
    }

    /// Reset only the settled workspace. Archive originals/sidecars are retained.
    @discardableResult func prepareNextSession() -> Bool {
        guard canPrepareNextSession else { return false }
        sample = nil
        sampleURL = nil
        recordingFailed = false
        failure = false
        interrupted = false
        startedAt = nil
        uploadState = .idle
        uploadMessage = "Upload not started"
        message = phase == .preview ? "Check the picture and sound before starting the next session." :
            "Check camera and sound to prepare the next session."
        return true
    }

    var localSavingStatus: String {
        if fileFinalization.recordingID != nil || phase == .stopping { return "Finalizing · keep the app open" }
        if recordingFailed { return "Failed · incomplete footage retained" }
        if isRecording { return "Recording" }
        if phase == .starting { return "Starting" }
        if let sample, sample.status == .completed { return "Saved" }
        if let sample, sample.status != .pending { return "Incomplete · inspect in Recordings" }
        return "Not started"
    }

    init(readOverlayURL: @MainActor () throws -> String = OverlayURLStore.read,
         saveOverlayURL: @escaping @MainActor (String) throws -> Void = OverlayURLStore.save,
         profile: SessionProfile = .fullHD,
         persistProfile: @escaping @MainActor (SessionProfile) -> Void = {
             UserDefaults.standard.set($0.rawValue, forKey: SessionProfile.preferenceKey)
         },
         interfaceOrientation: @escaping @MainActor () -> UIInterfaceOrientation = { .landscapeRight },
         authorizeCapture: @escaping @MainActor () async -> Bool = {
             guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
             return await AVCaptureDevice.requestAccess(for: .audio)
         }) {
        self.profile = profile
        self.persistProfile = persistProfile
        self.authorizeCapture = authorizeCapture
        self.interfaceOrientation = interfaceOrientation
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

    private let recordingRecovery = RecordingRecovery()
    private var recordingReviewTask: Task<Void, Never>?
    private(set) var recoveringSampleID: UUID?

    func refreshSamples(clearFeedback: Bool = true) {
        recordingReviewTask?.cancel()
        do {
            savedSamples = try ExperimentSample.loadAll(activeID: protectedRecordingID)
            if clearFeedback { recordingsMessage = "" }
        }
        catch { recordingsMessage = "Saved recordings could not be listed. Files are retained."; return }
        guard recoveringSampleID == nil else { return }
        let candidates = savedSamples.filter {
            $0.id != protectedRecordingID && ($0.review == nil || $0.status != .completed)
        }
        recordingReviewTask = Task { [weak self] in
            guard let self, let directory = try? ExperimentSample.directory() else { return }
            for var sample in candidates {
                guard !Task.isCancelled else { return }
                let url = directory.appendingPathComponent(sample.fileName)
                if !FileManager.default.fileExists(atPath: url.path) { sample.review = .missing }
                else {
                    do {
                        let result = try await recordingRecovery.inspect(url)
                        sample.duration = result.duration
                        sample.review = .readable
                        sample.byteCount = sample.fileSize(in: directory)
                    } catch {
                        guard !Task.isCancelled else { return }
                        sample.review = .unreadable
                    }
                }
                guard !Task.isCancelled, sample.id != protectedRecordingID,
                      let index = savedSamples.firstIndex(where: { $0.id == sample.id }) else { continue }
                do { try sample.save(in: directory); savedSamples[index] = sample }
                catch { recordingsMessage = "Recording review could not be saved. Originals are retained." }
            }
        }
    }

    func recoverSample(_ selected: ExperimentSample) async {
        guard canDeleteSamples, recoveringSampleID == nil,
              var sample = savedSamples.first(where: { $0.id == selected.id }), (sample.status != .completed || sample.review != .readable) else { return }
        recordingReviewTask?.cancel()
        recoveringSampleID = sample.id
        defer { recoveringSampleID = nil; refreshSamples(clearFeedback: false) }
        do {
            let directory = try ExperimentSample.directory()
            var attempt = ExperimentSample.Recovery()
            sample.recoveries = (sample.recoveries ?? []) + [attempt]
            // Persist the attempt before native export; relaunch labels pending attempts failed.
            try sample.save(in: directory)
            savedSamples[savedSamples.firstIndex(where: { $0.id == sample.id })!] = sample
            do {
                let result = try await recordingRecovery.recover(original: directory.appendingPathComponent(sample.fileName),
                    destination: directory.appendingPathComponent(sample.recoveryFileName(attempt)))
                attempt.status = .recovered
                attempt.duration = result.duration
                recordingsMessage = "Recovered copy saved. It may omit the unfinished fragment; inspect playback. Original retained."
            } catch {
                attempt.status = .failed
                recordingsMessage = "Recovery could not finish. Original and any partial recovered copy are retained."
            }
            if let index = sample.recoveries?.firstIndex(where: { $0.id == attempt.id }) {
                sample.recoveries?[index] = attempt
            }
            try sample.save(in: directory)
        } catch { recordingsMessage = "Recovery status could not be saved. All existing files are retained for review." }
    }

    func deleteRecovery(_ recovery: ExperimentSample.Recovery, from selected: ExperimentSample) {
        guard canDeleteSamples, let sample = savedSamples.first(where: { $0.id == selected.id }) else { return }
        do {
            let directory = try ExperimentSample.directory()
            _ = try sample.deletingRecovery(recovery, in: directory)
            recordingsMessage = "Selected recovery copy deleted. Original recording is retained."
        } catch { recordingsMessage = "Could not delete the recovery copy or save its status. Remaining files are retained; retry is available." }
        refreshSamples(clearFeedback: false)
    }

    func deleteSample(_ sample: ExperimentSample) {
        guard canDeleteSamples, recoveringSampleID == nil else { return }
        do {
            let directory = try ExperimentSample.directory()
            try sample.delete(in: directory)
            if sampleURL?.lastPathComponent == sample.fileName { sampleURL = nil }
            refreshSamples()
            recordingsMessage = "Recording deleted from this iPhone. Exported copies are unchanged."
        } catch {
            if let sampleURL, !FileManager.default.fileExists(atPath: sampleURL.path) { self.sampleURL = nil }
            refreshSamples()
            recordingsMessage = "Could not delete all recording files. Remaining files are kept; you can retry."
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
        guard phase == .idle, !busy, captureForeground else { return }
        #if DEBUG
        if interfaceFixtureMode {
            phase = .preview; message = "Fixture camera ready; no capture is running."
            availableLenses = [.wide]
            return
        }
        #endif
        previewRequested = true
        previewResumePending = false
        captureGeneration &+= 1
        let generation = captureGeneration
        previewFrameReadiness = PreviewFrameReadiness()
        busy = true
        phase = .preparing
        stopRequested = false
        failure = false
        interrupted = false
        interruptionReported = false
        defer { finishOperation() }
        do {
            guard await authorizeCapture() else {
                throw ExperimentError.permissions
            }
            guard !stopRequested else { phase = .idle; return }
            try await startPreviewCapture(generation: generation)
            try await waitForPreviewFrames(generation: generation)
            // Native startup is not cancellation-aware. A background/Close request
            // received during it must never publish a usable preview or recorder.
            guard !stopRequested, captureForeground, captureGeneration == generation else { return }
            phase = .preview
            message = "Preview ready · landscape \(profile.rawValue). Check the picture and overlay before recording."
        } catch {
            clearPreviewIntent()
            failure = true
            message = error is RearCameraLens.ConfigurationError ?
                "The selected lens is unavailable for \(profile.rawValue). Open the camera again to retry with an available lens." :
                ((error as? ExperimentError)?.description ?? "Camera/audio setup failed. Open the camera again to retry.")
            stopRequested = true
        }
    }

    /// A fresh native setup follows completed teardown, never startRunning on
    /// the interrupted session while its previous stop is still suspended.
    private func startPreviewCapture(generation: UInt64) async throws {
        await applyPreviewOrientation(interfaceOrientation())
        #if DEBUG
        if let previewStartFixture { try await previewStartFixture(); return }
        #endif
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
        await mixer.addOutput(PreviewFrameObserver(readiness: previewFrameReadiness, camera: true))
        await mixer.addOutput(PreviewFrameObserver(readiness: previewFrameReadiness, camera: false))
        updateAudioRoute()
        routeTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVAudioSession.routeChangeNotification) {
                guard !Task.isCancelled else { return }
                guard let self, self.captureGeneration == generation else { return }
                self.updateAudioRoute()
                if AVAudioSession.sharedInstance().currentRoute.inputs.isEmpty { self.interrupt(.audioUnavailable) }
            }
        }
        // Register interruption streams before capture begins.
        let interruptions = await mixer.isInterputted
        interruptionTask = Task { [weak self] in
            for await value in interruptions {
                guard !Task.isCancelled else { return }
                guard let self, self.captureGeneration == generation else { return }
                if value { self.interrupt(.camera) }
            }
        }
        audioInterruptionTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVAudioSession.didBecomeInactiveNotification) {
                guard !Task.isCancelled else { return }
                guard let self, self.captureGeneration == generation else { return }
                self.interrupt(.audio)
            }
        }
        runtimeErrorTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVCaptureSession.runtimeErrorNotification) {
                guard !Task.isCancelled else { return }
                guard let self, self.captureGeneration == generation else { return }
                self.failure = true
                self.message = "Camera capture failed. The recording is retained; reopen the camera to retry."
                self.interrupt(.captureFailure)
            }
        }
        updateThermalState()
        thermalTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: ProcessInfo.thermalStateDidChangeNotification) {
                guard !Task.isCancelled else { return }
                guard let self, self.captureGeneration == generation else { return }
                self.updateThermalState()
            }
        }
        guard !stopRequested else { return }
        await mixer.startRunning()
        overlayTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.captureGeneration == generation else { return }
                await self.refreshPreviewOrientation()
                guard !Task.isCancelled, self.captureGeneration == generation else { return }
                self.microphoneLevel = self.microphoneMuted ? 0 : self.microphoneMeter.level
                await overlay.update(image: self.renderer.image, visible: self.renderer.visible)
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
        }
    }

    func refreshPreviewOrientation() async {
        guard phase == .preview, captureForeground, !busy, !stopRequested else { return }
        let orientation = interfaceOrientation()
        guard orientation != .unknown, orientation != previewOrientation else {
            if previewOrientationSettling && previewHasFreshFrames { previewOrientationSettling = false }
            return
        }

        // Shares the operation guard with lens changes, shutdown and writer
        // startup. Recording and upload therefore never see a rotation change.
        busy = true
        previewOrientationSettling = true
        await applyPreviewOrientation(orientation)
        previewFrameReadiness.waitForRotation(portrait: orientation.isPortrait)
        if previewHasFreshFrames { previewOrientationSettling = false }
        finishOperation()
    }

    private func applyPreviewOrientation(_ orientation: UIInterfaceOrientation) async {
        await mixer.setVideoOrientation(DeviceUtil.videoOrientation(by: orientation) ?? .landscapeRight)
        previewOrientation = orientation
    }

    private var previewHasFreshFrames: Bool {
        #if DEBUG
        if let previewReadyFixture { return previewReadyFixture() }
        #endif
        return previewFrameReadiness.isReady
    }

    private func waitForPreviewFrames(generation: UInt64) async throws {
        let clock = ContinuousClock()
        #if DEBUG
        let timeout = previewFrameTimeout
        #else
        let timeout: Duration = .seconds(5)
        #endif
        let deadline = clock.now.advanced(by: timeout)
        while !stopRequested, captureForeground, captureGeneration == generation {
            if previewHasFreshFrames { return }
            guard clock.now < deadline else { throw ExperimentError.previewFrames }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Scene availability, independent of overlay health and YouTube reconciliation.
    func setCaptureForeground(_ foreground: Bool) {
        captureForeground = foreground
        if foreground {
            schedulePreviewResume()
        } else {
            previewResumePending = previewRequested && !broadcastConfigurationLocked &&
                recorder == nil && sharedEncoder == nil && publisher == nil && !failure
            interrupt(.background)
        }
    }

    private func clearPreviewIntent() {
        previewRequested = false
        previewResumePending = false
    }

    private func schedulePreviewResume() {
        guard captureForeground, previewRequested, previewResumePending,
              !previewResumeScheduled, !busy, phase == .idle, !stopRequested,
              !failure, !broadcastConfigurationLocked else { return }
        previewResumeScheduled = true
        Task { [weak self] in
            guard let self else { return }
            self.previewResumeScheduled = false
            guard self.captureForeground, self.previewRequested, self.previewResumePending,
                  !self.busy, self.phase == .idle, !self.stopRequested,
                  !self.failure, !self.broadcastConfigurationLocked else { return }
            self.previewResumePending = false
            await self.openPreview()
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

    private func updateThermalState() { applyThermalState(ProcessInfo.processInfo.thermalState) }

    func applyThermalState(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .serious:
            thermalWarning = "Device is hot. Overlay captures are reduced to protect camera recording."
            renderer.captureInterval = 3
        case .critical:
            thermalWarning = "Device is too hot. Recording is stopping; let it cool before restarting."
            interrupt(.criticalHeat)
        default:
            thermalWarning = ""
            renderer.captureInterval = 1
        }
    }

    func record(injection: LocalRecorder.Injection = .none) async {
        #if DEBUG
        if interfaceFixtureMode {
            guard canRecord else { return }
            phase = .recording; recordingFailed = false
            message = "Fixture local recording; no file or capture is opened."
            return
        }
        #endif
        guard canRecord else { return }
        // The device may have turned between the preview loop and the tap.
        guard interfaceOrientation() == previewOrientation else {
            message = "Check the picture in landscape before starting again."
            return
        }
        clearPreviewIntent()
        busy = true
        phase = .starting
        failure = false
        recordingFailed = false
        pendingWriterFailure = false
        uploadAffinity.beginRecordingSession(keepingTransportEpoch: publisher != nil || sharedEncoder != nil)
        uploadState = .idle
        uploadMessage = "Upload not started"
        sampleURL = nil
        defer { finishOperation() }
        do {
            let directory = try ExperimentSample.directory()
            self.directory = directory
            var sample = ExperimentSample()
            sample.profile = profile.rawValue
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
                    self?.interrupt(.encoderFailure)
                }
            }
            startQualification()
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

    func interrupt(_ reason: SessionInterruption) {
        // Native camera/audio notifications can precede the scene background
        // notification. Retain only preview intent until that scene cycle arrives.
        if ![SessionInterruption.background, .camera, .audio, .audioUnavailable].contains(reason) ||
            recorder != nil || sharedEncoder != nil || publisher != nil || broadcastConfigurationLocked {
            clearPreviewIntent()
        }
        if !interruptionReported {
            interruptionReported = true
            onInterruption?(reason)
        }
        requestStop(interruption: true)
    }

    /// Expiry is not writer success. Persist the conservative status immediately
    /// because iOS may suspend us before an awaited finish callback returns.
    func backgroundTimeExpired() {
        failure = true
        recordingFailed = recorder != nil || recordingFailed
        interrupted = true
        message = "Background time expired. Saved footage remains incomplete; YouTube end is unconfirmed."
        sample?.status = .failed
        if let sample, let directory { try? sample.save(in: directory) }
        restoreIdleTimer()
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    /// Background/interruption wins over in-flight setup/start without racing writer state.
    func requestStop(interruption: Bool = false) {
        if !interruption { clearPreviewIntent() }
        if interruption {
            renderer.stop()
            if !interruptionReported {
                interruptionReported = true
                onInterruption?(.camera)
            }
        }
        guard phase != .idle || busy else { return }
        interrupted = interrupted || interruption
        if UIApplication.shared.applicationState == .background && backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finish local sample") { [weak self] in
                self?.backgroundTimeExpired()
            }
        }
        stopRequested = true
        uploadStopGeneration &+= 1
        mediaDestinations?.detachPublisher()
        if let publisher = self.publisher {
            self.publisher = nil
            publisherErrorTask?.cancel(); publisherErrorTask = nil
            uploadState = .idle
            uploadMessage = "Upload stopped after session interruption; YouTube end is unconfirmed"
            interruptedUploadClosing = Task { await publisher.stop() }
        }
        if !busy { Task { await close() } }
    }

    func stopRecording() async {
        #if DEBUG
        if interfaceFixtureMode {
            guard isRecording else { return }
            phase = .preview; sample = ExperimentSample(status: .completed)
            message = "Fixture saved result; no file was created."
            return
        }
        #endif
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
            // A normal foreground Stop returns to an explicitly requested preview.
            // An interruption arriving during finish must not gain this intent.
            if captureForeground && !stopRequested && !interrupted && !failure && !broadcastConfigurationLocked {
                previewRequested = true
            }
        }
        finishOperation()
    }

    private func handleRecorderFailure() async {
        guard recorder != nil else { return }
        failure = true
        recordingFailed = true
        message = "Recording failed. The file is retained as incomplete."
        if publisher != nil || uploadAffinity.hasAdmittedTransport {
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
        guard phase == .recording, !busy, !stopRequested, !pendingUploadCleanup, publisher == nil,
              prepared.profile == profile, let sharedEncoder, let mediaDestinations else {
            throw RTMPSPublisher.StartupFailure.recordingNotReady
        }
        let recorder = self.recorder
        guard uploadAffinity.permits(prepared) else { throw RTMPSPublisher.StartupFailure.contextChanged }
        let retry = uploadAffinity.hasAdmittedTransport
        guard retry || recorder?.hasStarted == true else { throw RTMPSPublisher.StartupFailure.recordingNotReady }
        busy = true
        uploadState = .connecting
        uploadMessage = "Connecting upload"
        defer {
            if publisher == nil, uploadState == .connecting { uploadState = Task.isCancelled ? .idle : .failed }
            finishOperation()
        }
        let stopGeneration = uploadStopGeneration
        let recordingID = sample?.id
        let (failures, continuation) = AsyncStream<RTMPSPublisher.Failure>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let publisher = try await RTMPSPublisher.connected(to: prepared,
            canPublish: { retry || recorder?.hasStarted == true },
            diagnostics: qualificationTransport,
            failed: { failure in continuation.yield(failure); continuation.finish() })
        guard !Task.isCancelled, !stopRequested, stopGeneration == uploadStopGeneration, phase == .recording, sample?.id == recordingID else {
            await publisher.stop()
            throw RTMPSPublisher.StartupFailure.cancelled
        }
        self.publisher = publisher
        mediaDestinations.attachPublisher(publisher)
        await sharedEncoder.requestKeyframe()
        guard !Task.isCancelled, !stopRequested, stopGeneration == uploadStopGeneration else {
            mediaDestinations.detachPublisher()
            self.publisher = nil
            await publisher.stop()
            uploadState = .idle
            throw RTMPSPublisher.StartupFailure.cancelled
        }
        guard uploadAffinity.admit(prepared) else {
            mediaDestinations.detachPublisher()
            self.publisher = nil
            await publisher.stop()
            throw RTMPSPublisher.StartupFailure.contextChanged
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
        // Admission/detachment never waits behind a writer or camera-control
        // await. A stopped remote event must not keep receiving media while busy.
        uploadStopGeneration &+= 1
        let publisher = self.publisher
        self.publisher = nil
        mediaDestinations?.detachPublisher()
        publisherErrorTask?.cancel(); publisherErrorTask = nil
        uploadState = .idle
        uploadMessage = "Upload stopped"
        if busy {
            pendingUploadCleanup = true
            await publisher?.stop()
            return
        }
        busy = true
        pendingUploadCleanup = false
        defer { finishOperation() }
        await publisher?.stop()
        if recorder == nil, sharedEncoder != nil {
            await finishRecording()
            phase = .preview
        }
    }

#if DEBUG
    /// Deterministic no-capture fixture for busy-control/finalization races. The
    /// supplied encoder has no media input and the publisher uses fixture I/O.
    func installBroadcastFixture(encoder: SharedMediaEncoder, publisher: RTMPSPublisher) {
        precondition(sharedEncoder == nil && self.publisher == nil && !busy)
        sharedEncoder = encoder
        self.publisher = publisher
        phase = .recording
        uploadState = .connected
    }
    func installWriterFixture(_ recorder: LocalRecorder, sample: ExperimentSample, directory: URL) {
        precondition(self.recorder == nil && !busy && fileFinalization.recordingID == nil)
        self.recorder = recorder
        self.sample = sample
        self.directory = directory
        mediaDestinations = SharedMediaDestinations(recorder: recorder)
        if let publisher { mediaDestinations?.attachPublisher(publisher) }
        previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
    }
    func failWriterFixture() async { await handleRecorderFailure() }
    /// Synthetic camera/audio input uses the same shared encoder admission as capture.
    func offerRecordingInputFixture(_ sample: CMSampleBuffer) -> Bool { sharedEncoder?.offer(sample) ?? false }
    /// Exercise the production deadline/ownership boundary without native IO.
    func holdNativeFinalizationFixture(id: UUID, deadline: Double = 0,
        operation: @escaping @MainActor @Sendable () async throws -> LocalRecorder.Metrics) async throws {
        _ = try await fileFinalization.finish(id: id, deadline: deadline, operation: operation,
            released: { [weak self] in self?.refreshSamples(clearFeedback: false) })
    }
    func holdFileFinalizationFixture(_ hold: @MainActor () async -> Void) async {
        precondition(!busy)
        busy = true
        phase = .stopping
        await hold()
        phase = .recording
        finishOperation()
    }
#endif

    private func finishOperation() {
        busy = false
        if stopRequested { Task { await close() } }
        else if pendingUploadCleanup {
            Task { await stopUpload() }
        }
        else if pendingWriterFailure {
            pendingWriterFailure = false
            Task { await handleRecorderFailure() }
        } else { schedulePreviewResume() }
    }

    private func finishRecording(keepEncoding: Bool = false, closingSession: Bool = false) async {
        await checkpointQualification()
        if !keepEncoding, let sharedEncoder {
            await mixer.removeOutput(sharedEncoder)
            do { try await sharedEncoder.finish() }
            catch { failure = true }
            await checkpointQualification()
            self.sharedEncoder = nil
            encoderErrorTask?.cancel(); encoderErrorTask = nil
        }
        guard let recorder else {
            if !keepEncoding {
                if !closingSession { await finishQualification() }
                restoreIdleTimer()
            }
            return
        }
        mediaDestinations?.detachRecorder()
        do {
            guard let id = sample?.id else { throw ExperimentError.emptySample }
            let metrics = try await fileFinalization.finish(id: id,
                operation: { try await recorder.finish() },
                released: { [weak self] in self?.refreshSamples(clearFeedback: false) })
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
            self.sample?.recordStructuralValidation(duration: duration.seconds,
                                                    byteCount: sample.fileSize(in: directory))
            sampleURL = url
            if !failure {
                message = interrupted ? "Interrupted recording finalized. Inspect playback before using it." :
                    "Recording saved. Play or export the original file."
            }
        } catch {
            failure = true
            recordingFailed = true
            message = fileFinalization.recordingID == nil
                ? "Sample did not finish or has missing audio/video. Partial files are retained."
                : "Finalization exceeded the wait limit. Original is retained and protected while native writing continues."
        }
        sample?.metrics = recorder.metrics
        sample?.status = failure ? .failed : (interrupted ? .interrupted : .completed)
        if let sample, let directory {
            do { try sample.save(in: directory) } catch {
                failure = true
                recordingFailed = true
                message = "Could not save sample status. Files remain pending and are retained."
            }
        }
        errorTask?.cancel()
        errorTask = nil
        await checkpointQualification()
        self.recorder = nil
        if !keepEncoding && !closingSession { await finishQualification() }
        refreshSamples()
        startedAt = nil
        if !keepEncoding { restoreIdleTimer() }
    }

    private func finishQualification() async {
        qualificationTask?.cancel(); qualificationTask = nil
        await checkpointQualification(stopped: true)
        qualificationReport = nil
        qualificationStart = nil
    }

    #if DEBUG
    func beginQualificationFixture(transport: QualificationTransportCounter) {
        startQualification()
        qualificationTransport = transport
    }
    func checkpointQualificationFixture() async { await checkpointQualification() }
    #endif

    private func startQualification() {
        qualificationTask?.cancel()
        qualificationReport = QualificationReport(profile: profile)
        qualificationStart = ContinuousClock.now
        qualificationTransport = QualificationTransportCounter()
        qualificationWarning = ""
        qualificationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }
                await self?.checkpointQualification()
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
            }
        }
    }

    private func checkpointQualification(stopped: Bool = false) async {
        guard var report = qualificationReport, let start = qualificationStart,
              let id = sample?.id, let directory else { return }
        let duration = start.duration(to: .now).components
        report.observe(QualificationReport.memory(elapsed: Double(duration.seconds) + Double(duration.attoseconds) / 1e18))
        if let metrics = sharedEncoder?.metrics {
            report.encoder = .init(admittedVideo: metrics.admittedVideoFrames,
                admittedPCMFrames: metrics.admittedAudioFrames, rejectedVideo: metrics.rejectedVideoFrames,
                rejectedPCMFrames: metrics.rejectedAudioFrames, highWaterBytes: metrics.highWaterBytes,
                highWaterVideo: metrics.highWaterVideoFrames, highWaterPCMFrames: metrics.highWaterAudioFrames)
        }
        if let metrics = recorder?.metrics {
            report.file = .init(offeredVideo: metrics.offeredVideo ?? 0,
                offeredAudioPackets: metrics.offeredAudio ?? 0, writtenVideo: metrics.videoWritten,
                writtenAudioPackets: metrics.audioWritten ?? 0, rejectedVideo: metrics.videoDropped,
                rejectedAudioPackets: metrics.audioDropped,
                estimatedMissing30HzIntervals: metrics.missingOutputFrames ?? 0,
                videoGapsAtLeast500ms: metrics.videoStalls, largestVideoGapSeconds: metrics.largestVideoGap,
                startupHighWaterBytes: metrics.startupHighWaterBytes ?? 0,
                startupHighWaterPackets: metrics.startupHighWaterPackets ?? 0)
        }
        report.nativeFinalizationOutstanding = fileFinalization.recordingID == id
        report.recording = switch sample?.status {
        case .completed: .completed
        case .interrupted: .interrupted
        case .failed: .failed
        default: .pending
        }
        report.transport = qualificationTransport.snapshot
        report.end = stopped ? .stopped : .checkpoint
        qualificationReport = report
        do { try await qualificationCheckpoint.save(report, id: id, directory: directory) }
        catch { qualificationWarning = "Qualification summary could not be saved. Recording is unaffected." }
    }

    private func restoreIdleTimer() {
        if let previousIdleTimerDisabled { UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled }
        previousIdleTimerDisabled = nil
    }

    private func close() async {
        guard !busy, phase != .idle || stopRequested || backgroundTask != .invalid else { return }
        busy = true
        stopRequested = false
        phase = .stopping
        captureGeneration &+= 1
        #if DEBUG
        if let previewCloseFixture { await previewCloseFixture() }
        #endif
        let publisher = self.publisher
        self.publisher = nil
        mediaDestinations?.detachPublisher()
        publisherErrorTask?.cancel(); publisherErrorTask = nil
        // Socket shutdown never delays file finalization. This is one control
        // task per stop operation, not a retained task per media callback.
        let uploadClosing = interruptedUploadClosing ?? publisher.map { publisher in Task { await publisher.stop() } }
        await finishRecording(closingSession: true)
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
        // SDK Screen.reset() retains its timing/latency and the view retains its
        // last CIImage. A fully closed capture must not reuse either on return.
        // Old capture has stopped and detached before the new single owner exists.
        mixer = MediaMixer(captureSessionMode: .single)
        preview = MTHKView(frame: .zero)
        previewOrientation = .unknown
        previewOrientationSettling = false
        overlay = nil
        _ = try? await AVAudioSession.sharedInstance().deactivate(options: [.notifyOthersOnDeactivation])
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        if let uploadClosing {
            _ = try? await withBroadcastDeadline(seconds: 3) { await uploadClosing.value }
        }
        interruptedUploadClosing = nil
        await finishQualification()
        uploadAffinity.endCaptureSession()
        uploadState = .idle
        phase = .idle
        if interrupted && !failure { message = "Capture stopped after an interruption. Open the camera explicitly to resume." }
        finishOperation()
    }

    #if DEBUG
    private var interfaceFixtureMode = false
    private var interfaceFixtureName = ""

    /// Replaces only native camera acquisition for deterministic lifecycle tests.
    /// Production phases, permission/stop checks and teardown ownership still run.
    func installPreviewLifecycleFixture(start: @escaping @MainActor () async throws -> Void,
                                        close: (@MainActor () async -> Void)? = nil,
                                        ready: @escaping @MainActor () -> Bool = { true },
                                        frameTimeout: Duration = .seconds(5)) {
        previewStartFixture = start
        previewCloseFixture = close
        previewReadyFixture = ready
        previewFrameTimeout = frameTimeout
    }

    /// Bounded UI-regression input; never opens media or changes output ownership.
    func updateMenuInterfaceFixture(_ tick: Int) {
        guard interfaceFixtureMode, interfaceFixtureName == "menu-updates" else { return }
        microphoneLevel = Double(tick % 10) / 10
        message = "Fixture status update \(tick)"
    }

    /// Presentation-only fixture: no capture, encoder, writer or network is opened.
    func installInterfaceFixture(_ state: String) {
        interfaceFixtureMode = true
        interfaceFixtureName = state
        guard state != "idle" && state != "permission-denied" else { return }
        phase = .preview
        message = "Fixture camera ready; no capture is running."
        audioRoute = "Fixture microphone"
        cameraZoom = CameraZoom(value: 1, minimum: 1, maximum: 3)
        availableLenses = [.wide]
        if ["reconnecting", "upload-recovered", "active-overlay-unavailable"].contains(state) { phase = .recording }
        if state == "ended" { sample = ExperimentSample(status: .completed) }
        if state == "finalizing" { phase = .stopping }
        if state == "upload-recovered" { uploadMessage = "Connected to the same event" }
        if ["reconnecting", "backup-failed", "unknown-end", "ended"].contains(state) {
            broadcastConfigurationLocked = state != "ended"
            uploadMessage = state == "reconnecting" ? "Reconnecting. Local recording continues while healthy." : "Upload stopped"
        }
        if state == "backup-failed" {
            recordingFailed = true
            uploadMessage = "Upload connected; YouTube confirmed live"
        }
    }
    #endif

    private enum ExperimentError: Error {
        case permissions, devices, emptySample, previewFrames
        var description: String {
            switch self {
            case .permissions: "Camera and microphone permission are required. Enable them in Settings to retry."
            case .devices: "The rear camera or microphone is unavailable. Try again on the testing iPhone."
            case .emptySample: "The sample has no usable audio/video."
            case .previewFrames: "Camera preview did not receive fresh frames. Close and reopen the camera to retry."
            }
        }
    }
}
