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
| F3 / #16 | Fresh agent implementing REST client/event picker; initial native builds pass | `codex/issue-16-youtube-client` / `f3` | Fixture tests/review, F4 merge, actual authorized event read |
| F4 / #17 | Implemented and independently reviewed; `615ea08` implementation, `c73605a` evidence; F1/F2 integrated | `codex/issue-17-session-controls` / `f4` | PR publication, physical profile/mute/zoom/route/media checks |
| F5 / #18 | Not started | — | F3 prerequisite |
| F6 / #19 | Fresh agent auditing/prototyping single shared encoder and actual bounded-send feasibility; no production adoption | `codex/issue-19-independent-transport` / `f6` | F1 gates; library nested tasks/unbounded socket queue cannot be bounded by an app queue alone |
| F7 / #20 | Not started | — | F2–F6 prerequisites |
| F8 / #21 | Not started | — | F7 prerequisite |
| F9 / #22 | Not started | — | F7/F8 prerequisites |
| F10 / #23 | Not started | — | F4/F7/F8/F9 prerequisites |
| F11 / #24 | Not started | — | F6/F9 prerequisites |
| F12 / #25 | Not started | — | F6/F8/F9/F11 prerequisites |
| F13 / #26 | Not started | — | Integrated reviewed candidate, service setup and signed delivery |
| F14 / #27 | Not started | — | Delivered candidate, separately agreed qualification and owner acceptance |

Current chain: F1 → F2 → F4 → F3 → F5 → F6, then lifecycle stages. None has merged into main. Stage numbering follows dependency lanes, not PR creation order. Worktree paths use prefix `/private/tmp/stream14-epic13-` plus the suffix above. Inspect actual refs/status before resuming.

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
