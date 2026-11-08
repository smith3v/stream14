# Shared Media Integration Implementation Plan

**Goal:** Prepare a reviewed draft single-encoder file/RTMPS integration while preserving all outstanding physical and receiver acceptance gates.

**Architecture:** Keep HaishinKit's one MediaMixer camera/compositor and MTHKView preview. One app-owned SharedMediaEncoder encodes mixed NV12/PCM to H.264/AAC; LocalRecorder becomes a compressed passthrough MP4 consumer. A separately owned bounded RTMPSPublisher consumes the same immutable compressed packets without controlling recording or encoding lifetime.

**Tech Stack:** Swift 6, Synchronization.Mutex, VideoToolbox, AVAudioConverter, AVAssetWriter, HaishinKit/RTMPHaishinKit 2.3.0 plus an explicitly reviewed immutable fork revision before production adoption.

---

## Workspace and authorization

Root authorized the native single-encoder architecture for draft implementation on 2026-11-08. The independent HTTPS clone is `/private/tmp/stream14-epic13-f6-integration-repo`, branch `codex/issue-19-shared-media-integration`, starting at verified `02dcc664e220c3e4ff5e6e0644c6c9e89ea2df95` (PR #46). Original checkout and failed iCloud-backed worktree attempts are retained untouched. The short-phone-smoke prerequisite will join later through a root-coordinated merge. No automatic merge, fork publication, operator upload, Google mutation, phone installation or recording deletion is authorized by this stage.

## Decision and limits

A public standalone HaishinKit codec API was considered first. Merely exposing OutgoingStream/VideoCodec/AudioCodec does not solve its unbounded compressed AsyncStreams, converter buffer ownership, log-only codec errors, publish-coupled lifecycle or per-track clock rebasing. A safe exposure would need a larger lifecycle/backpressure API change in addition to the necessary transport patch. The tested native one-encoder candidate offers explicit lifetime and synchronous failure reporting while retaining the existing library capture/compositor. This is an architecture selection for a draft, not measured realtime feasibility or F1 acceptance.

MediaMixer supplies NV12 and PCM on the common host timeline. Admit raw samples before retaining/copying them: at most two video frames and 250 ms of audio, with a finite byte budget. One consumer owns encoder work; at most one VT frame is in flight and one completion is retained. Do not create a Task per sample. Reject overload explicitly with metrics; sustained audio/timeline/encoder failure ends media safely rather than silently inventing continuity. AAC conversion retains actual cookie, priming and trim metadata and maintains one source clock across callback boundaries. The current mixer already normalizes route audio to the profile; unsupported format changes fail explicitly.

Compressed writer appends never await a network operation. Writer initialization failure blocks session startup; append/finalization failure preserves the original and failed manifest, detaches/finalizes the writer and keeps a healthy uploader alive. Transport failure/overflow clears only its bounded queue and keeps healthy encoding/writing alive. Its proposed limit is 2 MiB/128 packets including one in flight; the package's own byte/message reservations remain a second independently tested bound. No arbitrary chunk dropping. A single sender pump awaits acknowledged local socket processing, which does not prove receiver delivery.

The reviewed bounded package candidate still independently rebases audio/video. Before any fork adoption add an explicit shared transport epoch with deterministic tests: reconnect begins on a fresh forced video keyframe; audio before that epoch is omitted, later audio keeps its relative timestamp (including AAC encoder delay), and both tracks use common millisecond rounding. Codec headers precede payload in the same FIFO. Epoch reset affects transport only; the continuous local writer retains its capture timeline. Test receiver decoding and marker sync separately; an offline file result cannot prove wire timestamps or physical sync.

## Task 1: Commit decision before wiring

**Prompt:** Read the actual specification, full-app F1/F6 tasks, development guide, predecessor sources and package patch. Commit this focused plan and canonical specification decision. Report exact clone/HEAD to root. No app or dependency wiring precedes root's design response.

## Task 2: Implement native encoding and compressed recording

**Prompt:** Introduce `Stream14/Media/SharedMediaEncoder.swift` with explicit serial ownership, finite raw admission and immutable H.264/AAC output. Migrate `Stream14/Media/LocalRecorder.swift` to AVAssetWriter passthrough inputs (`outputSettings: nil`, actual format hints), preserving metrics/failure injection/finalization and retained original semantics. Add deterministic tests in `Stream14Tests/SharedMediaEncoderTests.swift` for both profiles, bytes/PTS passthrough, decoded independent markers, AAC priming, arbitrary PCM callback sizes, invalid/order/format failures, bounded admission and final drain. Keep old prototype evidence distinct. Compile against native iPhone SDK; execute Simulator only with root lease. Commit useful checkpoints; never run parallel active production encoders.

## Task 3: Review common-origin package patch before pinning

**Prompt:** Extend the isolated package experiment, not any shared package cache. Add explicit common-epoch compressed publishing APIs and tests for first-track offsets, rounding, strictly increasing timestamps, codec headers, disconnect/cancellation, stale generation and keyframe rejoin. Export a reproducible patch and update its README. Request root-coordinated independent source review before root publishes an immutable fork. Keep production package pins unchanged until that gate. A private absolute local package override is compile-experiment-only and must never be committed.

## Task 4: Implement bounded upload and lifecycle integration

**Prompt:** Add concrete `Stream14/Media/RTMPSPublisher.swift` with finite byte/packet accounting including in flight and one asynchronous pump. Wire `MediaSession.swift` to independently owned encoding/file/upload lifetimes, with no publishing UI or Google mutation (F7 owns explicit confirmation). Add deterministic injected stalled-send/overflow/connect rejection/cancel/repeated attach-detach tests plus writer failure surviving upload, upload failure surviving writing, writer initialization preventing startup and stop draining once. Verify profile/color/alpha/mute/lens/route behavior remains at the existing common mixed boundary. Compile/build using native Xcode and test only affected selectors; retain physical receiver/13-mini checks as pending. Commit.

## Task 5: Review and handoff

**Prompt:** Run `git diff --check`, native iOS build-for-testing and affected hosted tests (with root Simulator lease). Update canonical evidence and epic progress with exact results and limitations. Root arranges independent review of actual full diff against main and predecessor delta; resolve material findings and rerun affected checks. Root coordinates stacked PR creation after short-smoke prerequisite merge. No F1/F6 completion, shipping, three-hour/endurance claim, or merge is implied.

## Outstanding owner/device evidence

Phone availability is later. Routine connected-phone visits have FIVE MINUTES TOTAL including install, prompts and wrap-up; prepare builds/fixtures/Simulator first and stop on setup blockers. Longer qualification requires separate explicit agreement; development experiments otherwise remain capped at 15 minutes. Real camera/receiver markers, TLS/socket behavior, AAC reconnect, finite resource use, thermal/memory behavior and simultaneous independent-output qualification remain pending. No new owner decision is required to implement this draft; immutable dependency publication is root-coordinated after review.

### Source checkpoint 1

`SharedMediaEncoder.swift` now contains finite raw admission (including the current
item), a signal-only coalesced wake stream, one actor consumer, one VT frame in
flight and a persistent AAC converter with owned compressed packets/cookie/trim
metadata. Five focused tests compile for both profiles, callback slicing, timeline
errors and admission limits. It is deliberately not attached to MediaSession yet;
this checkpoint adds no active second production encoder.

Unsigned generic-iPhone SDK `build-for-testing` passed at
`/private/tmp/stream14-integration-build-3.log`, using the native shared scheme,
DerivedData `/private/tmp/stream14-integration-build` and the existing pinned
packages. The first compile exposed one nonoptional AVAudioFormat initializer
assumption; corrected before the passing build. Runtime tests await the root's
Simulator lease. No realtime performance, receiver or physical result is claimed.
