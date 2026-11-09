# Epic #13 progress and resume ledger

Updated: 2026-11-08. Implementation, review and external acceptance are tracked separately.

## Owner workflow

Use a fresh agent per stage and make useful committed PRs in a chain. The owner explicitly permits development atop unmerged prerequisite PRs, superseding the old wait-for-merge rule. First PR targets main; dependent PRs target their preceding branch and are retargeted after predecessor merges. Do not merge automatically, rewrite shared history or delete branches.

Preserve the original checkout and its private signing/concurrent setup edits. All epic work uses isolated `/private/tmp/stream14-epic13-*` worktrees. Experiments stay at most 15 minutes, originals are retained, and camera upload requires explicit operator action. Longer qualification needs separate agreement.

## Stage ledger

| Stage / issue | Current implementation and PR | Branch / worktree suffix | Remaining acceptance |
| --- | --- | --- | --- |
| F1 / #14 | Reviewed [PR #40](https://github.com/smith3v/stream14/pull/40), head `dbb1e28` | `codex/issue-14-media-feasibility` / `f1` | Physical dual output, selected production encoding/bounded transport path |
| F2 / #15 | Reviewed [PR #41](https://github.com/smith3v/stream14/pull/41), includes F1 | `codex/issue-15-youtube-authorization` / `f2` | Signed-phone Google callback, Keychain, scope/revoke and actual channel |
| F3 / #16 | Reviewed [PR #43](https://github.com/smith3v/stream14/pull/43), F4 integrated | `codex/issue-16-youtube-client` / `f3` | Actual authorized event read |
| F4 / #17 | Reviewed [PR #42](https://github.com/smith3v/stream14/pull/42), F1/F2 integrated | `codex/issue-17-session-controls` / `f4` | Physical profile/mute/zoom/route/media checks |
| F5 / #18 | Reviewed [PR #45](https://github.com/smith3v/stream14/pull/45), phone-plan prerequisite integrated | `codex/issue-18-safe-ingestion` / `f5` | Real dedicated-event acceptance via later F7/integration entry |
| F6 / #19 | Fresh agent auditing/prototyping single shared encoder and actual bounded-send feasibility; no production adoption | `codex/issue-19-independent-transport` / `f6` | F1 gates; library nested tasks/unbounded socket queue cannot be bounded by an app queue alone |
| F7 / #20 | Not started | — | F2–F6 prerequisites |
| F8 / #21 | Not started | — | F7 prerequisite |
| F9 / #22 | Implemented/reviewed runtime 75d7b92; 140 hosted passes, seven physical skips; Release pass | codex/issue-22-session-interruptions / isolated clone | Physical Home/lock/audio, same-event receiver/file resume and heat qualification pending |
| F10 / #23 | Implemented; product source independently reviewed; Release, 148-case hosted phase and final native checks pass | codex/issue-23-integrated-interface / isolated clone | Exact test-geometry/screenshot focused review, physical F10 operation/VoiceOver and receiver acceptance pending |
| F11 / #24 | Native Mac feasibility probe reviewed at 8503510; production integration pending | codex/issue-24-recovery-feasibility / separate clone | Selected compressed writer, F6/F9 and physical A5 |
| F12 / #25 | Not started | — | F6/F8/F9/F11 prerequisites |
| F13 / #26 | Not started | — | Integrated reviewed candidate, service setup and signed delivery |
| F14 / #27 | Not started | — | Delivered candidate, separately agreed qualification and owner acceptance |

Current chain: F1/#40 → F2/#41 → F4/#42 → F3/#43 → phone plan/#44 → F5/#45 → F6, then lifecycle stages. None has merged into main. Stage numbering follows dependency lanes, not PR creation order. Worktree paths use prefix `/private/tmp/stream14-epic13-` plus the suffix above. Inspect actual refs/status before resuming.

## Validation and review evidence

- F1: unsigned Release and Simulator/device-SDK build-for-testing pass. Two deterministic hosted tests execute successfully; private physical publishing test skips. `/tmp/stream14-f1-tests-5.xcresult` and `/tmp/stream14-f1-review-fix-build.log`. Independent review corrected an acceptance overclaim; focused re-review at `dbb1e28` found no remaining material findings.
- F1 limit: public compressed RTMP calls establish compile/call compatibility only. Passing runs log `invalidSequence` for zero/nonpositive initial timestamps, and Void APIs swallow errors. Offline MP4 passthrough independently preserves packet bytes/PTS. Positive common input timeline, reconnect origins and physical A/V acceptance remain unproven. No production duplicate encoder is approved.
- F2: native unsigned Release and 13 focused hosted tests pass. Independent source review at `9fd23a5` and stack review at `51dbdc3` found no material findings. Combined stack `/private/tmp/stream14-f2-stack-tests.xcresult`: 15 executed checks pass, one physical publishing test skips. Guide merge retained both stage sections; auth runtime/package configuration stayed unchanged.
- F4: native unsigned Release/build-for-testing pass. Initial focused/regression checks execute 22 tests successfully with two physical/reference opt-ins skipped. Two existing accessibility UI tests pass. New profile UI test passes selection, relaunch persistence and largest-text scrolling/audits in both landscape orientations: `/tmp/stream14-f4-stack-profile-ui-3.xcresult`. Final merged hosted run executes 19 tests successfully with one physical publishing test skipped: `/tmp/stream14-f4-stack-focused.xcresult`. Initial failed UI results are retained; fixes were test synchronization/bounded scrolling, not production changes.
- F4 independent actual-source review at `9152d05` found no material findings. Final UI test/evidence changes do not alter reviewed production behavior. Private F1 candidate explicitly selects 1080p before opening capture, avoiding persisted-profile mismatch.
- Relative Markdown link checks pass in F1/F2/F4; plist/diff checks pass. Exact commands/public APIs are in the stage implementation/handoff documents. Retained logs and result bundles are private; never attach tokens, keys, camera media or signing/tester information publicly.

## Owner-dependent work

The owner will connect/unlock the test iPhone when available; paired discovery is not capture readiness. Concurrent owner setup is now recorded in the original checkout's `docs/2026-11-07-google-youtube-setup.md`: console project, API, testing audience and public iOS OAuth client are prepared and a channel was inspected. Preserve that external local work; do not create duplicate clients/projects. Actual app OAuth scope/callback/channel identity remains unverified. Configure the public client through the selected local configuration mechanism for signed-phone tests.

No dedicated unlisted test event or private RTMPS destination/key is configured. No live camera media has been published. F1's physical performance/receiver/sync gates remain pending, as do later long-run agreement and delivered-build qualification. Missing setup does not block deterministic implementation.

## Resume procedure

1. Read this ledger, the full-app plan, current stage handoff and actual issue/PR. Inspect `git status`, `git worktree list`, remote refs and open PRs; preserve unrelated edits.
2. Resume the existing stage agent after an interruption, or use a fresh agent for the next stage. Commit meaningful checkpoints early. Root coordinates the single Simulator lease; isolated native builds can run concurrently.
3. Merge committed predecessor branches normally, retain both sides of documentation conflicts, run affected integration checks and independent review before handoff. Do not force-push or merge PRs automatically.
4. Update this ledger/PR with exact executed/skipped test counts, actual evidence and pending external gates. Do not close an issue with unmet acceptance or treat synthetic/Simulator evidence as physical qualification.

## Coordinator checkpoint — F3 reviewed and phone candidate prepared

F3 independent actual-file review at `5e0f3e4` found no material findings. Native unsigned Release and 32 merged hosted tests pass; final 13 client tests plus two accessibility UI tests pass after hiding unavailable Refresh in the disconnected state. See `/private/tmp/stream14-f3-ui-recheck.xcresult` and the F3 handoff. The PR targets F4/#42.

An isolated detached candidate at `/private/tmp/stream14-epic13-phone` uses ignored `Config/Local.xcconfig` with the owner-created public OAuth client/callback and private local signing selection. A normally signed Debug build succeeded and strict signature/compiled callback checks passed. App path: `/private/tmp/stream14-epic13-phone-build/Build/Products/Debug-iphoneos/Stream14.app`; private build log `/private/tmp/stream14-epic13-phone-build.log`. Nothing was installed or launched. The owner was asked asynchronously for phone readiness; continue independent work while waiting. If later source fixes are needed, update/rebuild this detached candidate before installing; never overwrite its local configuration or uninstall the owner's app/recordings as cleanup.

F6's first synthetic encode/writer run failed with CoreMedia adapter-format/timing errors; native encoding itself ran, but no shared-writer success is claimed. The failed result is retained at `/private/tmp/stream14-f6-prototype.xcresult`. The stage agent is investigating and preparing an isolated bounded-send package patch, with no production dependency adoption.

Current SSH-agent signing is unavailable. Publishing via an explicit HTTPS URL and the existing GitHub CLI credential helper works, without changing repository remotes or exposing tokens: `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push https://github.com/smith3v/stream14.git <branch>:refs/heads/<branch>`. Do not force-push.

## Connected-phone batching request

The owner will connect the phone later and requested that all connected-device tests be recorded for one coordinated session. The [connected-iPhone test plan](2026-11-07-connected-iphone-test-plan.md) now lists current commands, manual/service-gated checks, future F6–F14 acceptance and separately agreed long runs, with status/evidence templates. No phone tests have been started. This documentation PR is inserted after F3/#43; F5 must merge it before its own chained PR.

## Coordinator checkpoint — phone checklist published and F5 reviewed

The consolidated [50-check connected-iPhone plan](2026-11-07-connected-iphone-test-plan.md) is reviewed [PR #44](https://github.com/smith3v/stream14/pull/44), stacked on #43. Independent review added distinct Wi-Fi/cellular path-switch and actual instrumentation-overhead checks; focused re-review at `7edbbce` found no material findings. Links/fences/shell-template syntax and diff checks pass; no app/phone commands were executed for the doc change. Owner confirmed phone availability is later; all physical rows remain pending.

F5 independent review found a completed single-slot mutation intent blocked later events. Fix `4ed574e` uses a per-channel/event journal and adds sequential/relaunch/manual-resolution coverage while preserving unknown-create duplicate guards. Focused re-review found no new material findings. All 46 hosted checks execute successfully with no skips, final unsigned Release passes, and the phone-plan merge `7f4af87` changes documentation only. F5 exposes a component for later confirmed Go Live, not a ready phone-facing binding UI.

F6 is continuing synthetic encoder/timestamp/failure-preservation work and an isolated bounded-send library patch. The local package patch has 34 deterministic checks passing under a reduced validation manifest; this is not full iOS product/dependency adoption or physical transport qualification. Keep actual failing/progress evidence distinct from final acceptance.

## Coordinator checkpoint — F6 experimental evidence

F5 is reviewed PR [#45](https://github.com/smith3v/stream14/pull/45), stacked on the phone-plan PR #44. F6 merged its latest `ce00961` checkpoint normally at `e2a3b66`; no PR has merged into main.

F6 native synthetic prototype checkpoint `9753224` passes two Simulator tests in `/private/tmp/stream14-f6-prototype-4.xcresult`: one native encode fans into two original files with matching codec bytes, explicit AAC priming-origin handling, and independently decoded midpoint markers within 35 ms. The failure seam retains a finalized partial artifact marked failed instead of calling AVAssetWriter.cancelWriting, which deletes output. These are synthetic test proofs, not actual storage-failure retention or physical camera/receiver sync.

Candidate bounded-send patch artifacts at `Experiments/HaishinKit-2.3.0-bounded-output` are not adopted or published as a fork. Independent review found handshake wire-order and reconnect-during-close races; both are fixed with passing deterministic regressions and await focused re-review. Reduced-manifest source tests passing does not establish the normal iOS product build, real TLS/socket/receiver behavior or whole transport acceptance. The current connected-iPhone checklist reflects these limits.

F6 combined stack validation at `e2a3b66` passes eight hosted checks in three suites
(prototype, existing LocalRecorder and AppConfiguration) at
`/private/tmp/stream14-f6-stack-checks.xcresult`, no skips. The isolated package
candidate passes 34 deterministic tests in 15 suites with two review regressions;
its reduced manifest is still not the normal iOS dependency/product validation.
The candidate remains unadopted and has no production MediaSession wiring.

F6 original-manifest patched iOS product compile/link gate also passes: an isolated
detached app copy selects actual local RTMPHaishinKit via Xcode's normal full
package manifest; `/private/tmp/stream14-f6-patched-ios-build.log` reports unsigned
generic-iOS TEST BUILD SUCCEEDED. The production project/package pins and shared
caches remain unchanged. Both independent reviews report no remaining material
findings after package-race fixes; no physical execution or production dependency
adoption occurred. The reviewed five-minute routine phone-plan correction has now joined this branch through the F5 prerequisite; no device work has started.

## Owner correction — five-minute routine

The owner rejected an hour-long connected-phone test session and requested about five minutes. The connected-phone plan now starts with a five-minute TOTAL timeline; its 50 rows are a backlog, not a single run. Laptop-only preparation/fixtures/Simulator checks happen beforehand; setup blockers stop the visit within budget, long-run criteria remain pending/unscheduled unless agreed. A fresh short-smoke agent is implementing one local-only opt-in two-profile test targeting 60–90 seconds actual execution. Do not claim that selector exists or passes before its source/build evidence. Root is updating PR #44 and will merge this correction forward into F5/F6 without rewriting history.

## Coordinator checkpoint — short smoke ready (2026-11-08)

Short-smoke runtime a7c18e5, evidence 0b92879, branch codex/short-connected-phone-smoke, worktree /private/tmp/stream14-epic13-short-smoke. Independent review fixed unsupported Release opt-in versus Debug-only isolation; focused re-review found no remaining material findings. Debug iOS test build and normal Release app build pass. Noncapturing normal regressions execute eight hosted checks plus two UI checks, with physical smoke skipped; final flag-enabled Simulator recheck executes two configuration checks and skips physical capture. No phone pass or measured five-minute runtime is claimed.

The master plan records exact prebuild and Debug-only test-without-building commands. No phone was installed/launched; owner availability remains later.

Pipeline integration is progressing in separate non-iCloud clone /private/tmp/stream14-epic13-f6-integration-repo, branch codex/issue-19-shared-media-integration, plan 4c07b75 from F6 predecessor 02dcc66. Native single encoder ownership is approved for draft work; root coordinates reviewed shared-clock patch and immutable fork pin before dependency adoption. Failed iCloud worktree remains preserved. Integration must include the short-smoke predecessor before its PR.

## Coordinator checkpoint — native recovery feasibility (2026-11-08)

Early F11 native research is committed at 8503510 in /private/tmp/stream14-epic13-f11-recovery, branch codex/issue-24-recovery-feasibility. Independent review inspected source, guarded child-process harness, retained run8 media hashes and SDK contracts with no material findings. This does not implement production recovery or close A5/#24.

The Mac-only generated H.264/AAC test uses 320×180 video and mono 48 kHz, not the app profile. Ten-second fragments preserve about 20 of 25 submitted seconds after own-child termination; distinct native passthrough copies preserve compressed payload hashes and decoded counts, originals unchanged. Before-first-fragment files remain unreadable and are retained honestly. See the native recovery report and exact private evidence paths there.

Draft actual F6 pipeline work continues in /private/tmp/stream14-epic13-f6-integration-repo: single native persistent encoder and passthrough migration pass 12 executed generated-media checks plus one explicit physical skip, including independent decoded midpoint markers; current local checkpoint d50d4e5 reviewed with no material findings. Concrete bounded uploader queue ae313e4 has four checks; adapter and full-PR review remain pending. Common-origin patch fedc43b passed separate review, 39 package checks and original-manifest iOS product compilation.

The reviewed minimal fork is now published at https://github.com/smith3v/HaishinKit.swift.git revision 8dc2ecce781d320ef0f2576ff5195411c91505ad, parent official 2.3.0 aa2149df822f2e965adf2410a106db959b2e1962. Root verified all eight changed/new source/test files byte-for-byte against reviewed/validated sources and original Package.swift unchanged. No upstream PR was sent. App adoption must pin that exact revision, document maintenance/notices, run full affected regressions and independent full integration review; no live media or physical acceptance is implied.


## F6 actual shared-media integration — 2026-11-08 draft

The isolated integration branch has merged reviewed short-smoke #47 and native
recovery-feasibility #48 normally. Its normal Xcode project now pins the reviewed
owner fork `8dc2ecce781d320ef0f2576ff5195411c91505ad` with committed resolved graph,
links only core/RTMP products, and uses one persistent native encoder followed by
compressed MP4 passthrough and an independently bounded RTMPS pump. Preview/setup
still start no upload; F7 owns the explicit operator flow. All original files and
the five-minute TOTAL phone visit constraint remain intact.

Actual remote-pinned iPhone SDK build-for-testing passes. Eighteen focused
encoder/recorder/pump/integration checks execute and pass, including this new
persistent converter's decoded audible/video marker and packet readback, writer
failure surviving upload, upload failure surviving writing, actual writer-startup
admission and finite stalled-send accounting. Full hosted regression reports
96 passed, 7 explicit physical skips, 0 failed (103 total, 22 suites). Evidence
paths, earlier failures, current interfaces and review gates are in the
[shared-media integration record](2026-11-08-shared-media-integration-implementation.md).
Final whole-change review and noncapture UI/cancellation follow-up are pending.
No physical or receiver test, F1/F6 completion, actual CBR or shipping claim follows.

F6 final draft checkpoint: the immutable remote-fork-pinned app passes its generic
iPhone SDK build and two noncapture UI checks. Whole independent source review
found two startup/context gaps; both are resolved, and focused re-review reports
no remaining material findings at source `1103a9d`/docs `0b35a1c`. After those fixes,
11 affected checks execute/pass. Full hosted baseline is 96 passed, 7 explicit
physical skips, 0 failed; the corrected context-test compile failure is retained,
not counted as a pass. A reviewed draft PR is ready for root publication, with
F1/F6 receiver/physical/CBR/AMF and later endurance criteria still open. No phone
execution, media transmission or Google mutation occurred in this integration.

## Connected attempt and attended preparation — 2026-11-08

Owner connected the 13 mini, set Auto-Lock to Never and confirmed unlocked/ready. Prepared normally signed Short47 Debug products; initial signature preflight used the wrong sibling test-bundle path, corrected to embedded app/PlugIns. Initial test invocation then selected ZERO tests: missing parentheses in Swift Testing method selector. Exit0 is not pass; no camera clips were recorded. Stopped the attempt within the selected budget, no actual Google/lock/revoke tests.

Off-phone Xcode enumeration /private/tmp/stream14-short-smoke-enumeration-20261108.json has no errors and exactly one enabled identifier for suite Stream14Tests/ShortPhoneSmokeTests. Commands now use that suite, with explicit one-pass/zero-skip acceptance. Swift Testing method catalogue examples use quoted enumerated identifiers with parentheses; XCTest UI selectors unchanged.

The owner will be available soon for attended tests. The new attended-session card documents exact owner taps, a five-minute local-smoke + sign-in/channel agenda, alternatives and future/not-runnable gates. No additional physical test started while preparing it. Current private attempt evidence /private/tmp/stream14-short-phone-20261108-084609; source8af669f, zero executed tests. Broader integration agents/reviewer most recently hit usage limits; F6 source9097f1e retry-context fix awaits final focused review/results, F7 work remains checkpointed separately.

Latest follow-up: F6 final runtime review at1103a9d/docs0b35a1c found both startup findings resolved and no material issues; corrected 11 affected checks and native build pass. Final handoffd2bfec1 is ready for reviewed draft PR. F7 plan098cdd4 is committed and implementation proceeds without touching the phone.

Prepublication handoff: reviewed runtime1103a9d/docsd2bfec1 now includes the attended card and verified suite selector from PR47ef2dbf3 through the updated native-probe predecessor. This merge changes documentation only; no additional phone invocation occurred. F7 continues in /private/tmp/stream14-epic13-f7-session from reviewed source and must inherit this documentation before its PR.
## Actual attended results — 2026-11-08

The corrected short-suite selector executed on the physical iPhone 13 mini/iOS 27.2: one pass, zero failures, zero skips, with a 10.013-second test body. The retained original clips are 3.443 seconds at 1080p and 3.225 seconds at 720p. Installed source `8af669f`, reviewed runtime `a7c18e5`, displayed version 0.2 (3), used the Xcode development route and the PR #47 local-only path. This was neither the newer PR #49 shared pipeline nor TestFlight. Private evidence remains in `/private/tmp/stream14-attended-20261108-091215`; the [scoped public report](2026-11-08-attended-device-results.md) records limits. The initial zero-test attempt remains a non-pass.

The owner confirmed the real Google callback and intended channel after Refresh, then restored the SDK-saved connection without another Google prompt after an explicit normal process relaunch, Restore saved connection and Refresh. No tokens, keys or account contacts were exported. Separately Firefox showed the designated test event Unlisted, auto-stop Off, auto-start Off and No data; no setting or broadcast state changed. Event identifiers and URL remain in the private attended outcome only.

PR #49's reviewed shared integration has 96 hosted passes and seven skips, 11 affected passes and native SDK/UI checks; these do not establish physical new-pipeline or real RTMPS acceptance. F7 fixtures recorded 21 focused and 120 full-suite passes with seven skips, plus native builds; focused review at `91fa893` found no material findings and handoff `4891f0d` remained a separate checkpoint. No Go Live candidate was installed or exercised in this attended session. These later checkpoints are evidence references, not source included in this consolidation.

## Current merge and acceptance ledger — 2026-11-08

GitHub metadata checked on 2026-11-08 shows #40 merged into `main` at `965481e22361acff0655efb6eb8fee204dc03f4a`. PRs #41–#48 are merged, but each landed on its original predecessor branch:

| PR | Merged base branch | Included scope |
| --- | --- | --- |
| [#41](https://github.com/smith3v/stream14/pull/41) | `codex/issue-14-media-feasibility` | Google authorization |
| [#42](https://github.com/smith3v/stream14/pull/42) | `codex/issue-15-youtube-authorization` | Fixed profiles and shared microphone controls |
| [#43](https://github.com/smith3v/stream14/pull/43) | `codex/issue-17-session-controls` | Read-only channel and event selection |
| [#44](https://github.com/smith3v/stream14/pull/44) | `codex/issue-16-youtube-client` | Coordinated phone plan |
| [#45](https://github.com/smith3v/stream14/pull/45) | `codex/epic-13-device-test-plan` | Safe ingestion component and durable mutation guards |
| [#46](https://github.com/smith3v/stream14/pull/46) | `codex/issue-18-safe-ingestion` | Experimental shared encoding and unadopted bounded-send patch |
| [#47](https://github.com/smith3v/stream14/pull/47) | `codex/issue-19-independent-transport` | Isolated local-only physical smoke |
| [#48](https://github.com/smith3v/stream14/pull/48) | `codex/short-connected-phone-smoke` | Native Mac fragmented-MP4 feasibility probe |

The consolidation branch `codex/consolidate-reviewed-epic13` starts at that fetched current main and normally merges the original #48 head `8c3ce8f116dff45979841d9628079c8bf8fb2265`. Both are retained ancestors; no history is rewritten and no current-main changes are lost. Before adding attended-result documentation, the entire merged tree matched #48 exactly. Runtime, tests, project configuration, package pins, tools and experiment sources stay byte-identical to that tip. Only documentation records the attended results, current ledger and consolidation procedure. Prior independent reviews and native checks remain the evidence recorded in the stage handoffs above and the [recovery report](2026-11-08-native-fragment-recovery-feasibility.md); the attended-results documentation also received separate review with no material findings. A fresh full-diff independent consolidation review is required before publication, coordinated by the root agent.

This restores only the already-reviewed #40–#48 scope onto main. [PR #49](https://github.com/smith3v/stream14/pull/49) now targets main and remains held for physical shared-pipeline/RTMPS evidence; its production encoder, compressed writer and transport integration are not included. Main does not gain that runtime merely by incorporating #46's synthetic prototype or experimental patch. No automatic merge is authorized. The owner requested closure of eligible issues; the acceptance audit found none eligible yet, so none were closed.

Issues #14–#27 remain open with their existing acceptance limits. In particular: #14 needs physical dual output; #15 still needs signed-phone sign-out/revocation; #16 needs the intended scheduled unlisted event displayed in the app (Studio alone is insufficient); #17 retains audible mute, zoom, both-landscape, route/interruption and playback/export gaps; #18 needs real binding reconciliation; #19 needs new-pipeline RTMPS device evidence. #20 onward retain remaining implementation and qualification. Merged implementation is not acceptance. The five-minute routine phone budget and separately agreed longer qualification remain unchanged.


## Usage-limit handoff — 2026-11-08

The consolidation agent stopped at normal merge `19d454c` with documentation updates saved but not yet committed; root is completing checks and arranging the required independent review. Do not publish it as reviewed until that review completes. Original short-smoke worktree documentation remains preserved; this branch carries a copy.

F8 is independently committed in `/private/tmp/stream14-epic13-f8-reconnect`, branch `codex/issue-21-same-event-reconnect`, head `5f172ce` (runtime `49d294b`). Native Release passed; hosted suite reports 128 passes, seven physical skips and zero failures, including 29 coordinator tests. Simulator lease is released. Its separate reviewer hit the usage limit before returning a review; independent review is still PENDING and no F8 PR was published. F7 remains at `4891f0d` in `/private/tmp/stream14-epic13-f7-session`, independently reviewed with no remaining material findings, awaiting parent documentation inheritance and PR publication. Next: finish consolidation review/PR into main, inherit its documentation into held #49 and F7, publish reviewed F7 as the next stacked PR, and complete F8 independent review before publication. No device or YouTube mutation is needed for these repository steps.


## Consolidation publication and reconnect review — 2026-11-08

The consolidation at `d679d83` completed fresh independent actual-file/full-diff review with no material findings and is published as [PR #50](https://github.com/smith3v/stream14/pull/50) into main; it is not automatically merged. PR #49 now targets main and inherits that consolidation's documentation through a normal merge. All integration source remains unchanged from the prior reviewed runtime; no device rerun occurred.

F8 review resumed and found two material lifecycle issues: file-only finalization temporarily changes MediaSession phase and could end remote supervision even while upload continues; a terminal-event stop request could be lost when MediaSession was busy. The F8 author is fixing both with deterministic held-operation regressions. F8 must not publish until affected checks and focused independent re-review pass. No epic child issue is closed; the acceptance audit remains current.


## F7 reviewed PR published — 2026-11-08

[PR #51](https://github.com/smith3v/stream14/pull/51) publishes the independently reviewed Go Live/End coordinator on top of held #49. Its source remains the reviewed F7 runtime after documentation-only inheritance; final prepublication merge is `86c96bb`. Keep #51 for code review and defer merge until its prerequisite and attended broadcast checks are ready. The next physical build must use this new shared pipeline, not reuse the older successful Short47 run as acceptance.

[PR #50](https://github.com/smith3v/stream14/pull/50) is ready for review/merge into main to restore the already-reviewed #41–#48 stack. No child issue was closed after the requested audit: #14–#27 still have explicit unmet acceptance. No new camera test, live transition, binding or file deletion occurred during repository preparation.


## F8 reviewed publication checkpoint — 2026-11-08

F8 final implementation `4203446` inherits F7 `e22a04c`. Independent focused re-review confirms both lifecycle findings fixed in `2f456dd`, no remaining material findings. Full hosted regression: 130 passes, seven physical-only skips, zero failures; 31 coordinator checks and native Release pass. Root is publishing this reviewed stack above PR #51. Its actual two-minute outage, network change, receiver/file continuity and phone qualification remain pending.

F9 interruption implementation continues in `/private/tmp/stream14-epic13-f9-interruptions` with a new stage agent. A separate receiver-validation agent is preparing actual TLS/decoder evidence in `/private/tmp/stream14-epic13-receiver-validation`; it uses only generated media and a private laptop receiver, no phone or YouTube action. Both stages need independent review before handoff.


## F9 interruption implementation checkpoint — 2026-11-08

F9 runtime `75d7b92` normally inherits reviewed F8 `20a0035`. It cancels startup/reconnect work synchronously on whole-session interruption, stops upload even while file control is busy, retains remote uncertainty and pending mutation barriers, and offers explicit same-event resume after camera reopen and fresh confirmation. Resume validates the original nonsecret profile/binding, requires dedicated inactive ingestion and a new writer/timeline; it never creates/rebinds resources or repeats Live for an already-live event. Serious heat reduces raster cadence; critical heat/input loss/capture failure interrupts. Writer failures leave healthy upload running with a persistent backup warning. Background expiry immediately preserves conservative metadata and restores prior idle state.

Independent actual-file review against the full main diff and stage delta found one material early-permission cleanup issue; it was fixed with a deterministic regression. Focused re-review found no remaining material findings. Final runtime hosted coverage passed 140 tests with seven physical-only skips and zero failures (147 total); native unsigned generic-iOS Release passed. Additional test-only End-interruption case `859f6b0` passed the affected 37-test coordinator suite. Exact commands/artifacts and limits are recorded in [the F9 handoff](2026-11-08-f9-interruptions-handoff.md). No F9 physical or real-service experiment occurred, and no issue acceptance gate is closed.


## F9 publication and actual receiver checkpoint — 2026-11-08

[PR #53](https://github.com/smith3v/stream14/pull/53) publishes F9 `cb49f54` on top of #52. Independent final review found no remaining material findings, including the additional unsettled-End interruption regression. Native validation: 140 hosted passes, seven physical-only skips, zero failures; final affected coordinator suite 37/37; unsigned iPhone SDK Release passed. No acceptance issue closed and no automatic merge occurred.

Root prepared normally signed F8 `20a0035` Debug phone products at `/private/tmp/stream14-shared-phone-build`, build log `/private/tmp/stream14-shared-phone-build-signed.log`; app and embedded test normal strict signature verification passed. Private preparation record `/private/tmp/stream14-shared-phone-preparation.json` records the unchanged previously enumerated short-suite source. Initial build lacked the test targets' team; corrected via private command-line configuration. No phone test executed: USB/unlocked readiness remains requested, and the pending transport correction should be reviewed before selecting the next candidate. Do not interpret this build as physical shared-pipeline acceptance.

Actual synthetic RTMPS validation is in `/private/tmp/stream14-epic13-receiver-validation`: a standalone official MediaMTX receiver and disposable Simulator, private CA trusted only in that Simulator. The untrusted-certificate rejection passed. Trusted connect/publish succeeded but media failed; receiver reported a type-1 chunk without a preceding full header. Isolated wire tracing shows AVC type-0 precedes video, while AAC's first chunk is type-1 without a sequence header. The agent is investigating native AAC format metadata and SDK header construction; no receiver decoding gate is passed yet. Shared package caches and production fork pin remain unchanged. Keep #49 and its descendants held for the correction and remaining phone/service qualification.

F10 native interface work is checkpointed in `/private/tmp/stream14-epic13-f10-interface`, with final F9 parent inherited and test/navigation work active. A new production F11 agent works in `/private/tmp/stream14-epic13-f11-recordings`; it must verify selected compressed-writer recovery, preserve originals and inherit F10 before publication. Both stages require independent review.


## Current-main and usage-limit continuation checkpoint — 2026-11-08

GitHub now reports #50 and #49 merged; fetched main is `eaf9389`, still pinned to fork `8dc2ecce781d320ef0f2576ff5195411c91505ad`. Thus the newly diagnosed AAC header defect is present in current main; the isolated candidate fix is not integrated. PR #51 is retargeted to main; #52 and #53 remain stacked and open. Merges do not waive their physical acceptance.

Receiver agent stopped at usage limit after actual trusted receiver video/audio decoding exposed audio leading the marker by 116.213 ms (marker video4.500000s, audio4.383786848s, 179 decoded video frames and254903 decoded PCM frames). The AAC-header-only fork fix `79eaa938` is committed in `/private/tmp/stream14-haishinkit-aac-header-fix`; app pin remains unchanged. A separate explicit compressed-path CTS fix was planned because legacy SDK message construction adds66 ms for valid DTS; it is NOT committed. Investigate remaining AAC/receiver timeline behavior by comparing local and remote decoded onsets; do not add a guessed constant offset. Receiver tools/test/Debug seam/docs remain saved, partly uncommitted in `/private/tmp/stream14-epic13-receiver-validation`; remove temporary diagnostics and independently review both source/fixtures and minimal fork diff before publishing a new immutable pin. Retain private originals and evidence at `/private/tmp/stream14-private-receiver/`; no phone test ran. Owner will connect the phone later.

F10 checkpoint `e5cde84` plus uncommitted SetupView/UI-test layout corrections in `/private/tmp/stream14-epic13-f10-interface`; agent stopped at usage limit during final accessibility and recording action checks. F11 checkpoint `a2c42af` (implementation `c158073`) in `/private/tmp/stream14-epic13-f11-recordings`: focused12 native tests and Release pass, actual selected source-copy writer25-second termination probe retains20 seconds; passthrough copies preserve encoded payload/video identity but trim46 decoded AAC frames (~1.04ms). Physical recovery and final F10 UI integration/review remain pending. F12 metrics, full-app TestFlight delivery and A1–A9 release qualification are still future stages. Resume these existing stage agents from actual state; use new independent agents for outstanding reviews and a fresh agent for each new stage.


## New shared-pipeline physical local smoke — 2026-11-08

Owner reconnected/unlocked the13mini. Prepared reviewedF8source20a0035 successfully executed exactlyone shortlocaltest:1pass0fail0skip,10.173stestbody,22.769swholeinvocation. Retained1080p/720poriginals measure3.723333/3.196667s;captureclosedandnothingdeleted. [Public scoped report](2026-11-08-shared-pipeline-device-smoke.md) linksprivateevidencewithoutidentifiers. This is physical native shared-encoder/compressed-writer evidence, not olderlocalpipelineevidence,butitdoesnotexerciseRTMPS/newfork/F9/F10orphysicalA/Vsync. NoGoogleAPI/publishactionoccurred.

Revieweddependencycorrectionsarepublishedatimmutablefork497f742c5f2c04cf3ca085378e660a273e351788, afterindependentactualforkreviewandappscopefixre-review. PrivatefixedlocalhostfixtureisnowcompiledonlyforDebugSimulator. Rootmain-basedcorrectionclone/private/tmp/stream14-epic13-transport-correction selectsnewpin;nativeRelease+offlinehostedregressionsareinflight, notyetclaimedpassed. No guessedAACoffsetwasadded;realreceivercontainer/readbackalignmentstillunqualifieddespiterawpacketlatencyevidence.

F10sourcefa3140ereviewedclean;landscape/largesttext4casesanddeletiontests/hosted148checks/Releasepassed,butbroaderPreparationcontrastauditsneedcharacterization/fixsofullUIregressionnotgreen. F11source1c9a4f8nowintegratingF10. FreshF12agentstartedboundedReleaseprivatediagnosticsin/private/tmp/stream14-epic13-f12-diagnostics, exactissuecached/private/tmp/stream14-issue25-requirements.json. Next:completefocusedmaincorrectionnativechecksandPR,mergecorrectionforwardinto51–53andF10/F11/F12,finishF10UIandF11model/recoveryreviews,thenprepareafinalattendedcandidate. Phoneisidle;announcebeforeanynewcaptureoroperatorattendedtest.


## Current-main merge handoff — 2026-11-08

PR #54 is now merged. PRs #51, #52 and #53 all target main, with merge order 51 → 52 → 53. The predecessor-branch targets on #52/#53 were corrected; normal main/prerequisite merges preserved both lifecycle and receiver documentation and resolved documentation-only conflicts. Heads before this documentation checkpoint: F7 `a0ac075`, F8 `42ccef3`, F9 `2dd3a38`. GitHub reports all three mergeable. Independent code reviews and prior stage regressions remain valid; the combined F7–F9 iPhone SDK Release build against the merged immutable transport pin passed (`/private/tmp/stream14-lifecycle-main-integration-release.log`). Reviewed implementation may merge while explicit physical/service and release-acceptance criteria remain open; no automatic merge was performed or implied.

F10/F11/F12 agents reached a usage limit and have saved their branches, working files and logs. F10 product source `fa3140e` has a clean independent review; final test-only handling of a geometrically offscreen static-heading contrast false-positive and remaining UI results need completion/review. F11 recovered-copy UI now uses 44-point icon actions (commit `ffe64bd`), with retry-safe unique-copy test selection (`52b52dd`); final successful recovery UI rerun/affected checks and independent review remain pending. F12 core `33166f2` has a passing initial Release build and bounded model/export evidence; focused test result, final F11 integration, export/privacy review and phone overhead measurement remain pending. Revalidate exact current HEADs and live process handles/results before resuming; do not restart a still-live test merely because an observation expired.

The owner’s connected phone already completed the short local shared-pipeline smoke, documented separately. No further camera use or YouTube publishing has started. A final signed diagnostic candidate and deliberate attended unlisted start/end remain next device steps; routine active phone work retains the five-minute TOTAL budget.


## Account acceptance and required monitor transition — 2026-11-08

PRs #51–#54 are merged; current main is `f454e9b`. The owner confirmed the signed-main account/event checks and local sign-out/revocation; [the scoped report](2026-11-08-attended-account-event-results.md) records the observations. Issues #15/#16 are closed and checked in epic #13. The app was left disconnected, and the scheduled unlisted test event was not started. The physical local shared-encoder smoke is separately recorded; no live broadcast or full release acceptance is claimed.

Preflight found Google's required monitor/testing transition for monitor-enabled events. The focused correction is independently reviewed through `0a10b41`, with the pre-binding changed-setting race fixed. Final native validation: 151 passes, eight opt-in skips, zero failures; iPhone SDK Release passed. A corrected signed candidate still needs installation and operator-confirmed live testing.

F11 independent review found two unresolved material issues: timed-out native writers need UUID protection until the actual finish callback ends before inspection/recovery/deletion, and structural track/duration validation must not claim decoded-start readability. Its author is usage-blocked; no blocked rebuild is counted as a pass. F12 diagnostics code/review, 27 focused tests, Release/privacy, native analysis and Simulator Load/Share checks passed, but its F11 ancestry still needs these fixes and final integrated validation. F10's six affected UI checks and actual native-bound visibility probe passed; final test-only helper review/handoff remains. All future PRs target main, with dependency order in their descriptions; no automatic merges.


## Reviewed F12/F13 handoff — 2026-11-09

This checkpoint supersedes the earlier F10/F11 review and integration blockers
above. Main `f56d275` includes merged PRs #55–#57: required monitor transition,
integrated interface and protected native-finalization/recovered-copy handling.
Issues #15/#16 are closed on owner account/event evidence; implementation merges
do not close the remaining physical/service/release criteria.

F12 branch `codex/issue-25-qualification-metrics` in
`/private/tmp/stream14-epic13-f12-diagnostics` is at `79418b8`, an ancestry-only
normal merge of reviewed `ef202456` with main. Final affected checks passed:
14 tests in three suites, Release build, and failed-row numeric Load/Share UI.
Independent actual-file/full-diff review found no remaining material findings.
Physical instrumentation overhead/export and A1–A9 qualification remain open.

F13 branch `codex/issue-26-testflight-candidate` in
`/private/tmp/stream14-epic13-f13-release-preparation` normally inherited F12/main
at `6da5dcd`, byte-identical to independently reviewed `63557fb` before this
documentation checkpoint. Combined hosted results: 181 passed, eight opt-in skips,
zero failures in 30 suites; two Simulator UI checks and unsigned Release archive
passed. Final review found no remaining material findings. Exact artifacts and
limits are in the [full-app preparation record](2026-11-09-full-app-testflight.md).
Root handles publication of both PRs into main, F12 before F13; no automatic merge.

Next resume steps:

1. Verify current branch/PR/main state and publish the reviewed F12/F13 handoffs.
   Keep the unrelated original iCloud checkout and private signing setup intact.
2. Prepare a focused reviewed version change to 0.3 (4), available in the live
   read-only inventory check below; source remains 0.2 (3). Recheck before upload.
   Do not claim signed distribution from the unsigned archive.
3. Following owner merges, verify published policy URLs, configure the authorized
   public OAuth client outside Git, prepare a normally signed archive, and record
   validation/upload/processing/compliance/internal-group checkpoints separately.
4. Coordinate the next attended phone visit within five minutes TOTAL, including
   setup and wrap-up. Reauthorize Google deliberately: the owner revoked access
   and left the installed app disconnected. Confirm a fresh Unlisted event and
   obtain explicit operator Go Live/End confirmation before sending camera/audio.
   The installed development app predates the monitor/interface/recovery changes;
   a prepared corrected candidate is not proof of installation or TestFlight.
5. Keep receiver/original playback, recovery, diagnostic export/overhead and
   interruption/reconnect checks pending until observed. Longer A2/A7 and full
   qualification require separate explicit agreement; retain all originals.

After owner sign-in, root read App Store Connect Build Uploads / All Statuses on
2026-11-09: only 0.2 (3), 0.1 (2), 0.1 (1), all Complete, no newer/processing
upload. Existing 0.2 (3) is Testing in Owner MVP with 88 days remaining. No
password/code was requested and no settings were changed. No phone, capture, live
Google/YouTube, upload or distribution action occurred in this handoff. A
connected/unlocked device alone does not establish attended readiness.


## Signed release identity checkpoint — 2026-11-09

F12 [PR #58](https://github.com/smith3v/stream14/pull/58) and F13
[PR #59](https://github.com/smith3v/stream14/pull/59) are published into main;
merge in that order. New release branch `codex/release-0.3-candidate` in
`/private/tmp/stream14-release-0.3-candidate` inherits F13 `9bd5c7d` and commits
both app configurations and the existing identity assertion to 0.3 (4) at
`1ae3f87`. No merge/upload occurred. This supersedes the earlier uncommitted
version/signed-archive gaps, while live inventory must still be rechecked before
distribution.

Normal signed Release archiving and strict signature verification passed. The
archive contains the actual configured public Google client/matching callback,
expected icon/purpose keys, nine parseable manifests and corrected notices;
Debug/test artifacts were absent. It uses existing **development provisioning**,
not App Store distribution validation. Two hosted app-configuration cases passed,
zero failures/skips; no full regression rerun was needed for version metadata.
[The delivery record](2026-11-09-full-app-testflight.md#account-enabled-03-4-archive-checkpoint--2026-11-09)
records commands, private evidence paths and exact limitations.

Independent actual-file/full-diff release review found no material findings,
including the archive and two-case native result. Diff/link checks passed.
Next: owner merges #58 → #59 → release PR; verify signed-out published policy links; obtain distribution validation/aggregate privacy
report; then record upload, processing, compliance and existing group assignment
separately. Phone/session/endurance gates remain unchanged: app disconnected after
revocation, five-minute TOTAL routine attended budget, explicit publishing action,
retained originals and separate agreement for longer runs. No phone/camera/mic,
provider API or App Store mutation occurred in this packaging stage.
