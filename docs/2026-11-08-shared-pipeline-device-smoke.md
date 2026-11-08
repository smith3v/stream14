# Shared-pipeline short physical smoke — 2026-11-08

## Scope and result

The prepared, normally signed Xcode Debug build of source `20a0035` (reviewed F8 runtime `2f456dd`), displayed version 0.2 (3), ran the opt-in `Stream14Tests/ShortPhoneSmokeTests` suite on the connected iPhone 13 mini / iOS 27.2. This build uses the native shared encoder and compressed local writer, unlike the earlier [attended baseline](2026-11-08-attended-device-results.md). It is development evidence, not TestFlight delivery.

Xcode's native result summary reports **one passed test, zero failures and zero skips**. Test body: **10.173 seconds**. Full `test-without-building` invocation: **22.769 seconds**. No build was performed during this phone invocation. The user confirmed USB connection/unlocked readiness; Codex announced camera/microphone capture before running it.

| Retained original | Requested profile | Measured duration |
| --- | --- | --- |
| First clip | 1920×1080 / 30 fps | 3.723333 seconds |
| Second clip | 1280×720 / 30 fps | 3.196667 seconds |

The existing suite checks the actual retained media's expected dimensions, H.264/AAC tracks, decoded media and red/green composition markers after an in-memory WebKit source change. Its direct control checks cover frozen profile selection, manual visibility and mute state. The suite closes capture and retains both originals. Identifiers and raw footage stay private.

## Limits

- No upload connection, Google request, YouTube binding or transition was made. The Debug smoke host isolates saved overlay URLs and Google driver initialization.
- This build still uses the preceding dependency revision; it does not validate the newly reviewed AAC-header/CTS corrections or actual RTMPS delivery.
- No physical clap/lip-sync, audible mute, actual receiver playback, route interruption, performance series, CBR or endurance acceptance follows from these short clips. Requested 30 fps is not a measured sustained frame-rate claim.
- F9/F10 interface and interruption changes are not physically qualified by this earlier F8 build. Whole-app A1–A9 and issue acceptance remain pending.
- No recording was deleted. The normal app has no test-imposed recording duration limit.

## Private evidence and reproduction

Private evidence: `/private/tmp/stream14-shared-phone-20261108-203139/` contains `smoke.xcresult`, `smoke.log`, `invocation.json`, native `test-summary.json` and `retained-clips.json`. The latter maps the two originals' private identifiers to their durations. Prepared products are at `/private/tmp/stream14-shared-phone-build/Build/Products`; the signed build and strict app/embedded-test signature checks passed before phone execution. The ignored signing/OAuth configuration was not committed.

The prepared `.xctestrun` was used directly, avoiding package resolution/building on the phone clock, with the suite selector, `TEST_RUNNER_STREAM14_SHORT_DEVICE_SMOKE=1`, serial testing and a 90-second runner watchdog. The command also had an external 180-second timeout; it completed normally. Require the native one-pass/zero-skip summary rather than exit status alone. See the [master plan](2026-11-07-connected-iphone-test-plan.md) for the five-minute TOTAL routine budget and the full pending-test backlog.
