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
  -only-testing:Stream14Tests/ShortPhoneSmokeTests \
  -resultBundlePath "$STREAM14_EVIDENCE/short-phone-smoke.xcresult" test
~~~

The operator's five-minute budget includes installation and unresolved prerequisites. If permission/consent/setup or installation is not ready in that budget, stop and record BLOCKED; do not silently turn the visit into an hour. The test target is under one minute after launch, leaving time for installation and laptop analysis. Neither the one-minute cooperative test limit nor an internal polling deadline is a guarantee that a native API can be interrupted; the runner watchdog is the outer bound for the test process.

## Evidence limitations

The clips exercise current local composition/profile controls with actual camera/microphone data. A red/green rectangle in decoded originals proves the changing overlay reached each file; audio track/decode structure does not prove audible unmute or physical A/V synchronization. No network output, actual overlay-source outage, two-minute internet outage, injected disk fault, crash recovery or long-run stability is established. Originals remain in MediaExperiments and are never deleted by this test.

## Checkpoint and validation — 2026-11-08

Worktree: /private/tmp/stream14-epic13-short-smoke. Branch: codex/short-connected-phone-smoke. The stage started from reviewed F5 ce00961, then merged reviewed experimental F6 at 8c14f67. Plan checkpoint 3e07c3c; implementation ae12876; independent-review fix a7c18e5.

Independent review found that physical Release tests could have enabled capture while host isolation was Debug-only. The fix compiles enablement only under DEBUG on a physical device and makes the operator command explicitly Debug. Release is not a supported hosted-smoke configuration. Extra checks prevent starting recording after the internal deadline or accepting a polling success after cancellation/deadline expiry.

| Check | Actual result / retained local evidence |
| --- | --- |
| Physical iOS SDK Debug build-for-testing, final reviewed source | Passed; /private/tmp/stream14-short-smoke-ios-build-tests-4.log |
| Simulator normal-mode regression | Eight hosted tests executed successfully, one physical smoke skipped, two accessibility UI tests passed; /private/tmp/stream14-short-smoke-regression.xcresult and .log |
| Explicit short-smoke flag on Simulator | Two configuration tests executed successfully, physical smoke skipped; /private/tmp/stream14-short-smoke-opt-in-simulator.xcresult |
| Final Debug gate/deadline recheck with flag on Simulator | Two configuration tests executed successfully, physical smoke skipped; /private/tmp/stream14-short-smoke-review-recheck.xcresult and .log |
| Ordinary unsigned Release app build | Passed; /private/tmp/stream14-short-smoke-release-app-build.log |
| Attempted Release build-for-testing | Unsupported existing configuration: app module lacks -enable-testing for the project's @testable imports. Failed log retained at /private/tmp/stream14-short-smoke-ios-release-build-tests.log; no project setting was changed to make Release tests work |
| Focused documentation links/fences, shell-template syntax, git diff --check | Passed; no documented command was executed for the syntax check |

No phone was installed, launched or recorded. Actual physical duration, camera/file marker checks, audio audibility and physical synchronization remain pending. The one-minute test target and 90-second runner watchdog are design limits, not measured physical performance or a guarantee that installation fits the owner’s total five-minute visit.

The ShortPhoneSmokeTests selector is supported only after permission setup, normal Debug signing and branding. The source host deliberately does not load the saved overlay URL/preferences or construct Google's SDK driver under its opt-in flag; it never signs out or revokes the owner's authorization. Normal app/Release paths retain their usual configuration. The fixture contains no network resources and the test session uses independent empty-URL/nonpersisting configuration.

## First connected attempt and selector correction — 2026-11-08

Signed Debug app and embedded test signature checks pass. The first phone invocation matched zero tests because its bare Swift Testing method filter omitted parentheses. It is not a pass; no camera clips were made. Off-phone Xcode enumeration verifies suite selector Stream14Tests/ShortPhoneSmokeTests selects exactly one method, twoProfilesRetainComposedOriginals(). Commands now use the suite selector. Require one executed/passed physical test and zero skips; installation/runtime and device assertions remain pending. See the attended-session card for operator actions and the next five-minute visit.
