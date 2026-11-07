# Overlay recovery and safe URL editing Implementation Plan

**Goal:** Keep a configured foreground overlay running and make URL changes deliberate, validated and reversible until applied (issue #38).

**Architecture:** MediaSession owns the committed URL and foreground intent; the settings sheet owns an unapplied draft. A renderer timer supervises callback-based WebKit capture independently of WebKit completion. A session reconciliation task ensures the configured renderer remains running; replacing a stalled browser invalidates prior delegates/results without accumulating suspended capture tasks. Empty configuration cancels and clears all overlay work. Capture/recording ownership remains unchanged.

**Tech Stack:** Swift 6, SwiftUI, WebKit public navigation/JavaScript/snapshot APIs, Foundation Timer, existing Keychain store, Swift Testing/XCTest and shared Stream14 scheme. No new dependencies.

---

### Task 1: Configuration and foreground intent

**Prompt:** In `Stream14/Media/MediaSession.swift`, make `overlayURL` read-only outside its owner, implement `applyOverlayURL(_:) -> Bool` with validation before Keychain persistence, and reconcile a saved valid URL while foregrounded. Inject only read/save closures for deterministic configuration failure tests. In `Stream14/App/SetupView.swift`, edit a sheet-local draft, apply explicitly, and reset unapplied edits when opening the sheet. Wire foreground/background changes without resuming media. Keep existing recording/setup restrictions. Add lifecycle/persistence tests in `Stream14Tests/OverlayConfigurationTests.swift`.

### Task 2: Bounded renderer recovery

**Prompt:** In `Stream14/Media/WebOverlayRenderer.swift`, replace capture's potentially indefinitely suspended async loop with weak, generation-checked callbacks and a timer. Keep independent source/render health, approximately 1 Hz snapshots, 6-second operation deadline, 2-second failure retry and 10-second hide. Recover a missing ticker, stopped renderer, failed navigation/process or stalled render using foreground intent; recreate the browser when necessary and ignore old browser delegates/results. Update `OverlayViewport` when its browser changes. Preserve manual-hide intent. Disable cancels loading/timer, clears images and releases the old document. Add real attached fixture tests for stopped work, process termination, stale callbacks, replacement and disabling; inject monotonic time for deadlines. Run affected tests and fix failures.

### Task 3: Verify and document

**Prompt:** Update the relevant specification sections and `docs/ios-development-guide.md`, explicitly superseding historical manual-Load behavior. Run `git diff --check`; run the shared Stream14 scheme's hosted tests and focused UI settings tests on the Stream14 iPhone 13 mini Simulator with `/tmp/stream14-issue3-packages` and a new result bundle; build unsigned Release for generic iOS. Inspect normal/largest-text settings and cancellation. Ask for/perform a short paired-13-mini check of actual WebKit recovery and preview/recording, never exceeding 15 minutes or deleting originals. Record actual evidence and limitations.

### Task 4: Independent review and PR

**Prompt:** Request a separate agent to inspect the actual files and full diff against current main, requirements and validation results for material correctness/privacy/reliability/build/test gaps. Resolve material findings, rerun affected checks, and request focused re-review when behavior changes. Commit the focused change and prepare a PR into main with independent review outcome and any unverified device criteria. Do not merge.

Commands (run from the focused worktree):

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' -derivedDataPath /tmp/stream14-issue38-simulator -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages -disableAutomaticPackageResolution -resultBundlePath /tmp/stream14-issue38-hosted.xcresult -only-testing:Stream14Tests test
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/stream14-issue38-release -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Success requires actual `TEST SUCCEEDED`/`BUILD SUCCEEDED`; Simulator success does not qualify physical media performance. Use fresh result-bundle names for reruns.
