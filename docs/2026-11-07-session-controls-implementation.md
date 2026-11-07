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
