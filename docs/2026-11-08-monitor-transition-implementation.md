# Required YouTube Monitor Transition Implementation Plan

**Goal:** Honor the existing event's required monitor phase under one explicit Go Live confirmation.

**Architecture:** Extend the existing decoded broadcast content details and BroadcastSession startup loop. Reuse its durable mutation UUID, outstanding-request barrier, cancellation/account fences and bounded startup deadline; no new user mode, event settings or resources.

**Tech Stack:** Swift 6, Foundation Codable, Swift Testing, native Xcode.

---

### Task 1: Decode and preserve the monitor setting

**Prompt:** Add optional `monitorStream.enableMonitorStream` to Stream14/YouTube/YouTubeModels.swift. Missing/null remains unknown: Google's true default is an insert default, not proof of an omitted list value. Refuse a manual startup with unknown setting before publishing, and freeze the known setting with confirmation. Add decoder coverage for true/false/missing/null and malformed types.

### Task 2: Add the required internal phase

**Prompt:** In Stream14/Broadcast/BroadcastSession.swift, after active ingestion, send testing once only when enabled and ready. Await an authoritative testing read before sending live once. Existing testing skips the testing POST; testStarting waits. Disabled monitor goes directly live; auto-start still only polls. Journal every mutation before POST. Timeout/cancellation/relaunch retain uncertainty; no blind mutation retry or implicit resume.

### Task 3: Validate lifecycle and document

**Prompt:** Extend Stream14Tests/BroadcastSessionTests.swift fixtures for both monitor settings, intermediate states, uncertain/lost/late testing responses, timeout/relaunch, cancellation, End and account changes. Use isolated Simulator native focused tests then relevant full regression and unsigned Release build with /private/tmp/stream14-transport-fix-packages and -disableAutomaticPackageResolution. Record exact results and material remaining limits. Update section 5 of docs/2026-11-01-stream14-design.md with official resource and migration sources. Run git diff --check. Commit focused checkpoints. Parent arranges independent full-diff review, fixes and PR into main; no publishing/merging or device/API/media actions in this stage.
