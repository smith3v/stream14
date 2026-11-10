# Stable More Menu Implementation Plan

**Goal:** Keep the existing More/ellipsis dropdown open and usable during periodic session updates.

**Architecture:** Retain the Session workspace and its sole media/broadcast owners. Reproduce menu presentation under an isolated, Debug-only meter/status pulse, then give the toolbar menu stable ownership independent of frequently changing session content. Preserve Settings, landscape Navigate and manual overlay actions; do not change preview placement.

**Tech Stack:** Swift 6, SwiftUI, native XCTest UI fixtures, shared Stream14 scheme.

---

### Task 1: Reproduce the presentation failure

**Prompt:** Inspect `Stream14/App/SetupView.swift`, `InterfaceFixture.swift` and the existing UI tests. The owner reported the More dropdown blinking on development source `6459c74`; Settings itself was not identified as the problem. Add an isolated no-capture/no-network `menu-updates` fixture that updates the same displayed media scalars at 10 Hz. A focused UI test opens More in portrait and both landscape orientations, verifies the popup remains available across updates, and activates Settings/Navigate. Run the test against the original menu first. No phone access or publishing.

### Task 2: Stabilize the smallest ownership boundary

**Prompt:** Compare an explicit stable ToolbarItem with an isolated More-menu view against replacing the menu with a sheet. Select the smallest native SwiftUI correction supported by reproduction; keep the dropdown and all current actions. Do not use generic state layers, suppress ongoing media updates, move the camera preview, or change capture/recording/broadcast ownership. Add test evidence for periodic updates and existing navigation.

### Task 3: Validate and hand off

**Prompt:** Run the focused safe UI tests on the owned E0 Simulator only after its prior lease is released, plus the normal unsigned generic-iOS Release build. Preserve prior failures and authoritative exit/results. Update the canonical UI section and guide with exact evidence and pending phone retest. Commit the fix and hand the actual full diff against current main to a fresh independent reviewer through root; do not push or merge automatically.

## Candidate checkpoint

The original implicit menu passed the safe 10 Hz status/meter functional test in
portrait and both landscape orientations (one XCTest case, native exit 0). This
does not reproduce or disprove the owner's visual flicker. The candidate uses a
named `ToolbarItem` and a small menu view receiving only menu flags, stable
bindings and the renderer reference. The menu body does not observe the changing
media status, meter, image or whole overlay-health struct; actions still read the
current renderer when tapped. All existing menu actions and preview placement are
retained. The fixture is Debug-only, explicit opt-in and finite (20 seconds), with
capture and networking still isolated.

The first fixed functional/navigation run is still live at this checkpoint:
`/private/tmp/stream14-pr63-menu-fixed.xcresult`, log
`/private/tmp/stream14-pr63-menu-fixed.log`, native session `48889`. No successful
fixed result, Release result, independent review or physical flicker pass is
claimed yet. The owner requested installing this focused menu candidate for direct
verification; root owns review, signing and the newly authorized in-place install.
