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
| A7 long event | Uninterrupted powered one-hour 1080p30 broadcast and local recording on 13 mini, A2 targets, physical beginning/end sync ≤100 ms with uncertainty | pending |
| A8 devices/UI | Physical 13 mini and available 15/17/Pro, 720p, audio interruptions/lock/background/VoiceOver/large text/export/delete cancellation | pending |
| A9 TestFlight | Actual later full-app uploaded/installed identity and regression, privacy declarations/notices/policy verification | pending |

Measured pipeline drops: pending. Pre-boundary/unexposed drops: unknown.
Raw/file/transport high water and internal queue limits: pending/unknown.
Charged footprint first/last/peak/trend/coverage: pending. Resident mappings:
pending (separate measure). Child/GPU/media charge coverage: pending.
Original/receiver first/end offsets and uncertainties: pending.
Independent review, unresolved failures and owner acceptance: pending.
