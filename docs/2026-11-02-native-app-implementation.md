# Native App Setup Implementation Plan

**Goal:** Implement issue #2: a reproducible minimal SwiftUI app and native tests,
then verify installation on the testing iPhone 13 mini.

**Architecture:** One iPhone app target displays a native, scrollable setup screen.
A hosted Swift Testing target checks the built app's configuration; an XCUITest
target checks launch, orientation, and accessible layout. No media pipeline or packages.

**Tech Stack:** Xcode 27.2, Swift 6, SwiftUI, Swift Testing, XCTest/XCUIAutomation,
iOS 27.0 deployment target.

---

### Task 1: Establish the project

**Prompt:**
Create the ordinary root-level Stream14.xcodeproj and shared Stream14 scheme on
codex/issue-2-native-app from current main. Add the entry point at
Stream14/App/Stream14App.swift and a minimal setup view at
Stream14/App/SetupView.swift. Use com.smith3v.stream14 (owner confirmed 2026-11-02),
Swift 6, iPhone only, portrait and both landscape orientations. Use automatic
signing without inventing a development team. Do not register an Apple identifier,
add packages, request permissions, or implement future media controls.

### Task 2: Add focused native checks

**Prompt:**
Add Stream14Tests/AppConfigurationTests.swift to inspect the actual hosted app's
identity/deployment/device configuration, and Stream14UITests/SetupScreenTests.swift
to verify the honest setup status in portrait and landscape with larger text.
Use a Form and system typography so content scrolls and respects safe areas.
Inspect the shared scheme with xcodebuild -list and -showdestinations.

### Task 3: Build, test, and inspect

**Prompt:**
Use DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer explicitly. The owner
also selected Xcode as the system developer tools. Build for generic iOS without
signing, and run native tests on the dedicated iPhone 13 mini / iOS 27.2 Simulator.
Record the exact successful commands and results in docs/ios-development-guide.md;
do not predict success. Inspect portrait/landscape and large-text screenshots.
Run git diff --check and local Markdown link checks. Fix failures before committing.

### Task 4: Verify the physical phone and update the handoff

**Prompt:**
Explain Xcode account, signing-team selection, device trust, and Developer Mode to
the owner. Run the shared scheme on the physical 13 mini when access is ready.
Record model, OS, app version/build, and observed setup screen without private device
identifiers or credentials. If access remains unavailable, leave this acceptance
item explicitly pending. Update README.md, the specification's implementation
status, and Task 2 in the canonical implementation plan. Keep TestFlight and M1–M5
pending; stop before dependent issue work.

### Task 5: Independently review and prepare the PR

**Prompt:**
Have a separate agent inspect the full diff against main, actual files, issue #2,
and validation results for material problems. Fix findings, rerun affected checks,
and request focused re-review if needed. Commit the focused change and open a PR
into main referencing #2. Record the independent review outcome, exact next-stage
commands, and remaining owner/device setup. Do not merge or close unmet acceptance.
