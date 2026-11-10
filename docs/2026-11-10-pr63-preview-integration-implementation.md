# PR63 Preview Integration Implementation Plan

**Goal:** Prepare the Session workspace for a direct development-phone check while retaining the reviewed preview recovery fix.

**Architecture:** Normally merge PR #68 into PR #63 without rewriting shared history. Keep the existing workspace and media/coordinator owners; resolve only overlapping source/documentation changes and preserve fresh-frame readiness and view identity.

**Tech Stack:** Swift 6, SwiftUI, existing HaishinKit pin, Xcode native tests and Release build.

---

### Task 1: Integrate reviewed source

**Prompt:** Start at PR63 `100ed21` in a separate clone. Normally merge PR68 `52cdc67`, resolve overlapping `Stream14/App/SetupView.swift` and `Stream14/Media/MediaSession.swift` changes, and preserve both parents' canonical documentation. Keep interface fixtures before native capture; preserve workspace reset guards, preview-only restoration, metadata-only frame readiness and explicit view remount. Do not include deferred PR69 or change packages/signing/version.

### Task 2: Verify the integrated application

**Prompt:** Use the shared Stream14 scheme and an owned iPhone 13 mini Simulator. Run PreviewForegroundTests, SessionInterruptionTests, BroadcastSessionTests, SessionProfileTests, SessionWorkspaceTests, YouTubeBindingTests and RecordingFinalizationTests plus `SetupScreenTests/testNativeDestinationsNeverStartCaptureOrPublishing`. Use unique result/derived-data paths and a verified pinned package cache. Run the ordinary unsigned generic-iOS Release build. Inspect authoritative native summaries and final exits; do not restart a live job on an observation timeout.

### Task 3: Document and independently review

**Prompt:** Update this checkpoint and the development guide with exact merge/source/build/test evidence and pending physical UI/contrast-audit acceptance. Check local links, fences and `git diff --check`. Have a separate agent inspect the full diff against main and the actual merge delta, resolve material issues and repeat affected checks. Commit and hand the root agent the normally pushable PR63 head; retain draft status until acceptance is addressed. No phone install, camera/recording, publishing or TestFlight operation occurs in this stage.


## Integration checkpoint

PR63 `100ed21` normally merged reviewed PR68 `52cdc67` at `3154200`, with no
conflicts. After the owner merged PR67/68, current main `2001d76` was normally
merged at `6459c74`. Main and PR68 have identical trees; the second merge changes
no files relative to `3154200`. No history was rewritten and deferred PR69 is not
included.

The production delta relative to the prior workspace is the reviewed preview fix:
retire the stopped mixer/view/overlay, observe fresh raw/composed frame metadata,
and remount the replacement preview with explicit SwiftUI identity. Workspace
readiness, next-session guards, consent/End confirmation, output independence and
Debug fixture short-circuit remain intact. Preview fixtures still return before
native camera acquisition. Existing phone passes apply only to runtime `70eca51`,
not yet to this integrated workspace.

Owned E0 native/navigation and generic-iOS Release checks completed successfully;
exact evidence follows. The unresolved legacy profile contrast audit
remains pending; this integration does not alter its handler or claim an audit
pass. Physical interface operation, VoiceOver/larger text, and file/receiver checks
remain separate acceptance. No phone or TestFlight operation occurs in this stage.

## Next phone visit: interface only, five minutes total

Laptop source review, signing/branding and normal candidate preparation must finish
before requesting readiness. Install in place without uninstall/reset, preserve
originals and stop by the five-minute cutoff. Setup delays consume the same budget;
record skipped cases rather than extending. The owner uses ordinary controls, not
Debug fixtures. Leave Record only, Start recording and streaming, deletion and account changes
untouched.

| Time from first device operation | Interface check | Observation to record |
| --- | --- | --- |
| 0:00–1:00 | In-place install/ordinary launch; portrait Session → Recordings → Session. | Both tabs and existing archive remain reachable; no output starts. |
| 1:00–1:45 | More (ellipsis) → Settings → Done. | Secondary settings open and dismiss; no account/configuration change requested. |
| 1:45–3:15 | Check camera and sound; inspect the moving picture, then both landscape orientations. Use More → Navigate for Session/Recordings. | Entire 16:9 composition and main controls remain reachable; navigation works without implicit recording/upload. |
| 3:15–4:15 | Return to portrait; switch to Codex briefly and return once, then expand Camera controls → Close camera. | Moving preview returns; Close ends preview. |
| 4:15–5:00 | Confirm camera is closed and no recording/upload started; report fit/navigation problems. | Visit wrapped inside budget; no deletion or new media recording. |

This is not a VoiceOver, largest-text, recording/receiver, numerical sync or
TestFlight pass. Those checks remain separate; the native contrast audit remains
unresolved until diagnosed rather than waived based on this visit.


## Native validation checkpoint

The integrated runtime at `3154200` / identical-tree `6459c74` passed **107 tests,
zero failures/skips**: 106 checks in seven native suites (40.893 seconds) plus the
single noncapturing navigation UI test (28.679 seconds). The authoritative xcresult
summary reports Passed, total/passed 107, failed/skipped 0. The overall native
command exited 0 after 240.729 seconds, including build, Simulator and result
collection. The ordinary unsigned generic-iOS Release build also exited 0 with
BUILD SUCCEEDED after 99.476 seconds. Both commands are terminal/reaped; no retry
or replacement test run was started during an observation wait.

The shared Stream14 scheme used Xcode 27.2, the owned E0 iPhone 13 mini Simulator
on iOS 27.2, and twelve verified locked package checkouts including HaishinKit
`497f742`. The native invocation began before the landed-main ancestry merge;
`git diff 3154200..6459c74` is empty for the entire tree, so its checked source is
identical. Subsequent checkpoint edits change documentation only.

Private evidence, not attachments:

- `/private/tmp/stream14-pr63-preview-integration.xcresult`
- `/private/tmp/stream14-pr63-preview-integration-test-summary.json`
- `/private/tmp/stream14-pr63-preview-integration-tests.log`
- `/private/tmp/stream14-pr63-preview-integration-tests-outcome.json`
- `/private/tmp/stream14-pr63-preview-integration-release.log`
- `/private/tmp/stream14-pr63-preview-integration-release-outcome.json`

E0 was handed off booted to the separate one-case contrast-probe stage after the
native command finished; this stage performs no further Simulator operation.
D6 was observed booted and left untouched. The contrast probe is separate from
these 107 passes. Neither that legacy audit nor the physical UI is claimed passed.
Initial independent actual-full-diff and both-parent integration review found no
material source issues; final source/evidence review is required before root's
normal PR update and candidate handoff.

Reproduce with a **new** result path and an owned Simulator:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination 'platform=iOS Simulator,id=E0ABEB8B-B5A5-4FC9-AD6A-FA6A5908A78C' \
  -derivedDataPath /private/tmp/stream14-pr63-preview-build \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -only-testing:Stream14Tests/PreviewForegroundTests \
  -only-testing:Stream14Tests/SessionInterruptionTests \
  -only-testing:Stream14Tests/BroadcastSessionTests \
  -only-testing:Stream14Tests/SessionProfileTests \
  -only-testing:Stream14Tests/SessionWorkspaceTests \
  -only-testing:Stream14Tests/YouTubeBindingTests \
  -only-testing:Stream14Tests/RecordingFinalizationTests \
  -only-testing:Stream14UITests/SetupScreenTests/testNativeDestinationsNeverStartCaptureOrPublishing \
  -resultBundlePath /private/tmp/a-new-pr63-preview-result.xcresult test

xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/stream14-pr63-preview-release-build \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```
