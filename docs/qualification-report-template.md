# Device qualification

Use the exact signed build under review. Record version/build, commit, install
route, device/OS, profile, result and coverage limits. An Xcode install,
Simulator test or private synthetic receiver exercises only the observed path.
Use iPhone 13 mini for minimum-device acceptance, with iPhone 15 and 17
families (including available Pro models) for compatibility.

## Short attended checks

Prepare account, permissions, install and fixtures on the Mac or ahead of the
visit when possible. Budget five minutes total per routine visit, including
setup and wrap-up. If setup takes the slot, record what was blocked. Agree on
private media capture, publishing, app lock or termination with the owner first.
Keep all originals and do not uninstall the app.

- **Local smoke:** in landscape, check moving preview, scoreboard and mic.
  Record about 20 seconds, speaking from the start, then mute and unmute.
  End and play the original: speech starts clearly, mute produces silence,
  overlay appears and app controls don't. Upload should stay idle. Use separate
  visits for both profiles and for zoom, rotation, Close camera, and return from
  an app switch.
- **Unlisted broadcast:** prepare an unused scheduled encoder event with
  auto-stop off and a second-device receiver. Check the expected channel,
  title and visibility. Confirm Go Live and observe Local saving, upload,
  YouTube-confirmed Live and picture/speech at the receiver. End, then verify
  remote completion and local file playback. If ending is uncertain, reconcile
  in the app or Studio; ensure someone takes responsibility for the remote event.
- **Picture-in-Picture:** with automatic PiP enabled, switch to Settings and
  return twice. Check continuous picture and speech at the receiver and in one
  local original. The overlay should pause while away and refresh after return.
  In separate short cases, interrupt the network to verify same-destination
  recovery without replacing the file, and close PiP while away to verify a
  new local file and automatic upload recovery on return. Confirm that an
  explicit streaming stop cancels any pending retry.
- **Relaunch recovery:** with the owner's agreement, terminate the app during an
  unlisted broadcast with Auto-stop off. Reopen Stream14 and use the resume
  control. Check that the same receiver gets picture and speech and the new
  recording is separate from the retained original. Repeat after explicitly
  stopping upload and verify that the old session offers no resume action.
- **Fault cases:** choose one scenario per visit from the acceptance gates.
  For recovery, test termination before and after a fragment; inspect retained
  originals and any separate copy. Keep the non-private scene and test event
  independent of real work.

## Endurance and analysis

Routine development recordings are capped at 15 minutes; obtain explicit
agreement for the 30-minute A2 or one-hour A7 run. Use a powered 13 mini in
landscape, foreground and unlocked, initially without external cooling. Use
stable Wi-Fi; report power, case/mount, brightness, ambient conditions and any
network, thermal or output changes. At 1080p30 nominally allow about 6.36 GB
per hour before variation and overhead; aim for about 9 GB free on the phone.

For A7, use 1080p30 with an Unlisted scheduled encoder event. Start the clock
once local saving, Live and receiver playback are confirmed. Make a sharp
visible/audible clap at each end with hands in frame. Keep both markers in the
original and a separate receiver recording. Check both outputs at 15-minute
intervals. Stop if storage or heat threatens the recording and report a partial
run. After the last marker plays at the receiver, confirm End and local save.

Export the original and **Load qualification summary → Export qualification
summary** separately from **Recordings**. Save receiver evidence, media and
diagnostics privately. Do not commit account/event identities, network
identifiers, private paths or media. Read-only analysis from the repository root:

```sh
xcrun swiftc -O -swift-version 6 -parse-as-library Tools/qualification/Analyze.swift \
  -o /tmp/stream14-analyze
/tmp/stream14-analyze /private/path/to/original.mp4 > /private/path/to/analysis.json
```

Require `finishedReading` and zero invalid timestamps across tracks; exit 2
means partial analysis. Compare file PTS gaps and estimated missing frame
intervals with raw encoder, file and transport counters; they measure different
boundaries and must not be summed. Lifetime counters and peaks lack a separate
30-minute snapshot. A file-only first-30-minute result needs a timestamp range
scan. Record loss/queue coverage and memory trend explicitly: process charged
footprint differs from resident mappings and excludes some WebKit/GPU/media
costs. Use full-run Instruments where needed. To quantify observer overhead,
compare the same short physical scenario with a separately identified build
with the diagnostic observer disabled. Neither a successful checkpoint nor a
stopped observer proves a complete recording.

For both the original and receiver, report beginning and end offsets from the
contact frame and audio transient, with uncertainty. Frame/track endpoints
and receiver latency are not lip sync; missing markers leave the gate open.

## Acceptance gates

| Gate | Required evidence |
| --- | --- |
| A1 Overlay | Exact full-canvas alpha, text and logos across reloads without white/blank flashes; compare physical preview, original and receiver, with no app controls in output. |
| A2 Smooth video | At least 30 measured minutes on 13 mini; <1% measured pipeline drops, no repeated stalls of 500 ms or more, and no monotonic memory or queue growth. State any coverage gaps. |
| A3 YouTube | Correct channel, event and visibility; real picture and audio at a second-device receiver; confirmed start/end and no publication from preparation. |
| A4 Independence | Startup rejection, loss of at least two minutes, and remote end leave a healthy original uninterrupted. Verify same-event recovery after the loss and automatic overlay hide/restore. Verify healthy upload continues through a post-start writer failure. |
| A5 Recovery | Multiple physical interruption/termination points; retained original, separate recovery copy when possible, measured lost tail, playback and export. |
| A6 Failure UX | Actionable, distinct permission, event, auth, quota/rate limit, overlay outage, disk-full/writer failure and uncertain end states. |
| A7 Endurance | One continuous powered hour at 1080p30 on 13 mini with broadcast and local recording; A2 targets and physical beginning/end sync within 100 ms, with uncertainty. |
| A8 Devices and UI | Physical 13 mini and available 15/17/Pro; 720p, both landscapes, interruption/lock/background, VoiceOver and large text, Files export and deletion cancellation. |
| A9 Delivery | Exact TestFlight version/build installed and relevant regressions verified, with privacy declarations, notices and policy checks. |

For each gate record pass/fail/pending, exact observations or artifact reference,
unmeasured criteria, and any independent review or owner acceptance. Report
elapsed/checkpoint coverage, frame cadence and drop counts at each measured
boundary, queue peaks and trend, charged footprint and heat, and separate sync
measurements for the original and receiver.

Track release readiness and sanitized results by build in
[qualification issue #27](https://github.com/smith3v/stream14/issues/27).
