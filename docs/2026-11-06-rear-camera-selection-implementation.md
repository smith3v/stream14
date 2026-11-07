# Rear Camera Selection Implementation Plan

**Goal:** Allow selecting the compatible rear lenses on the current iPhone before recording, including ultra-wide capture for a wider view (#33).

**Architecture:** Discover physical rear ultra-wide, wide and telephoto devices through public AVFoundation APIs. Filter against the current 1920×1080 NV12/30 fps profile, configure the selected camera through the existing single HaishinKit mixer, and keep selection locked during recording. Restore the prior camera after a failed preview change; stop capture if restoration fails.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, HaishinKit 2.3.0, Swift Testing and XCTest.

---

### Task 1: Discover and configure compatible lenses

**Prompt:** Add `Stream14/Media/RearCameraLens.swift` with stable lens identities, accessible labels and runtime format filtering (1920×1080 video-range NV12 supporting 30 fps). Discovery runs away from MainActor. Use `MediaMixer.configuration(video:configuration:)` after attach: upstream attach swallows errors in its optional configuration closure. Select input-priority capture and explicitly set the qualified format and frame rate through library ownership. No package or additional session/encoder is needed. Add deterministic profile-range tests to `Stream14Tests/RearCameraLensTests.swift`.

### Task 2: Integrate selection and failure recovery

**Prompt:** Update `Stream14/Media/MediaSession.swift` with available/selected lens state, idle/preview selection guards, serial busy ownership and rollback on failed preview changes. An interruption during an asynchronous change must still win. Add a Camera button and native lens-choice dialog to `Stream14/App/SetupView.swift`, with clear selected value and disabled-during-recording explanation. Tests verify invalid selection and lifecycle guards; physical tests check real camera configuration.

### Task 3: Verify on simulator and the owner's testing phone

**Prompt:** Run the existing shared Stream14 scheme against the installed 13 mini simulator with `xcodebuild -project Stream14.xcodeproj -scheme Stream14 -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages -disableAutomaticPackageResolution -derivedDataPath /tmp/stream14-issue33-simulator test`. Use new xcresult paths. Build/sign the same scheme for the paired physical phone, using the local signing selection; preserve the scheme's test-runner branding. Add explicit opt-in device tests for short per-lens recordings, preview changes, locked recording selection, saved dimensions/audio/video and overlay. Retain all recordings. Install the development app without uninstalling or removing existing data. Have the owner compare Wide and Ultra Wide from a fixed phone position, record/play a short clip and inspect both landscape layouts. Never infer visual field of view or A/V sync from structural file checks.

### Task 4: Document, review and prepare PR

**Prompt:** Update the canonical specification and development guide with actual APIs, commands, results and unverified coverage. Run `git diff --check` and appropriate native checks. Commit only feature files, preserving the owner's unrelated signing changes. Ask an independent agent to inspect actual files and the full diff against main plus requirements/results; fix material issues and rerun affected checks. Prepare a focused PR to main referencing #33, recording review and limits. Do not merge automatically.

## Implementation and validation (2026-11-07)

Implemented on `codex/issue-33-rear-camera-selection` from main `36e1150`.
The final control is a Camera button with an internal 44-point minimum label and
native lens-choice dialog. A menu-style Picker was replaced after the physical
test measured its intrinsic accessible control at only 34.33 points despite an
outer layout minimum. Explicit label/value expose the active lens to VoiceOver.

- Simulator: `/tmp/stream14-issue33-resume-simulator-final.xcresult` passed the full default suite (26 Swift Testing cases, including opt-in skips, and three ordinary UI checks; opt-in UI checks skipped).
- Release: `/tmp/stream14-issue33-resume-release-final.log` ends `BUILD SUCCEEDED` with signing disabled. Normally signed development installation and test-runner branding were verified separately.
- Physical capture: `/tmp/stream14-issue33-device-final.xcresult` passed all three hosted lens tests on iPhone 13 mini/iOS 27.2. Actual Ultra Wide/Wide formats are 1080p30; saved files contain audio/video and decoded overlay pixels. Recording selection lock, rollback with another successful recording, failed restoration and interruption passed. Its earlier UI case failed and is superseded only for UI by the final result below.
- Physical UI: `/tmp/stream14-issue33-resume-device-ui-2.xcresult` passed the lens-choice dialog, Ultra Wide selection/value, actual touch target in both landscape orientations, recording lock, stop and playback sheet. Private screenshots under `/tmp/stream14-issue33-resume-ui-attachments` were inspected. The app was reopened for owner review.
- Independent agent inspected actual files/full diff against main. The initial missing rollback/interruption-test finding was resolved; final full review and focused Button/dialog re-review found no remaining material issues.

The owner confirmed on 2026-11-07 that Ultra Wide shows the wider scene from the
same position and the landscape controls work as expected. Spoken VoiceOver
navigation, Telephoto/other iPhone hardware and long-run qualification remain
separate checks. No broadcast output,
measured A/V alignment or TestFlight delivery is claimed for this feature.
Recordings are retained on the phone; media, private results, device identifiers
and unrelated local project signing settings are excluded from commits/PRs.

## Owner UI follow-up (2026-11-07)

Use the existing brainstorming/writing-plans workflow for this focused correction:
1. In `Stream14/App/SetupView.swift`, nest the selector inside the same non-idle condition as the preview. Keep discovered choices/selected lens intact when closing capture. Use a small standard bordered camera button, a short magnification label and an internal 44-point minimum target; move the explanatory caption to its accessibility hint.
2. In `RearCameraLens.swift`, provide the short button label while retaining full dialog/accessibility names. Extend the existing opt-in device UI check to assert initial absence, compact touch-target bounds, disappearance after Close camera, and remembered selection after reopen. No new recording experiment is needed beyond the existing short UI smoke clip.
3. Run focused physical UI validation, inspect its screenshots, build Release and run relevant hosted checks. Update specification/guide, get an independent review of the actual follow-up diff and full PR, commit only feature files and update PR #35. Preserve unrelated signing settings and all phone recordings; do not merge.

Follow-up validation: `/tmp/stream14-issue33-compact-device-2.xcresult` passed
initial selector absence, compact dimensions (44–64 points high and at most 180
points wide for Ultra Wide at normal text) in both landscape orientations,
selection/recording lock/playback, absence after Close camera, and retained Ultra
Wide after reopen. `/tmp/stream14-issue33-compact-simulator.xcresult` passed the
focused lens/setup checks; `/tmp/stream14-issue33-compact-release.log` passed
Release build. The first physical attempt hit XCTest's offscreen activation-point
error after rotation; the final helper scrolls before querying hittability.
Independent review of the actual follow-up/full PR found no material issues.
