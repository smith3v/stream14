# Required YouTube Monitor Transition Implementation Plan

**Goal:** Honor the existing event's required monitor phase under one explicit Go Live confirmation.

**Architecture:** Extend the existing decoded broadcast content details and BroadcastSession startup loop. Reuse its durable mutation UUID, outstanding-request barrier, cancellation/account fences and bounded startup deadline; no new user mode, event settings or resources.

**Tech Stack:** Swift 6, Foundation Codable, Swift Testing, native Xcode.

---

### Task 1: Decode and preserve the monitor setting

**Prompt:** Add optional `monitorStream.enableMonitorStream` to Stream14/YouTube/YouTubeModels.swift. Missing/null remains unknown: Google's true default is an insert default, not proof of an omitted list value. Refuse a manual startup with unknown setting before publishing, and freeze the known setting with confirmation. Add decoder coverage for true/false/missing/null and malformed types.

### Task 2: Add the required internal phase

**Prompt:** In Stream14/Broadcast/BroadcastSession.swift, after active ingestion, send testing once only when enabled and ready. Await an authoritative testing read before sending live once. Existing testing skips the testing POST; testStarting waits. Disabled monitor goes directly live; auto-start still only polls. Journal every mutation before POST. Timeout/cancellation/relaunch retain uncertainty; no blind mutation retry or implicit resume.

### Task 3: Validate lifecycle and document

**Prompt:** Extend Stream14Tests/BroadcastSessionTests.swift fixtures for both monitor settings, intermediate states, uncertain/lost/late testing responses, timeout/relaunch, cancellation, End and account changes. Use isolated Simulator native focused tests then relevant full regression and unsigned Release build with /private/tmp/stream14-transport-fix-packages and -disableAutomaticPackageResolution. Record exact results and material remaining limits. Update section 5 of docs/2026-11-01-stream14-design.md with official resource and migration sources. Run git diff --check. Commit focused checkpoints. Parent arranges independent full-diff review, fixes and PR into main; no publishing/merging or device/API/media actions in this stage.

## Result and fresh-agent handoff — 2026-11-08

Based on main `f454e9b89e4fd30ac1d41672507ed88a15723004`, focused branch
`codex/fix-youtube-monitor-transition`. The public fixture-facing entry point
`YouTubeBinding.prepareConfirmed` now accepts optional `expectedMonitorEnabled`;
BroadcastSession passes its authoritative resolved setting, and F5 checks it on
both pre-insert/pre-bind reads. Direct F5 fixture callers can omit the constraint.
The production manual path requires a known monitor setting before entering F5.
`YouTubeBroadcast.ContentDetails.MonitorStream` preserves the optional decoded
boolean; `YouTubeBroadcastTransition` adds `testing`, compatible with old journals.
No package, signing, UI mode, event setting or media ownership change.

Validation used Xcode 27.2/iOS 27.2 and isolated iPhone 13 mini Simulator
`8B9BE889-6F76-400A-837C-8C50A4226D5A` (Stream14 Monitor Protocol). Commands ran
from the correction checkout, with immutable reviewed packages and no phone/API
mutations:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,id=8B9BE889-6F76-400A-837C-8C50A4226D5A' \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -derivedDataPath /private/tmp/stream14-monitor-transition-derived \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -resultBundlePath /private/tmp/stream14-monitor-transition-unit-final.xcresult \
  -only-testing:Stream14Tests test
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -derivedDataPath /private/tmp/stream14-monitor-transition-release \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

Final unit regression: **TEST SUCCEEDED**, 159 tests in 26 suites, 73.254 seconds
of test execution. Opt-in device/private receiver/reference-page cases remained
skipped; no device or live API evidence is inferred. Release: **BUILD SUCCEEDED**.
Logs: `/private/tmp/stream14-monitor-transition-unit-final.log` and
`/private/tmp/stream14-monitor-transition-release.log`. Earlier focused pre-review
run passed 44 BroadcastSession tests; final unit run includes both review-fix
fixtures. `git diff --check` passed.

Independent review inspected the actual full diff/source against f454e9b, then
focused re-reviewed `0a10b41`. It identified a material pre-binding setting race;
this was fixed by enforcing the resolved monitor value on F5's authoritative
pre-mutation reads. Integration fixtures now prove unknown/changed second reads
send zero POSTs, while a post-create monitor change prevents bind and retains the
known created ID. Re-review found no remaining material source findings. All
validation jobs finished; no PR was published or merged by the implementation
agent. Parent owns reviewed PR preparation and attended service acceptance.

Required remaining evidence: actual signed-phone/YouTube manual true/false and
auto-start acceptance, receiver A/V, normal end, physical cancellation and longer
qualification under separately agreed limits. Routine phone budget remains five
minutes total; this stage used none. No local recordings were removed.


Native result-bundle verification reports **151 passed, eight explicit opt-in skips, zero failed** (159 total). The eight skips are not counted as executed passes. The implementation and pre-binding race fix received independent actual-source review with no remaining material findings.
