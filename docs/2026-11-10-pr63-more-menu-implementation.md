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

## Final validation and owner confirmation

Runtime checkpoint `4c097ae` passed **two focused native UI cases**, zero failures
or skips, in `/private/tmp/stream14-pr63-menu-fixed.xcresult`; the native command
exited 0 with TEST SUCCEEDED. The menu case keeps the native popup actionable for
three seconds under actual changing fixture status/meter values in portrait and
both landscapes, then checks Settings and landscape Navigate. The second case
checks ordinary destination/settings navigation without capture or publishing.
Together their test bodies took 167.462 seconds. The original-menu baseline had
one passing functional case; no automated visual flicker reproduction is claimed.

The ordinary unsigned generic-iOS Release build also exited 0 with BUILD SUCCEEDED,
log `/private/tmp/stream14-pr63-menu-release.log`. All twelve warmed dependency
checkouts matched Package.resolved, including the unchanged HaishinKit pin. Native
summaries and exit evidence remain private at
`/private/tmp/stream14-pr63-menu-{baseline-summary,fixed-summary,validation-outcome}.json`.
No camera, network publishing or TestFlight operation occurred in these checks.

At the owner's explicit request, root separately prepared and normally signed the
same runtime, then installed and ordinarily launched **Development 0.3 (4), source
`4c097ae`**, in place. Elevated native install/launch exited 0 (7.398/0.502 seconds);
the earlier sandbox-only CoreDevice-service attempt failed without contacting the
phone. The agreed visit started 22:33:02 UTC with a 22:38:02 cutoff. Installation
used no fixture arguments/environment; it did not uninstall, reset or read the
container. Private native evidence is retained under
`/private/tmp/stream14-pr63-menu-install-*.json`, including the outcome file.

The owner subsequently confirmed **“I confirm the flickering is resolved.”** This
is the narrow physical More-dropdown result on the installed `4c097ae`; no recovery
latency, whole-interface/VoiceOver/rotation qualification, recording or receiver
pass is inferred. The separate blank prominent streaming-button contrast finding
was not included in this installed menu candidate and remains separate work.
The previously installed source `6459c74` is superseded; earlier preview-only
`70eca51` evidence remains scoped to that source. Root owns independent final
review and PR publication, and no automatic merge is authorized.

No additional health fixture, timer or broader test sweep was added after this
direct owner confirmation. The menu already takes the manual-hidden/configured
flags as scalar inputs; its body does not observe whole health updates. Its actions
read the current renderer when invoked.

To repeat the focused fixture check, use fresh result paths from this clone:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination 'platform=iOS Simulator,id=E0ABEB8B-B5A5-4FC9-AD6A-FA6A5908A78C' \
  -derivedDataPath /private/tmp/stream14-pr63-menu-build \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -only-testing:Stream14UITests/SetupScreenTests/testMoreMenuRemainsUsableDuringSessionUpdates \
  -only-testing:Stream14UITests/SetupScreenTests/testNativeDestinationsNeverStartCaptureOrPublishing \
  -resultBundlePath /private/tmp/a-new-more-menu-result.xcresult test
```

Release uses the same project/scheme and pinned cache, configuration Release,
destination `generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO build`; the existing
Release-derived-data lease was idle before this stage reused it. All native jobs
are terminal/reaped. E0 remains available for root's next coordinated stage; D6
was not touched.
