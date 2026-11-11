# Attended iPhone session cards

Updated: 2026-11-11. Each routine visit is **five minutes TOTAL**, including
installation, permission/account prompts, actions and wrap-up. Choose ONE card;
these are separate visits, not a combined test script. Laptop builds, fixtures,
selector enumeration and analysis-tool preparation happen first. Stop and record
INCOMPLETE/BLOCKED if setup consumes the budget; never extend automatically.

## Evidence and prerequisites

- Historical [shared-pipeline local smoke](2026-11-08-shared-pipeline-device-smoke.md) passed on 13 mini/F8 `20a0035`: one executed pass, zero failures/skips, 10.173-second body. It predates later RTMPS, UI, interruption, recovery and diagnostics changes.
- The 13 mini has Development 0.3 (4) from PR #70 head `5e11ac6`. The owner confirmed the brighter green Start action and automatic reconnection to the saved YouTube account. The owner previously confirmed the More flicker fix on `4c097ae`. [PR #63](https://github.com/smith3v/stream14/pull/63) merged at `5f2d5c7` and [PR #70](https://github.com/smith3v/stream14/pull/70) merged at current main `f69f24a`.
- [Account evidence](2026-11-08-attended-account-event-results.md) covers OAuth callback, intended channel, restore, sign-out and revoke; #15/#16 closed. Verify current state and reauthorize/agree policy only if needed, not because an earlier checkpoint ended disconnected.
- [Short Unlisted development run](2026-11-10-default-key-phone-test.md) passed Live/End, receiver composition/speech and local playback on `625df2a`; #18/#20 closed. Default/reusable keys are supported, with no dedicated-key prerequisite; retain current safe selected-event gates and auto-stop Off. This does not qualify current UI or final TestFlight.
- #58/#59 are merged. Full-app TestFlight 0.3 (4) was delivered and owner-installed; that older source is not the corrected Development UI. The owner deferred a new release/regression; no upload/version change is scheduled.
- The next visit is [S2](#card-s2--local-recording-on-the-installed-development-build), pending explicit owner agreement to a local recording of a non-private scene. Broader physical interface/accessibility and receiver acceptance remains open.
- For visits that need the Mac, recheck USB/unlocked readiness and operator consent. Restore any changed Auto-Lock/Low Power settings afterwards. A prior connected report is not current readiness.

Use the [latest development handoff](ios-development-guide.md#installed-development-build-and-next-local-visit--2026-11-11) and [current A1–A9 audit](2026-11-07-epic13-progress.md#current-acceptance-audit--2026-11-11). Current UI is Session/Recordings with More → Settings; older Preparation click scripts and dated readiness wording in the preserved S0–S9 procedures below are historical. Apply the current prerequisites above. Deferred #65 shared-key mitigation and draft #69 custom A/V tooling are not dependencies; existing Analyze/manual markers suffice. Longer A2/A7 qualification remains unagreed; development recordings remain capped at 15 minutes.

## Laptop preflight when needed

1. Select reviewed source/build and prepare normal signing/branding in advance.
   Retain the current recording inventory; update in place, never uninstall/reset.
2. Pick one card and state the intended media, disruption and event use. Ask for
   operator confirmation before publishing, intentional lock or forced termination.
   Aim camera at a non-private test scene. The owner handles credentials/consent;
   never request passwords, passcodes, codes, tokens or stream keys in chat.
3. For streaming, privately recheck intended channel/title, Unlisted visibility,
   encoder eligibility, monitor setting, auto-start/auto-stop and compatible inactive
   binding. The corrected build supports the existing/default key; no separate key
   is required merely because another scheduled event shares it. The previous `test app 1` was Unlisted, auto-start Off, auto-stop Off;
   that old observation does not establish today's state. Prepare a second-device
   receiver/player before the clock. Use no real match or valuable event.
4. Prepare private evidence paths and a wrap-up route. If remote state is unknown,
   preserve that status and reconcile/hand off Studio action; do not claim End.
   Never abandon a potentially live event simply because the clock expired.
5. At 4:00 start wrap-up; at 5:00 record what actually finished, what remains open
   and any operator handoff. No further test starts. Retain originals/copies.

## Card S0 — setup or TestFlight identity only

Budget: 0:00–3:30 install/update and verify exact version/build/route, accept
necessary device prompts, inspect policy/notices links, then deliberate policy
agreement and Google reauthorization if time permits; 3:30–5:00 record readiness
and close. Leave Go Live untouched. If install/account setup is slow, this is the
whole visit. A9 still needs actual full-app TestFlight delivery and regression.

## Card S1 — short Unlisted end-to-end

Only select after installation/account/event/receiver preflight is ready. A fresh
sign-in or event repair that consumes the slot replaces this card with S0.

| Budget | Operator action and observable evidence |
| --- | --- |
| 0:00–0:45 | Verify installed identity, intended channel/title/Unlisted visibility and explicit permission to send camera/microphone media and use/end this test event. Confirm Go Live in the app |
| 0:45–2:30 | Observe separate recording/upload/YouTube labels. Monitor-enabled events pass through testing; Testing/socket-connected alone is not Live. Wait for confirmed Live and second-device playback; observe changing overlay and audible speech, with visible/audible beginning/end claps if feasible |
| 2:30–3:30 | Confirm End in the app. Require actual confirmed remote completion or record uncertainty and reconciliation; inspect retained file/finalization status separately |
| 3:30–5:00 | Brief original playback and explicit original/diagnostic export if time remains; record receiver result, stopped capture and retained-file inventory. Defer exports if they would exceed the budget |

A slow transition/receiver means INCOMPLETE, not a pass or an extra five minutes.
This establishes only observed portions of A3/A1/A5/A9. Off-phone analysis measures
original/receiver sync with uncertainty; track endpoints or a socket do not prove it.
One run does not cover both profiles, auto-start variants, failures or endurance.

## Card S2 — local recording on the installed Development build

The owner operates the installed 0.3 (4) build from `5e11ac6` after explicitly
agreeing to record a non-private test scene. Five minutes total, including any
prompts and playback. Use **Record only**. Keep the originals in Recordings.

| Budget | Operator action and observable evidence |
| --- | --- |
| 0:00–0:45 | In **Session**, note the current profile. Tap **Check camera and sound**. Look for the composed preview, overlay if already configured and healthy, and the microphone input label and moving level meter. |
| 0:45–2:00 | Tap **Record only** for about 20 seconds. Say a short phrase, tap **Mute microphone**, repeat it, tap **Unmute microphone** and repeat it again. If convenient, move **Camera zoom** on the rear Wide lens and rotate through both landscape directions. Look for the full preview left and scrolling controls right. Check that Upload stays idle while Local saving shows recording. Tap **End session**, then **Stop local recording and capture**. |
| 2:00–4:00 | Open **Recordings** from the portrait tab or **More → Navigate → Recordings** in landscape. Play the new file and listen for audible speech before and after mute and silence in between. Check that expected zoom/overlay changes are present, the picture stays correctly oriented, and app controls stay outside the video. |
| 4:00–5:00 | Confirm the new original remains in Recordings. Note the profile, playback result and skipped checks. If finalization is slow, prioritize preserving the file and record playback as pending. |

If time and the owner’s agreed scope allow, choose at most one optional check
before wrap-up. For the other profile, use **Prepare next session** after
finalization, select **1080p30 · 14 Mbps** or **720p30 · 8 Mbps** while the camera
is closed, then check camera and sound, record a short clip and end the session. Alternatively,
use the recording’s **Export original recording → Save to Files**, or use **Load
qualification summary → Export qualification summary** to retain the JSON
privately. Visible and audible claps near the start and end are optional when
practical and unmuted. Markers enable later measurement of A/V offset.

- For #17, record the observed profile, physical zoom, input label, meter,
  audible mute, orientation, overlay and playback. File codec and dimensions
  require original-file analysis. Track any untested profile, Files export,
  accessory route or interruption as pending. [Issue #17](https://github.com/smith3v/stream14/issues/17)
- For #62 and #23, record observed portrait/landscape operation at normal text
  size, local start/finish, the two status labels and whether UI controls are
  absent from the local file. Largest text, VoiceOver, failure states and
  current receiver behavior need separate evidence. [Issue #62](https://github.com/smith3v/stream14/issues/62) · [Issue #23](https://github.com/smith3v/stream14/issues/23)
- For #25, inspect the actual exported summary privately if collected. Overhead,
  bounded resource behavior and exact A/V sync require separate measurements.
  [Issue #25](https://github.com/smith3v/stream14/issues/25)

## Later cards — choose by the remaining gap

Each row is its own <=5-minute visit. Allow about 45 seconds readiness and at least
60 seconds wrap-up; drop optional actions first. Preflight-dependent variants may
require their own S0 visit. Use the full [coverage inventory](2026-11-07-connected-iphone-test-plan.md)
for exact IDs and expected results.

| Card / coverage | Selected short action / required observation |
| --- | --- |
| S3 overlay outage: L07–L09, A1/A4 | New local clip: brief source failure, then >10-second failure, manual hide through source recovery and explicit unhide. Observe preview/file freshness and continuous A/V. A source-only block does not establish upload outage |
| S4 upload outage: B08/B13, A4 | Dedicated already-ready Unlisted run: one REAL two-minute phone internet loss, restore, observe same-event reconnect/local continuity, then End/reconcile. Budget roughly 0:00–0:45 start, 0:45–2:45 loss, 2:45–3:45 restore/observe, 3:45–5:00 End/wrap. If readiness or retry delays prevent this, leave the remaining gate pending. Retry exhaustion and Wi-Fi/cellular switching are separate variants; mobile-data use needs owner agreement |
| S5 interruption: I02/I03, A6/A8 | One explicit Home OR lock OR available real audio-route/interruption action during a new short session; confirm honest stop/finalization, no silent camera restart/upload, and explicit same-event resume/new file if budget permits. A YouTube event can remain live: reconcile/end separately within wrap-up. Do not initiate a call automatically |
| S6 recovery: I07/L10/L11, A5 | One NEW expendable local recording, explicit force-termination at one selected point, relaunch/inspect, Try recovery to separate copy if supported. Original stays unchanged; retain copy and measure playable prefix/lost tail off-phone. Before-first-fragment, after-fragment and finalization points are separate variants; recovery/export may require a later visit |
| S7 accessibility: P04/P05/G05, A8 | ONE changed screen/state in portrait/both landscapes with large text OR physical VoiceOver navigation; check labels, focus, controls and cancellation. Restore settings. Select remaining screens/states later; Simulator audit is not physical VoiceOver |
| S8 diagnostics: I08/I10, #25/A2/A9 | Short local sample and deliberate Load/Export qualification summary plus original export; inspect saved phone JSON privately. A separately prepared comparable control can assess overhead in another bounded visit; record device method/uncertainty and restore shipping candidate. Numeric model fixtures do not measure phone overhead |
| S9 failure presentation: B04/B07/B09–B12/I01/I04–I06, A4/A6 | ONE safe prepared failure variant: startup rejection, remote end, writer failure, unknown End, denial or expired access. Use deterministic fixtures for destructive/quota/rate-limit cases; no quota exhaustion, disk filling or secret exposure. Verify any physical healthy-output independence claimed. New deletion/Studio-resolution policy controls need their own selected attended check after events are settled |

All cards retain originals. Play/export does not authorize deletion. Delete Cancel
and deliberate deletion apply only to an owner-designated expendable file with its
separate confirmation. Never run Simulator seeding/privacy-reset scripts on the phone.

## Deferred qualification and result record

The formal A2 **30-minute** run and A7 **three-hour** powered 1080p30 broadcast/local
run remain pending, with separate explicit agreement for their exact time and
markers. Five-minute samples, fake clocks and synthetic numeric models do not replace
those gates. Available iPhone 15/17/Pro coverage also remains pending; a 13 mini
cannot substitute. Use the [qualification report](qualification-report-template.md)
for measurements and scope limits.

For every visit record source/installed version/route/device/OS/profile, actual total
time, selected checklist IDs, pass/fail/blocked/skipped, private original/receiver/
JSON evidence, executed/skipped counts where automated, restored settings, remote
state and next step. No raw credentials, private event links or media go in Git.
A zero-test/physical-skip result is not a phone pass. For the optional local-only
short harness require exactly one enumerated/executed pass and zero skips, using
its prepared branded products; it is not the default next broadcast card.
