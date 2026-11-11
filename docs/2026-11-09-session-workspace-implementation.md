# Session workspace implementation plan

**Goal:** Implement issue #62's prepare, check, start, run and finish flow in one Session workspace.

**Architecture:** Keep MediaSession, BroadcastSession and the authorization/event owners as the sole state owners. Reorganize native views around their existing readiness, configuration locks and independent output states; gate next-session reset in the coordinator.

**Tech Stack:** Swift 6, SwiftUI native tabs, toolbarVisibility and sheets; existing HaishinKit pipeline; Swift Testing and XCTest fixtures.

---

### Task 1: Consolidate navigation and preparation

**Prompt:** Refactor `Stream14/App/SetupView.swift` to Session/Recordings, preserving the recordings content. Use available layout to hide the native tab bar in landscape and add Navigate to toolbar More. Move secondary screens into Settings and event picker sheets. Keep draft/apply and destructive confirmations. Place profile and compatible lens controls beside explicit picture/sound checking. Explain existing preview profile locks and offer camera close before changing quality. Do not start media from navigation.

### Task 2: Preserve start, run and finish safety

**Prompt:** Update `Stream14/Broadcast/BroadcastControlsView.swift` action names/confirmation and keep coordinator checks. Show independent upload/local/YouTube/overlay statuses, fix routes, output recovery progress and honest unavailable-recovery guidance. Add a guarded next-session operation to `Stream14/Broadcast/BroadcastSession.swift`; invalidate the old event only after reset succeeds. Retain finalization, saved/incomplete status and original playback/export.

### Task 3: Verify and document

**Prompt:** Update deterministic fixtures in `Stream14/App/InterfaceFixture.swift` and `Stream14/Media/MediaSession.swift`, and interface tests in `Stream14UITests/SetupScreenTests.swift`. Cover readiness routes, consent/cancel, active locks, asymmetric states, uncertain End, next-session reset, portrait/landscape navigation and larger text. Run native build/tests with Stream14 scheme, iPhone 13 mini Simulator and pinned package cache; `git diff --check`. Update operator-flow/F10 specification and development guide with exact evidence and pending phone checks. Have an independent agent inspect the full diff against main and actual files; resolve material findings, rerun affected checks, record review, commit and open a PR to main without merging.

## Implementation and review checkpoint

Originally implemented in `codex/issue-62-session-workspace` on main `ea90bd3`.
Rebased onto main `1960df2` on 2026-11-10; see the rebase checkpoint below.
The original iCloud checkout has unrelated project/setup changes; work uses a fresh
checkout at `/private/tmp/stream14-issue62-fresh` after worktree checkout encountered
iCloud object-read timeouts. Original changes and recordings are retained.

Independent review inspected the full diff and actual files. Material findings
were resolved: next-session reset clears stale transient output/failure state while
retaining archives; active overlay recovery/reconnect routes remain available;
writer admission gates Start/readiness; finish requires preparing the next session
before another Start. Focused re-review found no remaining material issues.

Native validation and remaining physical limits are recorded in the development guide.

Final handoff: [draft PR #63](https://github.com/smith3v/stream14/pull/63) targets main.
Debug/test and unsigned Release builds pass, as do 61 focused native tests and
12 selected interface tests across the recorded runs. One legacy profile native
contrast audit remains unresolved on an inaccessible SwiftUI node; its screenshots
show primary-color content but no audit pass is claimed. The audit handler remains
unchanged. Physical five-minute 13 mini inspection remains pending. This is an
implementation handoff with explicit validation limits, not completed issue/device
acceptance or permission to merge.

## Rebase checkpoint — 2026-11-10

The owner requested rebasing PR #63 on current main `1960df2`, incorporating
preview foreground recovery (#64) and compatible default-stream reuse (#66).
Conflicts in SetupView and MediaSession were resolved by retaining the redesigned
workspace plus main's root foreground reporting, transition preview placeholder,
foreground/permission guard and preview-intent/generation ownership. Debug UI
fixtures still return before native capture. Production recording still clears
preview-only restoration intent; no recording or upload resumes automatically.
Default-stream binding/client changes are retained unchanged from main.

Focused actual-file/range-diff review found no material integration issues. Rebase
validation is recorded in the development guide; prior native-audit and physical
inspection limits remain open.

Rebase checks passed: 100 tests in seven native suites (preview foreground,
interruptions, coordinator, profile, workspace, binding and writer finalization)
plus the deterministic navigation smoke test in
`/private/tmp/stream14-issue62-rebase.xcresult`; final unsigned Release build in
`/private/tmp/stream14-issue62-rebase-release-final.log`. The navigation test opens
no capture or upload. Independent review found no material conflict-resolution
issues. Existing profile audit and physical qualification limits are unchanged.


## Tested preview fix integration — 2026-11-10

Normal merge `3154200` incorporates reviewed PR68 into this workspace; a subsequent
normal merge of landed main `2001d76` at `6459c74` has no file delta. No history was
rewritten and deferred PR69 is excluded. The [focused integration checkpoint and
five-minute interface card](2026-11-10-pr63-preview-integration-implementation.md)
record exact source, fresh-frame/view-identity behavior and remaining acceptance.

Integrated validation passed 106 checks in seven native suites and one navigation
UI test (authoritative total 107, no failures/skips); ordinary unsigned Release
passed. No physical UI, legacy contrast audit, VoiceOver/larger text, file/receiver
or TestFlight pass follows from those results. Root coordinates final independent
review, normally signed development preparation and the separately agreed visit.
