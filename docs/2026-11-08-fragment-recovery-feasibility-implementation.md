# Fragment recovery feasibility Implementation Plan

**Goal:** Measure native recovery of synthetic MP4 files after a private child writer is killed, without touching production recording or using a phone.

**Architecture:** A standalone macOS Swift executable generates H.264/AAC, writes ten-second movie fragments, and signals deterministic checkpoints. A parent harness kills only its own child, retains originals, reads every recovered sample with AVAssetReader, and attempts a distinct AVAssetExportPresetPassthrough MP4. This is early F11 feasibility, not A5 or production F11 completion.

**Tech Stack:** Swift, AVFoundation, CoreMedia, CoreVideo, Foundation; Python standard-library process orchestration.

---

### Task 1: Inspect requirements and native APIs

Read canonical specification §7/A5, full-app plan F11, development guide, progress, LocalRecorder and ExperimentSample. Inspect installed Apple SDK headers and official Apple documentation. Candidate approaches: native fragmented MP4 plus passthrough export (selected smallest change); MOV only if MP4 fails and evidence justifies comparison; custom parser/transcode rejected by scope. Preserve originals and never cancel valued partial writing.

### Task 2: Build and run independent laptop probe

Add `Tools/fragment-recovery/Probe.swift` and `Tools/fragment-recovery/run.py`. Generate timed color/video and PCM tone, encode H.264/AAC with AVAssetWriter, interval ten seconds. Test normal stop, kill before first fragment, kill after completed fragments, and actual asynchronous finalization race. Compile using `xcrun swiftc -O -swift-version 6 -module-cache-path /private/tmp/stream14-f11-module-cache -parse-as-library Tools/fragment-recovery/Probe.swift -o /private/tmp/stream14-fragment-probe`. Run harness into a new private output directory. Record track counts, decoded endpoints, asset duration, writer status, file size, original SHA-256 and distinct remux outcome. Do not mistake a finalization race that completed before kill for an interrupted finalization.

### Task 3: Report evidence and constraints

Add focused results and exact repeat commands, native API links, limitations and later targeted phone checks. Keep binary/generated media outside Git. Do not change production LocalRecorder, SharedMediaEncoder, manifests or shared phone/epic ledger. Send writer requirements to F6 author early.

### Task 4: Review and checkpoint

Run `git diff --check`, inspect the full focused diff against base and main, commit useful checkpoints. Root coordinates a separate independent reviewer before any PR. Fix material findings and rerun affected checks. No external messages/PR/merge from this stage without root coordination.
