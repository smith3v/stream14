# HaishinKit Local Media Experiment Implementation Plan

**Goal:** Demonstrate issue #3's local-only camera/audio/replaceable alpha-image recording route on the iPhone 13 mini.

**Architecture:** Use HaishinKit 2.3.0 core MediaMixer in offscreen mode, one ScreenActor-owned image layer, MTHKView and native StreamRecorder. A main-actor experiment model serializes user actions and keeps writer lifetime separate from capture. Preserve incomplete samples and expose native playback/export for private inspection.

**Tech Stack:** Swift 6, SwiftUI, HaishinKit core via exact SPM pin, AVFoundation audio/permissions/asset inspection, Swift Testing and XCTest.

---

### Task 1: Verify and pin public APIs

**Prompt:** Inspect the exact stable tag's Package.swift, license, MediaMixer, Screen, ImageScreenObject, MTHKView and StreamRecorder. Record selection/tradeoffs and limitations in docs/feasibility.md before editing Stream14.xcodeproj/project.pbxproj. Add only the HaishinKit core product at exact 2.3.0. Resolve with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -resolvePackageDependencies -project Stream14.xcodeproj -scheme Stream14 -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages`. Inspect Package.resolved and target build graph, preserve local signing changes, and commit the dependency/docs without personal team values.

### Task 2: Implement the experiment

**Prompt:** Add Stream14/Media/MediaExperiment.swift, SyntheticOverlay.swift and ExperimentSample.swift. Request camera/microphone on an explicit user action. Configure one rear wide-angle camera and microphone through MediaMixer, 1920×1080 landscape/30 fps and a 1 Hz transparent counter image on ScreenActor. Connect composed preview and the native recorder directly as mixer outputs. Create persistent UUID MP4 samples and status sidecars under backup-excluded Application Support; retain failed files. Stop/finalize on explicit action, background or interruption, with no automatic resume. Check recorded audio/video tracks after stop but label native finish results as requiring inspection due to the upstream limitation. Update SetupView with native experiment controls and original-file playback/share; no WebKit/transport/production recovery. Build with `xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/stream14-issue3-device CODE_SIGNING_ALLOWED=NO build`. Resolve compiler diagnostics without unchecked concurrency suppression.

### Task 3: Verify state, UI, and device path

**Prompt:** Add meaningful sample/status lifecycle and synthetic alpha tests in Stream14Tests; update Stream14UITests for explicit permissions, accessible idle controls and layout. Run `xcodebuild -project Stream14.xcodeproj -scheme Stream14 -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' -derivedDataPath /tmp/stream14-issue3-simulator -resultBundlePath /tmp/stream14-issue3-tests.xcresult test`. Build/sign/install on the connected 13 mini using local signing values. Owner allows permissions and records a short clap/scene; privately inspect exported original MP4 for 1080p, actual camera/mic, alpha, a changing counter, A/V sync and missing app UI. Record exact outcomes/limits in feasibility.md and update the canonical spec, implementation plan, README and development guide. Do not claim device media success from Simulator or close unmet acceptance.

### Task 4: Independent review and PR

**Prompt:** Run git diff --check, native checks appropriate to final changes, and inspect public diff for signing/private media leakage. Have a separate agent inspect the actual full diff against origin/main, relevant AGENTS/spec/issue requirements and validation evidence. Fix material findings, rerun affected checks and request focused re-review as needed. Commit focused changes, open a PR into main referencing #3, record the independent outcome and concrete next-stage commands/limitations. Do not merge or claim full MVP qualification.
