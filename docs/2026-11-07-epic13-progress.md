# Epic #13 progress and resume ledger

Updated: 2026-11-07. This ledger tracks implementation separately from acceptance.

## Owner workflow

The owner explicitly requested a new agent per stage, committed useful PRs, and continued development on top of those PRs in a chain. This authorizes stacked work before prerequisite merges and supersedes the prior wait-for-merge instruction for this epic execution. The first stage starts at current main `ededeb1`; later stages merge the preceding reviewed stage without rewriting shared history. No automatic merges are authorized. Independent review remains required for each PR.

Preserve the original checkout's uncommitted Xcode signing settings. Use isolated worktrees. Development media experiments remain at most 15 minutes. Do not delete recordings. Do not publish camera media without an explicit private test action. Longer qualification remains separately agreed.

## Stage ledger

| Stage / issue | Implementation status | Branch / worktree | Evidence / remaining gate |
| --- | --- | --- | --- |
| F1 / #14 | API audit complete; test-only experiment in progress | `codex/issue-14-media-feasibility`, `/private/tmp/stream14-epic13-f1` | Latest/pinned 2.3.0 inspected; production encoding choice and physical dual-output acceptance pending |
| F2 / #15 | Parallel agent work planned | Root coordinator tracks branch | Google owner configuration absent; real browser/callback verification pending |
| F3 / #16 | Not started | — | F2 prerequisite |
| F4 / #17 | Parallel agent work planned | Root coordinator tracks branch | Physical controls/profile evidence pending |
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

## Owner-dependent work

The owner will connect and unlock the test iPhone when convenient. Paired-device discovery is not evidence that capture is ready or authorized. Google OAuth setup is currently absent. No private RTMPS destination/key is configured. Continue deterministic implementation while these are pending. Never place tokens, stream keys, signing information or raw recordings in this ledger or public PRs.

## Resume

1. Read this ledger, the [full plan](2026-11-05-full-app-implementation.md), the current stage handoff and its GitHub issue/PR.
2. Inspect `git status`, `git worktree list` and current remote refs before editing; preserve unrelated work.
3. Resume the first implementation-ready stage with a fresh agent. Do not close issues whose external acceptance remains unmet.
4. Commit meaningful checkpoints and update this ledger with PR, validation and outstanding requirements before a usage pause.
