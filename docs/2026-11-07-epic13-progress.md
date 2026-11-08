# Epic #13 progress and resume ledger

Updated: 2026-11-07. Implementation, review and external acceptance are tracked separately.

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
| F9 / #22 | Not started | — | F7/F8 prerequisites |
| F10 / #23 | Not started | — | F4/F7/F8/F9 prerequisites |
| F11 / #24 | Not started | — | F6/F9 prerequisites |
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
