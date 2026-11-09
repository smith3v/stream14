# F12 qualification diagnostics handoff

Issue #25 implements private instrumentation in the actual app, independent of
hosted tests. This is implementation evidence; physical overhead, installed-app
export, A/V markers and long-run qualification remain pending.

## Ownership and data contract

`QualificationDiagnostics.swift` contains the typed report allowlist, fixed-size
transport aggregate and actor-owned checkpoint. `MediaSession` owns one ten-second
observer per encoded session, associated with its original recording. File stop or
failure freezes file counters while observation continues for a surviving upload.
Whole-session close cancels the observer after bounded transport shutdown and
saves the final snapshot; unresolved sends remain explicit in the report.
`QualificationExportView` reads only that report on explicit Load/Refresh and
shares a fixed-name JSON Transferable. A recording-row action does not share media,
authenticate, publish or request permissions. Selected-group deletion also removes
its qualification checkpoint; selective recovery-copy deletion preserves it.

Counter meanings and missing API/process coverage are specified in the canonical
specification's F12 section. The window is 120 observations; first/count/peaks/online
regression span the entire observed lifetime. One report is <=128 KiB and replaced
atomically. Unsupported footprint is absent. Reconnect counters have constant
storage and no retained publisher dictionary. Native writer/input and underlying
codec/socket internal queues are not claimed as observed. A stopped report is not
qualification or media-success evidence. Recheck the observation time/count.

No free-form error, service metadata, SDK description, URL, path/query/header,
credential/key, tester identity, account/channel/event identifier, wall clock or
media enters the schema. Unknown JSON keys are discarded on typed decode/export;
invalid enum values/corruption/oversize checkpoints fail with static UI feedback.
No telemetry service, dependency, storage polling or capacity threshold is added.

## Reproducible offline evidence

```sh
python3 Tools/qualification/model-probe.py /private/tmp/a-new-f12-model-directory
xcrun swiftc -O -swift-version 6 -module-cache-path /private/tmp/f12-analysis-cache \
  -parse-as-library Tools/qualification/Analyze.swift -o /private/tmp/f12-analyze
python3 Tools/qualification/verify-analysis.py /private/tmp/f12-analyze \
  /private/path/to/retained-synthetic.mp4 /private/path/to/new-analysis.json
```

Both output locations must be new when the tool requires it. The model probe
compiles the actual report/checkpoint source under `-O`; only numeric media boundary
types are stubbed. `/private/tmp/stream14-f12-model-final/exported-summary.json` was
inspected: 13,952 bytes, 120 recent observations, lifetime 1081/10800 seconds,
first elapsed 0, expected synthetic +2 bytes/second regression, no private strings.
This is a synthetic three-hour numeric timeline, not a three-hour media run.

The final native analyzer/verification read the retained F11 synthetic 20-second
recovered file without modifying it. All four compressed/decoded A/V traversals
finished; 600 compressed and decoded video frames, no invalid PTS, no >=500ms gaps.
The tool distinguishes empty native marker buffers and uses per-sample timing for
batched AAC/PCM, avoiding false audio gaps from buffer spacing. Its deliberate
secret-shaped missing-path failure emitted only safe enums/numbers; original SHA
was unchanged. Evidence: `/private/tmp/stream14-f12-native-analysis-final.json`,
`/private/tmp/stream14-f12-analyzer-build-final.log`. Native macOS sandbox codec
access can fail; these successful read-only checks used normal native codec service
access. A failed/incomplete read returns nonzero and may retain partial safe JSON.

First integration checkpoint: unsigned Release build passed in
`/private/tmp/stream14-f12-release.log`; 21 tests in five focused suites passed in
`/private/tmp/stream14-f12-tests.log` / `stream14-f12-focused.xcresult`.
Those precede final F11/current-main integration and two extra checkpoint rejection
assertions. Final affected results and independent review are recorded below.

Final source inherits F11 checkpoint `52b52dd` by normal merge and current main
`f454e9b89e4fd30ac1d41672507ed88a15723004`, including reviewed media fork
`497f742c5f2c04cf3ca085378e660a273e351788`. F11's compact recovery UI still required
its final rerun after automatic approval review could not complete due usage limits;
this handoff does not silently turn that unverified UI evidence into a pass.

The first Release bundle's privacy manifest retained SystemBootTime 35F9.1,
FileTimestamp C617.1 and UserDefaults CA92.1, tracking false, collected-data list
empty. The app exports only elapsed intervals between in-app events, never boot
or host epochs. Apple reason wording was checked against the official reference
linked in the specification. The final reviewed Release bundle again retained these declarations and compiled
both qualification source files through the ordinary Release target. F13 full
dependency/submission review remains distinct.

## Remaining acceptance

No phone, camera, microphone, live Google/YouTube, network publishing or recording
experiment was started for F12. Root owns the attended total routine-phone budget.
A short separately coordinated 13 mini overhead run and actual installed-app
Share/Files diagnostic artifact inspection remain pending. The report template
maps A1–A9 and specifies visible/audible beginning/end claps, original/receiver
measurements, power/network/ambient controls and uncertainty. Longer runs need the
owner's separate explicit agreement. Development harness cap remains 900 seconds;
normal user recording stays unlimited. No originals are automatically deleted.

## Independent review checkpoint

A separate agent inspected the actual full diff against current main and focused
F12 files. It identified a misplaced Transferable helper and displaced recording
status modifiers; both were fixed before the final integrated build. It also
identified that observation stopped when a healthy upload outlived its local file.
The observer now continues through that condition, freezes file counters and saves
a final report after bounded transport shutdown, including unresolved admitted
sends. A deterministic production-owner fixture covers completed/failed file
finalization, continued encoder/transport admissions, frozen file counts and
whole-session close. Focused re-review found all three findings resolved and no
further material issues. No other privacy/original-deletion/native timestamp
defects were found in that review.

## Final affected checks

- Current-main/new-pin hosted fixture pass: **27 tests in six suites**, including
  the continued-upload observer lifecycle for both completed and failed local
  files. Log `/private/tmp/stream14-f12-final-tests.log`, result
  `/private/tmp/stream14-f12-final-focused.xcresult`; xcodebuild exited 0.
- Unsigned reviewed Release build passed after the lifetime fix. Log
  `/private/tmp/stream14-f12-release-reviewed.log`; ordinary Release compilation
  included `QualificationDiagnostics.swift` and `QualificationExportView.swift`.
  The actual app bundle retained all three reason declarations, tracking false
  and an empty collected-data list.
- Offline Simulator UI test **testQualificationSummaryLoadsAndDeliberateShareOpens**
  passed in 28.198 seconds. It loaded a new expendable numeric checkpoint, opened
  Share and observed Save to Files, without camera, microphone or publishing.
  Log `/private/tmp/stream14-f12-ui-actual.log`, result
  `/private/tmp/stream14-f12-ui-actual.xcresult`. Screenshot visually inspected at
  `/private/tmp/stream14-f12-ui-attachments/EAD4FEA0-1511-4A9D-94C6-5693661E44EC.png`:
  summary actions and numeric checkpoint text fit the small portrait screen.
  This does not prove an actual saved phone-export artifact or physical VoiceOver.
- The shared scheme branded the runner `s14 UI Tests` with
  `Stream14UITestIcon60x60`; its normal Simulator signature verified with
  `codesign --verify --deep --strict`. No installed app was uninstalled/reset.
- The final native analysis verification again passed after changing the original
  hash check to stream 1 MiB chunks. All track timing/decode results remained
  healthy and the secret-shaped missing input did not appear in failure output.
  `/private/tmp/stream14-f12-native-analysis-reviewed.json` retains the result.
- `git diff --check` and Python AST syntax checks passed. No phone actions or
  long media experiments were performed. Per-session resource bounds are model
  and source evidence; on-device overhead remains pending.

The first attempt to configure UI testing assumed Xcode's newer xctestrun schema
and stopped before any test launched. It was corrected to the actual format and
the passing result above is the resulting run. An earlier ordinary-sandbox build
could not access Xcode caches/codec services; approved native checks supplied the
reported passes. None of these infrastructure failures was treated as media
acceptance or caused deletion of an original.


## Validated F11 parent integration — 2026-11-09

The source now normally merges final F11 `72069f4` via `926916b`. That parent has
its own 160 executed passes/eight opt-in skips, 16 focused checks, Release build
and two recovery UI passes; its former compact-UI rerun limit above is superseded
by that new parent evidence. Physical recovery/A5 limits remain unchanged.

F12 preserves the retained finalizer UUID, single native finish task and exact
decoded-start review semantics. Diagnostic Load/Share still reads only the separate
allowlisted checkpoint while the original is protected. A new optional historical
`nativeFinalizationOutstanding` flag discloses a retained native operation at the
checkpoint; observer `stopped` never means native completion. A late callback may
release protection/review but does not promote a failed original's status.
The parent merge and this focused adjustment were independently reviewed with no
material findings. New affected validation results:

- **14 tests in three affected suites passed** (5.032 seconds), covering observer
  lifetime, typed bounds/redaction/checkpoint recovery and held finalizer ownership.
  The new protected-checkpoint test passed in 0.049 seconds. Result:
  `/private/tmp/stream14-f12-parent-final-focused2.xcresult`; log
  `/private/tmp/stream14-f12-parent-final-tests2.log` (native process exited 0).
- **Unsigned Release passed** after the parent merge and final observer guard.
  `/private/tmp/stream14-f12-parent-final-release.log`. Actual bundle privacy reasons
  and helper syntax checks again passed; no new collection/tracking declaration.
- **The diagnostic Load/Share UI passed** in 36.116 seconds using a new failed-row
  fixture with observer stopped and native-finalization-outstanding at checkpoint.
  Save to Files was available. Result `/private/tmp/stream14-f12-parent-ui2.xcresult`,
  log `/private/tmp/stream14-f12-parent-ui2.log`. Screenshot inspected at
  `/private/tmp/stream14-f12-parent-ui-attachments/F086A6BC-6C22-46AD-B65A-A66A4CDBC70F.png`:
  the failed status, available numeric export and explicit outstanding-at-checkpoint
  warning fit the small screen. No movie was supplied/opened by this fixture.
- Runner branding/icon and normal Simulator signature were verified again. The
  independent review covered the parent ownership integration and optional flag
  (`1107eb8`) with no material findings. `4bfdc45` corrects only the fixture's active
  phase and stops the weak observer loop when its owner no longer exists.

The first new fixture run had 13 passes and one test setup failure: it had never
entered recording phase, so Stop correctly did nothing. The corrected fixture
uses the existing no-capture phase seam; the fresh passing run above supersedes it.
The first UI seed attempt stopped before launch because the owned Simulator was
shutdown; only that Simulator was booted, and a new result path retained both
attempts. No original was deleted/reset or overwritten. Physical overhead,
installed-phone diagnostic export, markers and long qualification remain pending.
