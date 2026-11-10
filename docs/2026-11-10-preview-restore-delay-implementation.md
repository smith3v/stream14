# Preview Restore Delay Implementation Plan

**Goal:** Restore a moving preview after an app switch without reusing stale SDK timing state or claiming readiness before camera/composed frames arrive.

**Architecture:** Retire the stopped HaishinKit mixer, overlay layer and Metal preview after complete teardown, then create fresh instances before a subsequent camera open. Observe bounded raw/composed frame metadata during startup and keep capture unavailable for recording until fresh frames arrive. Existing preview intent, generation fencing and explicit recording/broadcast resume rules remain.

**Tech Stack:** Swift 6, SwiftUI, HaishinKit 2.3.0 pinned `497f742`, AVFoundation, native Swift Testing/Xcode.

---

### Task 1: Verify the retained SDK restart state

**Prompt:**
Read `MediaSession.swift`, the pinned SDK `Screen`, `MediaMixer` and capture-unit lifecycle, plus the owner’s portrait preview-only failure on merged main `1960df2`. The owner estimated a freeze longer than 15 seconds before eventual initialization; this is not a measured duration. The screenshot reports Preview ready while the image is frozen. Write a deterministic SDK-level regression showing `Screen.reset()` preserves target timestamp, latency and monotonic output PTS: the first post-gap input can shift output into the future, suppressing later output until time catches up. Contrast a fresh Screen. Do not infer exact physical cause from a fixture alone.

### Task 2: Retire stopped media state and validate fresh frames

**Prompt:**
Prefer recreating the fully stopped mixer/screen and preview to a guessed wall-clock offset, SDK-private access or a dependency fork update. Replace `MediaSession`'s mixer/preview only after output detachment and complete stop; clear its overlay layer so the new screen gets a newly installed child. Never overlap camera ownership or restart recording/upload automatically. Introduce bounded metadata-only raw-track/composed-track observers using mutex-owned scalar counters/PTS; no retained media, per-frame Tasks or new encoder. Keep phase preparing until advancing raw video and subsequent composed output are observed, then expose preview/Record. Cancel waiting on background/Close/generation change; use an explicit finite startup failure for absent frames. Preserve existing permission, failure and broadcast barriers.

### Task 3: Test lifecycle and validate native products

**Prompt:**
Extend `PreviewForegroundTests` with mixer/view identity retirement only after completed teardown, readiness blocking without raw/composed frames, early Close/background cancellation, and stalled readiness failure. Exercise actual metadata observers with generated samples. Run affected native suites and ordinary unsigned Release using the shared Stream14 scheme, a dedicated owned Simulator, unique results and verified pinned package cache. Do not touch the phone or another task’s Simulator. Update the canonical spec and development guide with exact implementation/evidence and a later five-minute physical return check. Independent review must inspect the actual full diff against current main and private native results; resolve material findings and rerun affected checks before committing/publishing the focused PR. Physical recovery remains failed/pending until retested on the corrected source.


## Validation checkpoint

Runtime source `70eca51` passes **76 native tests, zero failures/skips**, in
PreviewForegroundTests, SessionInterruptionTests, SessionProfileTests and
BroadcastSessionTests. The authoritative summary reports Passed, total/passed 76,
failed/skipped 0; body time 35.796 seconds, recorded result span 140.429 seconds.
It ran on the owned E0 iPhone 13 mini Simulator, iOS 27.2, with Xcode 27.2 and
verified HaishinKit checkout `497f742`. The separate ordinary unsigned generic-iOS
Release build also succeeded. Both native invocations ended with exit 0; no job
remains running. These are development/native results, not phone recovery or
TestFlight acceptance.

The SDK-level regression uses the actual pinned `Screen` implementation. It
establishes a pre-gap display tick at time 100, resets, then supplies camera input
at time 120 before the first new display tick. The reused screen produces PTS
above 139 and suppresses the next ordinary tick; a fresh screen produces advancing
PTS near 120. This proves the retained-timing defect for that ordering, not the
exact ordering or full cause of the owner's uninstrumented phone event. The
lifecycle tests prove retirement happens only after completed teardown, frame
readiness gates Record, background/Close cancels waiting, absent frames fail without
a retry loop, and recording/broadcast do not automatically restart. Raw metadata
observers are exercised with generated real CMSampleBuffers; they retain only
scalar state, never samples, images, queues or per-frame Tasks. They remain attached
until capture closes; after readiness their callback exits without changing state.

The first compile attempt failed because new helper methods inherited default
MainActor isolation; explicitly nonisolated Sendable classes with Mutex-owned
state corrected that without unchecked annotations. No tests executed in that
attempt. The next 75-test run proved the new cases but failed an existing normal
Stop fixture that incorrectly required every burst input to pass bounded encoder
admission. That fixture now admits generated A/V at 40 ms spacing, permits bounded
rejection, and still requires actual A/V admission, writer start, clean Stop with
no recording failure and successful later preview return. The final 76-pass run
supersedes both attempts. MainActor-only readiness fixture closures produce
Swift captured-variable warnings; both producer/consumer accesses remain explicitly
MainActor isolated, with no concurrent mutation or warning suppression.

Private local evidence, not Git attachments:

- `/private/tmp/stream14-preview-delay-focused3.xcresult`
- `/private/tmp/stream14-preview-delay-test-summary.json`
- `/private/tmp/stream14-preview-delay-focused3.log`
- `/private/tmp/stream14-preview-delay-release.log`

Reproduce with unique result/derived-data paths:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination 'platform=iOS Simulator,id=E0ABEB8B-B5A5-4FC9-AD6A-FA6A5908A78C' \
  -derivedDataPath /private/tmp/stream14-preview-delay-build \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -only-testing:Stream14Tests/PreviewForegroundTests \
  -only-testing:Stream14Tests/SessionInterruptionTests \
  -only-testing:Stream14Tests/SessionProfileTests \
  -only-testing:Stream14Tests/BroadcastSessionTests \
  -resultBundlePath /private/tmp/a-new-preview-delay-result.xcresult test

xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/stream14-preview-delay-release-build \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

No phone operation, private camera/audio recording, provider request, broadcasting,
version bump or TestFlight replacement was performed during implementation/native
validation. The separately authorized corrected-source phone retest below
supersedes the pending portrait/manual Close checks; optional landscape remains
pending. Independent final source/evidence review at `7407273` found no material
issues. All 75 local links, fences and diff checks passed before publication.

## Corrected-source attended retest — 2026-11-10

The owner explicitly agreed to a new five-minute preview-only visit. A normally
signed **Development 0.3 (4), runtime `70eca51`**, matching reviewed head `7407273`,
was installed in place (native exit 0, 7.460 seconds) and ordinarily launched
(native exit 0, 2.325 seconds). No uninstall, reset or container read occurred.
This supersedes the installed main `1960df2` whose earlier return check failed;
it is not a TestFlight update.

The first device operation was **21:45:22.294340 UTC**, with a strict
**21:50:22.294340 UTC** cutoff. Root recorded the completed visit at
**21:48:28 UTC**, about **186 seconds** after device work began. This is the
coordinated visit span, not measured camera-start or recovery latency.

| Check | Owner-reported result |
| --- | --- |
| Portrait Open camera → Codex for about ten seconds → return, repeated once | Moving preview returned promptly both times, without the earlier long dimmed freeze. |
| Close camera → Codex → return | Camera stayed closed with Open camera available; no recording or upload started. |
| Wrap-up | Owner left the camera closed; the visit ended within the five-minute cutoff. |

**Result: passed for these preview-only checks on this development source.**
No rotation, local recording or broadcasting was requested. Recovery latency was
not timed; overlay freshness, recording/broadcast interruption, A/V sync,
performance, optional landscape and final TestFlight qualification remain
unverified by this visit. Original recordings were retained.

Private proof is retained under
`/private/tmp/stream14-preview-delay-retest-phone-{visit,install,launch,install-outcome,launch-outcome}.json`.
Owner replies and the recorded end clock are summarized privately in
`/private/tmp/stream14-preview-delay-retest-observations.json`.
The signed candidate preparation and reproducible handoff are
`/private/tmp/stream14-preview-delay-phone-preparation.json` and
`/private/tmp/stream14-preview-delay-phone-handoff.md`. No private media, signing
identity or device/account identifier is included in Git.
