# Independent Transport Implementation Plan

**Goal:** Resolve the remaining single-encoder and transport-admission feasibility questions before wiring a production broadcaster.

**Architecture:** Keep the existing HaishinKit capture/composition and production LocalRecorder unchanged while F1 remains unqualified. A test-target-only native H.264/AAC prototype can evaluate one encoder per media track and compressed MP4 fan-out. Pinned RTMP output currently lacks acknowledged bounded admission, so an application queue alone is not evidence of a bounded complete sender.

**Tech Stack:** Swift 6, native Xcode/Swift Testing, VideoToolbox, AVAudioConverter, AVAssetWriter, pinned HaishinKit/RTMPHaishinKit 2.3.0 test product.

---

## Scope and gate

This stage follows the owner's explicit stacked-PR authorization and begins from F4 branch `codex/issue-17-session-controls` at `9152d05`. The isolated worktree is `/private/tmp/stream14-epic13-f6`, branch `codex/issue-19-independent-transport`. F3/F5 prerequisites will join through a later root-coordinated merge, without rewriting shared history.

Issue #19 explicitly says it remains blocked if F1 is unresolved. F1 PR #40 establishes public signatures and offline compressed-writer passthrough, not successful live compressed ingestion, initial A/V-origin handling, reconnect behavior or physical performance. Production adoption is not authorized by a prototype result. No second production encoder, capture/compositor replacement, network publication or production MediaSession wiring is part of the initial checkpoint.

## Source audit — 2026-11-07

The pinned revision is `aa2149df822f2e965adf2410a106db959b2e1962` (HaishinKit 2.3.0):

- `RTMPStream.append` accepts H.264 CMSampleBuffer and AAC AVAudioCompressedBuffer. It returns Void, catches/logs timestamp errors, and independently rebases each track's first strictly positive timestamp to zero. A positive common capture timeline is necessary, but does not itself preserve the original initial A/V offset on the wire.
- `RTMPStream.doOutput` creates a Task per encoded message. `RTMPConnection.doOutput` serializes chunks and creates another Task to send them. `RTMPSocket.send` increments private `queueBytesOut` then yields into an unbounded AsyncStream. Its consumer awaits Network.framework send completion.
- Public `setVideoInputBufferCounts` bounds raw encoder input only. Awaiting public compressed append does not await socket admission or completion. Public network reports are observational, not a reliable admission acknowledgment. A finite app queue cannot alone prove finite library tasks/socket backlog.
- A concrete app-owned single native encoder after the mixer could avoid duplicate encoding without replacing capture/composition. It is a candidate requiring explicit architecture review and physical evidence, not the currently selected production path.

Relevant exact source paths are `RTMPHaishinKit/Sources/RTMP/{RTMPStream,RTMPConnection,RTMPSocket,RTMPTimestamp}.swift` at that revision. Apple's installed iOS 27.2 SDK declares a Sendable VTCompressionOutputHandler; buffers must remain immutable after submission and timestamps strictly increase. VTCompressionSessionCompleteFrames can bound prototype in-flight work synchronously without a per-sample Task. AVAudioConverter provides the native PCM-to-AAC adapter.

## Task 1: Review the decision before production changes

**Prompt:** Present the audit and alternatives to the root coordinator: retain the current local-only production path while resolving F1; investigate a single native shared encoder; or obtain a reviewed library change exposing bounded acknowledged compressed admission. Do not choose a duplicate encoder or claim full F6 completion. Commit this plan, then wait for the root's scope response before production-path edits.

## Task 2: Test the native single-encoder candidate, if approved

**Prompt:** Add a test-only `Stream14Tests/SharedEncodingPrototypeTests.swift` with generated deterministic video/audio. Encode with one VTCompressionSession and one AVAudioConverter, retaining at most one in-flight video frame in this finite prototype. Feed the resulting compressed packets to two independently owned MP4 passthrough writers and compare actual codec bytes/timestamps, including one writer's injected failure. Exercise compressed RTMP calls only with positive strictly ordered timestamps, explicitly distinguishing API calls from receiver acceptance. Do not capture camera/microphone or open a connection. Keep private synthetic artifacts disposable; never delete device originals. Commit meaningful checkpoints.

## Task 3: Validate and hand off

**Prompt:** Build with the native shared Stream14 scheme, using private paths and the installed package cache; request the root's Simulator lease before execution. Run only the relevant deterministic tests plus affected existing tests; document actual counts/commands and any compile failures honestly. Run plist/content/link checks and git diff --check. Obtain independent review of the actual full diff against main and focused predecessor delta before PR handoff; resolve material findings, rerun affected checks and commit. Root creates the stacked PR after review. Physical upload/file comparison, two-minute outage, surviving writer failure, sync markers, finite transport backlog and 13 mini thermal/memory remain pending.

## Owner setup at this checkpoint

The root reports Google Cloud/API/iOS public client and owner tester setup now exists; real in-app authorization/scope and a dedicated unlisted event/RTMPS destination remain pending. Phone readiness is unconfirmed. No real client ID, credential, private endpoint, stream key or raw recording belongs in this document.
