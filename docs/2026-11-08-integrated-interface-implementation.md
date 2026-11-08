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
