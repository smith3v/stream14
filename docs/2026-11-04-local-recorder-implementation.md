# Local recorder implementation plan

**Goal:** Integrate issue #5's local camera/audio/web-overlay recorder with honest file status and bounded writing.

**Architecture:** Keep HaishinKit MediaMixer and its ScreenActor composition. MediaSession coordinates the attached main-actor WebKit renderer and one concrete local writer output; AVAssetWriter owns the sole H.264/AAC encode. Use a synchronous mutex-owned append boundary rather than spawning an unbounded task per sample. Record overload drops and fail visibly on writer errors.

**Tech Stack:** Swift 6, SwiftUI, HaishinKit 2.3.0 core, WebKit, AVFoundation, Security, Synchronization, Swift Testing/XCTest.

---

### Task 1: Writer and durable state

**Prompt:** Add Stream14/Media/LocalRecorder.swift on the verified MediaMixerOutput sample boundary. Check initialization/start/append/final status, bound admission without accumulating sample tasks, retain partial files, and expose drop/stall counters. Extend ExperimentSample with completion state and loading without promoting legacy or pending samples. Test real short generated audio/video writing plus injected initialization/append/finalization failures; never fill device storage.

### Task 2: Session and interface

**Prompt:** Replace MediaExperiment ownership with Stream14/Media/MediaSession.swift. Install one ScreenActor image layer; copy WebOverlayRenderer.image and visibility with one serialized update loop. Keep its browser visibly attached outside lazy rows. Store the complete overlay URL only in Keychain, retain explicit load and no automatic resume, and provide native Record/Stop, duration, status, playback/export and retained sample access. Preserve local signing settings and do not commit them.

### Task 3: Verification and documentation

**Prompt:** Build Release using the existing shared scheme and /tmp/stream14-issue3-packages. Run deterministic hosted/UI tests on the 13 mini Simulator and available physical device. Qualify saved composition/repeated recordings, background/audio/capture interruption, two-minute overlay outage and preliminary 30-minute performance with exact methods and limits. Update canonical docs and private evidence locations; leave unmet gates pending.

### Task 4: Independent review and PR

**Prompt:** Have a separate agent inspect actual full diff against origin/main, issue #5, requirements and validation results. Resolve material issues and rerun affected checks. Run git diff --check, commit only focused files, and prepare a PR into main referencing #5 without merging or claiming pending device/TestFlight gates.
