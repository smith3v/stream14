# Preview Foreground Recovery Implementation Plan

**Goal:** Restore an explicitly opened, preview-only camera after an app switch, including portrait use, without restarting a recording or broadcast.

**Architecture:** MediaSession retains preview-only intent and serializes interruption cleanup before a fresh foreground camera open. Scene changes report foreground availability; capture generations reject stale native callbacks. The fixed landscape composition canvas does not change with phone orientation.

**Tech Stack:** Swift 6, SwiftUI, HaishinKit 2.3.0 pinned fork, AVFoundation, native Xcode shared Stream14 scheme.

---

### Task 1: Verify the cause and select the smallest recovery

**Prompt:**
Inspect current main, scene handling, native capture ownership and existing interruption fixtures. The owner reproduced Open camera → Codex → stream14 in portrait, without recording or rotation. Current active handling restarts only the overlay and read-only YouTube reconciliation. Capture is deliberately torn down on background; native start also lacks a post-await stop check. Options: merely show Open camera (honest but does not meet requested return behavior); restart the existing mixer blindly (can race teardown and media ownership); retain explicit preview-only intent and finish teardown before a fresh open (selected). Recording/upload interruptions still require explicit restart, and no camera runs in background.

### Task 2: Implement and test production ownership

**Prompt:**
Update MediaSession.swift and the narrow scene/preview presentation in SetupView.swift. Preserve preview intent through background-related camera/audio notifications, clear it for user Close, media recording/start, terminal setup/capture/thermal failures, and prevent automatic reopen while a broadcast owns configuration. Fence native callbacks by capture generation; validate stop/foreground after awaited startup. Add deterministic tests at the actual native-open boundary for preview return, early interruption ordering, foreground during close, rapid cycles, cancellation/manual Close, late startup, and active recording/upload protection. No camera fixture may claim physical frame evidence.

### Task 3: Validate, independently review and hand off

**Prompt:**
Run affected native suites and Release build using the shared scheme, pinned warmed packages, unique derived-data/results and an owned Simulator. Preserve originals; no phone, provider API or publishing actions. Update the canonical specification's foreground exception and development guide with actual checks and a five-minute portrait/landscape physical regression that remains pending. Review actual full diff against main with a separate agent, fix material findings, rerun affected checks, commit and coordinate PR publication into main with root. Do not bump release version or merge automatically.


## Validation checkpoint

The focused native result `/private/tmp/stream14-preview-fix-focused2.xcresult`
contains **70 executed passes, zero skips/failures**, four suites, 31.493 seconds:
PreviewForegroundTests, SessionInterruptionTests, BroadcastSessionTests and
SessionProfileTests. It uses the owned F11 Simulator, iPhone 13 mini iOS 27.2,
Xcode 27.2, with the warmed package checkout verified at pinned fork `497f742`.
The first run was not a pass: its normal-stop fixture had not supplied media, so
native finalization correctly failed and prevented preview restore. That fixture
now feeds synthetic samples through the actual shared encoder before Stop. An
existing coordinator regression also observed asynchronous socket close before it
completed; the assertion now waits for exactly one actual close while file
finalization remains held. It still checks immediate detachment and continued
recording independently. The fresh 70-pass run supersedes those two failures.

The production lifecycle is exercised around an injected native camera-acquisition
boundary, including delayed startup/close. These are not actual camera-frame or
phone-performance passes. Native synthetic writer/encoder samples in the fixture
are not private camera recordings. No phone, account API or publishing was used.

Reproduce with unique result paths and the shared scheme:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination 'platform=iOS Simulator,id=E0ABEB8B-B5A5-4FC9-AD6A-FA6A5908A78C' \
  -derivedDataPath /private/tmp/stream14-preview-fix-build \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -only-testing:Stream14Tests/PreviewForegroundTests \
  -only-testing:Stream14Tests/SessionInterruptionTests \
  -only-testing:Stream14Tests/BroadcastSessionTests \
  -only-testing:Stream14Tests/SessionProfileTests \
  -resultBundlePath /private/tmp/a-new-preview-fix-result.xcresult test
```

Independent actual-file/full-diff review found no material lifecycle, ownership,
privacy or media-restart issues. Release verification and final source/evidence
confirmation are pending at this checkpoint. Physical portrait/landscape camera
return remains pending on a later normally signed replacement build.
