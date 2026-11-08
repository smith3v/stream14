# Reviewed epic #13 stack consolidation Implementation Plan

**Goal:** Restore the already-reviewed PR #40–#48 scope onto current main, preserving the held PR #49 boundary.

**Architecture:** Start from fetched main and normally merge original PR #48 tip `8c3ce8f`. Preserve runtime and existing history exactly; add only reviewed attended-result documentation and the current merge/acceptance ledger.

**Tech Stack:** Git, Markdown and Python standard-library content/link checks; unchanged Swift 6/Xcode sources and package pins.

---

### Task 1: Preserve and merge the reviewed stack

**Prompt:**
Use only `/private/tmp/stream14-epic13-stack-consolidation`, a new non-iCloud clone. Fetch current main, create `codex/consolidate-reviewed-epic13` from it and run `git merge --no-ff 8c3ce8f`. Confirm both main and #48 are ancestors, then `git diff --exit-code 8c3ce8f HEAD` must be empty. Preserve the source worktrees, all recordings and shared branch history.

---

### Task 2: Record scoped results and validate

**Prompt:**
Copy the separately reviewed attended-result updates from `/private/tmp/stream14-epic13-short-smoke` into `docs/2026-11-07-connected-iphone-test-plan.md`, `docs/2026-11-08-attended-iphone-session.md` and `docs/2026-11-08-attended-device-results.md`. Append their current evidence to `docs/2026-11-07-epic13-progress.md` without dropping newer predecessor checkpoints, then record actual merged bases and held runtime boundaries. Check relative file links and Markdown fences in changed docs, run `git diff --check` and verify every changed path versus #48 is under `docs/`. Do not rerun unchanged native media experiments solely for this history consolidation; retain their original evidence and limitations.

---

### Task 3: Review and prepare the PR

**Prompt:**
Commit the documentation and provide the full actual diff against fetched main plus exact checks to a separate independent reviewer via the root coordinator. Resolve material findings and rerun affected checks before publication. Root records the review outcome in the PR and publishes into main only after review; never merge automatically. Keep #49 held and do not close issues with outstanding acceptance.
