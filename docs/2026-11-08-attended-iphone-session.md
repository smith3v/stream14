# Attended iPhone session card

Updated: 2026-11-08. Purpose: prepare the checks that need the owner's taps or observations. Default visit: five minutes TOTAL; builds, selector verification and fixture tests happen on the laptop first. Select the minimum useful checks, not the whole coverage backlog.

## Current readiness

- iPhone 13 mini is connected; the owner confirmed unlocked/ready and set Auto-Lock to Never. Keep Low Power Mode off while testing.
- Reviewed short-smoke code is in PR #47. Normally signed Debug app and embedded hosted test bundle are prepared.
- The first phone invocation selected ZERO tests and made no camera recordings. Exit code zero was not a pass. The cause was a Swift Testing method selector missing parentheses.
- Off-phone Xcode enumeration now confirms that suite selector Stream14Tests/ShortPhoneSmokeTests selects exactly one method: twoProfilesRetainComposedOriginals(). No tests ran during enumeration.
- Actual short-smoke capture and physical timing remain pending. Codex must check one executed/passed test and zero skips after the real run, not just xcodebuild's exit code.
- Public Google iOS client/callback are configured in ignored local build configuration; actual owner sign-in, SDK restore and API-returned channel have not been verified.
- Broadcasting/reconnect/recovery UI is not ready for owner acceptance yet. Do not ask the owner to test missing Go Live/End/Recover controls or issue raw API commands.

## Suggested next five-minute visit

| Budget | Codex does | Owner does / success to observe |
| --- | --- | --- |
| 0:00–0:30 | Confirms prepared build, Trust/permissions and exact selector; no build/resolve at phone time | Keep phone unlocked, connected, aimed at a non-private test scene. Accept Trust/camera/microphone prompts if needed. If Developer Mode/reboot/setup is needed, record BLOCKED and stop within budget |
| 0:30–1:45 | Runs ONLY the isolated local short smoke using prepared Debug products; inspects executed/skipped result counts | No taps during the automated run. Two short camera/microphone clips are expected; no Google, website or upload. Codex retains the originals |
| 1:45–2:00 | Relaunches the normal app WITHOUT the short-test environment, restoring ordinary setup controls | Confirm the normal Connect YouTube control is shown; the isolated test host intentionally has no account driver |
| 2:00–4:15 | Guides Connect YouTube, then read-only Refresh; does not select/mutate a real event or publish | Complete Google's system-browser account/consent prompts yourself, then tap Refresh and verify the intended YouTube channel. A Google email/“authorized” message alone is not channel verification |
| 4:15–5:00 | Records callback/channel result, brief playback/report if time remains, stops capture and reconciles any open activity | Report the visible channel or safe error text. Leave passwords, 2FA codes, tokens and keys out of chat. Restore ordinary Auto-Lock when no further unattended testing is planned |

If consent/2FA takes longer, stop at the five-minute budget with the achieved state and pending steps recorded. Do not keep retrying account selection or silently extend the visit. If sign-in is not wanted in this visit, replace it with ONE short manual media observation below.

## Owner-attention checks and priorities

| Priority / check | Exact owner action | Codex verifies | Availability |
| --- | --- | --- | --- |
| Required readiness | Unlock once, accept Trust if shown; allow camera/microphone when intentionally opening capture | Device connection and permissions, normal signature; no app uninstall/reset | Ready to check |
| Google sign-in and callback | Tap Connect YouTube; choose intended account/channel; complete consent/2FA in the supported browser | App returns from callback with required scope; no overlay-WebView authentication, no implicit publish | Ready, owner required |
| Real channel/event read | Tap Refresh; confirm intended YouTube channel and any event title/date/visibility | API-returned identity and eligible state, clear empty/wrong-channel/error result; reads do not mutate events | Ready after authorization; no event is required merely to verify channel |
| Restore after relaunch | After Codex relaunches normal app, tap Restore saved connection | SDK-owned Keychain state restores without implicit camera or upload | Ready after successful sign-in, if time remains |
| Audible mute and short playback | Say a short phrase when prompted; observe mute/unmute and listen to one NEW test recording | Actual audio evidence, not a claim inferred from meter/track existence | Targeted alternative to sign-in |
| Physical A/V marker | In a separately selected ~15-second manual clip, clap with hands visible at beginning/end when prompted | Off-phone numerical marker alignment and uncertainty; the automated red/green smoke does NOT prove physical sync | Targeted alternative, budget permitting |
| Lens/route observation | Confirm actual Wide/Ultra Wide appearance or connect/remove an available headset when prompted | Truthful lens/zoom/route and original-file result | Select one when relevant; do not repeat all permutations |
| VoiceOver/larger text | Enable VoiceOver or largest text only while present; navigate the few changed controls, then restore settings | Correct labels/values/focus and important targets; do not leave owner stuck in an altered accessibility state | Targeted, not alongside all other tests |
| Home/lock/interruption | Press Home/lock only when specifically prompted; unlock again afterwards | Honest interruption/finalization and explicit resume; original file retained | Targeted; cannot run unattended |
| Sign-out/revoke/account switch | Confirm the explicit app action only after any event is ended | Honest SDK state clearing, no recording/overlay loss; revocation is not part of unattended smoke | Targeted after sign-in; changes access intentionally |
| Confirm Go Live/End | Verify channel/title/visibility; explicitly confirm intended start/end of a dedicated unlisted test event | Actual remote state and receiver result, healthy independent file | FUTURE: F7 flow and dedicated event/receiver not ready yet |
| Crash recovery | Confirm a new expendable test session/termination, then inspect supported recovered copy | Originals retained, measured loss and truthful incomplete/recovered status | FUTURE: selected compressed-writer/app recovery and device A5 not ready |

No incoming call is initiated automatically. No Google password, passcode, 2FA code or stream key is requested in chat. Existing valuable recordings are never deleted/reset as test preparation. A new expendable file is deleted only through the separate deliberate per-file confirmation if the owner chooses it.

## Codex preflight before requesting attention

1. Select the reviewed source and prepare normally signed/branded Debug products OFF-PHONE. Check the embedded bundle at Stream14.app/PlugIns/Stream14Tests.xctest; it is not a standalone sibling in this build.
2. Enumerate the prepared tests without execution. With suite selector Stream14Tests/ShortPhoneSmokeTests, require exactly one enabled identifier ending in twoProfilesRetainComposedOriginals(). Stop if enumeration errors, zero tests or unexpected tests appear.
3. Keep the existing original-file inventory. Install as an update, never uninstall/reset to fix a test or signing problem.
4. Start a single five-minute operator clock. Run the local-only smoke with the flag, then require one executed passed result and no physical skip. A zero-test run, a skipped test, permission failure or timeout is INCOMPLETE/BLOCKED, never PASS.
5. For owner sign-in, terminate/relaunch normally with no short-smoke environment. Do not try account tests inside the deliberately isolated nil-driver test host.
6. Show only concise channel/error/result text. Save private logs, result bundles and originals outside Git; no raw credentials or camera images in public PRs.
7. End with a short record: what executed, passed/failed/skipped/blocked, exact build, retained file IDs/private evidence paths, restored settings and next pending step.

Off-phone selector evidence: /private/tmp/stream14-short-smoke-enumeration-20261108.json (no errors, one enabled short-smoke identifier). Initial unsuccessful phone attempt: /private/tmp/stream14-short-phone-20261108-084609/smoke.xcresult and smoke.log (zero executed tests; no camera recording). These are private artifacts, not public attachments.

See the [five-minute plan and coverage backlog](2026-11-07-connected-iphone-test-plan.md), [short-smoke handoff](2026-11-07-short-phone-smoke-implementation.md), and [epic resume ledger](2026-11-07-epic13-progress.md).
