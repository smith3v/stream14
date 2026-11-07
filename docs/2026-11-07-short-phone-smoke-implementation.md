# Short Connected-Phone Smoke Implementation Plan

**Goal:** Keep routine connected-iPhone verification within a five-minute session by coalescing current camera/profile checks into one opt-in test.

**Architecture:** One serialized hosted physical test uses two short sequential MediaSession recordings, one for each fixed profile, with a covered attached local WebKit fixture. It uses the reviewed local recorder path, retains every original and avoids the owner's saved URL/configuration. An existing Debug-only isolated-media-host hook suppresses the app's unrelated saved-overlay reconciliation; its short-smoke host also uses an empty in-memory URL and blocks accidental host capture/configuration writes.

**Tech Stack:** Swift 6, Swift Testing, UIKit/WebKit, HaishinKit, AVFoundation, native Xcode.

---

### Task 1: Scope the physical smoke

**Prompt:** Inspect AGENTS.md, the canonical specification, current profile/capture/overlay/writer APIs and the existing physical harness. The existing long harness misses 720p and contacts a real website; replaying all UI harnesses repeatedly installs/launches and replaces windows. Choose one opt-in physical test with two short clips instead. Keep fixture decoding/retry/lifecycle cases on the laptop. Do not treat a short smoke as long-event, real network, physical sync, VoiceOver or recovery qualification.

### Task 2: Implement narrow coverage

**Prompt:** Add Stream14Tests/ShortPhoneSmokeTests.swift. Require Debug, pre-authorized camera/microphone and a physical iPhone 13 mini; default, Simulator and Release runs skip honestly. Release is unsupported for this harness because host isolation is Debug-only; its ordinary app initialization is not isolated. Use STREAM14_SHORT_DEVICE_SMOKE=1. No Google, sockets, websites, Keychain reads/writes or deletion. Each profile gets a local changing-alpha fixture, an initial red composed marker changed to green, mute/hide/unhide controls, frozen-profile rejection, a checked original H.264/AAC file, and decoded marker checks. Close the first session before the second. Use bounded polling plus a one-minute test limit; the Xcode runner gets a 90-second execution watchdog. Normal native operations are not assumed to be preemptible; the parent operator owns the overall five-minute wall-clock deadline.

In Stream14App.swift, the Debug short-smoke branch creates authorization with a nil driver/configured false so a signed candidate with a real public client cannot instantiate the SDK singleton or restore credentials. Selection construction performs no requests. Extend the existing Debug isolated-media-host condition in SetupView.swift and select an empty-URL, nonpersisting, capture-disabled host session only for this flag; normal and Release behavior stay unchanged. The actual test session has its own already-authorized capture boundary.

### Task 3: Validate and hand off

**Prompt:** Build for testing against both Simulator and generic iOS using the shared scheme and existing package cache. Default/Simulator execution must skip physical capture; do not install or run on the owner's phone before readiness. Run appropriate noncapturing regression coverage and git diff --check. A separate agent must review actual full changes against main plus the predecessor delta before PR handoff. Resolve material findings and rerun affected checks. Commit meaningful checkpoints and report exact flags, selector, budget and missing physical evidence.

## Operator command

Run from the selected integrated worktree with normal local signing. First build/brand/sign all products while the phone is absent. Select only this test when the owner is ready; no other camera/window-owning test runs concurrently.

~~~sh
TEST_RUNNER_STREAM14_SHORT_DEVICE_SMOKE=1 xcodebuild \
  -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination "platform=iOS,id=$STREAM14_DEVICE_ID" \
  -derivedDataPath "$STREAM14_EVIDENCE/DerivedData" \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f2-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 90 \
  -only-testing:Stream14Tests/ShortPhoneSmokeTests/twoProfilesRetainComposedOriginals \
  -resultBundlePath "$STREAM14_EVIDENCE/short-phone-smoke.xcresult" test
~~~

The operator's five-minute budget includes installation and unresolved prerequisites. If permission/consent/setup or installation is not ready in that budget, stop and record BLOCKED; do not silently turn the visit into an hour. The test target is under one minute after launch, leaving time for installation and laptop analysis. Neither the one-minute cooperative test limit nor an internal polling deadline is a guarantee that a native API can be interrupted; the runner watchdog is the outer bound for the test process.

## Evidence limitations

The clips exercise current local composition/profile controls with actual camera/microphone data. A red/green rectangle in decoded originals proves the changing overlay reached each file; audio track/decode structure does not prove audible unmute or physical A/V synchronization. No network output, actual overlay-source outage, two-minute internet outage, injected disk fault, crash recovery or long-run stability is established. Originals remain in MediaExperiments and are never deleted by this test.
