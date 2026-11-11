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

## Five-minute local smoke test

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

## Storage-limited endurance plan

Plan one uninterrupted **60-minute 1080p30 broadcast and simultaneous local
recording** on the iPhone 13 mini. At 14 Mbps video plus 128 kbps audio, the nominal
local size is 6.36 GB for an hour and 19.07 GB for three hours, before container
overhead and bitrate variation. Check Settings → General → iPhone Storage before
starting. Aim for about **9 GB free** for an hour and reserve space on the Mac for
both the original and receiver evidence. If space is tight, set a shorter cutoff
before starting. Retain originals and export to the Mac without making a second
large on-phone copy.

1. Confirm the TestFlight build and prepare a dedicated Unlisted event, a
   stable Wi-Fi connection, power and airflow, an overlay fixture, and a second
   device to observe or retain the receiver playback. Keep the phone foregrounded
   for the run.
2. Confirm **Start recording and streaming** for that event. Once live, make a
   visible and audible clap. Note elapsed time, receiver playback and both output
   states at 15, 30 and 45 minutes. Record any heat warning, stall, local failure
   or dropped connection. End early if storage, thermal or capture warnings
   threaten the recording.
3. At the end, make a second visible and audible clap, confirm End, and check that
   the event ended and the file plays. Retain the original, receiver evidence,
   and exported qualification summary privately.
4. Inspect cadence and diagnostic counters against A2, including the first
   30 minutes of the file. Target less than 1% pipeline frame drops, no repeated
   stalls of 500 ms or more, and no monotonic memory or queue growth. Report the scope of each counter and
   measurement. Measure start and end A/V offset with uncertainty against the
   100 ms limit. A missing marker or unavailable metric stays pending.

The one-hour run is the practical endurance target for this phone's storage.
It can measure A2 within the run and evaluate a proposed one-hour A7 criterion.
A healthy hour provides no observation of faults beginning after minute 60.
The [current specification](2026-11-01-stream14-design.md#10-later-full-product-acceptance-gates-and-test-matrix)
still calls for three hours. Agree and record the revised A7 duration before
using one-hour evidence for epic closure.
