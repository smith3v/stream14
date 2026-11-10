# Default YouTube Stream Reuse Implementation Plan

**Goal:** Let the owner use YouTube's existing default stream key without assigning a separate key to each scheduled event.

**Architecture:** Keep the existing selected-event, channel, profile, inactive-ingestion, RTMPS, account-generation and durable mutation guards. Remove the separate all-events dedication scan; selected-event readback and existing reconnect rules remain unchanged. Concurrent use of a reusable key is an explicitly deferred risk, not an ownership guarantee.

**Tech Stack:** Swift 6, native YouTube REST client, Swift Testing, Xcode shared Stream14 scheme.

---

### Task 1: Apply the owner's minimal-configuration decision

**Prompt:**
The owner tried two scheduled events using the same default key and received the app's unfinished-event dedication error before RTMPS upload. YouTube supports one stream bound to multiple broadcasts. Alternatives were requiring new dedicated keys, implementing cross-event coordination now, or retaining existing selected-event safety and reporting concurrent use for later mitigation. The owner explicitly chose the third: “I do not expect a conflicting active stream for now. Let's report it as a potential issue for the future mitigation.” This supersedes the old F5 all-unfinished-events exclusion. Do not create a new key, change another event or add a replacement coordination scan.

### Task 2: Implement the narrow existing-binding change

**Prompt:**
In Stream14/YouTube/YouTubeBinding.swift remove calls to the dedication scan for existing preparation, app-created binding readback and explicit resume, and remove the now-unreachable scan/errors and its unused all-broadcast client method. Preserve native stream activity/health/reuse/profile validation, selected-event/by-ID readback, secure destination validation and all intent/mutation handling. Keep live supervision/reconnect behavior unchanged. Update YouTubeBindingTests to prove shared/default-key reuse sends only selected-event/stream reads and no remote writes or all-events scan. Preserve active stream, missing data, profile, auto-stop, channel, ambiguous mutation and stale-generation failures. Document the future concurrency risk in [issue #65](https://github.com/smith3v/stream14/issues/65) rather than inventing a current incident.

### Task 3: Validate and independently review

**Prompt:**
Run affected native binding/coordinator/client suites and an unsigned Release build, with pinned warmed packages, new result paths and an owned Simulator. No phone, camera, provider call or publishing. Update canonical F5/F8 wording, full plan and owner setup/test instructions to match the default-key workflow and deferred limitation. Have a new independent agent inspect actual full diff against main, requirements and validation. Resolve material findings, record exact results/limits and commit; root publishes the PR into main. No version bump or automatic merge.


## Validation checkpoint

Source `625df2a` runs against main `ea90bd3`, without the unmerged interface or
preview-recovery changes. The retained pinned HaishinKit checkout was verified at
`497f742c5f2c04cf3ca085378e660a273e351788`. Xcode 27.2 (27B52), iPhone 13 mini
Simulator iOS 27.2, shared Stream14 scheme, separate owned E0 device.

The authoritative native result reports **87 executed passes, zero failures/skips,
three suites**: YouTubeBindingTests, YouTubeClientTests and BroadcastSessionTests.
Swift Testing body: 4.583 seconds; entire result invocation: 156.494 seconds.
Result `/private/tmp/stream14-default-stream-focused.xcresult`, log
`/private/tmp/stream14-default-stream-focused.log`, actual summary
`/private/tmp/stream14-default-stream-test-summary.json`. No earlier failed run
is replaced or hidden; this first focused run passed. Owned E0 was shut down with
fixtures retained after the test process finished; D6 and the phone were untouched.

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination 'platform=iOS Simulator,id=E0ABEB8B-B5A5-4FC9-AD6A-FA6A5908A78C' \
  -derivedDataPath /private/tmp/stream14-default-stream-build \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -only-testing:Stream14Tests/YouTubeBindingTests \
  -only-testing:Stream14Tests/YouTubeClientTests \
  -only-testing:Stream14Tests/BroadcastSessionTests \
  -resultBundlePath /private/tmp/a-new-default-stream-result.xcresult test
```

A separate agent inspected the actual full diff against main, selected-event/
ingestion guards, mutation journals, unchanged coordinator/media and the latest
owner-approved deferral. It found no material issues at `625df2a`. The ordinary unsigned Release build
then exited 0 with **BUILD SUCCEEDED**; log
`/private/tmp/stream14-default-stream-release.log`. It uses generic iOS destination,
Release configuration, the same warmed pinned packages, a separate derived-data
path and `CODE_SIGNING_ALLOWED=NO`. This is build evidence, not distribution
validation or a new TestFlight binary. Final changes after the tested source are
documentation only; no further native run is needed for that handoff.
No physical camera, provider request or publication was used; real default-key
YouTube reception and remaining A1–A9 qualification stay pending. The already
installed TestFlight 0.3 (4) is not replaced by this source branch.


Final focused independent review also inspected the actual native summary/logs,
Release success and documentation-only handoff: no material findings. All 86
changed-document local links resolved, `git diff --check` passed, and current main
was re-fetched at `ea90bd3` before handoff. Root owns publication; no automatic
merge, phone operation or replacement distribution is claimed.


## Combined integration checkpoint — 2026-11-10

The earlier validation checkpoint is historical. After the owner merged PR64,
normal merge `1cf40ab` integrates main `db70834`, retaining preview-only automatic
foreground recovery and the default-key correction. Three documentation append/
wording conflicts were resolved without runtime edits. A fresh independent actual-
source/merge review found no material findings. The combined six affected native
suites passed 107 tests, zero failures/skips; result
`/private/tmp/stream14-preview-default-focused.xcresult`, authoritative summary
`/private/tmp/stream14-preview-default-test-summary.json`. Unsigned generic-iOS Release validation also exited 0 with BUILD SUCCEEDED;
log `/private/tmp/stream14-preview-default-release.log`. Final independent review
verified actual tests, Release and checkpoints without material findings. All 88 changed-document local links resolve and diff whitespace passes.

The phone's current installation is Development source `625df2a`, not this combined
source or a new TestFlight upload. Its successful broadcast evidence does not qualify
preview recovery. The combined preview fix still needs physical app-switch testing;
no phone operation/capture/provider request occurred in this stage.
