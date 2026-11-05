# Recording cleanup and experiment limits implementation plan

**Goal:** Let the owner deliberately remove old recordings and limit development experiments to fifteen minutes.

**Architecture:** Keep the existing saved-sample list and concrete MediaSession ownership. A confirmed per-row action removes only the selected UUID's video and sidecars; retain metadata until the other artifacts are gone so partial failures remain retryable. Disable deletion while capture/recording lifecycle operations are busy. No automatic cleanup, available-space polling or storage estimates.

**Tech Stack:** Swift 6, SwiftUI confirmation dialog, Foundation file operations, existing Swift Testing/XCTest targets.

---

### Task 1: Narrow file removal

**Prompt:** Add ExperimentSample.delete(in:) for its UUID MP4, observations JSON and status JSON only. Allow missing artifacts, refuse unexpected directories, and remove the status marker last. Add temporary-directory tests for selected-only removal, missing/incomplete files and failure/retry without recursive deletion.

### Task 2: Confirmed native action

**Prompt:** Add MediaSession.canDeleteSamples/deleteSample and a per-recording destructive button in SetupView with an explicit irreversible-action confirmation and Cancel. Preserve existing exported copies; clear the latest playback/export URL if its file was removed. Report partial failure honestly and refresh the list. Add an opt-in UI test that creates and deletes only its own new short recording, checking Cancel first and leaving existing records untouched.

### Task 3: Experiment policy

**Prompt:** Cap normal device experiment configuration at 900 seconds, retain short smoke checks, and record actual elapsed observations on interruption. Document the owner's 2026-11-05 change: fifteen-minute development checks now, longer integrated whole-app qualification later. Do not claim fifteen minutes passes a deferred long-run gate. Do not launch another storage-heavy experiment before the owner has reclaimed space.

### Task 4: Checks, review and PR update

**Prompt:** Run focused hosted deletion tests, native build and relevant UI/accessibility checks. Have a separate agent inspect the actual full diff against main and final cleanup/test changes for material correctness/data-loss issues. Resolve findings and rerun affected checks. Commit focused changes excluding existing local signing settings, update PR #10 and issue #5's current experiment scope, and do not merge.

## Validation and delivery

- Three focused Foundation deletion tests pass: selected-only artifacts, missing/pending files, and partial-failure retry without recursive deletion.
- The isolated Simulator UI test seeds only its own synthetic pending recording and verifies Cancel, confirmed removal and unchanged count of unrelated entries. It passes with the explicit native alert. No phone recording was deleted by automation.
- The regular native Simulator suite passes. Signed build-for-testing and unsigned Release build pass with the app icon.
- The shared scheme automatically brands the separate UI runner. Simulator and physical runner icon metadata/display name are verified; physical normal signing and strict signature verification pass. A missing expanded signing environment value is handled by reusing the exact public leaf certificate already selected by Xcode, not a guessed identity.
- Independent review found and corrected the certificate-extraction optional-argument syntax. Focused re-review found no remaining material issue in deletion, duration control or branding.
- Installed both updated app products on the owner's 13 mini. Recording artifact filename/size maps before and after installation are identical. The app was updated in place; no uninstall, recording experiment or automatic cleanup was performed.

Private checks/results: `/tmp/stream14-issue5-deletion2.xcresult`,
`/tmp/stream14-issue5-delete-ui2.xcresult`,
`/tmp/stream14-issue5-cleanup-suite.xcresult`,
`/tmp/stream14-issue5-phone-icons-build3.log`, and
`/tmp/stream14-issue5-cleanup-release.log`.


## Owner acceptance and closeout

On 2026-11-05 the owner confirmed deleting old recordings reclaimed phone storage
and both icons are in place. PR #10 is finalized and marked ready for review at the
owner's request; merging is not authorized. Longer whole-app qualification remains
deferred, with development experiments capped at fifteen minutes.


## Verification follow-up: private assertion diagnostics

**Goal:** Prevent failed Swift Testing assertions from reflecting a MediaSession
and printing its Keychain-loaded overlay URL or renderer request URL.

**Design:** Snapshot only the relevant Boolean, phase/status, UUID, saved sample or
local file URL before each assertion. Keep the session/renderer outside the macro
expression. This avoids adding production diagnostic conformances or a generic
assertion framework; runtime app behavior and test decisions remain unchanged.

1. Update direct session assertion expressions in `Stream14Tests/MediaDeviceTests.swift`
   and `Stream14Tests/MediaExperimentTests.swift` to use safe local values.
2. Build the test target and run focused Simulator media lifecycle tests without
   enabling private physical camera tests. Inspect all changed assertions for
   remaining session/renderer captures; no new recording is required.
3. Have the independent reviewer inspect the actual diff and validation results;
   resolve material findings before handing off the PR. Keep the failed raw log
   private because it already contains reflected session state.
