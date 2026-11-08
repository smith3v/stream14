# Recording recovery Implementation Plan

**Goal:** Keep interrupted and orphaned recordings visible, inspect native readable media, and offer a separate passthrough recovery copy while preserving every original.

**Architecture:** Extend the existing Codable manifest, with backward-compatible optional review/profile/duration metadata and per-attempt recovered artifacts. Directory reconciliation identifies UUID media even when metadata is missing or malformed. Native inspection/export runs outside UI ownership; only a successful writer finish marks an original complete. Recovery has its own status and never changes that provenance.

**Tech Stack:** Swift 6, Foundation, AVFoundation AVAssetReader and AVAssetExportPresetPassthrough, SwiftUI, existing native Xcode tests.

---

Design considered: retaining only raw export would avoid recovery but would omit F11's supported-remux requirement; in-place repair would risk the only original and has no verified public API. Use distinct native passthrough exports and retain failed partial attempts. Keep MP4 and a ten-second movieFragmentInterval; verify with the actual app codec and writer in an owned synthetic Mac process before claiming feasibility. No parser, transcode, database or storage forecasting.

### Task 1: Reconcile manifests and orphaned artifacts

**Prompt:** Extend Stream14/Media/ExperimentSample.swift with compatible schema/profile/duration/review and recovery-attempt records. Preserve corrupt metadata, discover UUID originals and partial recovery attempts, convert inactive pending records to interrupted, and exclude the active UUID from review. Test legacy, corrupt/missing metadata, missing media, relaunched pending states and deletion retry in Stream14Tests/RecordingRecoveryTests.swift. Commit the model change after validation.

### Task 2: Native review and separate recovery

**Prompt:** Implement Stream14/Media/RecordingRecovery.swift using bounded-memory compressed AVAssetReader checks for nonempty audio and video through completion and native passthrough export to a new artifact. Persist attempt status before export; preserve all originals/partials on every outcome. Add MediaSession review/recovery entry points, configure the production writer interval before startWriting, and repeat Tools/fragment-recovery with actual SharedMediaCodec/LocalRecorder sources at 44.1 kHz stereo. Verify normal finish, pre-fragment termination, post-fragment termination and finalization race. Commit useful code and evidence.

### Task 3: Integrate recordings review UI

**Prompt:** Merge the completed F10 stage. Add persistent review/status/duration, explicit recovery action, distinct recovered playback/export and confirmed deletion. Disable mutation while capture/recovery is active; retain originals and existing original export. Test important lifecycle transitions and native failure paths. Run xcodebuild test for focused suites then full suite on a disposable iPhone 13 mini simulator; run unsigned Release build. Record exact commands and honest physical evidence gaps in docs/ios-development-guide.md and a focused handoff.

### Task 4: Independent review and handoff

**Prompt:** Commit the full focused change, run git diff --check, and supply root with the actual diff against main and F10, validation outputs and relevant requirements for an independent agent review. Resolve material findings and rerun affected checks. Do not publish/merge this PR; root owns reviewed publication. Physical forced app termination/relaunch/export and A5 remain pending until separately observed within the owner's shared phone budget.
