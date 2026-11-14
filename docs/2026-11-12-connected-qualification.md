# Connected qualification implementation plan

**Goal** — Reduce operator time by running repeatable checks on the Mac and on
one connected iPhone visit, and reuse the same recordings and exports across
the remaining physical checks.

**Architecture** — The runner uses the existing Stream14 Xcode scheme and
two-profile local smoke test. A private workspace holds the signed build, raw
logs and XCTest results. A JSON summary reports what actually ran. The
[case inventory](2026-11-07-connected-iphone-test-plan.md) remains the coverage
reference.

**Tools** — Xcode, Python 3, CoreDevice, an iPhone 13 mini, and an iOS Simulator.

## Run fixtures on the Mac

Use a reviewed checkout. Set `STREAM14_PACKAGES` to the Xcode cloned package
directory for the pinned `Package.resolved`. Use the iOS Simulator identifier
reported by `xcrun simctl list devices available`.

```sh
STREAM14_HOSTED="$(mktemp -d /private/tmp/stream14-hosted.XXXXXX)/hosted"
python3 Tools/qualification/connected.py hosted \
  --work-dir "$STREAM14_HOSTED" \
  --packages "$STREAM14_PACKAGES" \
  --simulator "$STREAM14_SIMULATOR"
```

This executes the allowlisted hosted suites with synthetic media and test
services. Use the per-test results for API/auth decisions, stale callbacks,
event eligibility, lifecycle, retry and cancellation, writer and transport
failure handling, permission decisions, diagnostics, and recovery metadata.
Keep real account setup, real internet interruption, and physical media
evidence in the device plan. Read `evidence.json` and keep the result bundle
and build log private. A failed, skipped or unexecuted selected test needs
an explicit disposition.

## Prepare the signed phone products on the Mac

Use the normal developer signing configuration in ignored
`Config/Local.xcconfig`. Keep the pinned package cache ready. Preparation
runs before the five-minute phone visit.

```sh
STREAM14_PHONE="$(mktemp -d /private/tmp/stream14-phone.XXXXXX)/phone"
python3 Tools/qualification/connected.py prepare \
  --work-dir "$STREAM14_PHONE" \
  --packages "$STREAM14_PACKAGES" \
  --simulator "$STREAM14_SIMULATOR"
```

Retain the prepared workspace. During the visit, stop any active session on the
phone, connect and unlock the 13 mini, and approve use of the camera and
microphone on a non-private scene. Have permissions and Developer Mode ready.
The existing host uses the app's bundle ID. Xcode can replace an installed
TestFlight app in place with the signed Development build. Export valuable
originals first and agree on the replacement before using the install flag.
Return to the exact TestFlight version through TestFlight for its acceptance
checks.

```sh
python3 Tools/qualification/connected.py run \
  --work-dir "$STREAM14_PHONE" \
  --device "$STREAM14_DEVICE" \
  --allow-camera-mic --allow-in-place-install
```

The device argument is the hardware identifier for the wired 13 mini. Obtain it
privately from Xcode Devices and Simulators or CoreDevice. Run only one physical
test at a time. The runner uses the reviewed `ShortPhoneSmokeTests` suite.
It checks that the selector enumerates exactly one test during preparation and
accepts exactly one physical pass and zero failures or skips. The test uses a
50-second internal capture deadline and Xcode enforces its own watchdog.
The runner leaves the two short originals on the phone for review. If the
visit is blocked or interrupted, inspect the private evidence and check that
capture is idle before retrying. Each attempt writes a new evidence subdirectory
under the prepared workspace.

### What the phone run covers

The shared fixture exercises both 720p30 and 1080p30 in one visit. It checks the
overlay canvas dimensions and alpha, preview profile lock, a visible change
composited into each saved movie, manual hide/unhide state, mute state, completed
file status, expected video orientation and codec, and native AAC decode.
Use this evidence for the corresponding parts of L01/L03/L05/L06/L08/L10.
The Development build uses a local fixture. Audible speech/mute, real network
recovery, exact delivered-build UX, and physical A/V sync need their respective
observations.

## Reuse evidence in the owner visits

| Visit | Do once and retain | Coverage |
| --- | --- | --- |
| Release sign-off | Confirm TestFlight build. Open About & Legal policy links and notices. Listen to the existing Unlisted replay and confirm the event ended. | P01, L12, Q01 and the receiver audio part of B06. Keep the owner-reported local smoke result. |
| Two short local clips | Use one per profile for the lens/zoom, visible overlay, speech/mute/unmute and deliberate playback/export observations. Use the same clips for original and diagnostics exports. Split across short visits if needed. | L01–L06, L10–L11, I08. Leave each subcheck pending until its own evidence exists. |
| Phone interface | Inspect the same prepared Session, event picker and Recordings across portrait, both landscape directions, large text and VoiceOver. Restore changed settings. | P04–P05, G05 and physical portions of #23/#62. |
| Short receiver check | On one fresh Unlisted manual-start event, verify no publish before confirmation, cancel Start, start both outputs, check live picture/overlay/speech, exercise active locks, cancel End, then confirm End and retain the file. Use a second disposable event for auto-start and the other profile if still pending. | G03, B01, B05–B06, B11–B12, I09. The completed existing replay can supply the #26 listening check. |
| Overlay and network | Combine brief and sustained source loss, manual hide and fresh recovery against one controlled overlay fixture. Run the separate real two-minute phone outage on a disposable Unlisted event with a receiver on independent internet. Check cellular handover only when available and agreed. | L07–L09 and B08/B13. The fixture outage and actual phone internet outage exercise different paths. |
| Interruption and recovery | Reuse one inspection sequence for each Home, lock, audio-route and interruption trigger. Use fresh expendable clips for before-fragment, after-fragment and during-finalization stops. Keep originals and recovery copies. | I02–I03, I07, I09. Each trigger requires its own result. |
| Endurance | Use one 60-minute TestFlight 1080p30 event with actual receiver capture and clear claps at each end. Export one original and one qualification summary. Use the first 30 minutes for A2 where measurement coverage permits. | Q02–Q03 and I08. Inspect receiver duration, both start/end offsets, and measured quality independently. |

The five-minute limit applies to each routine visit. Keep permissions and
event setup outside the timed segment when possible. Use disposable Unlisted
events with explicit Start/End and retain the originals. Use prepared injection
for writer or API failures, including the separate physical healthy-receiver
check when a suitable build and test event are ready. Avoid repeating a
successful fixture on the phone simply to acquire the same observation.
Keep the diagnostics-overhead comparison and available-device coverage
separate where their evidence differs.

## Verification and handoff

Run the safe Simulator fixtures, build normally signed phone products and
review the runner against the exact Xcode enumeration and result formats.
Check failure, skip, and timeout handling before starting a phone visit. Record
the prepared revision, build and result summary. The connected run starts
when the owner has supplied the wired phone and approved the short capture.

On 2026-11-12 revision `aadb545` passed the Mac-side runner with **181 passes
across 23 suites**, zero failures and zero skips on the iPhone 13 mini Simulator
with iOS 27.2. The unsigned Release build and signed Development preparation
for 0.4 (5) also passed. Xcode enumerated one phone test for the visit.

The first connected run failed the transparency check on both profiles. The
visible-window WebKit snapshot returned alpha 255 in the clear and
half-transparent regions before normalization. The corrected renderer attaches
its snapshot viewport to a hidden window. The rerun on the iPhone 13 mini
with iOS 27.2 passed **one test with zero failures and zero skips**. On both
profiles the clear, half-transparent and opaque fixture pixels measured alpha
0, 128 and 255. The saved originals retained the composed marker change and
passed video-format and native AAC decode checks. The originals were 2.833 s
at 1080p30 and 3.233 s at 720p30.

This local Development run used a synthetic overlay fixture. Speech and mute
listening, real overlay and network recovery, installed TestFlight behavior
and physical A/V sync remain manual observations.
