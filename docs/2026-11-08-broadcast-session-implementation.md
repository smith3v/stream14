# Confirmed broadcast session implementation plan

**Goal:** Implement F7/#20's explicit Go Live and bounded End flow while preserving healthy local recordings and truthful remote state.

**Architecture:** A concrete MainActor BroadcastSession coordinates the existing, single MediaSession, YouTubeClient and YouTubeBinding. Immutable confirmation intent freezes account generation, channel, event metadata, profile and overlay; a session operation token rejects stale completions. Narrow media closures permit deterministic side-effect tests without capture. A small backup-excluded journal retains only unresolved channel/event IDs, never credentials, and prevents implicit restart after relaunch.

**Tech Stack:** Swift 6, SwiftUI/Observation, existing native encoder/HaishinKit fork, URLSession YouTube REST API, native Xcode/Swift Testing.

---

## Design checkpoint

The approved canonical specification and live issue #20 define the behavior; implementation proceeds under that authorization. Three approaches were considered: embedding lifecycle in SetupView duplicates ownership and loses cancellation on navigation; a generic service/protocol framework adds abstractions without another production implementation; the selected concrete coordinator retains explicit production owners with only fixture closures at the media boundary. No optional testing-state transition, event creation, reconnect policy or large UI redesign is included.

Start sequence: explicit confirmation names actual channel/event/visibility; lock the intent; recheck capture/profile/URL/overlay/auth; initialize and wait for actual local writer start; re-read channel/event and resolve safe binding; recheck confirmed metadata and settings; connect/publish; read stream/broadcast about every two seconds within 60 seconds. Manual events transition to live once only after active ingestion; auto-start events only poll. Only a current API read of live yields the Live state. Startup cancellation/failure stops upload and leaves a healthy file recording. A read reconciliation is required before retry when upload or a transition may have affected the remote event.

End sequence: confirm the frozen event; invalidate/cancel startup; immediately request whole-session local stop (the existing media implementation serializes cancellation/close) and separately run a bounded remote read/complete/read sequence. Remote hangs cannot delay local stop. Unknown completion remains visible and journaled with Studio/reconciliation. Every retry reads first; there is no blind POST retry. File finalization remains owned by MediaSession and its actual state remains visible even after remote work finishes.

Normal launch, restore, selection and refresh never publish. App owns exactly one MediaSession and passes it to SetupView and coordinator; Debug smoke keeps its existing isolated no-permission/no-Keychain factory. Account controls are end-first while a session is starting/uploading/remote unresolved. F8/F9 retain supervision/recovery ownership.

### Task 1: Add transition API and fixture coverage

**Prompt:** In Stream14/YouTube/YouTubeClient.swift add bodyless, write-once liveBroadcasts/transition using existing guarded authorization/mutation semantics. Validate returned ID/channel; read status through existing broadcast/stream calls. Add deterministic request/unknown/rejection fixtures in Stream14Tests. Commit a useful checkpoint.

### Task 2: Add concrete lifecycle and media readiness

**Prompt:** Create Stream14/Broadcast/BroadcastSession.swift and minimal pending-remote journal. Add actual writer-ready/preflight properties to Stream14/Media/MediaSession.swift; keep startup transport Task cancellation owned by coordinator. Test ordering, writer init, each cancellation phase, auto/manual, unknown/timeouts/stale results/duplicates, recording independence, persisted reconciliation and hung End. Commit.

### Task 3: Connect explicit temporary native controls

**Prompt:** Promote the existing factory into Stream14App ownership, pass the same media reference to SetupView/coordinator, and add only confirmation/status/cancel/end/reconcile controls. Lock settings/selection during the session; pass broadcastActive to authorization actions. Preserve local rehearsal, short smoke and accessible standard controls. No real service/media action is invoked by tests or app initialization. Commit.

### Task 4: Validate and independent review

**Prompt:** Use isolated /private/tmp/stream14-f7-* DerivedData/package/result paths. Run unsigned native Release and Simulator build-for-testing, focused F7/client/binding/auth/media tests and noncapture UI regressions after the root grants the Simulator lease. Commands use the shared Stream14 scheme and a Simulator from xcrun simctl list. Check git diff --check and documentation links. Record exact results and limits here and in the specification/development guide. Root arranges an independent actual-source review of full diff against main and focused F7 parent diff; fix material findings, rerun affected tests and request focused re-review. Root publishes the reviewed stacked PR, with no automatic merge.

## Current API evidence

Checked official Google references on 2026-11-08: [transition](https://developers.google.com/youtube/data/live/reference/rest/v3/liveBroadcasts/transition), [broadcast resource](https://developers.google.com/youtube/data/live/reference/rest/v3/liveBroadcasts), [stream resource](https://developers.google.com/youtube/data/live/reference/rest/v3/liveStreams). Transition is POST with id/broadcastStatus/part query and no body, supported by youtube.force-ssl; live requires active bound stream. Redundant or invalid transitions can reject, so read reconciliation determines truth. No actual Google requests were made.

## Validation and remaining acceptance

Implementation and validation pending. No phone, receiver, OAuth callback, real unlisted event, physical A/V sync/performance/CBR or long-run acceptance is claimed. Routine phone validation remains FIVE MINUTES TOTAL including setup/wrap-up; longer qualification needs separate agreement. Original recordings are retained.
