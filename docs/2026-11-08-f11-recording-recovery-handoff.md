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
