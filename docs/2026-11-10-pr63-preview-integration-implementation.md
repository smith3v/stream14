# PR63 Preview Integration Implementation Plan

**Goal:** Prepare the Session workspace for a direct development-phone check while retaining the reviewed preview recovery fix.

**Architecture:** Normally merge PR #68 into PR #63 without rewriting shared history. Keep the existing workspace and media/coordinator owners; resolve only overlapping source/documentation changes and preserve fresh-frame readiness and view identity.

**Tech Stack:** Swift 6, SwiftUI, existing HaishinKit pin, Xcode native tests and Release build.

---

### Task 1: Integrate reviewed source

**Prompt:** Start at PR63 `100ed21` in a separate clone. Normally merge PR68 `52cdc67`, resolve overlapping `Stream14/App/SetupView.swift` and `Stream14/Media/MediaSession.swift` changes, and preserve both parents' canonical documentation. Keep interface fixtures before native capture; preserve workspace reset guards, preview-only restoration, metadata-only frame readiness and explicit view remount. Do not include deferred PR69 or change packages/signing/version.

### Task 2: Verify the integrated application

**Prompt:** Use the shared Stream14 scheme and an owned iPhone 13 mini Simulator. Run PreviewForegroundTests, SessionInterruptionTests, BroadcastSessionTests, SessionProfileTests, SessionWorkspaceTests, YouTubeBindingTests and RecordingFinalizationTests plus `SetupScreenTests/testNativeDestinationsNeverStartCaptureOrPublishing`. Use unique result/derived-data paths and a verified pinned package cache. Run the ordinary unsigned generic-iOS Release build. Inspect authoritative native summaries and final exits; do not restart a live job on an observation timeout.

### Task 3: Document and independently review

**Prompt:** Update this checkpoint and the development guide with exact merge/source/build/test evidence and pending physical UI/contrast-audit acceptance. Check local links, fences and `git diff --check`. Have a separate agent inspect the full diff against main and the actual merge delta, resolve material issues and repeat affected checks. Commit and hand the root agent the normally pushable PR63 head; retain draft status until acceptance is addressed. No phone install, camera/recording, publishing or TestFlight operation occurs in this stage.
