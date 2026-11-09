# Integrated Interface Implementation Plan

**Goal:** Provide native Preparation, Session and Recordings destinations with independent status and deliberate publishing/file controls for issue #23.

**Architecture:** SetupView remains the single presentation owner of the existing MediaSession, BroadcastSession, authorization and event selection. Native tabs separate preparation/account/event controls from active media controls and original-file review. View composition changes no media output ownership.

**Tech Stack:** Swift 6, SwiftUI TabView/NavigationStack, existing HaishinKit preview, native Xcode/XCTest.

---

### Task 1: Native destinations

**Prompt:** Refactor Stream14/App/SetupView.swift to expose Preparation, Session and Recordings tabs. Preserve the single attached overlay WebKit host and existing foreground/interruption callbacks. Preparation retains profile, account/event eligibility and full confirmation. Session keeps the full-canvas preview and camera/lens/zoom/mute, duration, overlay manual visibility/reload, explicit file stop and confirmed broadcast End. Recordings retains original-file actions and confirmation. No tab/setting selection calls publish. Use accessible native labels with 44-point targets. Commit after build verification.

### Task 2: Status and safe setup

**Prompt:** Add separate recording, upload, YouTube and overlay status labels; retain frozen active channel/event/visibility/profile plus persistent backup/thermal/reconnect uncertainty. Keep locked settings visible with explanation, preserve empty-URL disable and explicit same-event resume. Add help/privacy/disconnect access in preparation. Reuse existing coordinator readiness; do not duplicate a state machine.

### Task 3: Deterministic interface checks and handoff

**Prompt:** Update Stream14UITests/SetupScreenTests.swift navigation expectations and add safe tab/no-implicit-capture checks. Run shared-scheme Simulator build and focused UI accessibility tests using the parent-coordinated simulator lease, with private xcresult/screenshots. Inspect portrait, both landscapes and largest text on the 13 mini Simulator. Update canonical design and guide with actual behavior/evidence and explicit physical VoiceOver/receiver limits. Run git diff --check. Parent arranges independent review of actual full diff against main and focused stage delta, fixes and affected rechecks before publication. Do not use a phone, real Google API, media publishing or delete owner recordings for routine validation.

## Design rationale

Native tabs make the three specified destinations directly discoverable. A single long scrolling page obscures active controls among account/event/file content; nested navigation adds an extra step for file review. The existing compositor preview remains the only video surface and native controls remain outside it. Landscape uses a preview column and a scrolling controls column at normal text sizes; accessibility text falls back to one vertically scrolling column to avoid clipped controls. Recording and publishing remain independent actions owned by the existing services.

## Evidence

Pending implementation and focused native checks. Physical smallest-screen use, spoken VoiceOver, actual receiver/file exclusion and long qualification remain unverified.

### Initial checkpoint (before stable F9 handoff)

Preparation/Session/Recordings native tabs and normal-text landscape two-column layout are implemented in SetupView only. The existing overlay host, file actions and lifecycle callbacks are retained. Settings stays inspectable when URL edits are locked; active overlay reload/manual visibility are exposed. `git diff --check` passes. This is an incomplete stage checkpoint: existing UI tests still assume the old single screen and require navigation updates; F9 backup warning/foreground resume hooks must be inherited from its final reviewed commit. Build is running at `/private/tmp/stream14-f10-build.log` (initial sandboxed invocation stopped after native service restriction; authorized native invocation is compiling/resolving packages). No Simulator UI, phone, API or publishing validation has run. Do not publish/merge this checkpoint as completed F10.

## Reviewed implementation and native evidence

Product source `fa3140e` is independently reviewed with no remaining material
findings. Review identified that moving recordings off the original page hid
list/deletion errors. `MediaSession.recordingsMessage` now keeps that feedback in
Recordings; a real nonregular-file Simulator fixture verifies confirmed deletion
fails conservatively, retains the row and explains retry. The row is extracted to
`Stream14/App/RecordingRow.swift` with the original sample/play/delete contract
for F11. No original-file migration or cleanup was added.

Each native tab owns its NavigationStack; only the selected screen is instantiated.
One attached overlay host and one MediaSession remain above the screen boundary.
Navigation content is bounded to its viewport. MTHKView receives explicit dimensions
computed from 16:9, because relying only on UIViewRepresentable aspectRatio allowed
UIKit sizing to escape its proposed bounds. Session normal landscape uses the
preview/control columns; accessibility text uses one scroll column. Microphone and
manual overlay visibility use native buttons with 44-point minimum label targets,
explicit state values and SF Symbols. Native label transitions are allowed to settle
before retained screenshots. URL settings stay inspectable while mutation is locked.

Passed evidence on Xcode 27.2/iOS 27.2 Simulator:

- `/private/tmp/stream14-f10-release-final-2.log`: unsigned generic-iOS Release build
  passed. Binary inspection finds none of STREAM14_INTERFACE_FIXTURE,
  fixture-account, fixture-channel or invented-fixture-token.
- `/private/tmp/stream14-f10-ui-11.xcresult`: one native test covers both landscape
  directions at normal and largest accessibility text. Actual 16:9 frame assertions,
  44-point microphone target, actual renderer manual Hide/Show state and accessibility
  audits pass. This run used no audit exclusions. Its screenshot attachments capture
  the native label crossfade; the subsequent test-only settling delay improves QA
  artifacts without changing product behavior.
- `/private/tmp/stream14-f10-regression-1.log`: hosted phase completed 148 cases
  (seven physical opt-in skips); confirmed Delete/Cancel, failed deletion with retry
  feedback, native no-implicit-publish destinations, URL draft discard/invalid Apply,
  overlay settings accessibility, persistent reconnect/backup/unknown-end/ended states,
  and exact preflight/publishing confirmation pass. The combined run was stopped
  during obsolete legacy profile gestures; it is not an overall passing UI bundle.
- `/private/tmp/stream14-f10-ui-final.xcresult`: original playback/export passes;
  old unscoped contrast audits report offscreen/clipped static text. The known
  landscape example is the YouTube heading at y709.7 on a 375-point screen, outside
  the native y78–311 viewport (the gesture helper adds eight-point clearance,
  yielding a y86–303 target rectangle). Portrait similarly reports the event-status paragraph
  at y772.7 below the y729 tab boundary, and recording metadata at y784.3 below that
  boundary. These are retained diagnostic results, not visible-contrast passes.

The final test-only audit handler follows the earlier recording audit's geometric
approach more narrowly: it can exclude contrast only for the same uniquely matched
static text whose nonempty, horizontally contained frame is vertically clipped or
offscreen both before audit and in its callback. Fully visible text, control nodes,
unknown elements and every other audit category still fail normally. Each exception
logs both frames and the native nav/tab-bounded viewport. The final focused affected
run is recorded separately; do not call the whole suite unfiltered after this change.
Independent focused review of this exact test geometry and settled screenshots is
required before handoff publication. No native product colors or labels are hidden
to satisfy an audit heuristic.

Physical smallest-screen use, spoken VoiceOver, real camera/receiver exclusion of
controls, OAuth/publishing, numerical A/V sync and long qualification remain pending.
There was no physical phone use or real Google/publishing action in F10. The five-minute
TOTAL routine phone budget and separate long qualification agreement remain intact.

## Final current-main handoff

Normal merge `91c51f4` inherits actual main `f454e9b` and its reviewed HaishinKit
revision `497f742c5f2c04cf3ca085378e660a273e351788`. The shared cache
`/private/tmp/stream14-transport-fix-packages` was used read-only with automatic
resolution disabled. Product source remains the independently reviewed F10 behavior;
no media pin was edited manually.

The final affected run `/private/tmp/stream14-f10-ui-verified.xcresult` passes all
six selected native tests: portrait/largest-text preparation and privacy footer,
profile persistence in both landscapes, recording metadata/actions in portrait and
both landscapes at normal/largest text, original player/share-sheet opening, and
Session normal/largest-text operation in both landscape directions. Known clipped
static-text exceptions are logged with before/callback/native-viewport geometry;
this final run is not wholly unfiltered. Screenshots exported to
`/private/tmp/stream14-f10-ui-verified-attachments` were inspected. The native
Hide/Show label crossfade is settled in these artifacts.

A separate exact visibility check passes in
`/private/tmp/stream14-f10-last-control.xcresult` across all four Session layouts.
The normal last Go Live control is y260.667–311, height50.333, inside the actual
native y78–311 viewport; at largest text it is y201.667–294.667, height93. Both
landscape directions are fully visible, hittable and at least44 points high.
Thus the drag helper's optional8-point clearance caused extra retries at the last
control, rather than a product clipping bug. No product adjustment or contrast
waiver was used for this check. Exact-control screenshots are under
`/private/tmp/stream14-f10-last-control-attachments`.

Playback/export checks open the native player and original-file share sheet using
bundled sample media; they do not establish captured footage/receiver acceptance or
an external Files copy. Only invented Simulator fixtures were deliberately deleted
through confirmation; failed/pending and unrelated originals remain retained.

F11 integration entry points remain `RecordingRow(sample:canDelete:play:delete:)`,
`MediaSession.savedSamples`, `canDeleteSamples` and the dedicated
`recordingsMessage`. Root owns final focused independent review of the exact audit
geometry/new visibility test and settled screenshots, then publication into main.
The prepared PR body is `/private/tmp/stream14-f10-pr-body.md`; it references #23
without closing unmet physical acceptance. No PR was published by this stage.
