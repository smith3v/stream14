# Preview Restore Delay Implementation Plan

**Goal:** Restore a moving preview after an app switch without reusing stale SDK timing state or claiming readiness before camera/composed frames arrive.

**Architecture:** Retire the stopped HaishinKit mixer, overlay layer and Metal preview after complete teardown, then create fresh instances before a subsequent camera open. Observe bounded raw/composed frame metadata during startup and keep capture unavailable for recording until fresh frames arrive. Existing preview intent, generation fencing and explicit recording/broadcast resume rules remain.

**Tech Stack:** Swift 6, SwiftUI, HaishinKit 2.3.0 pinned `497f742`, AVFoundation, native Swift Testing/Xcode.

---

### Task 1: Verify the retained SDK restart state

**Prompt:**
Read `MediaSession.swift`, the pinned SDK `Screen`, `MediaMixer` and capture-unit lifecycle, plus the owner’s portrait preview-only failure on merged main `1960df2`. The owner estimated a freeze longer than 15 seconds before eventual initialization; this is not a measured duration. The screenshot reports Preview ready while the image is frozen. Write a deterministic SDK-level regression showing `Screen.reset()` preserves target timestamp, latency and monotonic output PTS: the first post-gap input can shift output into the future, suppressing later output until time catches up. Contrast a fresh Screen. Do not infer exact physical cause from a fixture alone.

### Task 2: Retire stopped media state and validate fresh frames

**Prompt:**
Prefer recreating the fully stopped mixer/screen and preview to a guessed wall-clock offset, SDK-private access or a dependency fork update. Replace `MediaSession`'s mixer/preview only after output detachment and complete stop; clear its overlay layer so the new screen gets a newly installed child. Never overlap camera ownership or restart recording/upload automatically. Introduce bounded metadata-only raw-track/composed-track observers using mutex-owned scalar counters/PTS; no retained media, per-frame Tasks or new encoder. Keep phase preparing until advancing raw video and subsequent composed output are observed, then expose preview/Record. Cancel waiting on background/Close/generation change; use an explicit finite startup failure for absent frames. Preserve existing permission, failure and broadcast barriers.

### Task 3: Test lifecycle and validate native products

**Prompt:**
Extend `PreviewForegroundTests` with mixer/view identity retirement only after completed teardown, readiness blocking without raw/composed frames, early Close/background cancellation, and stalled readiness failure. Exercise actual metadata observers with generated samples. Run affected native suites and ordinary unsigned Release using the shared Stream14 scheme, a dedicated owned Simulator, unique results and verified pinned package cache. Do not touch the phone or another task’s Simulator. Update the canonical spec and development guide with exact implementation/evidence and a later five-minute physical return check. Independent review must inspect the actual full diff against current main and private native results; resolve material findings and rerun affected checks before committing/publishing the focused PR. Physical recovery remains failed/pending until retested on the corrected source.
