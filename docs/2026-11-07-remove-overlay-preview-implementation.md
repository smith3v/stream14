# Remove Separate Overlay Preview Implementation Plan

**Goal:** Resolve issue #34 by reclaiming the main screen's overlay strip while preserving composed media and overlay controls.

**Architecture:** Keep the existing attached 1920×1080 WebKit source host at its nonzero presentation size behind the opaque scroll surface in a top-aligned ZStack. The scroll content occupies the whole available area. No renderer, composition or recording lifecycle changes.

**Tech Stack:** Swift 6, SwiftUI, UIKit/WebKit, existing HaishinKit pipeline, native Xcode tests.

---

### Task 1: Reclaim the layout space

**Prompt:** In `Stream14/App/SetupView.swift`, replace the outer VStack with a top-aligned ZStack, retain the attached source's 60-point host, and give the foreground ScrollView an opaque system background. Retain overlay status, settings and manual hiding. Do not hide, detach, zero-size or reduce the alpha of WebKit. A removed/detached browser risks snapshots; a transparent or zero-height host also changes the verified rendering conditions. Covering its existing host is the smallest approach to validate.

### Task 2: Verify rendering and layout

**Prompt:** Extend `Stream14Tests/WebOverlayRendererTests.swift` to cover the attached 60-point host with an opaque view and verify full-canvas alpha snapshots, continuing changing pixels and manual hiding. Extend the existing setup UI check in `Stream14UITests/SetupScreenTests.swift` to assert the heading begins with only standard padding and status/manual-hide controls remain. Run the native Simulator suite and unsigned Release build using the guide's shared scheme/package cache, fresh `/tmp/stream14-issue34-*` derived data/results. Inspect retained portrait and landscape screenshots. Physical covered-WebKit/recording acceptance remains separate if the phone is unavailable.

### Task 3: Document, review and hand off

**Prompt:** Update the relevant specification and guide sections with the actual attachment/presentation decision and evidence, run `git diff --check`, and ask an independent agent to inspect the complete diff against `origin/main` plus requirements and check results. Resolve material findings, rerun affected checks, commit only issue files (exclude the pre-existing project signing edit), and prepare a PR into main recording results and review outcome. Do not merge.
