# Recording UI polish implementation plan

**Goal:** Implement issue #30's footer links, accessible recording action row and actual video sizes on the full-app integration branch.

**Architecture:** Retain MediaSession's recording ownership, playback sheet, original ShareLink export and confirmed deletion. A small RecordingRow reads optional per-file metadata from ExperimentSample; missing/unreadable/nonregular files have unavailable size and disabled Play/Export. No persisted size, capacity polling or estimates. Use one row per saved recording instead of duplicating latest-file actions.

**Tech Stack:** Swift 6, SwiftUI, Foundation file attributes/ByteCountFormatter, Swift Testing and XCTest, existing native Xcode scheme.

---

### Task 1: Metadata and action row

**Prompt:** In `Stream14/Media/ExperimentSample.swift`, add `fileSize(in:) -> Int64?` using the selected UUID MP4's regular-file attributes, preserving nil for errors and zero for a real empty file. In `Stream14/App/SetupView.swift`, render date/time plus formatted size in wrapping text, status, and one horizontal row of Play/Export/Delete SF Symbols. Give labels at least 44×44 points and dated accessibility labels; preserve delete confirmation. Move Privacy policy beside Third-party notices in an adaptive footer. Keep original-file export and playback ownership unchanged. Avoid new dependencies or project/signing edits.

### Task 2: Verification

**Prompt:** Add temporary-directory tests in `Stream14Tests/RecordingFileSizeTests.swift` for actual size after rewrite, missing video, real empty video and unexpected directory. Add opt-in seeded Simulator UI checks in `Stream14UITests/SetupScreenTests.swift` for available/missing rows, actions/confirmation, footer position, both landscape orientations and portrait at normal/largest text. Inspect retained screenshots and run accessibility audits. Seed only synthetic fixtures; never delete unrelated recordings or enable camera experiments. Run `xcodebuild -project Stream14.xcodeproj -scheme Stream14 -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' -derivedDataPath /tmp/stream14-issue30-build -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages -disableAutomaticPackageResolution -resultBundlePath /tmp/stream14-issue30-tests.xcresult test`, plus an unsigned generic iOS Release build. Expected: native checks pass with device-only checks skipped. Physical VoiceOver/playback/export remain explicit if unavailable.

### Task 3: Documentation, review and delivery

**Prompt:** Update the relevant interface and policy-link sections in `docs/2026-11-01-stream14-design.md` and add reproduction/evidence to `docs/ios-development-guide.md`. Record #23's carry-forward contract here. Check `git diff --check`. A separate agent must inspect actual files, full diff against current origin/main and incremental origin/codex/full-app diff, requirements and validation. Fix material findings and rerun affected checks. Commit only issue changes and open a PR into `codex/full-app`, referencing #30/#23 and recording independent review and physical acceptance limits. Do not merge or backport to main.

## Carry-forward for issue #23

Retain the per-recording size and horizontal icon actions with dated VoiceOver labels, 44-point targets, confirmed deletion and original export when splitting the full-app recordings UI. Keep policy/notices together in the footer. A missing size must never become a fabricated zero.

## Validation and handoff

- Xcode 27.2/iOS 27.2: complete hosted suite passes 23 tests in 9 suites, including the new file-size cases (`/tmp/stream14-issue30-unit2.xcresult`).
- Final unsigned generic iPhone Release build passes (`/tmp/stream14-issue30-release-final2.log`). No package or signing changes.
- Seeded 13 mini Simulator layout check passes all six combinations of portrait/both landscape directions and normal/accessibility XXXL text (`/tmp/stream14-issue30-layout7.xcresult`). Retained row/footer screenshots were visually inspected. Target geometry, dated action labels, missing-file behavior, footer placement and scoped accessibility audits pass.
- Original playback sheet and system Save to Files availability pass (`/tmp/stream14-issue30-ui2.xcresult`, focused playback/export test). Cancel/confirmed selected-only deletion plus baseline launch/large-text/overlay-settings checks passed in the first UI run (`/tmp/stream14-issue30-ui.xcresult`); that first bundle also contains the superseded footer/test failures. The final footer uses native AnyLayout to preserve control identity while switching to a column for accessibility text sizes.
- The audit exception is limited to contrast on vertically clipped static text at scroll boundaries, using pre-audit geometry because the audit can alter scrolling/navigation height. Controls, full text and all other audit types remain checked. See the guide for reproduction/scope.
- A separate non-author agent inspected actual files and full diffs against current origin/main and origin/codex/full-app, plus focused footer/test changes. Final independent review: no material findings. Relative documentation links and `git diff --check` pass.

Physical 13 mini layout/spoken VoiceOver, actual media playback and completed Files
export/readback remain pending. No phone app was replaced and no camera experiment
was run. Only the isolated synthetic Simulator deletion fixture was removed; other
recordings and the original checkout's local signing edits were preserved. The initial plan was a draft PR into `codex/full-app`; the owner’s subsequent
merge/release authorization below supersedes that handoff.


## Owner-authorized merge, main backport and TestFlight update

The owner explicitly authorized merging when reviewed/ready and autonomously
delivering the update through TestFlight while away from the laptop. PR #31 merged
into `codex/full-app` at `25c3d26`. Issue #6 had closed at the owner’s request;
a focused backport onto current main preserves its newer owner-verification
records while carrying the exact reviewed UI/app/test files from `efeb462`.
No broader full-app development is promoted.

The signed 0.1 (2) archive uses that same app source, with build number 2 supplied
as an archive override, the existing paid team/account and normal automatic
signing. Signature/manifest checks and native upload pass. See the
[release record](2026-11-05-recording-ui-testflight.md) for processing, group
availability and the distinction from actual phone installation.

At 23:10 Amsterdam on 2026-11-05, App Store Connect shows 0.1 (2) Testing in
Owner MVP after compliance and group assignment. Beta update notes were saved.
The final main backport was independently reviewed with no material findings;
all 30 app/project/test files match `efeb462`, and documentation/whitespace checks
pass. Actual phone installation and physical UI/media acceptance remain unverified.
