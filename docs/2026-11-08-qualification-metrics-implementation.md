# Qualification Metrics Implementation Plan

**Goal:** Give the delivered Release app a private, bounded, deliberately exported measurement summary for F12.

**Architecture:** Existing encoder, writer and transport locks own numeric counters. One per-recording ten-second task snapshots counters outside callbacks into a typed allowlist report and atomically replaces one backup-excluded checkpoint. A 120-observation rolling window bounds memory and disk; cumulative counters and maxima cover the session. Unknown/free-form strings never enter the schema.

**Tech Stack:** Swift 6, Foundation, Darwin task_info, SwiftUI/CoreTransferable, AVFoundation; no new dependency.

---

### Task 1: Define bounded reports and checkpoint recovery

Implement `Stream14/Media/QualificationDiagnostics.swift` with safe enums, fixed numeric fields, a monotonic clock, charged footprint separate from resident mappings, a 120-observation ring and an actor-owned checkpoint. Test bounds, monotonic time, round-trip/recovery, corrupt checkpoints and allowlist export. Commit model and tests.

### Task 2: Connect existing owners

Extend metrics under existing locks in `SharedMediaEncoder.swift`, `LocalRecorder.swift` and `RTMPSPublisher.swift`. Count admitted/rejected raw video and PCM frames, accepted/written/rejected encoded packets, estimated absent video intervals and queue high water separately. Connect one ten-second task in `MediaSession.swift`, persist final snapshot, retain transport generation totals across reconnects. Keep all persistence outside callbacks and stop before dropping owner references. Add per-record deliberate sanitized ShareLink, coordinating F11 UI. Preserve originals and unlimited normal recording; development harness stays capped at 900 seconds.

### Task 3: Native evidence workflow and audit

Add `Tools/qualification/Analyze.swift` for streaming original compressed PTS scanning and complete decoded A/V traversal; no re-encode or copied media. Add A1–A9 report template with start/end clap markers, receiver, power/network/ambient controls and uncertainty. Document counter meaning, footprint limitations, privacy reasons and fixed resource bounds in specification/guide. Inspect actual exported JSON, run focused native tests and unsigned Release build/package audit. Device overhead remains pending without a separately authorized 13 mini run.

### Task 4: Review and handoff

Review full diff against main plus focused F12 diff using an independent reviewer; resolve material findings and rerun affected checks. Commit useful stages. Parent coordinates final F11 integration, fresh review and PR publication into main; no automatic merge.
