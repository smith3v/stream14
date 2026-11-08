# Connected-iPhone test session plan

Updated: 2026-11-08. Owner request: make routine connected-iPhone testing take about FIVE MINUTES, with the full inventory retained as a coverage backlog.

Routine phone visits have a five-minute wall-clock budget, including installation, prompts, test execution and wrap-up. Do not turn this inventory into a one-hour session. Use the current integrated reviewed build; all checks remain pending until observed. The phone is not needed for fixture-driven development. Current availability: owner will connect it later.

## Default: one five-minute smoke check

Run build/package resolution, deterministic fixtures/fault/race tests, Simulator UI checks and evidence-tool preparation on the laptop BEFORE asking for the phone. Prepare normally signed/branded products in advance. These do not consume connected-phone time.

| Wall-clock budget | Work |
| --- | --- |
| 0:00–0:45 | Install/launch the prepared build, verify version, handle permission/authorization readiness. If setup is blocked, record the blocker instead of extending the visit |
| 0:45–2:15 | One short serialized harness: two approximately 6–8-second clips, 1080p and 720p, local changing alpha fixture, mute/hide/unhide/profile-lock checks and native original-file validation. The Debug-only opt-in harness is implemented, compiled and independently reviewed; physical execution/timing remain pending |
| 2:15–3:15 | Brief actual-app check of changed controls/read-only channel/event state; do not repeat all accessibility cases or consent variants |
| 3:15–4:15 | At most ONE relevant targeted manual case selected for this change. Otherwise inspect playback/Files export. A future real two-minute upload outage REPLACES other steps and needs its own budgeted variant; it is not added here |
| 4:15–5:00 | Stop/finalize normally, retain/copy small originals, record the automated report and unmeasured criteria, reconcile remote state and restore settings |

This is a risk-based smoke check, not all 50 physical cases in five minutes. Most failure permutations run deterministically on the laptop; physical checks verify camera/codec/WebKit/route/device behavior. Select additional physical coverage only when a change or specific gap justifies it. Do not schedule repeated visits solely to exhaust the inventory.

First-time consent, trust/Developer Mode or permissions may consume the budget. Stop with BLOCKED/INCOMPLETE at five minutes and retain progress; do not hide setup outside the clock or promise first-time setup fits. Publishing still needs a prepared event and explicit operator action.

The old multi-test camera harnesses below are targeted tools, not the default. Historical 600/900-second examples are not the routine. Longer development runs need explicit agreement; the existing 15-minute ceiling is a ceiling, not a target. The 30-minute/three-hour gates stay unverified and unscheduled unless separately agreed.

## What the owner needs to do

Connect the iPhone 13 mini by USB, unlock it, trust the Mac/enable Developer Mode if requested, and keep it available for permission and Google consent prompts. Codex builds, signs, installs, runs the commands, copies private evidence and analyzes files; the owner does not need to write code or learn Xcode.

For media checks, aim the phone at a private test scene and make visible/audible clap markers when prompted. For streaming checks, have a second device ready to observe the dedicated unlisted event. Do not use a real match or valuable scheduled event as a fixture.

“All together” means one prepared five-minute visit with a selected sequential smoke path, not every backlog row, parallel capture tests or a blanket command. Some checks intentionally change permissions, foreground state, network or authorization. Run these in the order below, restoring state between them.

## Readiness and time limits

| Requirement | Current state / action before the session |
| --- | --- |
| iPhone 13 mini, iOS 27+, cable, Developer Mode, unlocked screen | Owner availability pending; record exact device/OS privately |
| Normally signed app and branded UI runner | F3 signed candidate exists at /private/tmp/stream14-epic13-phone-build/Build/Products/Debug-iphoneos/Stream14.app; signature and compiled OAuth callback verified; not installed/launched. Rebuild if the selected source changes |
| Existing recordings | Inventory/export valuable originals before installation; never uninstall/reset the app as routine setup |
| Public Google iOS client and callback | Console/API/testing audience/client prepared; ignored local configuration exists only in the phone candidate. Actual consent/scope/callback is unverified |
| Account/channel | Owner completes supported browser consent; app must confirm the API-returned channel, not infer it from an email or Studio page |
| Overlay | Known nonsecret reference page plus changing transparent fixture, with reliable source access; keep token-bearing URLs private |
| Test event | Dedicated unlisted encoder event, auto-stop off; no event/key has been created or retrieved by this development run |
| Receiver | Second-device playback/receiver recording for network tests; never use a public destination by accident |
| Production transport/recovery/instrumentation | F6–F12 not complete; their rows below are future gates, not executable acceptance tests today |
| Routine duration | Five-minute wall-clock budget including setup/wrap-up. No automatic extension; an explicitly agreed development experiment still respects the 15-minute ceiling |
| Long qualification | The 30-minute A2 run and three-hour A7 run require separate explicit agreement; they are not authorized by this batch plan |

The current private F1 dual-output candidate uses TWO encoders, a fixed 1080p profile and only a one-second internal disconnect. It is an optional architecture experiment, not the selected production path, a two-minute outage test, or proof of bounded transport.

## Coverage backlog — select checks, not one exhaustive session

Status key: Available = current code/manual flow can be exercised; Service-gated = requires owner setup and actual Google/receiver access; Future = implementation or a verified harness is still needed; Separate agreement = excluded from the ordinary batch. Every row starts PENDING. Mark PASS/FAIL/BLOCKED/SKIPPED with evidence after the actual run.

### Batch 1 — install, permissions and preparation

| ID | Check | Expected result / evidence | Availability / trace |
| --- | --- | --- | --- |
| P01 | Record source commit, version/build, signing/install route, device/OS, power/network and initial recording inventory | Installed binary matches selected build; valuable files survive update; no uninstall | Available; F13/A9 |
| P02 | Launch, return from background and relaunch with saved settings | No automatic camera capture, recording or camera upload. Saved overlay may make its intended website requests; no automatic Google sign-in UI/publishing | Available; F2/F3 and overlay recovery |
| P03 | First camera/microphone permission grant | Honest in-context system prompts; preview and recording become usable; no Photos permission solely for app storage/Files export | Available; A6/A8 |
| P04 | Smallest-screen setup in portrait and both landscapes, then largest Dynamic Type | Essential controls visible/reachable; meaningful text states, adequate contrast, targets at least 44×44 points | Available current UI; full live UI Future F10 |
| P05 | Physical VoiceOver: setup, profile, rear lens, zoom, mute/meter/route, overlay, event rows, recording actions | Correct labels/values/order, no color-only status; dated Play/Export/Delete actions and understandable confirmations | Available current UI; authenticated rows Service-gated; full live UI Future F10 |

### Batch 2 — Google and read-only event selection

When selected for a targeted visit, run sign-in/restore early and revocation/account-reset after the stream ends; do not repeat every variant in the routine smoke check.

| ID | Check | Expected result / evidence | Availability / trace |
| --- | --- | --- | --- |
| G01 | Connect through supported browser; cancel once, then grant youtube.force-ssl | Cancellation is recoverable; callback returns to app; no embedded-overlay login, password collection or camera upload | Service-gated; F2/A6/A9 |
| G02 | Restore SDK-managed authorization after app relaunch and supported token refresh | No duplicate token storage or implicit publish; readiness is honest; actual Keychain/refresh observed, not inferred from fixtures | Service-gated; F2 |
| G03 | Refresh real channel and scheduled events, select dedicated unlisted event | Actual channel ID/title match intended channel; event date/time/visibility/eligibility clear; every returned page handled | Service-gated; F3/A3 |
| G04 | Empty/ineligible/missing event, wrong account/channel and selection becoming stale | Clear actionable state, stale selection cleared, by-ID recheck before use, zero event mutations/media from selection/refresh | Service-gated where safely reproducible; fixtures cover API variants |
| G05 | Authenticated event rows at largest text and VoiceOver in both landscapes | Real titles/dates wrap and remain operable; no credentials or stream keys in UI/screenshots | Service-gated; F3/F10/A8 |
| G06 | Cancel an in-flight read or change selection/account while responses are pending | Old metadata/token callbacks cannot restore a previous account/event; cancellation does not sign out a valid account | Device smoke where controllable; deterministic race coverage remains primary |

Do not deliberately exhaust real quota, damage a channel, or publish an event to manufacture 401/403/429/5xx cases. Verify these with deterministic fixtures or a reviewed app fault harness when one exists; on-device presentation is a later F10 check.

### Batch 3 — local camera, overlay and file quality

| ID | Check | Expected result / evidence | Availability / trace |
| --- | --- | --- | --- |
| L01 | 1080p30 and 720p30: preview, short original recording, stop, playback and original Files export | 1920×1080/1280×720 landscape canvas respectively, H.264/AAC, identity orientation, correct aspect ratio and common composition; export does not transcode | Available; F4/A1/A5/A8 |
| L02 | Physical clap markers at beginning/end of each quality sample | Retain synchronized visual/audio events for numerical offset and uncertainty; target ≤100 ms where applicable, never infer physical sync from track endpoints | Available; M3/A7 measurement support |
| L03 | Change profile before capture; attempt changes during preparation/preview/recording/finalization | Profile persists for next launch and remains frozen for active capture; components do not mix canvas dimensions/bitrate/profile | Available; F4 |
| L04 | Wide and available Ultra Wide choices, supported zoom, reopening capture | Only real compatible rear lenses offered; wide default; truthful zoom limits; no lens change while recording; no extra capture session | Available; F4 and owner lens extension |
| L05 | Mute/unmute, meter, built-in route and an available supported accessory route | Meter is bounded/responsive; original file proves actual audible mute/unmute, no timing discontinuity; route label updates honestly | Available locally; both-output proof Future F6 |
| L06 | Transparent changing overlay, text/logos/alpha edges, two-second source reloads | Same overlay in composed preview and saved file, correct exact canvas at both profiles, changing score visible, no white/blank flashes or app controls | Available; A1 |
| L07 | Brief overlay failure, healthy unchanged score, two-minute source failure, cached content during failed source access | Last-good grace, hide at ten seconds without confirmed source/render health, local A/V continues; cached raster alone cannot count as fresh | Available; M4/A4 |
| L08 | Source recovery while manually hidden; unhide afterwards | Fresh image returns only when health recovers and manual-hide precedence permits; preview and file agree | Available; M4/A4 |
| L09 | Saved URL foreground/relaunch recovery, failed navigation/WebKit recovery, disabled overlay, invalid draft/cancel/Apply | Current automatic overlay recovery and secure disabled/draft rules preserved; stale callbacks cannot resurrect disabled or replaced sources | Available overlay behavior |
| L10 | Repeated start/stop; inspect complete, interrupted and failed entries | Independent playable/exportable originals; honest size/status; no automatic deletion or false “complete” | Available; A5/A6 |
| L11 | Play/Files export; Delete Cancel; deliberate confirmed deletion of one owner-designated expendable NEW test file only | Cancel keeps it; confirmed deletion affects selected original/metadata only and exported copy remains. Never delete valuable or failed originals as cleanup | Available; explicit per-file owner action |
| L12 | Privacy link and bundled notices on installed app | Correct published policy opens; Google/dependency disclosures match build; no unnecessary Photos access | Available; F13/A9 |

The existing automated camera harness uses its explicit default 1080p profile and a visible attached overlay host. It does not replace manual 720p checks or the actual app's covered-host overlay test.

### Batch 4 — safe ingestion and whole broadcast

These rows wait for the corresponding integrated implementation and a dedicated event. F5 preparation currently has no user-facing entry point; Codex must provide a reviewed integration harness or F7 operator flow. The owner is not expected to write Swift or issue raw API commands.

| ID | Check | Expected result / evidence | Availability / trace |
| --- | --- | --- | --- |
| B01 | Reuse an eligible inactive compatible existing binding | Identity/profile/security checks pass; no new stream or unwanted event mutation | Future integration F5/F7; Service-gated |
| B02 | Explicitly prepare an unbound dedicated event; create/bind and read back | One non-reusable app-owned stream, durable ID/phase before ambiguous outcomes, verified RTMPS endpoint; no insecure fallback or key persistence/logs | Future integration F5/F7 |
| B03 | Prepare a second event after successful first preparation, then relaunch | Completed intent cannot permanently block later events; unresolved creation remains guarded; retry cannot create duplicates | Future integration; F5 review regression |
| B04 | Ambiguous create/bind, cancellation, stale account/profile, incompatible/shared binding, auto-stop enabled | Read/reconcile before retry; unknown creation blocks duplicate insert; unsupported event stays blocked with explanation; operator state preserved | Fault harness/fixtures first; safe real reconciliation only |
| B05 | Confirm Go Live for correct channel/title/visibility; auto-start on/off variants | Recorder initialization succeeds before any upload; selection/preview alone never publishes; “Live” requires confirmed YouTube state | Future F7/A3/A6 |
| B06 | Receiver and local file show changing alpha composition, audible mute/route and physical markers, both profiles | Same composed media, no app buttons/alerts; documented single encoder ownership; inspect actual receiver and original file | Future selected F6 path; A1/A3/A4 |
| B07 | Startup/API reject/timeout or transport connect rejection | Healthy local recording continues; no false Live state; writer initialization failure sends zero camera media | Future F6/F7/A4/A6 |
| B08 | Two-minute REAL phone internet outage, restoration and bounded retry exhaustion | Local file remains continuous; queue/high-water limits finite; reconnect only same eligible event; no silent duplicate event or stop of healthy writer | Future F6/F8/A4 |
| B09 | Remote event completed/deleted/otherwise ineligible while local capture is healthy | Upload/reconnect stops as appropriate; local recording continues with clear remote state; no auto-switch to another event | Future F8/A4/A6 |
| B10 | Inject local writer initialization, append and finalization faults separately | Initialization blocks initial Go Live; after live, healthy upload continues with persistent backup-failed warning; retain partial/original files honestly | Future F6/F9/A4/A6 |
| B11 | Confirm End; duplicate taps/cancel; delayed, failed or hung remote end request | Bounded local shutdown, file finalization, truthful confirmed/unknown remote result; reconcile before retry. Never label socket close as remote completion | Future F7/A3/A6 |
| B12 | Account/event/profile/URL changes during active broadcast | Frozen session settings; end-first account flow, no cross-account late results or secret exposure | Future F7/F10 |
| B13 | Wi-Fi → cellular → Wi-Fi path switch, where available and the owner permits mobile-data use | Local file remains continuous; any reconnect stays on the same eligible event, transport/remote labels remain truthful; record path-change times and receiver continuity separately from total internet loss | Future F8/A4/A8 |

B08 requires loss of the PHONE'S internet connectivity. Disconnecting USB, changing only the laptop's network, or the WebKit-only request block does not establish upload outage behavior. Keep capture foreground; do not combine background interruption with this test.

### Batch 5 — interruptions, permissions, recovery and final cleanup

Run disruptions serially after normal recording/broadcast evidence. Restore the original permission, network, text-size, VoiceOver and audio-route settings before leaving.

| ID | Check | Expected result / evidence | Availability / trace |
| --- | --- | --- | --- |
| I01 | Current injected writer init/append/finalize faults and injected capture/audio-inactive notification | Failed/interrupted durable state, retained files, explicit restart and original idle-timer state restored; injection is not a real incoming call | Available existing harness; dual-output independence Future F9 |
| I02 | Home, lock/unlock and foreground return during a NEW short recording | Capture stops/finalizes within available time; no background-camera promise, silent auto-resume or auto-publish; manual restart creates new file | Available local UI; whole broadcast Future F9 |
| I03 | Real audio interruption/route removal where feasible, capture runtime failure and cancellation during setup/stop | Honest UI/file state, no leaked capture/encoder/session; fresh explicit resume and correct route; no warning sound recorded by app | Partial current local behavior; complete matrix Future F9 |
| I04 | Serious/critical thermal decision injection and ordinary real thermal observation | Reduce overlay work first; critical state stops safely; no silent resolution change. Injected decisions are not proof of real heat tolerance | Current local behavior / Future whole-session F9/F12 |
| I05 | Camera denied, microphone denied, both denied; grant again in Settings | Distinct actionable state; no false successful media; local/export functions remain available where possible; no app uninstall/privacy reset | Available manual phone checks; Simulator denial automation is separate |
| I06 | Local sign-out, restore/reconnect, explicit revoke, revoked/expired consent and failed revoke reporting | SDK-owned state clears honestly; no event/key leak or media resume; recordings/overlay remain; do this after remote event is confirmed ended | Service-gated; F2/A6 |
| I07 | Forced termination before first movie fragment, after completed fragments and during finalization | Preserve original/pending metadata; relaunch never calls incomplete file complete; supported recovered copy is separate and measured; no transcoding or automatic cleanup | Future F11/A5; dedicated NEW files only |
| I08 | Export finalized originals and supported private metrics; inspect audio/video reads, timestamps/gaps, markers, bytes/status and receiver capture | Evidence tied to exact run/build; finite queue/memory observations; diagnostics redact tokens, keys, private URLs and account/tester information | Original inspection Available; delivered-app metrics Future F12 |
| I09 | Final reconcile and restore | Test event confirmed ended, camera/mic stopped, idle timer normal; retained originals/evidence inventoried, no pending automatic retries/publishing | Available portions / Future full lifecycle |
| I10 | Short 13 mini run measuring the actual app instrumentation overhead against a documented comparable control | Record cadence/drops, memory/queue/task/disk growth and collection cost under the same profile/conditions; inspect the real exported diagnostic artifact and explain baseline/method limitations. A hosted test alone is insufficient | Future F12; ≤15-minute development experiment |

Do not fill the phone to simulate disk-full. Use the reviewed fault injection. Do not kill/uninstall an app with valuable active recording. Crash tests use newly created expendable test sessions with explicit operator intent and preserve every original. If the remote event might still be live after interruption, reconcile/end it explicitly in the supported flow or Studio before leaving.

## Existing targeted commands — not the default five-minute batch

Run from the selected integrated worktree with ignored local signing configuration. Codex reads the private identifier from devicectl; no identifier/team/token belongs in Git or public evidence. Use a new run/result path on every attempt.

The helper below is a command template for Codex, not an installed project script. It intentionally selects ONE test at a time. Shared-scheme build/branding and normal signing must run before installation; for a reused xctestrun verify those products were branded and normally signed first. Never run concurrent window-owning/camera tests merely because xcodebuild offers parallel workers.

~~~sh
export STREAM14_DEVICE_ID='<private connected device identifier>'
export STREAM14_RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
export STREAM14_EVIDENCE="/private/tmp/stream14-device-$STREAM14_RUN_ID"
mkdir -p "$STREAM14_EVIDENCE"

device_test() {
  local test_id="$1"
  local result_name="$2"
  shift 2
  xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
    -destination "platform=iOS,id=$STREAM14_DEVICE_ID" \
    -derivedDataPath "$STREAM14_EVIDENCE/DerivedData" \
    -clonedSourcePackagesDirPath /private/tmp/stream14-f2-packages \
    -disableAutomaticPackageResolution -allowProvisioningUpdates \
    -parallel-testing-enabled NO \
    -only-testing:"$test_id" \
    -resultBundlePath "$STREAM14_EVIDENCE/$result_name.xcresult" \
    "$@" test >"$STREAM14_EVIDENCE/$result_name.log" 2>&1
}
~~~

### Preferred short smoke

Prepare normally signed/branded Debug test products BEFORE connecting the phone. Use the SAME prepared DerivedData/evidence directory for both actions, not a fresh empty build directory at phone time. Local signing configuration must be present. Verify normal signing/branding before any reused test product is installed; this selected smoke is hosted in the normal app.

~~~sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$STREAM14_EVIDENCE/DerivedData" \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f2-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  -only-testing:Stream14Tests/ShortPhoneSmokeTests/twoProfilesRetainComposedOriginals \
  build-for-testing
~~~

When the phone is ready, run only this opt-in against the prepared products:

~~~sh
TEST_RUNNER_STREAM14_SHORT_DEVICE_SMOKE=1 xcodebuild \
  -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination "platform=iOS,id=$STREAM14_DEVICE_ID" \
  -derivedDataPath "$STREAM14_EVIDENCE/DerivedData" \
  -disableAutomaticPackageResolution \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 90 \
  -only-testing:Stream14Tests/ShortPhoneSmokeTests/twoProfilesRetainComposedOriginals \
  -resultBundlePath "$STREAM14_EVIDENCE/short-phone-smoke.xcresult" \
  test-without-building
~~~

The harness requires pre-authorized camera/microphone and the physical 13 mini; it does not wait for permission prompts. Debug-only host isolation avoids saved overlay URLs and Google SDK/account initialization. Simulator, default and Release runs skip, so a skip is NOT a phone pass. Two clips share a 50-second internal deadline, a one-minute cooperative test limit and the configured 90-second runner watchdog. Native calls are not assumed interruptible; Codex still owns the overall five-minute wall-clock stop/report decision. Originals are retained. File/decoded-marker checks do not prove physical sync, audible unmute, real network behavior or endurance.

See the [short-smoke handoff](2026-11-07-short-phone-smoke-implementation.md) for actual compile/regression evidence and limits. Do not run the legacy catalogue in addition to the smoke merely to fill coverage.

### Legacy targeted catalogue

Inspect each exit status/result before the next call; stop on an unexpected failure. Select at most one relevant short legacy command for a targeted visit; these examples are a catalogue, not a combined unattended script. Ensure camera/microphone permission prompts are resolved and owner/private scene are ready before camera checks.

~~~sh
# Reference website only; no camera recording. Requires its current public fixture.
TEST_RUNNER_STREAM14_REFERENCE_TEST=1 \
  device_test Stream14Tests/WebOverlayRendererTests/referencePageReloadEvidence reference

# Short legacy reference sample plus changing-fixture/repeated-recording follow-ons.
# This setting does NOT cover the two-minute outage/manual-hide sequence.
TEST_RUNNER_STREAM14_DEVICE_RECORDING=1 \
TEST_RUNNER_STREAM14_RECORDING_SECONDS=30 \
  device_test Stream14Tests/MediaDeviceTests/combinedDeviceRecording local-composition

# Separate short writer faults and notification-path interruption checks.
TEST_RUNNER_STREAM14_DEVICE_FAILURES=1 \
  device_test Stream14Tests/MediaDeviceTests/deviceWriterFailuresAndInterruption local-faults

# Actual app UI camera/lens/short-record/playback check; iPhone 13 mini expectations.
TEST_RUNNER_STREAM14_DEVICE_LENS_UI=1 \
  device_test Stream14UITests/SetupScreenTests/testDeviceRearLensSelector lens-ui

# Actual Home transition and playback; does not substitute for manual lock/call.
TEST_RUNNER_STREAM14_DEVICE_UI=1 \
  device_test Stream14UITests/SetupScreenTests/testDeviceBackgroundFinalizesAndPlaybackOpens background-ui
~~~

The combined harness's longer outage path blocks WebKit DOCUMENT requests, not upload/all phone radios. Its fixed 1080p profile does not exercise 720p. At least 180 seconds enables its two-minute source outage; 600 seconds enables its old manual-hide/recovery branch. Those modes are NOT the five-minute default and must not launch automatically. The short setting and new two-profile smoke do not prove that long outage branch. Follow-on files and runner/setup time count toward the session budget.

The existing F1 private candidate is a separate OPTIONAL architecture experiment. Only enable after the receiver/event and private destination are explicitly approved for that run. Supply TEST_RUNNER_STREAM14_PRIVATE_RTMPS_URL and TEST_RUNNER_STREAM14_PRIVATE_STREAM_KEY through the private local test environment, never a recorded command/history or committed file. Test environment copies, xctestrun, xcresult and logs can contain configuration and must stay private.

~~~sh
TEST_RUNNER_STREAM14_DUAL_OUTPUT=1 \
TEST_RUNNER_STREAM14_DUAL_OUTPUT_SECONDS=30 \
  device_test Stream14Tests/DualOutputFeasibilityTests/privateDeviceDualOutputCandidate f1-private-candidate
~~~

This candidate clamps its requested loop to 12–600 seconds and uses two encoders. Its one-second reconnect and isolated writer-failure probe are NOT proof of B08/B10, common encoded fan-out, finite socket queues or physical sync. Do not run it against an ordinary public event.

The F6 SharedEncodingPrototypeTests suite is experimental. At checkpoint 9753224, both synthetic Simulator tests pass: native single-encode fan-out into two files, codec packet bytes with explicit AAC trim-origin handling, decoded midpoint markers within 35 ms, and bounded sender/retained partial-consumer checks. This is not physical sync, real socket delivery or production acceptance. After independent review and integration, Codex should run the same suite on the connected 13 mini using selector Stream14Tests/SharedEncodingPrototypeTests to verify native-device API behavior. It uses generated media and no camera/network. Earlier failed results are retained; never label this proof of the full F6 acceptance gate.

Other fixture-driven hosted tests and Simulator-only seeded deletion/recording-layout/denied-permission tests do not need this phone session. Do not carry their fixture IDs or Simulator privacy-reset commands onto the owner's phone.

## Later TestFlight and longer qualification

These are unverified requirements, not an extension of the five-minute visit. Short Q01/Q04 checks remain readiness-gated authorized work when they fit the same budget. Q02/Q03 and any run exceeding that budget need a separate explicit agreement; never extend automatically.

| ID | Required run | Conditions / pass evidence | Availability |
| --- | --- | --- | --- |
| Q01 | Install actual full-app TestFlight candidate and repeat short local + unlisted end-to-end smoke | Delivered build/version, policy/notices, real consent, channel/event/start/receiver/end, overlay/audio, stop/play/export and interruption; Xcode install does not pass A9 | Future F13/A9 |
| Q02 | Agreed 30-minute compositing/recording qualification, both selected profiles as required by the final matrix | <1% measured pipeline drops, no repeated stalls ≥500 ms, no monotonic memory/queue growth; start/end physical markers and delivered-app metrics with limits | Separate explicit agreement; F14/A2 |
| Q03 | Agreed powered three-hour 1080p30 simultaneous broadcast + local backup on 13 mini | A2 quality targets, physical A/V offset ≤100 ms at start/end, receiver and original analysis, stable qualified network; record mount/case/power/brightness/ambient/airflow, first without external cooling | Separate explicit agreement; F14/A7 |
| Q04 | Available iPhone 15/17 representatives and relevant Pro variants | 720p/1080p, real route/interruption/background/VoiceOver/larger-text/play/export/cancel checks; no required Pro-only behavior | Future F14/A8; 13 mini does not replace wider-device coverage |

A1–A9 mapping: A1=L01/L06/B06; A2=I08/I10/Q02; A3=G03/B05/B06/B11; A4=L07/L08/B07–B10/B13; A5=L10/L11/I07/I08; A6=P03/G01/G04/B04/B07/B10/B11/I01–I06; A7=Q03; A8=P04/P05/L01/L04/L05/B13/I02/I03/Q04; A9=P01/L12/I10/Q01. Preserve earlier MVP evidence and its measurement limits; no new row is passed by a historical build.

## Per-run evidence record

Copy this table for each executed row/group; leave no empty PASS without evidence.

| Field | Record |
| --- | --- |
| Checklist IDs / status / date and operator | Pending / Pass / Fail / Blocked / Skipped, reason |
| Source / installed version-build / route | Exact commit; Xcode or TestFlight |
| Device / OS / profile / lens / audio route | Private device identifier outside Git |
| Setup and duration | Power/mount/case/brightness/airflow/ambient/network; five-minute routine total, or exact separately agreed exception |
| Changes/faults and timings | Permission/overlay/network/foreground/mute/route/fault actions; actual measured times |
| Original media and receiver evidence | UUID/path/hash; retained originals; no transcoding or deletion |
| Metrics | Executed/skipped test count, drops/gaps, queue bounds/high-water, charged-memory method/limits, thermal state |
| Physical sync | Start/end marker offsets with uncertainty, or explicitly unmeasured |
| Files / logs / result bundle | Private paths; redacted shareable summary only |
| Restore/reconcile | Event ended or unknown, permissions/network restored, capture stopped, retained-file inventory |
| Follow-up | Failed/pending criterion and owning issue; do not close acceptance prematurely |

See the [canonical specification](2026-11-01-stream14-design.md#10-later-full-product-acceptance-gates-and-test-matrix), [development guide](ios-development-guide.md), [full-app plan](2026-11-05-full-app-implementation.md) and [epic resume ledger](2026-11-07-epic13-progress.md). Update this list as later stage APIs/harnesses become real; do not invent successful commands for future behavior.
