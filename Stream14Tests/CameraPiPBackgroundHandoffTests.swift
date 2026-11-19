#if DEBUG
import Testing
@testable import Stream14

struct CameraPiPBackgroundHandoffTests {
    @Test func backgroundCanArriveBeforeAVKitAndItsFirstLiveFrame() {
        let now = ContinuousClock.now
        var handoff = CameraPiPBackgroundHandoff(now: now)
        #expect(handoff.decision(active: false, mediaFresh: true, now: now) == .wait)
        #expect(handoff.decision(active: true, mediaFresh: false, now: now + .milliseconds(200)) == .wait)
        #expect(handoff.decision(active: true, mediaFresh: true, now: now + .milliseconds(300)) == .keepRecording)
        #expect(handoff.decision(active: false, mediaFresh: true, now: now + .milliseconds(400)) == .interrupt)
    }

    @Test func missingAutomaticStartTimesOut() {
        let now = ContinuousClock.now
        var handoff = CameraPiPBackgroundHandoff(now: now)
        #expect(handoff.decision(active: false, mediaFresh: true, now: now + .milliseconds(1400)) == .wait)
        #expect(handoff.decision(active: false, mediaFresh: true, now: now + .milliseconds(1500)) == .interrupt)
    }

    @Test func lateStartCannotClaimTheRecording() {
        let now = ContinuousClock.now
        var handoff = CameraPiPBackgroundHandoff(now: now)
        #expect(handoff.decision(active: true, mediaFresh: true, now: now + .seconds(2)) == .interrupt)
    }

    @Test func anAlreadyActiveWindowNeedsLiveSamples() {
        let now = ContinuousClock.now
        var handoff = CameraPiPBackgroundHandoff(now: now)
        #expect(handoff.decision(active: true, mediaFresh: true, now: now) == .keepRecording)
        #expect(handoff.decision(active: true, mediaFresh: false, now: now + .milliseconds(300)) == .interrupt)
    }

    @Test func allTracksMustArriveAfterTheAppSwitch() {
        let transition = ContinuousClock.now
        let before = transition - .milliseconds(30)
        let after = transition + .milliseconds(30)
        let activity = PiPCaptureActivity()
        activity.mark(.camera, at: before)
        activity.mark(.composition, at: before)
        activity.mark(.audio, at: before)
        #expect(activity.isFresh(now: transition))
        #expect(!activity.isFresh(after: transition, now: transition))

        activity.mark(.camera, at: after)
        activity.mark(.composition, at: after)
        #expect(!activity.isFresh(after: transition, now: after))
        activity.mark(.audio, at: after)
        #expect(activity.isFresh(after: transition, now: after))
        #expect(!activity.isFresh(now: after + .seconds(3)))
    }

    @Test func previewCadenceChangesAtTheWindowTransition() {
        let now = ContinuousClock.now
        var cadence = PiPPreviewCadence()
        let inline = [cadence.admit(at: now), cadence.admit(at: now + .milliseconds(200))]
        #expect(inline == [true, false])
        cadence.setWindowVisible(true)
        let floating = [cadence.admit(at: now + .milliseconds(205)),
                        cadence.admit(at: now + .milliseconds(275)),
                        cadence.admit(at: now + .milliseconds(285))]
        #expect(floating == [true, false, true])
        cadence.setWindowVisible(false)
        let restored = [cadence.admit(at: now + .milliseconds(300)),
                        cadence.admit(at: now + .milliseconds(400)),
                        cadence.admit(at: now + .milliseconds(550))]
        #expect(restored == [true, false, true])
    }
}
#endif
