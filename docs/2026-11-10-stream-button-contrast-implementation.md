# Streaming Button Contrast Implementation Plan

**Goal:** Make Start recording and streaming readable in light and dark mode while preserving its unavailable state and publishing confirmation.

**Architecture:** Use the same standard native bordered treatment as the adjacent Record only action and an explicit semantic primary label, retaining the screen’s monochrome tint and all readiness predicates. A complementary label on the prominent style is insufficient because its native disabled fill changes independently; no custom palette or button framework is added. Isolated Debug fixtures may request a SwiftUI color scheme so native UI tests verify both appearances without changing normal builds.

**Tech Stack:** Swift 6, SwiftUI, UIKit semantic colors, native Xcode/XCTest.

---

### Task 1: Reproduce the actual states

**Prompt:** Inspect the owner's private screenshot and actual source. The screen applies `.tint(Color.primary)` while the streaming action uses `.borderedProminent`; in dark mode both native fill and inherited label can become white, including when no event disables the action. Use isolated interface fixtures for ready and no-event states. Do not enable a disabled button or invoke capture/upload.

### Task 2: Apply the smallest contrast change

**Prompt:** In `Stream14/Broadcast/BroadcastControlsView.swift`, retain the existing action, 44-point target and all disabled predicates; replace `.buttonStyle(.borderedProminent)` with `.buttonStyle(.bordered)` and `.foregroundStyle(.primary)`. Avoid changing the page, preview position, More menu or media owners. Compare native enabled/disabled light/dark output and assert actual readable rendering in every state.

### Task 3: Verify and review

**Prompt:** Add a separate focused UI test file using safe preview/no-event fixtures. Assert enabled/disabled state and label, capture all four actual appearances and inspect rendered label/fill contrast; retain screenshots privately. Run the shared Stream14 scheme and ordinary unsigned Release. Record actual native results and limitations, check links and `git diff --check`, commit, and obtain independent actual-file review against current main before root incorporates the fix into PR #63. This is separate from the existing unresolved profile audit and is not physical phone qualification.

## Validation checkpoint

The owner supplied a private dark-mode screenshot of a blank white streaming pill
on Development source `6459c74` (PR63's initial phone candidate). The existing
screen-wide primary tint combined with a prominent style could make fill and
label equal. The final two-line change uses native bordered styling and semantic
primary foreground. Every selection/capture/overlay/writer eligibility predicate,
confirmation closure and 44-point minimum is unchanged. Native unavailable fill
and accessibility disabled state remain; only label readability is strengthened.

A complementary-background label candidate was rejected after actual Light
unavailable rendering measured about 1.15:1. Standard bordered alone preserved a
faint native unavailable label (about 1.94:1 Dark, 1.47:1 Light). The final explicit
primary label gives a substantial visual improvement in both unavailable states;
this was not a palette redesign or a change to publishing readiness.

Final native result `/private/tmp/stream14-pr63-button-readable.xcresult` and
`...-readable-summary.json`: **four passes, zero failures/skips**, native exit 0.
The public SwiftUI color-scheme fixture is Debug-only, requires the existing
isolated interface-fixture flag, and returns nil for normal launches. It is
compiled out of Release. Tests verify the actual page appearance, label,
44-point target, exact enabled/unavailable state and central-pill rendered pixels
without relying on rounded corners for contrast. Native label/fill raster ratios:

| Appearance | Enabled | Unavailable |
| --- | ---: | ---: |
| Dark | 10.37:1 | 9.11:1 |
| Light | 13.75:1 | 9.37:1 |

These screenshot measurements are regression evidence, not a certification of
whole-screen WCAG compliance. Inactive controls are exempt from WCAG's text
contrast minimum; the test's 1.5 inactive floor is a visibility-regression heuristic,
not an AA gate. All four private button crops were visually inspected and remain
in `/private/tmp/stream14-pr63-button-readable-images/` (not Git attachments).
The earlier failed theme-control and native-faintness runs are retained privately;
no failed run is relabeled as a pass.

The existing `testPreflightBlockersAndExactPublishingConfirmation` case separately
passed in 80.922 seconds on the bordered-only candidate, confirming unavailable
states and explicit confirmation/Cancel with fail-closed fixtures. That earlier
mixed suite failed its later authored inactive-visibility assertion; it is not a
successful five-case final-source run. Adding primary foreground is label-only;
the action, eligibility and confirmation code remains unchanged. No media was
captured or published by the fixtures.

Final ordinary unsigned generic-iOS Release passed with native exit 0; log
`/private/tmp/stream14-pr63-button-readable-release.log`. All twelve package
checkouts match the committed lockfile; private check record
`/private/tmp/stream14-pr63-button-package-check.json`. No phone operation, recording,
broadcast, TestFlight upload or version change occurred. The separate native
profile audit's unknown-node failure is not waived or claimed fixed. Physical
color verification remains a later owner visit.

Reproduce the four isolated native appearance checks with an owned Simulator:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination 'platform=iOS Simulator,id=3135E8B9-99D5-4287-BBC4-D6719CC0466D' \
  -derivedDataPath /private/tmp/stream14-pr63-button-build \
  -clonedSourcePackagesDirPath /private/tmp/stream14-pr63-button-packages \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -only-testing:Stream14UITests/StreamingButtonContrastTests \
  -resultBundlePath /private/tmp/a-new-stream-button-result.xcresult test
```

Use a new result path; existing evidence must not be overwritten. Independent
actual-file and final-evidence review is coordinated by root before PR63 handoff.

## Final integration checkpoint

Color commit `d3df258` normally inherits published PR63 menu head `b614a42` at
`e6a5c77`. The color component, App fixture-theme gate and focused test are unchanged
from the validated color commit; menu/runtime fixture sources are unchanged from
the independently reviewed and phone-tested menu head. There were no conflicts.
Independent actual-file, native-image and merged-delta review found no material
issues. Final documentation-only checks do not imply another media/device run.
