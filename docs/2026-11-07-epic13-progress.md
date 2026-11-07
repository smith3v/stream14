# Epic #13 progress and resume ledger

Updated: 2026-11-07. This ledger tracks implementation separately from acceptance.

## Owner workflow

The owner explicitly requested a new agent per stage, committed useful PRs, and continued development on top of those PRs in a chain. This authorizes stacked work before prerequisite merges and supersedes the prior wait-for-merge instruction for this epic execution. The first stage starts at current main `ededeb1`; later stages merge the preceding reviewed stage without rewriting shared history. No automatic merges are authorized. Independent review remains required for each PR.

Preserve the original checkout's uncommitted Xcode signing settings. Use isolated worktrees. Development media experiments remain at most 15 minutes. Do not delete recordings. Do not publish camera media without an explicit private test action. Longer qualification remains separately agreed.

## Stage ledger

| Stage / issue | Implementation status | Branch / worktree | Evidence / remaining gate |
| --- | --- | --- | --- |
| F1 / #14 | API audit and test-only experiment implemented; independent review pending | `codex/issue-14-media-feasibility`, `/private/tmp/stream14-epic13-f1` | Checkpoint `51da480`; Release and device/Simulator test builds pass; two hosted checks pass, one physical test skipped; production encoding choice and physical acceptance pending |
| F2 / #15 | Implemented and independently reviewed; PR pending | `codex/issue-15-youtube-authorization`, `/private/tmp/stream14-epic13-f2`, `9fd23a5` | 13 hosted tests and Release pass; independent review found no material findings at `9fd23a5`; Google owner configuration/browser callback evidence pending |
| F3 / #16 | Not started | — | F2 prerequisite |
| F4 / #17 | Implementation in progress | `codex/issue-17-session-controls`, `/private/tmp/stream14-epic13-f4`, plan `c2cb946` | Production edits uncommitted at this update; Release/build-for-testing pass, Simulator execution/physical controls evidence pending |
| F5 / #18 | Not started | — | F3 prerequisite |
| F6 / #19 | Not started | — | F1/F4; must not treat feasibility gate as passed |
| F7 / #20 | Not started | — | F2/F3/F4/F5/F6 prerequisites |
| F8 / #21 | Not started | — | F7 prerequisite |
| F9 / #22 | Not started | — | F7/F8 prerequisites |
| F10 / #23 | Not started | — | F4/F7/F8/F9 prerequisites |
| F11 / #24 | Not started | — | F6/F9 prerequisites |
| F12 / #25 | Not started | — | F6/F8/F9/F11 prerequisites |
| F13 / #26 | Not started | — | Reviewed integrated candidate and service setup |
| F14 / #27 | Not started | — | Delivered candidate, device qualification and owner acceptance |

The planned PR chain is F1 → F2 → F4 → F3 → F5 → F6 → remaining dependent stages. The root coordinator owns merging each reviewed predecessor into the next stage, PR creation and recording review outcomes. A usage-limit interruption on 2026-11-07 preserved all worktrees and checkpoints; F1 resumed from `51da480` without modifying the original checkout.

## F1 validation and exact resume

- Unsigned Release app build passed: `/tmp/stream14-f1-release.log`. App target graph remains HaishinKit/Logboard, with RTMP linked only by hosted tests.
- Final focused Simulator result: `/tmp/stream14-f1-tests-5.xcresult` and `/tmp/stream14-f1-tests-5.log`; two deterministic checks pass, physical publishing test skipped. Earlier failing bundles are retained. AAC packet payload/timestamps are compared after normalizing reader-dependent packet grouping; zero-sample trim markers are not media packets.
- Final device-SDK build-for-testing passed at `/tmp/stream14-f1-device-test-build-3.log`, including physical-only start/record-identity assertions. No signed installation or physical experiment occurred.
- Independent review identified an overclaim in compressed RTMP evidence: passing run 5 logs `invalidSequence` on initial zero/nonpositive timestamps. Public overload calls establish compile/call compatibility only, not successful media acceptance. Documentation/helper naming now distinguish this from independently passing offline MP4 packet-byte/PTS comparison; future live input needs a positive common timeline, strict per-track ordering and verified per-track origin/reconnect A/V handling.
- Required next work: independent actual-file review of F1 full diff against `origin/main` is in progress; record/fix findings, then open the first PR. Do not close #14 or claim F6 feasibility acceptance. See [F1 plan](2026-11-07-dual-output-implementation.md) and [guide](ios-development-guide.md#full-app-f1-dual-output-feasibility-checks-2026-11-07).

## Owner-dependent work

The owner will connect and unlock the test iPhone when convenient. Paired-device discovery is not evidence that capture is ready or authorized. Google OAuth setup is currently absent. No private RTMPS destination/key is configured. Continue deterministic implementation while these are pending. Never place tokens, stream keys, signing information or raw recordings in this ledger or public PRs.

## Resume

1. Read this ledger, the [full plan](2026-11-05-full-app-implementation.md), the current stage handoff and its GitHub issue/PR.
2. Inspect `git status`, `git worktree list` and current remote refs before editing; preserve unrelated work.
3. Resume the first implementation-ready stage with a fresh agent. Do not close issues whose external acceptance remains unmet.
4. Commit meaningful checkpoints and update this ledger with PR, validation and outstanding requirements before a usage pause.

## Coordinator checkpoint — first PR open

- F1 head `dbb1e28`, reviewed PR [#40](https://github.com/smith3v/stream14/pull/40) targets main. Independent review corrected an RTMP-acceptance overclaim; focused re-review found no remaining material findings. Physical publishing is still unverified.
- F2 authored head `9fd23a5` passed independent review; its branch `codex/issue-15-youtube-authorization` at `/private/tmp/stream14-epic13-f2` now includes F1 through merge commits. The only conflict retained both appended guide sections. Combined checks at `/private/tmp/stream14-f2-stack-tests.xcresult` report 16 tests: 15 executed checks passed and one physical test skipped. Focused stack review at `51dbdc3` found no material integration issues; its PR will target F1.
- F4 implementation `615ea08` at `/private/tmp/stream14-epic13-f4` passed unsigned Release, six focused + eighteen regression hosted tests and two existing accessibility UI tests. Final profile UI checks and F2 integration are in progress; independent review remains pending.
- Fresh F3 agent is implementing at `/private/tmp/stream14-epic13-f3`, branch `codex/issue-16-youtube-client`, initially from the F2 stack. It must merge reviewed F4 before opening the next chained PR.
- No branches have been merged into main. The original checkout and private signing changes remain untouched. Google setup, phone readiness and a private RTMPS destination remain owner-dependent.

After a usage interruption, inspect these worktrees and actual latest commits before repeating checks. Continue the existing stage agent or assign a fresh agent for the next stage; do not discard unfinished work.
