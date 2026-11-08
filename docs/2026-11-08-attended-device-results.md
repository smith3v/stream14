# Attended iPhone results — 2026-11-08

This records the completed short local smoke and owner-assisted authorization checks. It does not qualify the newer shared-encoder/RTMPS path in PR #49, a real broadcast, physical A/V sync, or endurance.

## Installed candidate and evidence

| Item | Observed |
| --- | --- |
| Source | 8af669f, reviewed short-smoke runtime a7c18e5; PR #47 local-only recorder path |
| Installation | Normally signed development/Xcode products; not TestFlight |
| Displayed version/build | 0.2 (3); source and installation route distinguish this from earlier builds with the same version |
| Bundle / minimum OS | com.smith3v.stream14 / iOS 27.0 |
| Physical device | iPhone 13 mini, arm64, iOS 27.2 (24B119), from xcresult summary; private device identifier omitted |
| Selected test | Stream14Tests/ShortPhoneSmokeTests; exactly one physical method |
| Actual result | 1 passed, 0 failed, 0 skipped, verified with xcresulttool |
| Test body / runner interval | 10.013 seconds / approximately 14.94 seconds; these are not the entire owner-interaction duration |
| Original clips | 1080p30: 3.443333 s; 720p30: 3.225011 s; both retained on phone |
| Private evidence | /private/tmp/stream14-attended-20261108-091215/smoke.xcresult, smoke.log, test-summary.json and attended-outcome.json |

The successful suite ran both short profile recordings sequentially. Actual file checks passed for H.264/AAC media structure/audio decoding and red-to-green markers decoded from the composed originals. The smoke also exercised mute/hide/unhide and frozen-profile rejection in its local fixture flow. It did not use a website, Google or a socket while recording. Meter/state checks and an audio track do not independently prove audible unmute or physical synchronization.

The first earlier phone invocation selected ZERO tests because the bare Swift Testing method filter omitted parentheses. Its successful process exit was not a pass and made no camera recordings. That attempt remains private at /private/tmp/stream14-short-phone-20261108-084609. Off-phone Xcode enumeration then verified the corrected one-test suite selection before this successful attempt.

## Owner-assisted checks

| Check | Evidence / result |
| --- | --- |
| Supported Google sign-in and callback | Owner completed Connect YouTube in the system flow and returned to the normal app |
| Actual channel read | After Refresh, owner confirmed the app showed the intended YouTube channel |
| Saved authorization after process relaunch | Codex terminated/relaunched the normal app without smoke isolation; owner tapped Restore saved connection, then Refresh, and confirmed the intended channel returned WITHOUT another Google sign-in |
| No deliberate account reset | No sign-out, revocation, account switch or credential export was performed |
| No broadcast | No camera media was uploaded and no event was started/ended by this session |

The intended channel confirmation is the owner's observation of the app's API-derived UI; no private account/contact details or raw OAuth tokens are copied into this report. These checks support F2's real callback/SDK persistence and F3's real channel handoff. They do not cover expiry/revocation, every Brand Account/delegation case, event binding mutations or Go Live.

Separately, the owner supplied a scheduled test event. Firefox visibly showed its visibility Unlisted, auto-stop Off, auto-start Off, and No data. These values were already configured; no setting change or Go Live action was needed. Actual event/channel identifiers and the unlisted URL remain only in the private attended outcome, not in public artifacts.

## Budget and next checks

The selected agenda targets five minutes, with prepared builds and count-checked selection. The physical automated body took ten seconds. Exact owner-response completion timestamps were not captured independently, so this report does not claim a measured five-minute end-to-end guarantee. No additional long recording, lock test, revocation or broad failure sweep was run.

Pending:
- Repeat the short physical smoke against the NEW shared encoder/passthrough integration; the above installed source is the older local-only path.
- Use the owner-designated unlisted event only after the reviewed Go Live/End candidate is prepared and the explicit operator confirms start/end.
- Check real RTMPS receiver composition/audio, bounded outage/reconnect behavior and independent writer failure; targeted runs must fit the agreed budget.
- Physical clap markers, audible mute, VoiceOver, real route/lock/interruption and expiry/revoke cases remain targeted backlog items.
- Selected compressed-writer crash recovery, delivered-build instrumentation and long-run qualification remain unverified and unscheduled unless separately agreed.

See the [attended-session card](2026-11-08-attended-iphone-session.md), [five-minute plan](2026-11-07-connected-iphone-test-plan.md) and [epic ledger](2026-11-07-epic13-progress.md).
