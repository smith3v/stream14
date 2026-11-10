# Full-app qualification report

Copy this template to a private evidence location. Keep raw media, account/event
identity, network identifiers and tester details out of Git/issues. Public reports
contain sanitized numeric summaries and a private evidence reference only.

Build/version/commit: pending. TestFlight-installed identity: pending.
Device/OS/profile/orientation: pending. Instrumentation schema: pending.
Owner agreement for exact run/time (required above 15 minutes): pending.
Run duration, clock coverage/count, first/last checkpoint: pending.
Power source/charge state, mount/case, brightness, airflow, ambient temperature:
pending. Start without external cooling. Network type/quality, bandwidth/latency,
loss/change timings, receiver device/player latency: pending. Do not publish SSIDs,
IP addresses, private service/account identifiers or original file paths.

Keep app foreground/unlocked and explicitly start the intended local rehearsal or
confirmed unlisted event. At the beginning and end, place both hands in the camera
view and make one sharp visible/audible clap. Retain both markers in the original
file and the independent receiver recording. Record visual-contact frame time,
audio transient time, estimated offset and uncertainty separately for each end.
Track endpoints alone do not prove A/V sync; missing markers mean pending. Receiver
latency is different from audio/video offset. Note operator reaction/clock limits.

After stop, use the recording's **Load qualification summary**, then **Export
qualification summary**. Share only intentionally; inspect JSON for allowed fields.
Export the original movie separately to private local Files. Keep originals after
recovery or failed analysis. Run native read-only analysis on that original:

```sh
xcrun swiftc -O -swift-version 6 -module-cache-path /private/tmp/stream14-analysis-cache \
  -parse-as-library Tools/qualification/Analyze.swift -o /private/tmp/stream14-analyze
/private/tmp/stream14-analyze /private/path/to/original.mp4 > /private/path/to/analysis.json
```

The tool streams compressed track PTS and independently decodes every video/audio
buffer. `finishedReading` must be true and invalid timestamp counts must be zero for all
tracks; exit 2 retains partial JSON but means analysis failed. Failure is unreadable or
incomplete, never a repaired/complete claim. Compare PTS gaps/estimated 30 Hz missing
intervals with measured raw encoder rejections and file/transport counters; do not
sum them as independent losses. Audio sample units differ between compressed and
decoded buffers. Empty native boundary-marker buffers are counted separately;
batched AAC/PCM timing is expanded using native sample timing, not buffer spacing. It never remuxes, transcodes or edits the original. Analysis is
private; terminal errors deliberately omit file paths and SDK descriptions.

### Physical marker inspection after the phone visit

The operator can now inspect two short windows using a separate native Mac tool.
The owner only needs to make the visible/audible beginning/end claps during an
agreed recording and export the original afterward; the operator does the
timestamp analysis on the laptop. No camera or microphone is opened by this tool.
First locate both claps with ordinary playback. Choose nonoverlapping windows
of **at most two seconds each** that include the last separated-hand frame, first
contact frame and matching sound. Times are asset presentation seconds, including
any nonzero track start. The following times are examples, not measured markers:

```sh
xcrun swiftc -O -swift-version 6 -module-cache-path /private/tmp/stream14-marker-cache \
  -parse-as-library Tools/qualification/Markers.swift -o /private/tmp/stream14-markers
/private/tmp/stream14-markers inspect /private/path/to/original.mp4 \
  /private/path/to/new-inspection 3 5 123 125
```

The destination must not already exist; its parent must exist. The tool creates
an owner-only directory, JPEG contact sheet (`index.html`), waveform SVGs and JSON,
`manifest.json` and a selection template. These are private media, not issue/PR
attachments. Every frame label uses its actual decoded PTS; each per-channel
waveform bin retains first/last/peak sample PTS, min/max and sample count over
at most about one millisecond. The SVG amplitude is normalized separately per
channel, not dB. Inspect the original sound and the exact waveform bins rather
than treating the loudest peak as an automatically detected clap. Sample rate,
frame interval, occlusion/motion blur, acoustic distance and ambiguous sound all
affect uncertainty. No priming, latency or acoustic-delay correction is guessed.

Copy `selections-template.json` to a new private selection file. For each marker,
set a zero-based audio channel, the actual PTS of the last clearly separated-hand
and first contact frames, and conservative nonzero audio-transient bounds from
the waveform. Use the exact manifest frame numbers, not rounded player times.
Leave all three fields absent/null for a missing or ambiguous marker. For example
only (replace every selected time with inspected evidence):

```json
{"schema":1,"markers":[
  {"name":"beginning","channel":0,
   "video":{"lower":3.466666666666667,"upper":3.5},
   "audio":{"lower":3.5795,"upper":3.5805}},
  {"name":"end"}
]}
```

```sh
umask 077
/private/tmp/stream14-markers measure /private/path/to/new-inspection/manifest.json \
  /private/path/to/selections.json > /private/path/to/marker-intervals.json
```

The result uses **audio minus video**, positive when audio is later. For visual
bracket `[v0,v1]` and audio bracket `[a0,a1]`, the conservative offset interval is
`[a0-v1,a1-v0]`; midpoint and half-range describe that interval, not a statistical
confidence estimate. The tool validates frame choices and decoded PCM coverage,
but cannot verify that a human selected the right physical clap. It never assigns
a physical pass. An independently reviewed interval wholly inside ±100 ms can
support only that marker's sync requirement; an interval crossing a threshold
or an ambiguous/missing marker stays indeterminate/pending. Report beginning/end
and original/receiver separately. Two markers in a short clip do not prove A7.

The input is SHA-256 checked before and after extraction and never modified.
Failure emits a safe fixed code and returns nonzero. Partial private output is
retained, but no successful manifest is produced unless both requested windows
decode and the input hash is unchanged. This is bounded window inspection, not
the full-file readability check above. Native framework decoder allocations are
outside this tool's application-owned bounds; unsupported layouts or excessive
dimensions/rates/counts fail rather than silently downsampling timing evidence.

For overhead: with an agreed short 13 mini run and fixed scene/profile/power/network,
compare the candidate's Instruments Time Profiler/Allocations/energy trace with the
same build's diagnostic task disabled in an explicitly identified experimental
build. Record observer task duration, lock/callback delay, allocations, process and
WebKit/GPU charges, checkpoint file size and count over time, counter coverage and
measurement uncertainty. An experiment switch is not a delivered-build route. The
shipping build always measures. Restore the shipping candidate for acceptance.
Do not infer overhead or stability from Simulator or model fixtures.

| Gate | Required evidence | Result / private evidence / limits |
| --- | --- | --- |
| A1 overlay | Physical 13 mini exact full-canvas alpha/text/logos/reload, preview/file/receiver comparison, no controls in output | pending |
| A2 smooth video | Explicitly agreed 30-minute run, <1% measured pipeline drops, no repeated >=500ms stalls, memory/queue evidence and coverage | pending |
| A3 YouTube | Exact selected channel/event/visibility, confirmed start/end, second-device A/V, no implicit publishing | pending |
| A4 independence | Startup rejection, >=2-minute loss/retry exhaustion/remote end, uninterrupted original A/V, same-event resume, overlay 10s hide/recovery | pending |
| A5 recovery | Multiple physical termination points before/after fragments, retained originals, separate copies, measured lost tail, playback/export | pending |
| A6 failure UX | Permissions/event/auth/quota/overlay/write failure/ambiguous end, distinct actionable states | pending |
| A7 long event | Separately agreed powered three-hour 1080p30 run on 13 mini, A2 targets, physical beginning/end sync <=100ms with uncertainty | pending |
| A8 devices/UI | Physical 13 mini and available 15/17/Pro, 720p, audio interruptions/lock/background/VoiceOver/large text/export/delete cancellation | pending |
| A9 TestFlight | Actual later full-app uploaded/installed identity and regression, privacy declarations/notices/policy verification | pending |

Measured pipeline drops: pending. Pre-boundary/unexposed drops: unknown.
Raw/file/transport high water and internal queue limits: pending/unknown.
Charged footprint first/last/peak/trend/coverage: pending. Resident mappings:
pending (separate measure). Child/GPU/media charge coverage: pending.
Original/receiver first/end offsets and uncertainties: pending.
Independent review, unresolved failures and owner acceptance: pending.
