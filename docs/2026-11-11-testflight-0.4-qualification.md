# TestFlight 0.4 (5) delivery and qualification plan

**Goal** — Deliver the current broadcaster to Owner MVP through TestFlight and
record the smoke-test and endurance evidence on that exact build.

**Architecture** — Archive the reviewed app from merged main with normal Apple
signing and the existing Google OAuth configuration. Use the shipped local
recorder, diagnostic export, and an independent YouTube receiver for evidence.

**Tools** — Xcode, App Store Connect, TestFlight, YouTube Studio, the iPhone 13 mini
and the repository's existing [qualification analysis](qualification-report-template.md).

## Release

1. Verify the newest uploaded build number and the existing internal Owner MVP
   group. Increment the app's marketing version and build number. Update the hosted
   identity assertion to match.
2. Archive from merged main `0c2e8f5`, which includes PR #74. Verify the signed
   bundle, OAuth callback, privacy manifests, linked dependencies, and archive
   toolchain. Have a separate agent inspect the release changes and evidence.
3. Upload with normal Apple distribution signing. Wait for processing, check the
   actual export compliance questions, save build-specific What to Test notes,
   and verify the build is Testing in Owner MVP.
4. Record actual TestFlight availability separately from installation and device
   results. The earlier 720p30 pass used Development `25b32f4`.

### Verified archive and checks

Xcode 27.2 (27B52) and iOS SDK 27.2 produced the signed Release archive with
minimum iOS 27.0. All 21 archive checks and both hosted app identity tests
passed. The archive's nine privacy manifests and 55 dynamic loads match the
previous TestFlight build. The audit found no OpenSSL, SRT or RTC symbols.
The public privacy, support and terms pages responded successfully. Independent
review found no material issues. Apple documents the
[upload requirements](https://developer.apple.com/news/upcoming-requirements/)
and [SDK privacy manifest requirements](https://developer.apple.com/support/third-party-SDK-requirements/).

### Delivery result

Xcode uploaded **0.4 (5)** as TestFlight Internal Only on 2026-11-11 at
11:54 Amsterdam time. App Store Connect finished processing. The saved export
answer matched the previous release's Apple operating-system encryption
classification. Build-specific What to Test notes were saved and verified.
The existing **Owner MVP** group shows the build **Testing**, with 90 days
remaining at verification. On 2026-11-11 the owner confirmed installation of
0.4 (5) through TestFlight and a passing five-minute local smoke test. See the
[first 1080p30 run results](#first-1080p30-run-results) for endurance evidence.
See Apple's
[internal testing guidance](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)
and [export compliance reference](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption).

## Five-minute local smoke test

Result for 0.4 (5) on 2026-11-11: **passed, owner-reported**.

Update stream14 in place through TestFlight and confirm **0.4 (5)** before the
timed test. Resolve permissions and overlay setup beforehand if necessary. Keep
existing recordings and use a non-private test scene.

| Time | Action and expected result |
| --- | --- |
| 0:00–0:45 | In **Session**, choose **720p30 · 8 Mbps** with the camera closed. Tap **Check camera and sound**. Look for moving preview, the configured overlay, and a responding microphone meter. |
| 0:45–2:00 | Tap **Record only** and speak immediately for five seconds. Briefly mute while speaking, then unmute and repeat a phrase. After about 20 seconds tap **End session → Stop local recording and capture**. |
| 2:00–4:00 | Play the new file in **Recordings**. Speech is clear from the start, mute produces silence, speech returns after unmute, and the video shows the overlay without app controls. |
| 4:00–5:00 | Keep the original. Record the installed version/build and any failed or skipped step. |

Use a separate [five-minute Unlisted broadcast card](2026-11-08-attended-iphone-session.md#card-s1--short-unlisted-end-to-end)
to verify 1080p30, receiver picture and speech, confirmed End, and local playback
on the delivered build. Prepare the event and receiver before the timed visit.

## One-hour 1080p30 endurance run

The owner adopted **60 continuous minutes** for A7 on 2026-11-11. Use the
TestFlight **0.4 (5)** build on the powered iPhone 13 mini. See the
[first run results](#first-1080p30-run-results).

### Before starting

- Check **Settings → General → iPhone Storage**. The nominal one-hour recording
  is 6.36 GB at 14 Mbps video plus 128 kbps audio, before container overhead and
  bitrate variation. Aim for about **9 GB free** on the phone. Reserve room on
  the Mac for the original and receiver evidence. Export valuable older originals
  if space is tight. An early stop records a partial run.
- Prepare an unused **Unlisted** scheduled encoder event in the intended channel
  with auto-stop off. Use a non-private test scene and the configured overlay. On a second device,
  open the event's YouTube watch page and prepare receiver evidence that includes
  picture and sound at both clap markers.
- Plug in the phone and mount it in landscape with airflow. Start without
  external cooling. Use stable Wi-Fi, keep stream14 foregrounded and the screen
  awake, and note the device/OS, power, mount/case, brightness and room conditions.
- In **Session**, choose **1080p30 · 14 Mbps** with the camera closed, select the
  intended event, and tap **Check camera and sound**. Verify moving preview,
  overlay and mic activity. Use the short broadcast card above for an initial
  delivered-build receiver check if needed. A completed test event needs a
  different scheduled event for the endurance run.

### Run

| Elapsed | Operator action and evidence |
| --- | --- |
| Start | Tap **Start recording and streaming**. Confirm the channel, event, Unlisted visibility and profile, then confirm **Go Live**. Once YouTube is Live and Local saving is recording, confirm picture, overlay and speech on the receiver. Make a visible, sharp clap with hands in frame and start the timer. |
| 15, 30 and 45 minutes | Note both output states, receiver playback and any thermal warning, stall or reconnect. Keep the scene and network stable. A failure that interrupts either output breaks the continuous run. |
| 60 minutes | Make another visible, sharp clap. Allow the receiver to play it. Tap **End session → End session and local recording**. Verify remote completion and check the finalized file plays. If remote status is uncertain, reconcile in the app or verify it in YouTube Studio. |

If a storage, heat or capture warning threatens the recording, end the session
and preserve the partial evidence.

### After the run

1. From **Recordings**, export the original to the Mac, then use **Load
   qualification summary → Export qualification summary**. Retain both files
   and the receiver evidence privately. Record the event result and actual
   elapsed time in the [qualification report](qualification-report-template.md).
2. Analyze the original's frame cadence and stalls and reconcile those with the
   exported encoder/file/transport counters. Evaluate the 30-minute A2 evidence
   within the run where measured, and review the full hour for less than 1%
   measured pipeline frame drops, no repeated stalls of 500 ms or more, and no
   monotonic memory or queue growth. The existing analyzer scans the whole file.
   A first-30-minute cadence result needs a read-only timestamp range scan.
   The diagnostic export reports lifetime counters and peaks. It does not
   provide a separate minute-30 counter snapshot. Report these coverage limits.
3. Measure A/V offset from visible clap contact and the audio transient at each
   marker. Report uncertainty and the original and receiver results separately. A7 requires start and end offset
   within 100 ms. Missing markers or unavailable measurements leave the affected
   criteria pending.

### First 1080p30 run results

The owner reported completing the hour-long run on TestFlight **0.4 (5)**.
The local original, exported qualification summary and completed Unlisted
YouTube replay were checked separately.

| Evidence | Result |
| --- | --- |
| Local original | Finalized 60:36.313 movie (6.398 GB), 1920×1080 H.264 with stereo 44.1 kHz AAC. Native analysis read and decoded both tracks through the end, with 107,939 video frames, 156,605 compressed audio packets, 160,361,418 decoded PCM frames and zero invalid timestamps. The one-hour local duration passed. |
| Local cadence | Mean observed rate 29.685 fps. The largest video timestamp gap was 343 ms, with no gaps of 500 ms or more. The rounded-gap estimate was 1,762 missing 30 Hz intervals (1.61%) over the movie and 711 (1.31%) in the first 30 minutes. These estimates describe output cadence. |
| App diagnostics | Final checkpoint reports 60:39.539 elapsed and a completed local recording. File write counts match the original. The encoder rejected two of 107,941 offered video frames (0.0019%), and the file writer reported no video or audio rejections. These counters cover the measured app stages. Earlier pipeline losses and separate minute-30 rejection counts remain unmeasured. |
| Memory and heat | 368 observations, with process charged footprint of 111.79 MB at start, 151.92 MB peak and a fitted slope of +3.75 kB/s. The worst thermal state was fair. Recent pre-teardown samples from about minute 41 varied between 117.30 and 144.88 MiB before a final 55.39 MiB observation. These samples and queue peaks leave full-run memory and queue growth unverified. |
| Upload | Three publisher generations after connect/publish, 171 discarded admitted packets, two rejected packets and zero unresolved packets. The app-owned upload queue peaked at 2.048 MB and 90 packets. The aggregate records publisher replacements without timing or cause. |
| Receiver | Completed Unlisted replay showed 59:45. Spot checks near the start, middle and end showed the changing overlay. The player reported 1920×1080 at 30 fps and an AAC audio track at the middle and end. Audible quality, receiver sync and full continuity were outside these checks. |
| A/V sync | The owner confirmed both claps. The local markers were about 60:27 apart. Estimated local audio-minus-video offset was −51 to −17 ms at the start, within the 100 ms bound. The end interval was −19 to +150 ms because motion blur obscured contact, leaving the bound inconclusive. Receiver sync remains unmeasured. |

The local recording duration, decode and stall checks passed. The completed
replay adds delivered-build broadcast evidence for A3 and A9. The 59:45 replay
and three publisher generations leave one uninterrupted hour of receiver output
unverified. A7 remains pending. For A2, the exposed rejection rate and the
file cadence estimate measure different things. The full pipeline drop rate and
memory and queue growth criteria remain open.
