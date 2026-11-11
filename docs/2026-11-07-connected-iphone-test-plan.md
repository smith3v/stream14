# Connected-iPhone test session plan

Updated: 2026-11-11. Routine connected-iPhone testing has a **five-minute TOTAL
wall-clock budget**, including install, prompts, actions and wrap-up. This full
inventory is a backlog, not a one-hour session or a combined command. Build,
resolve, run fixtures/Simulator checks and prepare analysis tools on the laptop
first. Pick ONE [attended-session card](2026-11-08-attended-iphone-session.md).

## Current evidence and next visit

- Historical [shared-pipeline local smoke](2026-11-08-shared-pipeline-device-smoke.md) passed on 13 mini/F8 `20a0035`: one executed pass, zero failures/skips, 10.173-second body. It predates later RTMPS, UI, interruption, recovery and diagnostics changes.
- The 13 mini has Development 0.3 (4) from PR #70 head `5e11ac6`. The owner confirmed the brighter green Start action and automatic reconnection to the saved YouTube account. The owner previously confirmed the More flicker fix on `4c097ae`. [PR #63](https://github.com/smith3v/stream14/pull/63) merged at `5f2d5c7` and [PR #70](https://github.com/smith3v/stream14/pull/70) merged at current main `f69f24a`.
- [Account/event checks](2026-11-08-attended-account-event-results.md) verified OAuth callback, intended channel, restore, sign-out and revoke; #15/#16 closed. Do not repeat setup unless the current account/policy state actually requires it.
- [Short Unlisted development run](2026-11-10-default-key-phone-test.md) passed on `625df2a`: confirmed Live/End, receiver composition/speech and retained local playback; #18/#20 closed. This is not current UI or final TestFlight qualification. Default/reusable keys are supported; no dedicated-key prerequisite. “Dedicated test event” below means a disposable test event, not an exclusive key. Preserve selected-event eligibility and auto-stop Off.
- Full-app TestFlight 0.3 (4) was delivered and owner-installed; #58/#59 are merged. Its source predates the corrected Development UI. The owner deferred a new TestFlight release/regression; no upload/version change is scheduled.
- Next visit is [local recording card S2](2026-11-08-attended-iphone-session.md#card-s2--local-recording-on-the-installed-development-build), pending explicit owner agreement to a local recording of a non-private scene. Full physical portrait/both-landscape, largest-text/VoiceOver, both-profile and actual file/receiver checks remain open where required by #17/#62/#23.

Use the [latest development handoff](ios-development-guide.md#installed-development-build-and-next-local-visit--2026-11-11) and [current A1–A9 audit](2026-11-07-epic13-progress.md#current-acceptance-audit--2026-11-11). Current UI is Session/Recordings with More → Settings. Older Preparation click scripts and backlog status snapshots below are historical coverage, not current navigation or pass claims. All backlog rows remain intact. Deferred #65 shared-key mitigation and draft #69 custom A/V tooling do not block these visits; existing Analyze/manual markers suffice.

A prepared event and explicit operator confirmation are required before media
publishing. Intentional lock and force-termination also need operator agreement.
An earlier connected/unlocked report does not establish present attendance.
Stop starting tests at wrap-up; record incomplete work instead of extending.
The 15-minute development ceiling is not a routine target. Formal 30-minute A2
and three-hour A7 runs remain pending, unscheduled and separately agreed; shorter
samples and fake-clock tests do not qualify elapsed-duration performance.

## What the owner needs to do

[Local recording card S2](2026-11-08-attended-iphone-session.md#card-s2--local-recording-on-the-installed-development-build) uses the already installed app. For visits that need the Mac, connect the iPhone 13 mini by USB, unlock it and trust the Mac or enable Developer Mode if requested. Codex handles builds, commands and authorized private analysis.

For media checks, obtain explicit owner agreement and aim the phone at a non-private test scene. Make visible and audible clap markers when selected for measurement. For streaming checks, have a second device ready to observe the selected disposable Unlisted event. Do not use a real match or valuable scheduled event as a fixture.

“All together” means one prepared five-minute visit with a selected sequential smoke path, not every backlog row, parallel capture tests or a blanket command. Some checks intentionally change permissions, foreground state, network or authorization. Run these in the order below, restoring state between them.

## Readiness and time limits

| Requirement | Action before selecting a card |
| --- | --- |
| Phone | Confirm current USB/unlocked/owner availability; record exact 13 mini/OS privately |
| Prepared binary | Normally signed exact reviewed source, appropriate public OAuth callback outside Git, recognizable app/branded runner; TestFlight route required for A9 |
| Recordings | Inventory/export valuable originals before update; never uninstall/reset or automatically clean up |
| Authorization | Reuse historical checks; verify current state and perform deliberate policy agreement/reauthorization only if actually needed |
| Event and receiver | Freshly verify selected disposable Unlisted encoder event (existing/default reusable key allowed), auto-start/auto-stop/monitor/binding eligibility, second-device receiver; no private keys or links in public artifacts |
| Overlay | Known nonsecret reference and changing transparent fixture with controllable source access |
| Recovery/diagnostics | Implemented/reviewed flows exist and #58/#59 are merged; physical current-build recovery, overhead and exported JSON evidence remains pending |
| Routine time | Five minutes total including setup/wrap; one selected card, no automatic extension |
| Longer qualification | Exact A2/A7 runs and markers require separate explicit owner agreement |

## Coverage backlog — select checks, not one exhaustive session

Status key: Available = current code/manual flow can be exercised; Service-gated = requires owner setup and actual Google/receiver access; Separate agreement = excluded from the ordinary batch. Rows are coverage requirements, not claimed passes. The historical evidence above covers only its named source/scope. Mark PASS/FAIL/BLOCKED/SKIPPED for the exact selected current-build run.

### Batch 1 — install, permissions and preparation

| ID | Check | Expected result / evidence | Availability / trace |
| --- | --- | --- | --- |
| P01 | Record source commit, version/build, signing/install route, device/OS, power/network and initial recording inventory | Installed binary matches selected build; valuable files survive update; no uninstall | Available; F13/A9 |
| P02 | Launch, return from background and relaunch with saved settings | No automatic camera capture, recording or camera upload. Saved overlay may make its intended website requests; no automatic Google sign-in UI/publishing | Available; F2/F3 and overlay recovery |
| P03 | First camera/microphone permission grant | Honest in-context system prompts; preview and recording become usable; no Photos permission solely for app storage/Files export | Available; A6/A8 |
| P04 | Smallest-screen setup in portrait and both landscapes, then largest Dynamic Type | Essential controls visible/reachable; meaningful text states, adequate contrast, targets at least 44×44 points | Current integrated UI; physical current-build check pending |
| P05 | Physical VoiceOver: setup, profile, rear lens, zoom, mute/meter/route, overlay, event rows, recording actions | Correct labels/values/order, no color-only status; dated Play/Export/Delete actions and understandable confirmations | Current integrated UI; authenticated rows Service-gated; physical check pending |

### Batch 2 — Google and read-only event selection

When selected for a targeted visit, run sign-in/restore early and revocation/account-reset after the stream ends; do not repeat every variant in the routine smoke check.

| ID | Check | Expected result / evidence | Availability / trace |
| --- | --- | --- | --- |
| G01 | Connect through supported browser; cancel once, then grant youtube.force-ssl | Cancellation is recoverable; callback returns to app; no embedded-overlay login, password collection or camera upload | Historical grant/callback verified; current policy/candidate integration pending; F2/A6/A9 |
| G02 | Restore SDK-managed authorization after app relaunch and supported token refresh | No duplicate token storage or implicit publish; readiness is honest; actual Keychain/refresh observed, not inferred from fixtures | Historical restore verified; supported real refresh/current-candidate behavior only where changed; F2 |
| G03 | Refresh real channel and scheduled events, select dedicated unlisted event | Actual channel ID/title match intended channel; event date/time/visibility/eligibility clear; every returned page handled | Historical channel/event read verified; fresh by-ID preflight required before publishing; F3/A3 |
| G04 | Empty/ineligible/missing event, wrong account/channel and selection becoming stale | Clear actionable state, stale selection cleared, by-ID recheck before use, zero event mutations/media from selection/refresh | Service-gated where safely reproducible; fixtures cover API variants |
| G05 | Authenticated event rows at largest text and VoiceOver in both landscapes | Real titles/dates wrap and remain operable; no credentials or stream keys in UI/screenshots | Service-gated; F3/F10/A8 |
| G06 | Cancel an in-flight read or change selection/account while responses are pending | Old metadata/token callbacks cannot restore a previous account/event; cancellation does not sign out a valid account | Device smoke where controllable; deterministic race coverage remains primary |
| G07 | New YouTube policy gate, local rehearsal without agreement, explicit API-data deletion and Studio-resolution acknowledgement after settled work | Links open the correct policy/terms; no implicit consent or upload; deletion retains recordings/overlay, unresolved remote work stays guarded across relaunch | F13 implemented; exact candidate physical presentation pending; retention/auth-loss permutations remain deterministic fixtures |

Do not deliberately exhaust real quota, damage a channel, or publish an event to manufacture 401/403/429/5xx cases. Verify these with deterministic fixtures or a reviewed app fault harness when one exists; on-device presentation is a later F10 check.

### Batch 3 — local camera, overlay and file quality

| ID | Check | Expected result / evidence | Availability / trace |
| --- | --- | --- | --- |
| L01 | 1080p30 and 720p30: preview, short original recording, stop, playback and original Files export | 1920×1080/1280×720 landscape canvas respectively, H.264/AAC, identity orientation, correct aspect ratio and common composition; export does not transcode | Available; F4/A1/A5/A8 |
| L02 | Physical clap markers at beginning/end of each quality sample | Retain synchronized visual/audio events for numerical offset and uncertainty; target ≤100 ms where applicable, never infer physical sync from track endpoints | Available; M3/A7 measurement support |
| L03 | Change profile before capture; attempt changes during preparation/preview/recording/finalization | Profile persists for next launch and remains frozen for active capture; components do not mix canvas dimensions/bitrate/profile | Available; F4 |
| L04 | Wide and available Ultra Wide choices, supported zoom, reopening capture | Only real compatible rear lenses offered; wide default; truthful zoom limits; no lens change while recording; no extra capture session | Available; F4 and owner lens extension |
| L05 | Mute/unmute, meter, built-in route and an available supported accessory route | Meter is bounded/responsive; original file proves actual audible mute/unmute, no timing discontinuity; route label updates honestly | Local and both-output phone audio proof pending |
| L06 | Transparent changing overlay, text/logos/alpha edges, two-second source reloads | Same overlay in composed preview and saved file, correct exact canvas at both profiles, changing score visible, no white/blank flashes or app controls | Available; A1 |
| L07 | Brief overlay failure, healthy unchanged score, two-minute source failure, cached content during failed source access | Last-good grace, hide at ten seconds without confirmed source/render health, local A/V continues; cached raster alone cannot count as fresh | Available; M4/A4 |
| L08 | Source recovery while manually hidden; unhide afterwards | Fresh image returns only when health recovers and manual-hide precedence permits; preview and file agree | Available; M4/A4 |
| L09 | Saved URL foreground/relaunch recovery, failed navigation/WebKit recovery, disabled overlay, invalid draft/cancel/Apply | Current automatic overlay recovery and secure disabled/draft rules preserved; stale callbacks cannot resurrect disabled or replaced sources | Available overlay behavior |
| L10 | Repeated start/stop; inspect complete, interrupted and failed entries | Independent playable/exportable originals; honest size/status; no automatic deletion or false “complete” | Available; A5/A6 |
| L11 | Play/Files export; Delete Cancel; deliberate confirmed deletion of one owner-designated expendable NEW test file only | Cancel keeps it; confirmed deletion affects selected original/metadata only and exported copy remains. Never delete valuable or failed originals as cleanup | Available; explicit per-file owner action |
| L12 | Privacy link and bundled notices on installed app | Correct published policy opens; Google/dependency disclosures match build; no unnecessary Photos access | Available; F13/A9 |

The existing automated camera harness uses its explicit default 1080p profile and a visible attached overlay host. It does not replace manual 720p checks or the actual app's covered-host overlay test.

### Batch 4 — safe ingestion and whole broadcast

The integrated F7 operator flow now exists. Use a dedicated eligible event and current reviewed candidate; physical binding/RTMPS/lifecycle acceptance remains pending. The owner is not expected to write Swift or issue raw API commands. Test manual/auto-start variants in separate selected visits.

| ID | Check | Expected result / evidence | Availability / trace |
| --- | --- | --- | --- |
| B01 | Reuse an eligible inactive compatible existing binding | Identity/profile/security checks pass; no new stream or unwanted event mutation | Integrated; Service-gated physical check pending |
| B02 | Explicitly prepare an unbound dedicated event; create/bind and read back | One non-reusable app-owned stream, durable ID/phase before ambiguous outcomes, verified RTMPS endpoint; no insecure fallback or key persistence/logs | Integrated; Service-gated physical check pending |
| B03 | Prepare a second event after successful first preparation, then relaunch | Completed intent cannot permanently block later events; unresolved creation remains guarded; retry cannot create duplicates | Integrated; fixture regression plus safe physical check pending |
| B04 | Ambiguous create/bind, cancellation, stale account/profile, incompatible binding, auto-stop enabled | Read/reconcile before retry; unknown creation blocks duplicate insert; unsupported event stays blocked with explanation; operator state preserved | Fault harness/fixtures first; safe real reconciliation only |
| B05 | Confirm Go Live for correct channel/title/visibility; auto-start on/off variants | Recorder initialization succeeds before any upload; selection/preview alone never publishes; “Live” requires confirmed YouTube state | Integrated; A3/A6 physical check pending |
| B06 | Receiver and local file show changing alpha composition, audible mute/route and physical markers, both profiles | Same composed media, no app buttons/alerts; documented single encoder ownership; inspect actual receiver and original file | Shared native path implemented; A1/A3/A4 physical evidence pending |
| B07 | Startup/API reject/timeout or transport connect rejection | Healthy local recording continues; no false Live state; writer initialization failure sends zero camera media | Integrated; A4/A6 physical check pending |
| B08 | Two-minute REAL phone internet outage, restoration and bounded retry exhaustion | Local file remains continuous; queue/high-water limits finite; reconnect only same eligible event; no silent duplicate event or stop of healthy writer | Integrated; A4 physical check pending |
| B09 | Remote event completed/deleted/otherwise ineligible while local capture is healthy | Upload/reconnect stops as appropriate; local recording continues with clear remote state; no auto-switch to another event | Integrated; A4/A6 physical check pending |
| B10 | Inject local writer initialization, append and finalization faults separately | Initialization blocks initial Go Live; after live, healthy upload continues with persistent backup-failed warning; retain partial/original files honestly | Integrated; fixtures first, A4/A6 physical check pending |
| B11 | Confirm End; duplicate taps/cancel; delayed, failed or hung remote end request | Bounded local shutdown, file finalization, truthful confirmed/unknown remote result; reconcile before retry. Never label socket close as remote completion | Integrated; A3/A6 physical check pending |
| B12 | Account/event/profile/URL changes during active broadcast | Frozen session settings; end-first account flow, no cross-account late results or secret exposure | Integrated; physical state/locked-control check pending |
| B13 | Wi-Fi → cellular → Wi-Fi path switch, where available and the owner permits mobile-data use | Local file remains continuous; any reconnect stays on the same eligible event, transport/remote labels remain truthful; record path-change times and receiver continuity separately from total internet loss | Integrated; A4/A8 physical check pending |

Default/reusable stream keys are supported without a per-event dedicated key in
the corrected build. Reuse of a key by another scheduled event is not itself a
blocker. The existing initial inactive-ingestion check remains. Concurrent key use
and sibling auto-start mitigation are deferred in
[issue #65](https://github.com/smith3v/stream14/issues/65); this plan does not claim
exclusive ownership or coordinated protection against those races.

B08 requires loss of the PHONE'S internet connectivity. Disconnecting USB, changing only the laptop's network, or the WebKit-only request block does not establish upload outage behavior. Keep capture foreground; do not combine background interruption with this test.

### Batch 5 — interruptions, permissions, recovery and final cleanup

Run disruptions serially after normal recording/broadcast evidence. Restore the original permission, network, text-size, VoiceOver and audio-route settings before leaving.

| ID | Check | Expected result / evidence | Availability / trace |
| --- | --- | --- | --- |
| I01 | Current injected writer init/append/finalize faults and injected capture/audio-inactive notification | Failed/interrupted durable state, retained files, explicit restart and original idle-timer state restored; injection is not a real incoming call | Fixtures implemented; actual healthy-output physical independence pending |
| I02 | Home, lock/unlock and foreground return during a NEW short recording | Capture stops/finalizes within available time; no background-camera promise, silent auto-resume or auto-publish; manual restart creates new file | Whole-session flow implemented; physical check pending |
| I03 | Real audio interruption/route removal where feasible, capture runtime failure and cancellation during setup/stop | Honest UI/file state, no leaked capture/encoder/session; fresh explicit resume and correct route; no warning sound recorded by app | Whole-session flow implemented; select one physical interruption variant |
| I04 | Serious/critical thermal decision injection and ordinary real thermal observation | Reduce overlay work first; critical state stops safely; no silent resolution change. Injected decisions are not proof of real heat tolerance | Whole-session/diagnostic decisions implemented; injection is not heat qualification |
| I05 | Camera denied, microphone denied, both denied; grant again in Settings | Distinct actionable state; no false successful media; local/export functions remain available where possible; no app uninstall/privacy reset | Available manual phone checks; Simulator denial automation is separate |
| I06 | Local sign-out, restore/reconnect, explicit revoke, revoked/expired consent and failed revoke reporting | SDK-owned state clears honestly; no event/key leak or media resume; recordings/overlay remain; do this after remote event is confirmed ended | Historical sign-out/revoke verified; new deletion/Studio guards and other variants pending; F2/A6 |
| I07 | Forced termination before first movie fragment, after completed fragments and during finalization | Preserve original/pending metadata; relaunch never calls incomplete file complete; supported recovered copy is separate and measured; no transcoding or automatic cleanup | F11 implemented; A5 physical check pending; dedicated NEW files only |
| I08 | Export finalized originals and supported private metrics; inspect audio/video reads, timestamps/gaps, markers, bytes/status and receiver capture | Evidence tied to exact run/build; finite queue/memory observations; diagnostics redact tokens, keys, private URLs and account/tester information | Native inspection implemented; current phone export/receiver evidence pending |
| I09 | Final reconcile and restore | Test event confirmed ended, camera/mic stopped, idle timer normal; retained originals/evidence inventoried, no pending automatic retries/publishing | Integrated; verify actual local and remote state after each run |
| I10 | Short 13 mini run measuring the actual app instrumentation overhead against a documented comparable control | Record cadence/drops, memory/queue/task/disk growth and collection cost under the same profile/conditions; inspect the real exported diagnostic artifact and explain baseline/method limitations. A hosted test alone is insufficient | F12 implemented; prepared comparable short phone measurement pending; routine total ≤5 minutes |

Do not fill the phone to simulate disk-full. Use the reviewed fault injection. Do not kill/uninstall an app with valuable active recording. Crash tests use newly created expendable test sessions with explicit operator intent and preserve every original. If the remote event might still be live after interruption, reconcile/end it explicitly in the supported flow or Studio before leaving.

## Existing targeted commands — not the default five-minute batch

Run from the selected integrated worktree with ignored local signing configuration. Codex reads the private identifier from devicectl; no identifier/team/token belongs in Git or public evidence. Use a new run/result path on every attempt.

Validate the warmed package cache pin against the selected Package.resolved before reusing it; cache location is not version evidence. The helper below is a command template for Codex, not an installed project script. It intentionally selects ONE test at a time. Shared-scheme build/branding and normal signing must run before installation; for a reused xctestrun verify those products were branded and normally signed first. Never run concurrent window-owning/camera tests merely because xcodebuild offers parallel workers.

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
    -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
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
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  -only-testing:Stream14Tests/ShortPhoneSmokeTests \
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
  -only-testing:Stream14Tests/ShortPhoneSmokeTests \
  -resultBundlePath "$STREAM14_EVIDENCE/short-phone-smoke.xcresult" \
  test-without-building
~~~

Before phone time, enumerate the prepared products and require exactly one enabled short-smoke test. The bare method selector without parentheses previously selected zero tests; use the suite selector above. After execution require one passed test and zero skips, not merely process exit zero.

The harness requires pre-authorized camera/microphone and the physical 13 mini; it does not wait for permission prompts. Debug-only host isolation avoids saved overlay URLs and Google SDK/account initialization. Simulator, default and Release runs skip, so a skip is NOT a phone pass. Two clips share a 50-second internal deadline, a one-minute cooperative test limit and the configured 90-second runner watchdog. Native calls are not assumed interruptible; Codex still owns the overall five-minute wall-clock stop/report decision. Originals are retained. File/decoded-marker checks do not prove physical sync, audible unmute, real network behavior or endurance.

See the [short-smoke handoff](2026-11-07-short-phone-smoke-implementation.md) for actual compile/regression evidence and limits. Do not run the legacy catalogue in addition to the smoke merely to fill coverage.

### Legacy targeted catalogue

Inspect each exit status/result before the next call; stop on an unexpected failure. Select at most one relevant short legacy command for a targeted visit; these examples are a catalogue, not a combined unattended script. Ensure camera/microphone permission prompts are resolved and owner/private scene are ready before camera checks.

~~~sh
# Reference website only; no camera recording. Requires its current public fixture.
TEST_RUNNER_STREAM14_REFERENCE_TEST=1 \
  device_test 'Stream14Tests/WebOverlayRendererTests/referencePageReloadEvidence()' reference

# Short legacy reference sample plus changing-fixture/repeated-recording follow-ons.
# This setting does NOT cover the two-minute outage/manual-hide sequence.
TEST_RUNNER_STREAM14_DEVICE_RECORDING=1 \
TEST_RUNNER_STREAM14_RECORDING_SECONDS=30 \
  device_test 'Stream14Tests/MediaDeviceTests/combinedDeviceRecording()' local-composition

# Separate short writer faults and notification-path interruption checks.
TEST_RUNNER_STREAM14_DEVICE_FAILURES=1 \
  device_test 'Stream14Tests/MediaDeviceTests/deviceWriterFailuresAndInterruption()' local-faults

# Actual app UI camera/lens/short-record/playback check; iPhone 13 mini expectations.
TEST_RUNNER_STREAM14_DEVICE_LENS_UI=1 \
  device_test Stream14UITests/SetupScreenTests/testDeviceRearLensSelector lens-ui

# Actual Home transition and playback; does not substitute for manual lock/call.
TEST_RUNNER_STREAM14_DEVICE_UI=1 \
  device_test Stream14UITests/SetupScreenTests/testDeviceBackgroundFinalizesAndPlaybackOpens background-ui
~~~

The combined harness's longer outage path blocks WebKit DOCUMENT requests, not upload/all phone radios. Its fixed 1080p profile does not exercise 720p. At least 180 seconds enables its two-minute source outage; 600 seconds enables its old manual-hide/recovery branch. Those modes are NOT the five-minute default and must not launch automatically. The short setting and new two-profile smoke do not prove that long outage branch. Follow-on files and runner/setup time count toward the session budget.

The existing F1 two-encoder private candidate is historical architecture evidence, not the selected current single-encoder production path or a default next test. Only enable after the receiver/event and private destination are explicitly approved for that run. Supply TEST_RUNNER_STREAM14_PRIVATE_RTMPS_URL and TEST_RUNNER_STREAM14_PRIVATE_STREAM_KEY through the private local test environment, never a recorded command/history or committed file. Test environment copies, xctestrun, xcresult and logs can contain configuration and must stay private.

~~~sh
TEST_RUNNER_STREAM14_DUAL_OUTPUT=1 \
TEST_RUNNER_STREAM14_DUAL_OUTPUT_SECONDS=30 \
  device_test 'Stream14Tests/DualOutputFeasibilityTests/privateDeviceDualOutputCandidate()' f1-private-candidate
~~~

This candidate clamps its requested loop to 12–600 seconds and uses two encoders. Its one-second reconnect and isolated writer-failure probe are NOT proof of B08/B10, common encoded fan-out, finite socket queues or physical sync. Do not run it against an ordinary public event.

The F6 SharedEncodingPrototypeTests suite is experimental. At checkpoint 9753224, both synthetic Simulator tests pass: native single-encode fan-out into two files, codec packet bytes with explicit AAC trim-origin handling, decoded midpoint markers within 35 ms, and bounded sender/retained partial-consumer checks. This is not physical sync, real socket delivery or production acceptance. If a specific native-device API gap still justifies it, select Stream14Tests/SharedEncodingPrototypeTests for a separate prepared visit; do not repeat an architecture suite merely to fill the backlog. It uses generated media and no camera/network. Earlier failed results are retained; never label this proof of the full F6 acceptance gate.

Other fixture-driven hosted tests and Simulator-only seeded deletion/recording-layout/denied-permission tests do not need this phone session. Do not carry their fixture IDs or Simulator privacy-reset commands onto the owner's phone.

## Later TestFlight and longer qualification

These are unverified requirements, not an extension of the five-minute visit. Each selected Q01/Q04 check remains readiness-gated work within one card budget; the whole matrix cannot fit one visit. Q02/Q03 and any run exceeding that budget need a separate explicit agreement; never extend automatically.

| ID | Required run | Conditions / pass evidence | Availability |
| --- | --- | --- | --- |
| Q01 | Install actual full-app TestFlight candidate and complete selected regression cards across visits | Delivered build/version and policy/notices (S0), selected private end-to-end (S1), local audio/export and interruption gaps (later cards); not all in one visit. Xcode install does not pass A9 | F13 delivery pending; A9 exact-build physical checks pending |
| Q02 | Agreed 30-minute compositing/recording qualification, both selected profiles as required by the final matrix | <1% measured pipeline drops, no repeated stalls ≥500 ms, no monotonic memory/queue growth; start/end physical markers and delivered-app metrics with limits | Separate explicit agreement; F14/A2 |
| Q03 | Agreed powered three-hour 1080p30 simultaneous broadcast + local backup on 13 mini | A2 quality targets, physical A/V offset ≤100 ms at start/end, receiver and original analysis, stable qualified network; record mount/case/power/brightness/ambient/airflow, first without external cooling | Separate explicit agreement; F14/A7 |
| Q04 | Available iPhone 15/17 representatives and relevant Pro variants | 720p/1080p, real route/interruption/background/VoiceOver/larger-text/play/export/cancel checks; no required Pro-only behavior | F14 pending; unavailable representatives remain explicit acceptance gaps |

A1–A9 inventory mapping (all full-product gates remain pending for the delivered candidate): A1=L01/L06/B06; A2=I08/I10/Q02; A3=G03/B05/B06/B11; A4=L07/L08/B07–B10/B13; A5=L10/L11/I07/I08; A6=P03/G01/G04/G07/B04/B07/B10/B11/I01–I06; A7=Q03; A8=P04/P05/L01/L04/L05/B13/I02/I03/Q04; A9=P01/L12/I10/Q01. Preserve earlier MVP evidence and its measurement limits; no new row is passed by a historical build.

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
