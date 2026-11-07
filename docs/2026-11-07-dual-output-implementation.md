# Dual-output feasibility implementation plan

**Goal:** Establish the public encoded-output boundary and provide reproducible, explicit feasibility experiments for F1/#14 without changing production media behavior.

**Architecture:** Keep the existing one-camera HaishinKit mixer and LocalRecorder. Link RTMPHaishinKit only in the hosted test target. Exercise disconnected raw observation and compressed MP4 passthrough deterministically; provide an opt-in physical dual-encoder candidate to gather the evidence required before any production decision.

**Tech Stack:** Swift 6, HaishinKit/RTMPHaishinKit 2.3.0, AVAssetWriter/AVAssetReader, native Xcode hosted tests.

---

### Task 1: Verify the boundary

**Prompt:** Read issue #14 and canonical specification sections 6–7. Trace pinned source at `aa2149df822f2e965adf2410a106db959b2e1962`, verify latest upstream release, document public vs package-only codec/output APIs and disconnect behavior. Compare library dual encoding, app-owned single encoder with public compressed ingestion, and an upstream API change. Keep production adoption pending physical evidence and an explicit architecture decision.

### Task 2: Add test-only experiments

**Prompt:** Add `Stream14Tests/DualOutputFeasibilityTests.swift`, link only RTMPHaishinKit in the hosted test target, and leave production frameworks unchanged. Verify that an idle stream observer receives raw input while a local file completes; remux real H.264/AAC packets with nil output settings/source hints and compare bytes/timestamps. Record disconnected compressed calls as compile/call compatibility only; Void append catches/logs errors and cannot prove format acceptance. Add a separately enabled private physical candidate using the existing MediaSession and changing alpha fixture; retain originals and redact failures/configuration. Never connect by ordinary tests.

### Task 3: Validate and hand off

**Prompt:** Build unsigned Release with the shared Stream14 scheme and pinned package cache, run focused hosted tests on the iPhone 13 mini Simulator, and run `git diff --check` and plist lint. Record exact results and missing physical evidence in feasibility/specification/development guide and the epic ledger. Obtain independent review of actual full diff against main, fix material findings, rerun affected checks, commit, and prepare a PR body. Do not merge or claim device acceptance.
