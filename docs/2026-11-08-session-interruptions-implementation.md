# Session Interruptions Implementation Plan

**Goal:** Stop the whole foreground session safely on system interruption and require explicit same-event resume while preserving asymmetric output independence.

**Architecture:** Keep MediaSession responsible for capture/encoder/writer cleanup and BroadcastSession responsible for cancellation and remote uncertainty. A direct main-actor callback connects those owners; optional nonsecret journal fields support a guarded explicit resume without credentials.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, UIKit, existing HaishinKit mixer/shared encoder, Swift Testing, native Xcode.

---

### Task 1: Remote cancellation and explicit resume

**Prompt:** Extend Stream14/Broadcast/PendingRemoteBroadcast.swift with optional interrupted/stream/profile fields. Extend Stream14/Broadcast/BroadcastSession.swift with interruption cancellation, read-only foreground reconciliation and explicit resume confirmation. Add read-only same-binding resume validation in Stream14/YouTube/YouTubeBinding.swift; never insert/bind during resume. Require no unsettled/ambiguous transition before upload, writer admission before network, and no repeated live POST for a live event. Add deterministic cases in Stream14Tests/BroadcastSessionTests.swift for late results, repeated stops, relaunch, terminal/changed events and ambiguity. Commit the implementation after affected checks.

### Task 2: Media lifecycle integration

**Prompt:** Extend Stream14/Media/MediaSession.swift observers and thermal decisions with direct interruption notification, audio input-loss handling, background expiration metadata and persistent backup-failure status. Update Stream14/App/SetupView.swift and Stream14/Broadcast/BroadcastControlsView.swift for foreground reads and explicit resume. Preserve one encoder and output independence. Add meaningful injected lifecycle tests using existing media fixtures. Run native Stream14 Simulator fixtures using the shared simulator lease; no physical/live service work.

### Task 3: Review and handoff

**Prompt:** Update docs/2026-11-01-stream14-design.md and docs/ios-development-guide.md with actual ownership, commands and limitations. Run git diff --check and affected Stream14 tests with xcodebuild -project Stream14.xcodeproj -scheme Stream14 -destination 'platform=iOS Simulator,id=D6BEAF78-D273-4952-8349-B50B2824E6A9' -derivedDataPath /private/tmp/stream14-f9-tests -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages -only-testing:Stream14Tests test. Parent arranges an independent review of the actual diff against main and focused stage delta. Fix material findings, rerun affected checks, commit and hand off without publishing/merging.
