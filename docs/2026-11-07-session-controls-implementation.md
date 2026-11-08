# Session Profiles and Controls Implementation Plan

**Goal:** Add fixed 1080p30/720p30 local-session profiles, shared microphone mute/meter and supported rear-camera zoom for F4/#17.

**Architecture:** One immutable SessionProfile is selected while capture is closed and flows through camera format selection, mixer canvas, attached WebKit renderer and local writer. HaishinKit's mixed-audio mute precedes fan-out; a synchronous meter retains only the latest scalar, polled by the existing UI loop. Retain current rear-lens selection and overlay recovery.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, WebKit, HaishinKit 2.3.0, native Xcode tests.

---

### Task 1: Profile propagation

**Prompt:** Read @brainstorming and the canonical approved F4 design. Add `Stream14/Media/SessionProfile.swift` with explicit 1920×1080/14 Mbps and 1280×720/8 Mbps constants, 30 fps, two-second keyframes and 44.1 kHz stereo/128 kbps audio. Persist only the enum preference. Keep profile changes unavailable until camera closes. Parameterize `RearCameraLens`, `WebOverlayLayer`, `WebOverlayRenderer` and `LocalRecorder`, retaining default arguments for existing tests. Request SDR/Rec.709 metadata without claiming measured color/CBR conformance. Add deterministic consistency and viewport/raster tests. Commit the implementation after checks.

### Task 2: Shared audio and camera controls

**Prompt:** Use verified public `AudioMixerSettings.isMuted` before mixed output distribution. Add one `MediaMixerOutput` that computes bounded peaks and retains one scalar under Mutex, without sample Tasks. Poll it at 10 Hz in the existing UI loop. Add route notification observation, supported zoom configuration on MediaMixer, and accessible standard controls in `SetupView`. Preserve operation serialization, interruptions and lens rollback. Test mute settings, level calculation and camera-closed profile policy.

### Task 3: Verification and review

**Prompt:** Run an unsigned Release build and hosted focused tests with the shared Stream14 scheme, private derived data `/tmp/stream14-f4-build` and packages `/tmp/stream14-issue3-packages`. Coordinate Simulator destination with root. Run `git diff --check`. Update canonical specification and the development guide with exact results and pending physical profile/mute/zoom/route checks. Give root the full diff against origin/main for an independent agent review; address material findings and rerun affected checks, commit and prepare a focused PR in the owner-authorized chain. No merge or automatic publication.

### Persistence privacy declaration

The only new preference is the profile enum in app-only UserDefaults. The app
manifest declares `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1` for
this use; no app group, system preferences or third-party preferences are accessed.
Checked against [Apple's required reasons reference](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)
on 2026-11-07.

## Implementation handoff and evidence

Branch: `codex/issue-17-session-controls`, isolated worktree
`/private/tmp/stream14-epic13-f4`, started from `origin/main` `ededeb1`.
Plan checkpoint `c2cb946`; implementation checkpoint `615ea08`. Root owns later
merging of reviewed F2 predecessor into this branch for the requested PR chain.
No merge, transport connection, physical camera test, upload or recording cleanup
has occurred in this stage. Independent review and PR creation are pending root
coordination.

Public concrete boundaries:

- `SessionProfile` constants and `videoSettings`, `audioSettings`,
  `audioSettings(muted:)`; future transport must consume the same selected value.
- `MediaSession(profile:persistProfile:authorizeCapture:)` keeps profile explicit
  and frozen outside idle. Setup reads the saved enum; hosted tests default to the
  baseline profile so prior app preferences cannot change test media dimensions.
- `WebOverlayRenderer(profile:)`, `setProfile(_:)`, and `canvasSize` retire the old
  browser/generation/raster and rebuild the attached exact-size viewport.
- `RearCameraLens` format/discovery and `WebOverlayLayer.install` accept the profile.
- `LocalRecorder.start(_:injection:profile:)` retains one native encode path and
  original MP4 export. Existing defaults preserve baseline callers.
- Shared mixer mute is upstream of every mixed output. `MicrophoneMeter` retains
  only a bounded scalar reading, no audio buffers or callback Tasks.
- `MediaMixer.configureZoom(_:)` returns a Sendable range/value snapshot from its
  serial device configuration; no AVCaptureDevice moves to UI. Touch commits on
  release; VoiceOver has explicit bounded 0.1× increments/decrements.

Validation so far (Xcode 27.2, iOS SDK/Simulator 27.2):

| Check | Result and local evidence |
| --- | --- |
| Native unsigned Release, final implementation | Passed, `/tmp/stream14-f4-release-final.log` |
| Build-for-testing, final bundle/resources | Passed, `/tmp/stream14-f4-build-tests-final.log` |
| Six focused SessionProfileTests | Passed, `/tmp/stream14-f4-profiles.xcresult`, log `/tmp/stream14-f4-profiles.log` |
| Regression suites: 16 executed, two physical/reference opt-ins skipped | Passed, `/tmp/stream14-f4-regression.xcresult`, log `/tmp/stream14-f4-regression.log` |
| Privacy plist and whitespace | `plutil -lint Stream14/PrivacyInfo.xcprivacy` and `git diff --check` passed |

The focused suite verifies both attached CSS/raster dimensions with alpha, profile
rebuild/manual-hide preservation, preference fallback, rejection during suspended
capture preparation and cancellation before device activation, bounded meter
handling of float/interleaved/int16 PCM, and actual shared mixer mute/unmute output
samples delivered to two consumers. Regression suites cover local writer failure
injections plus an original 720p H.264/AAC file, identity orientation, existing
1080p overlay rendering/recovery, explicit composition visibility, lens filtering,
health rules and app configuration. Synthetic unit-test temporary files are isolated;
owner originals are untouched.

Physical F4 acceptance remains pending exactly as listed in the development guide.
No Simulator result proves real-device controls, camera formats, audible sync,
route/interruption behavior or long-run performance. No CBR, color-fidelity or
network fan-out performance qualification is claimed.

Two existing setup UI tests also passed in `/tmp/stream14-f4-layout.xcresult`:
portrait setup and largest-text landscape accessibility audits. Exported screenshots
under `/tmp/stream14-f4-layout-images` were visually inspected. The portrait profile
button is clear; the largest-text screenshot covers the introduction before scrolling,
so it does not itself verify the profile button at that size. The focused profile
selection/persistence/scroll check now passes as recorded below.

### Final stacked implementation checks

F4 now includes the reviewed F1/F2 predecessor through merge `9152d05`, whose
second parent is F2 `51dbdc3`. The F4 delta is reviewed against
`codex/issue-15-youtube-authorization`; also inspect the full diff against
`origin/main` for integration. The private F1 candidate explicitly chooses
`.fullHD` because its fixtures and RTMP settings are fixed at 1080p. It cannot
inherit the operator's persisted 720p preference. App profile settings remain
independent of Google setup/authentication.

The merged Release build passed with `/tmp/stream14-f4-stack-release.log` and
merged build-for-testing passed with `/tmp/stream14-f4-stack-build-tests.log`.
After merging Google dependencies, reproduce with
`-clonedSourcePackagesDirPath /tmp/stream14-f2-packages` instead of the earlier
local-only cache. This changes no package pin beyond the F2 predecessor.

A focused UI test now selects 720p, verifies it after app relaunch, scrolls to the
profile button at the largest accessibility text size in both landscape
orientations, verifies at least 44-point height, runs accessibility audits and
restores 1080p. Passed in `/tmp/stream14-f4-stack-profile-ui-3.xcresult`; log
`/tmp/stream14-f4-stack-profile-ui-3.log`. Both exported screenshots in
`/tmp/stream14-f4-profile-layout-images` were visually inspected: the entire profile
control/text is visible without clipping. Earlier failures are retained: the first
asserted an accessibility value before SwiftUI propagated it, and the second used
full-screen flicks that alternated past the target. Predicate expectations and
bounded drags fix the test; no production behavior changed to accommodate it.

No phone recording, Google consent/callback, YouTube event or transport acceptance
is established by these checks. Those gates remain open even though the code is
ready for a reviewed PR. No root-checkout owner setup file or private configuration
is imported by F4.

Final merged hosted run `/tmp/stream14-f4-stack-focused.xcresult` passed with
19 executed tests across profile, authorization and media-feasibility suites;
one private publishing test was skipped (Swift Testing reports 20 including that
skip). Initial regression summary likewise reports 18 including two opt-in skips:
16 executed. Six focused F4 tests and three UI tests executed successfully. These
skips remain pending evidence rather than passed physical gates.
