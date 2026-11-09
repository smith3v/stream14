# F11 recording review and recovery handoff

Issue #24 extends the actual shared compressed writer, not only the earlier native
feasibility probe. This stage is stacked on the owner-coordinated F9/F10 work and
must be independently reviewed before root publishes its PR. No automatic merge
is authorized; physical A5 acceptance remains open.

## Ownership and retained artifacts

- `ExperimentSample` remains the small Codable manifest in Application Support /
  MediaExperiments. Optional schema version/profile/duration/byte count, readable
  start review, and per-attempt UUID/status/duration preserve legacy decoding.
- Reconciliation scans UUID originals, metadata-only entries and recovery copies.
  Missing/malformed metadata never hides UUID media; malformed originals retain
  their bytes while `.review.json` stores review. Inactive pending is interrupted.
- `RecordingRecovery` is the actor owning native AVAssetReader work. Launch checks
  duration and one decoded audio/video sample; it does not scan a three-hour file
  or claim full integrity. Explicit passthrough export makes another MP4, never
  repairs/mutates the original, and checks the exported start. No encoder is added.
- Attempt metadata is written before export; pending attempts become failed on
  relaunch. Partial files remain visible/exportable. Explicit deletion supports an
  individual copy or selected recording group, with status metadata last. No
  background publishing, automatic deletion, Photos permission or storage polling.
- The writer's fragment interval is ten seconds before `startWriting`. AAC packet
  duration/priming and the one encoder's ownership remain unchanged.

## Production-source Mac experiment

The source-copy builder extracts the unchanged production `SharedMediaCodec` body,
unchanged `LocalRecorder`, and native profile settings, omitting unrelated
HaishinKit actor wiring. It reuses the pinned dependency's existing CMSampleBuffer
Sendable declaration for identical compiler semantics; no new app unchecked
annotation is introduced. Synthetic fullHD BGRA frames and a 440 Hz 44.1 kHz stereo
tone pass through the actual VideoToolbox/AAC codec and compressed writer.

```sh
python3 Tools/fragment-recovery/build-app-probe.py \
  /private/tmp/stream14-f11-app-probe-new \
  /private/tmp/stream14-f7-packages/checkouts/HaishinKit.swift
python3 Tools/fragment-recovery/run.py \
  /private/tmp/stream14-f11-app-probe-new/probe \
  /private/tmp/stream14-f11-app-run-new --app-writer
```

Both output directories must be new. The parent SIGKILLs only its own un-reaped
synthetic child; it never accesses a phone/camera/user recording. Native codec
services need normal unsandboxed Mac execution. The generation/read/export work
is bounded by the harness timeout; artifacts are retained, never cleaned up.

Measured production-source run: `/private/tmp/stream14-f11-app-native-run2`, detailed
`results.json`, stdout `/private/tmp/stream14-f11-app-native-run2.log`; compiler log
`/private/tmp/stream14-f11-app-probe3-build.log`. macOS 27.2 / Swift 6.

| Case | Original bytes | Decoded video | Decoded original PCM | Decoded recovery PCM | Duration |
| --- | ---: | ---: | ---: | ---: | ---: |
| Normal 25 s | 676,703 | 750 | 1,102,500 | 1,102,500 | 25 s |
| SIGKILL before first fragment at 5 s | 82,066 | Unreadable | Unreadable | Export fails | Unknown |
| SIGKILL after appending 25 s | 644,350 | 600 | 880,576 | 880,530 | 20 s |
| SIGKILL at finish request after 25 s | 644,350 | 600 | 880,576 | 880,530 | 20 s |

The old probe's strict equality of decoded audio counts failed for these truncated
production files. Both complete readers succeed, encoded per-track byte counts and
SHA-256 match exactly, video counts match, and every original whole-file SHA-256
is unchanged. Native passthrough clips 46 PCM frames (~1.04 ms) at the incomplete
tail; it does not re-encode. The app-path validator permits only nonnegative audio
trimming of at most one 1024-frame AAC packet (the actual codec packet contract),
with the corresponding 44.1 kHz endpoint bound. Normal stop and video retain strict
decoded-count equality; compressed byte hashes always retain exact equality. This
is explicitly useful-prefix recovery, not a lossless or measured A/V sync claim.

The updated validator was run against all four retained actual results, rechecking
original file hashes:

```sh
python3 Tools/fragment-recovery/run.py \
  /private/tmp/stream14-f11-app-probe3/probe \
  /private/tmp/stream14-f11-app-native-run2 --app-writer --validate-only
```

It reports 46 clipped frames for both interrupted readable cases and passes. The
finish-request marker precedes `LocalRecorder.finish()`; unlike the earlier
feasibility probe it cannot prove `finishWriting` itself had started. Keep this
race distinct from the deterministically post-fragment kill. The two clear
termination points (before first fragment, after fragments) provide the primary
native evidence. iOS execution may differ from macOS.

## Native validation

First focused simulator run passed 12 tests in 3 suites (RecordingRecoveryTests,
RecordingDeletionTests, LocalRecorderTests), including native production-source
clean-stop/passthrough recovery. Log `/private/tmp/stream14-f11-focused2.log`.
Final integrated validation and independent review are recorded below when ready.

## Remaining owner/device evidence

No physical device, camera or YouTube session was used. Actual app process death,
launch reconciliation, playback/export UI, fragment loss and A5 need physical
13 mini evidence. Do not reuse old mono Mac probe/device recorder results as these
checks. Root owns the shared five-minute total routine-phone budget; additional
qualification needs a separate explicit agreement. Never reset/uninstall the app
or delete user recordings for this test. Preserve expendable originals/copies.

### Exact production recovery-helper check

The source-copy builder also compiles `RecordingRecovery.swift` unchanged. On the
retained synthetic post-fragment original, the exact app actor's `app-review`
reported a readable 20-second start and `app-recover` produced another readable
20-second separate file. The pre-first-fragment `app-review` failed honestly with
AVFoundation -11829. All four original SHA-256 values still matched afterwards.
Logs: `/private/tmp/stream14-f11-app-helper-{review,recover,before}.log`; distinct
copy: `/private/tmp/stream14-f11-app-native-run2/after.app-helper.recovered.mp4`.
These commands perform reads/remux only, without another encode experiment:

```sh
/private/tmp/stream14-f11-app-probe4/probe app-review \
  /private/tmp/stream14-f11-app-native-run2/after.original.mp4
/private/tmp/stream14-f11-app-probe4/probe app-recover \
  /private/tmp/stream14-f11-app-native-run2/after.original.mp4 \
  /private/tmp/stream14-f11-app-native-run2/another-new-recovered-copy.mp4
/private/tmp/stream14-f11-app-probe4/probe app-review \
  /private/tmp/stream14-f11-app-native-run2/before.original.mp4
```

The last command is expected to fail. Final F10 UI integration, the added 13th
selective-copy deletion test, a final affected-suite/Release rerun and independent
review are still pending. The existing first 12-test pass and Release pass preceded
that selective deletion test and the final refresh predicate, which now reinspects
incomplete originals on each library reconciliation instead of trusting an older
readable-start review forever. No process is left running at this checkpoint.

## Independent review fixes — source only, NOT RUN

Review of `52b52dd` found two material issues. The five-second nonjoining deadline
released MediaSession's recording reference while AVAssetWriter could still be
finalizing; listing then permitted inspection/recovery/deletion of a changing
original. Structural track/duration validation also incorrectly persisted the
stronger decoded-start `readable` claim.

The source fix adds the concrete `RecordingFinalization` owner. It retains one
UUID/task until the actual `LocalRecorder.finish()` returns; the UI timeout only
ends its waiter. A held finalizer blocks another writer and all library mutations,
and its UUID is excluded from both pre-read and post-await review decisions.
Original playback/export is disabled while protected. LocalRecorder also rejects
restart while its actual native finalization is in flight. Late completion releases
protection and permits exact native inspection; it does not promote the timed-out
record's original failed status to complete.

Structural writer validation now records duration/size with `review = nil`. Only
the exact `RecordingRecovery.inspect` path can persist `.readable`. Writer success
provenance and decoded-start review remain separate.

`RecordingFinalizationTests` adds held-operation/deadline coverage (one native task,
retained UUID after timeout, rejected replacement finalizer, late callback release),
MediaSession admission/protection/recovery policy, and persisted structural-review
semantics. These are authored deterministic tests, not executed results. Native
build/test/UI jobs are **NOT RUN** for this fix: automatic approval review was
blocked by account usage limits. No reroute or retry of that rejected native job
was attempted. The prior 13-test and Release results precede these changes and do
not validate them. Focused source re-review and native validation remain required.

## Final combined validation — 2026-11-09

Normal native approval succeeded after the earlier usage-related review failure.
That earlier blocked build was never rerouted or counted as a pass. The branch
normally inherited final F10 `01d4c48` / main `f454e9b`, reviewed fork `497f742`,
and the reviewed monitor correction `afaa5ae` (`78d24b7`, `80aa31c` merges).
The one F10 EOF blank-line cleanup was also retained. Independent focused source
re-review of `7d3d846` resolved both P1/P2 findings with no further material issue.

Fresh checks of these fixes and prerequisites, not the older source snapshot:

- Focused native tests: **16 passed / 4 suites**, 11.712-second test body. Includes
  held-finalizer deadline/ownership, admission/late callback, structural-review
  persistence, retained originals/copies and native writer/passthrough behavior.
  Log `/private/tmp/stream14-f11-review-fixes-focused.log`; result bundle
  `/private/tmp/stream14-f11-tests/Logs/Test/Test-Stream14-2026.11.09_07-18-47-+0100.xcresult`.
- Final unsigned Release: **BUILD SUCCEEDED** on final source `5500c34`.
  Log `/private/tmp/stream14-f11-final-release.log`.
- Actual native recovery UI: **2/2 passed** on the dedicated iPhone 13 mini / iOS
  27.2 simulator. Successful recovery (99.494 seconds) creates another UUID copy,
  preserves interrupted original provenance through relaunch, opens native playback
  and the export sheet's Save to Files option, exercises Cancel then confirms
  deletion of only that new copy. Failure flow (18.749 seconds) keeps the unreadable
  pre-fragment original exportable with an honest failed attempt.
  Log `/private/tmp/stream14-f11-ui-recovery3.log`; result bundle
  `/private/tmp/stream14-f11-ui-recovery3.xcresult`.
- Both seeded original MP4 files remained byte-identical to their retained
  synthetic sources after every UI attempt and the confirmed copy deletion.
  Log `/private/tmp/stream14-f11-ui-original-preservation.log`.
- Two actual UI screenshots were exported and visually inspected under
  `/private/tmp/stream14-f11-ui-evidence`, with `manifest.json` mapping filenames
  to the original-retained and distinct-recovery-copy views. Copy duration, tail
  warning, playback/export/delete controls and original retention are legible.

The two earlier UI success-path runs stopped at native contrast diagnostics for
partially clipped text; their other passing steps are not substituted for the
final full-flow pass. Recovery actions now use the same descriptive, minimum
44-point icon controls as originals. Repeated metadata fields have per-recording
or per-copy identifiers. The unchanged independently reviewed F10 audit helper
then proved three clipped static-text frames outside the nav/tab viewport before
and during the callback. All visible text, controls and other audit types retain
their checks. This is not an unfiltered audit or a physical VoiceOver claim.

### Reproduce the native checks

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,id=E0ABEB8B-B5A5-4FC9-AD6A-FA6A5908A78C' \
  -derivedDataPath /private/tmp/stream14-f11-tests \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages \
  -disableAutomaticPackageResolution \
  -only-testing:Stream14Tests/RecordingFinalizationTests \
  -only-testing:Stream14Tests/RecordingRecoveryTests \
  -only-testing:Stream14Tests/RecordingDeletionTests \
  -only-testing:Stream14Tests/LocalRecorderTests test

xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,id=E0ABEB8B-B5A5-4FC9-AD6A-FA6A5908A78C' \
  -derivedDataPath /private/tmp/stream14-f11-tests \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages \
  -disableAutomaticPackageResolution -only-testing:Stream14Tests test

xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/stream14-f11-release \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

For recovery UI, build normally with `build-for-testing` first, which brands/signs
its purple runner. Use a disposable simulator with the app installed; never reset,
uninstall or delete originals to prepare this test. Seed only expendable synthetic
files with `Tools/fragment-recovery/seed-simulator.py`, passing simulator UUID,
readable post-fragment file, unreadable pre-fragment file and a new JSON output.
It adds fresh UUID copies and never removes existing artifacts. Merge that JSON
into the generated `Stream14UITests.EnvironmentVariables` in a **copy** of the
built `.xctestrun`, stored alongside the original in Build/Products so relative
product paths resolve. The existing private test configuration is
`/private/tmp/stream14-f11-tests/Build/Products/Stream14-recovery-ui.xctestrun`.

```sh
xcodebuild test-without-building \
  -xctestrun /private/tmp/stream14-f11-tests/Build/Products/Stream14-recovery-ui.xctestrun \
  -destination 'platform=iOS Simulator,id=E0ABEB8B-B5A5-4FC9-AD6A-FA6A5908A78C' \
  -parallel-testing-enabled NO \
  -only-testing:Stream14UITests/SetupScreenTests/testSeparateRecoveryPersistsAndCopyDeletionKeepsOriginal \
  -only-testing:Stream14UITests/SetupScreenTests/testUnreadableRecoveryFailureRetainsOriginalExportAndFailedAttempt \
  -resultBundlePath /private/tmp/stream14-f11-ui-another-new-run.xcresult
```

Final full hosted-suite result is recorded below. Root owns the
reviewed PR publication into main. The stage references issue #24 without closing
it: physical forced termination/relaunch/playback/export, measured actual-phone
fragment loss and A5 remain pending. No phone, camera, microphone capture or live
YouTube/RTMPS call was used by this stage. The owner's later phone budget remains
root-coordinated. The older synthetic process-termination evidence above applies
to that exact retained source snapshot; lifecycle-only ownership fixes were then
checked with the fresh tests above, not a repeated kill qualification.

### Full hosted regression and final handoff

Full hosted native regression on the final source **passed**: XCResult reports
**160 passed, 8 skipped, 0 failed (168 total)** across 28 suites; test body
83.443 seconds. The skipped cases require opt-in physical-device/private-receiver
execution and were not enabled. Log `/private/tmp/stream14-f11-final-hosted.log`,
parsed native summary `/private/tmp/stream14-f11-final-hosted-summary.json`, result
bundle `/private/tmp/stream14-f11-tests/Logs/Test/Test-Stream14-2026.11.09_07-28-57-+0100.xcresult`.
The Swift Testing line's “168 tests” includes those eight skipped tests; it must
not be reported as 168 executed passes. Fresh focused, full hosted, Release and
UI processes all completed and were reaped before handoff. Local links and full
diff whitespace checks passed. The PR body is prepared privately at
`/private/tmp/stream14-f11-pr-body.md`; root owns publication into main and the
remaining physical acceptance. No issue closure or automatic merge is implied.
