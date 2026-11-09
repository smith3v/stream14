# Attended iPhone session cards

Updated: 2026-11-09. Each routine visit is **five minutes TOTAL**, including
installation, permission/account prompts, actions and wrap-up. Choose ONE card;
these are separate visits, not a combined test script. Laptop builds, fixtures,
selector enumeration and analysis-tool preparation happen first. Stop and record
INCOMPLETE/BLOCKED if setup consumes the budget; never extend automatically.

## Evidence and prerequisites

- The [shared-pipeline local smoke](2026-11-08-shared-pipeline-device-smoke.md)
  passed on the 13 mini: one executed test, zero failures/skips, 10.173-second body.
  It predates the current RTMPS correction, interface, recovery and diagnostics.
- The owner verified intended channel/event, restore after relaunch, local sign-out
  and revocation in the [account report](2026-11-08-attended-account-event-results.md).
  Issues #15/#16 are closed. Do not repeat that whole checklist just for coverage.
  The app was left disconnected: the next account-enabled run needs deliberate
  reauthorization and the new YouTube policy agreement.
- Main includes the monitor/testing transition, native Session/Recordings UI and
  separate-copy recovery. [PR #58](https://github.com/smith3v/stream14/pull/58) adds
  diagnostics; [PR #59](https://github.com/smith3v/stream14/pull/59) adds reviewed
  policy/retention preparation. Merge in that order before using their main build.
  The later [full-app TestFlight candidate](2026-11-09-full-app-testflight.md) has
  not yet been delivered; historical 0.2 (3) TestFlight is the local-only app.
- The last installed development app was `f454e9b`, before the monitor correction.
  Use a newly prepared, normally signed, exact-source candidate. Record Xcode vs
  TestFlight explicitly; development evidence does not pass A9.
- Check actual USB/unlocked readiness at the visit; an earlier connected-phone
  report is not current availability or publishing consent. Auto-Lock Never and
  Low Power Mode off can help foreground tests; restore owner settings afterwards.

## Laptop preflight for every card

1. Select reviewed source/build and prepare normal signing/branding in advance.
   Retain the current recording inventory; update in place, never uninstall/reset.
2. Pick one card and state the intended media, disruption and event use. Ask for
   operator confirmation before publishing, intentional lock or forced termination.
   Aim camera at a non-private test scene. The owner handles credentials/consent;
   never request passwords, passcodes, codes, tokens or stream keys in chat.
3. For streaming, privately recheck intended channel/title, Unlisted visibility,
   encoder eligibility, monitor setting, auto-start/auto-stop and dedicated safe
   binding. The previous `test app 1` was Unlisted, auto-start Off, auto-stop Off;
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

## Card S1 — next priority: short Unlisted end-to-end

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

## Later cards — choose by the remaining gap

Each row is its own <=5-minute visit. Allow about 45 seconds readiness and at least
60 seconds wrap-up; drop optional actions first. Preflight-dependent variants may
require their own S0 visit. Use the full [coverage inventory](2026-11-07-connected-iphone-test-plan.md)
for exact IDs and expected results.

| Card / coverage | Selected short action / required observation |
| --- | --- |
| S2 composition/audio: L01–L06, A1/A8 | One selected profile, short local clip with alpha/reloads, visible clap and spoken/muted/spoken phases. Inspect actual zoom/lens and frozen profile controls. Retain original for off-phone decode/audio/sync; run the other profile later only if still missing |
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
