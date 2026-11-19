import AVKit
import HaishinKit
import Observation
import Synchronization
import UIKit

@MainActor
@Observable
final class CameraPictureInPicture: NSObject, AVPictureInPictureControllerDelegate {
    enum PresentationEnd {
        case closing, failedToStart
    }

    static var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }

    private(set) var isPrepared = false
    private(set) var isActive = false
    var canContinueInBackground: Bool {
        isActive && controller.isPictureInPictureActive && !controller.isPictureInPictureSuspended
    }
    func hasFreshMedia(after transition: ContinuousClock.Instant?) -> Bool {
        activity.isFresh(after: transition, now: .now)
    }

    private let mixer: MediaMixer
    private let controller: AVPictureInPictureController
    private let activity = PiPCaptureActivity()
    private let cameraTap: PiPFrameTap
    private let compositionTap: PiPFrameTap
    private let renderer: AVSampleBufferVideoRenderer
    private let renderSynchronizer = AVSampleBufferRenderSynchronizer()
    private let frames: AsyncStream<PiPFrameTap.Frame>
    private var displayTask: Task<Void, Never>?
    private var stopped = false
    private var awaitingStartResult = false
    private let onEnd: (CameraPictureInPicture, PresentationEnd) -> Void

    init?(mixer: MediaMixer, sourceView: UIView, size: CGSize,
          onEnd: @escaping (CameraPictureInPicture, PresentationEnd) -> Void) {
        guard sourceView.window != nil, Self.isSupported else { return nil }
        let content = AVPictureInPictureVideoCallViewController()
        content.preferredContentSize = size
        let video = PiPVideoView()
        let badge = UILabel()
        badge.text = " Camera active "
        badge.font = .preferredFont(forTextStyle: .caption1)
        badge.adjustsFontForContentSizeCategory = true
        badge.textColor = .white
        badge.backgroundColor = .black.withAlphaComponent(0.8)
        video.translatesAutoresizingMaskIntoConstraints = false
        badge.translatesAutoresizingMaskIntoConstraints = false
        content.view.addSubview(video)
        content.view.addSubview(badge)
        NSLayoutConstraint.activate([
            video.leadingAnchor.constraint(equalTo: content.view.leadingAnchor),
            video.trailingAnchor.constraint(equalTo: content.view.trailingAnchor),
            video.topAnchor.constraint(equalTo: content.view.topAnchor),
            video.bottomAnchor.constraint(equalTo: content.view.bottomAnchor),
            badge.leadingAnchor.constraint(equalTo: video.leadingAnchor, constant: 6),
            badge.trailingAnchor.constraint(lessThanOrEqualTo: video.trailingAnchor, constant: -6),
            badge.topAnchor.constraint(equalTo: video.topAnchor, constant: 6),
        ])
        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView, contentViewController: content)
        let controller = AVPictureInPictureController(contentSource: source)
        let (frames, sink) = AsyncStream<PiPFrameTap.Frame>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.mixer = mixer
        self.controller = controller
        self.renderer = (video.layer as! AVSampleBufferDisplayLayer).sampleBufferRenderer
        self.frames = frames
        self.onEnd = onEnd
        cameraTap = PiPFrameTap(track: 0, activity: activity)
        compositionTap = PiPFrameTap(track: .max, activity: activity, sink: sink)
        super.init()
        controller.delegate = self
    }

    func prepareForAutomaticStart() async {
        await mixer.addOutput(cameraTap)
        guard !stopped else { await mixer.removeOutput(cameraTap); return }
        await mixer.addOutput(compositionTap)
        guard !stopped else { await mixer.removeOutput(compositionTap); return }
        let receiver = renderSynchronizer.sampleBufferReceiver(adding: renderer)
        renderSynchronizer.delaysRateChangeUntilHasSufficientMediaData = false
        renderSynchronizer.setRate(1, time: .zero)
        displayTask = Task.detached { [frames, activity] in
            for await frame in frames {
                guard !Task.isCancelled else { return }
                do {
                    let result = try await receiver.enqueue(CMReadySampleBuffer(frame))
                    if case .cancelledDueToFlushRequiredToResume = result {
                        await receiver.flush(removingDisplayedImage: true)
                    } else if case .enqueued = result {
                        activity.mark(.composition)
                    }
                } catch {
                    return
                }
            }
        }
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        isPrepared = true
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        isActive = false
        isPrepared = false
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        if awaitingStartResult {
            // AVKit cannot stop an opening window until it becomes active.
            // Keep the delegate alive briefly to close a late start callback.
            Task { [self] in
                try? await Task.sleep(for: .seconds(4))
                detachController()
            }
        } else {
            detachController()
        }
        compositionTap.finish()
        displayTask?.cancel()
        displayTask = nil
        renderSynchronizer.rate = 0
        Task { [mixer, cameraTap, compositionTap] in
            await mixer.removeOutput(compositionTap)
            await mixer.removeOutput(cameraTap)
        }
    }

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        awaitingStartResult = true
        compositionTap.setWindowVisible(true)
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        awaitingStartResult = false
        guard !stopped else { detachController(); return }
        isActive = true
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        guard !stopped else { return }
        onEnd(self, .closing)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        awaitingStartResult = false
        guard !stopped else { return }
        isActive = false
        compositionTap.setWindowVisible(false)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    failedToStartPictureInPictureWithError error: Error) {
        awaitingStartResult = false
        guard !stopped else { detachController(); return }
        compositionTap.setWindowVisible(false)
        onEnd(self, .failedToStart)
    }

    private func detachController() {
        controller.delegate = nil
        if controller.isPictureInPictureActive { controller.stopPictureInPicture() }
        controller.contentSource = nil
    }
}

/// Allows AVKit's automatic start to finish after the scene backgrounds. Once
/// PiP has opened, losing it interrupts capture without a second grace period.
nonisolated struct CameraPiPBackgroundHandoff {
    enum Decision: Equatable { case wait, keepRecording, interrupt }
    private var startDeadline: ContinuousClock.Instant?

    init(now: ContinuousClock.Instant) { startDeadline = now + .milliseconds(1500) }

    mutating func decision(active: Bool, mediaFresh: Bool, now: ContinuousClock.Instant) -> Decision {
        if let startDeadline {
            guard now < startDeadline else { return .interrupt }
            guard active && mediaFresh else { return .wait }
            self.startDeadline = nil
        }
        return active && mediaFresh ? .keepRecording : .interrupt
    }
}

private final class PiPVideoView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
}

nonisolated final class PiPCaptureActivity: Sendable {
    enum Track { case camera, composition, audio }
    private let activity = Mutex<[Track: ContinuousClock.Instant]>([:])

    func mark(_ track: Track, at now: ContinuousClock.Instant = .now) {
        activity.withLock { $0[track] = now }
    }

    func isFresh(after transition: ContinuousClock.Instant? = nil, now: ContinuousClock.Instant) -> Bool {
        let cutoff = now - .seconds(2)
        return activity.withLock { times in
            guard times.count == 3 else { return false }
            return times.values.allSatisfy { time in
                time >= cutoff && (transition.map { time > $0 } ?? true)
            }
        }
    }
}

private nonisolated final class PiPFrameTap: MediaMixerOutput, Sendable {
    typealias Frame = CMReadySampleBuffer<CVReadOnlyPixelBuffer>
    let videoTrackId: UInt8?
    let audioTrackId: UInt8?
    private let activity: PiPCaptureActivity
    private let sink: AsyncStream<Frame>.Continuation?
    private let renderCadence = Mutex(PiPPreviewCadence())

    init(track: UInt8, activity: PiPCaptureActivity, sink: AsyncStream<Frame>.Continuation? = nil) {
        videoTrackId = track
        audioTrackId = sink == nil ? nil : .max
        self.activity = activity
        self.sink = sink
    }

    func finish() { sink?.finish() }
    func setWindowVisible(_ visible: Bool) { renderCadence.withLock { $0.setWindowVisible(visible) } }
    func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) async {}

    func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        if buffer.frameLength > 0 { activity.mark(.audio) }
    }

    func mixer(_ mixer: MediaMixer, didOutput sampleBuffer: CMSampleBuffer) {
        guard sampleBuffer.imageBuffer != nil, sampleBuffer.presentationTimeStamp.isNumeric else { return }
        guard let sink else { activity.mark(.camera); return }
        guard renderCadence.withLock({ $0.admit(at: .now) }) else { return }
        // Copy the sample metadata for PiP. The encoder and renderer retain
        // the shared pixel contents read-only until their respective work ends.
        guard let copy = try? CMSampleBuffer(copying: sampleBuffer) else { return }
        var frame = Frame(unsafeWithPixelBuffer: copy)
        frame.sampleAttachments.displayImmediately = true
        sink.yield(frame)
    }
}

/// Prime the renderer while inline. A small floating preview can run at a
/// lower cadence than the recording, which keeps its own encoder input.
nonisolated struct PiPPreviewCadence {
    private var windowVisible = false
    private var nextFrame: ContinuousClock.Instant?

    mutating func setWindowVisible(_ visible: Bool) {
        guard visible != windowVisible else { return }
        windowVisible = visible
        nextFrame = nil
    }

    mutating func admit(at now: ContinuousClock.Instant) -> Bool {
        if let nextFrame, now < nextFrame { return false }
        nextFrame = now + (windowVisible ? .milliseconds(80) : .milliseconds(250))
        return true
    }
}
