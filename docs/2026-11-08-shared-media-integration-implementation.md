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

### Source checkpoint 2 — draft migration under runtime validation

The independently reviewed short-smoke branch `8af669f` joined by merge `4d2cb71`.
The draft local path now attaches SharedMediaEncoder to the mixer and passes its
compressed samples to LocalRecorder. The recorder has no compression settings;
its finite startup queue waits for both actual codec descriptions, then creates
passthrough MP4 inputs. Append/backpressure failure fails that consumer rather
than dropping a compressed reference frame. No uploader is attached yet. The
existing failure handler still stops local-only capture; it must be revised for
independent active upload before F6 integration is complete.

Actual upstream ownership was inspected at HaishinKit 2.3.0:
`Screen.makeSampleBuffer` allocates a fresh pooled pixel buffer per composition;
`AudioCaptureUnit.audioMixer(didOutput:)` clones PCM before yielding. The app's
raw reservation precedes retaining the video sample or creating its CoreMedia PCM
copy. Reservations store their exact charge (including plane alignment allowance)
until processing returns; no per-buffer Task is created. Upstream capture/mixer
AsyncStreams themselves are not established as globally bounded by this change.

Runtime evidence is retained, including failures. The first five encoder tests
pass in `/private/tmp/stream14-integration-codec-2.xcresult` after fixing PCM size
accounting and setting destination frameLength before copying. Initial migrated
writer checks failed with native invalid-timestamp errors; the persistent AAC
path needed an explicit 1024/44100 packet duration, which the older finite
prototype's retiming happened to provide. The audible-marker experiment now
exercises this new persistent converter, arbitrary callback boundaries, two new
passthrough writers, actual packet readback and independent decode. Its first
assertion exposed nanosecond-vs-audio-grid rational timestamp rounding. The host
epoch is now quantized once to the nearest 44.1 kHz sample (at most half a sample),
so later AAC positions do not accumulate independent rounding. The affected
three-suite repeat is running at `/private/tmp/stream14-integration-local-2.log`;
no pass is claimed in this checkpoint before observing its result.

Recorder initialization now explicitly checks the parent directory because
AVAssetWriter initialization alone deferred a missing-parent error. Incomplete
cleanup never invokes cancelWriting, whose documented/observed behavior can
remove output. Original export/deletion UI and the short-smoke test remain intact.
No physical run, live receiver, transport attachment or fork pin is part of this
checkpoint. `git diff --check` passes; independent source re-review remains due.

### Observed checkpoint 2 validation

The affected Simulator repeat actually executed 13 tests in three suites and
passed at `/private/tmp/stream14-integration-local-2.xcresult` (27.259 seconds,
log beside it). This includes the new persistent encoder's audible/changing-video
midpoint decode, two passthrough files, byte comparison and exact normalized
packet PTS. The older opt-in physical feasibility selector does not execute
physical media without its explicit environment and a physical destination;
its presence in the suite count is not device evidence. The actual new marker
check passed video onset within 5 ms of 0.5 seconds and relative generated A/V
onset within 35 ms. No physical/receiver or endurance conclusion follows.

Independent review of common-origin artifact `fedc43b` reported no material
findings. Its normal full Package.swift iOS RTMP product also compiles/links:
`/private/tmp/stream14-integration-package-ios.log` ends TEST BUILD SUCCEEDED.
The private validation app is `/private/tmp/stream14-integration-ios-validation`
and references `/private/tmp/stream14-integration-full-package` locally. This
absolute override exists only in that private experiment; committed production
package references remain unchanged. Runtime socket/receiver evidence is pending.

### Source checkpoint 3 — concrete transport pump

`RTMPSPublisher.swift` now owns a concrete finite compressed-media queue and two
fixed workers: one acknowledged-send pump and one abort/close worker. Overflow
can therefore close a stalled sender immediately; it does not wait behind that
send's acknowledgment. A queue limit includes the in-flight item until the send
actually returns. Close/overflow clears only queued media, preserves in-flight
accounting, and prevents further admission. A fresh transport object waits for a
video keyframe, chooses its epoch and omits pre-epoch audio. It owns neither file
nor encoder and does not request Google mutations. Send/close closures are the
focused deterministic test seams; the actual library adapter awaits the root's
reviewed immutable fork pin.

Four Simulator checks pass at `/private/tmp/stream14-integration-pump-1.xcresult`
(log beside it): stalled-send overflow closes while retaining in-flight charge;
cancellation releases queued media; activation/random-access/common epoch handling;
and eight repeated failed fresh connections release their queues. The normal
upstream-pinned app still compiles: generic iPhone build-for-testing passes at
`/private/tmp/stream14-integration-build-5.log`. No socket was opened by these
checks. The prior migration reviewer reported no actionable material findings;
actual writer startup must be confirmed before a future publisher starts because
codec hints/startWriting are deferred beyond LocalRecorder.start returning.
