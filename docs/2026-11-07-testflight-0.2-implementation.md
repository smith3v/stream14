# TestFlight 0.2 Implementation Plan

**Goal:** Deliver merged rear-lens and overlay-layout improvements as TestFlight 0.2 (3).

**Architecture:** Archive merged main's app source with only version/build metadata changed. Reuse existing Apple signing/account and internal Owner MVP distribution. Keep private signing and export settings outside Git.

**Tech Stack:** Xcode 27.2, Swift 6, pinned SPM packages, xcodebuild archive/export, App Store Connect.

---

### Task 1: Prepare release metadata

**Prompt:** Start `codex/testflight-0.2` from main after PR #36 merges. Preserve unrelated project signing settings. Set both app configurations in `Stream14.xcodeproj/project.pbxproj` to `MARKETING_VERSION = 0.2` and `CURRENT_PROJECT_VERSION = 3`. Document the owner convention: each TestFlight update containing newly merged main changes increments the minor version; replacement uploads within that release retain the marketing version and increment the globally increasing build number. Confirm current TestFlight versions/builds before upload.

### Task 2: Archive and verify

**Prompt:** Use the shared scheme, Release, generic iOS, existing paid team and pinned `/tmp/stream14-issue3-packages` cache to archive into `/tmp/stream14-testflight-0.2-build3.xcarchive`. Verify strict signature, version/build/bundle ID, icons, privacy manifest, permission strings, linked libraries and no test fixtures. Reuse the actual-source native tests and owner development review from #33/#34; metadata-only packaging needs archive validation rather than another recording experiment. Recheck Apple's submission/upload/privacy rules and record evidence. Independently review full diff against main, address material findings, run documentation/whitespace checks and commit only release files.

### Task 3: Upload, distribute and record

**Prompt:** Export with `method=app-store-connect`, `destination=upload`, automatic signing, `manageAppVersionAndBuildNumber=false`, symbols and internal-only distribution. Use existing Xcode account; do not create credentials. Wait for processing, resolve compliance using the inspected OS-only encryption boundary, save release-specific What to Test notes and assign the existing Owner MVP group. Verify actual Testing availability. Record results/limits in `docs/testflight-delivery.md` and a focused release record; independently review final documentation and prepare a PR into main. Do not merge. Owner installation from TestFlight and delivered-build media qualification remain separate evidence.
