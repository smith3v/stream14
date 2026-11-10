# Full App Implementation Plan

**Goal:** Implement and qualify the specified YouTube broadcaster through focused PRs into main, preserving prior local-MVP evidence and its limitations.

**Architecture:** Retain one HaishinKit camera/composition pipeline and independently owned file and RTMPS outputs. Verify encoding/fan-out feasibility before adopting a production transport path. Use a concrete SwiftUI session coordinator, Google authorization adapter and small URLSession YouTube client; keep recording, transport and remote broadcast state independent.

**Tech Stack:** Swift 6, SwiftUI, WebKit, AVFoundation, HaishinKit 2.3.0 baseline, native Xcode/SPM, GoogleSignIn and RTMPHaishinKit only after API/dependency verification, App Store Connect/TestFlight.

---

## Owner scope and branch policy — updated 2026-11-06

The owner restored main as the merge target. Start each focused `codex/issue-<number>-<topic>` branch from current main and target its PR to main. This replaces the temporary 2026-11-05 `codex/full-app` workflow; no integration promotion or MVP backport stage is required. This planning PR also targets main. Do not delete old branches, rewrite shared history or merge automatically.

At this update remote main is `36e1150` (merged PR #32), including TestFlight delivery PR #29 and the reviewed UI update. Issue #6 is closed following delivered-build use and owner review, with formal measurement limits explicitly retained. Those limits are not waived by changing the PR base. Full-app development remains authorized; historical MVP-only sequencing does not block the planned implementation. This plan changes no app behavior.

### Approach and decision gates

Use staged media and YouTube work converging at F7. A single monolithic broadcast change would make independent failure behavior difficult to review. A new custom media pipeline would discard working capture/composition and adds ownership risk. The selected approach retains the native/library implementation and front-loads the uncertain shared-encoding boundary in F1; a second encoder or pipeline replacement needs measured evidence and an explicit decision.

F1/F2/F4 can begin independently. F3 follows F2; F5 follows F3; F6 follows F1/F4. F7 combines all prerequisites; F8/F9 complete recovery, followed by F10 interface, F11 files/recovery and F12 instrumentation. F13 prepares and delivers the later beta while preserving the completed MVP delivery evidence and its limits. F14 owns measured full-product acceptance and release readiness. These are dependency lanes, not instructions to spawn agents or begin implementation in this planning task.

No new scope beyond the canonical full-product specification: no event creation/editor, visibility changes, chat, arbitrary RTMP destinations, extra cameras/layers, HDR/60 fps, background broadcasting, backend, analytics or storage forecasting. Preserve the owner’s confirmed per-file deletion, main/test icons and 15-minute development-experiment limit. A2/A7 long runs remain future agreed qualification, not an instruction to run them now.

## Owner short-validation update — 2026-11-07

Routine connected-phone validation has a five-minute TOTAL budget including installation/prompts/wrap-up. Run fixtures, fault/race tests and Simulator checks on the laptop first. A short two-profile smoke plus a selected risk-based case replaces an exhaustive hour-long phone batch. Use the [connected-phone plan](2026-11-07-connected-iphone-test-plan.md); future/long-run rows remain pending, not automatic work. Do not extend silently or treat smoke results as endurance proof. Longer qualification needs separate explicit agreement.

## Baseline and fresh-agent workflow

The existing implementation is in Stream14/Media/MediaSession.swift, LocalRecorder.swift, WebOverlayRenderer.swift, WebOverlayLayer.swift and ExperimentSample.swift, with SwiftUI in Stream14/App/SetupView.swift. The baseline file writer owns one H.264/AAC encode of composed NV12/PCM. No shared compressed output or transport is established. Inspect prerequisite handoffs before choosing APIs or renaming experiment types.

Use @brainstorming for actual behavior/design choices, @writing-plans for a focused implementation plan, and @gh-current-repo-issues to inspect this repository’s issue context. The owner’s scope/branch instruction above governs any older MVP-only wording.

## Context and branch contract

Owner instruction of 2026-11-06 restores main as the branch/PR base for all full-app work. Start a focused `codex/issue-<number>-<topic>` branch from current main and target main. The former codex/full-app integration, backport and eventual promotion workflow is superseded; do not delete branches or rewrite shared history. PR destination is not permission to merge automatically.

Read AGENTS.md, docs/2026-11-01-stream14-design.md (R1–R11, sections 2–10, A1–A9), docs/2026-11-05-full-app-implementation.md, docs/ios-development-guide.md and docs/feasibility.md on current main, plus epic #13 and prerequisite issue/PR handoffs. Until planning PR #28 merges, its head branch publishes the full plan. Full-app development remains authorized despite historical MVP-only sequencing. Issue #6 is closed after local-only TestFlight delivery/owner review; preserve its objective measurement limits and qualify later builds independently.

Baseline is Swift 6/SwiftUI, iOS 27, one HaishinKit 2.3.0 MediaMixer, attached MainActor WebKit at about 1 Hz, explicit ScreenActor overlay visibility and a concrete LocalRecorder on composed NV12/PCM output. AVAssetWriter currently encodes H.264/AAC once for the file; shared encoded streaming output is unproven. Keep source/render freshness separate, 10-second hide/fresh-image recovery and manual-hide precedence. Keep Google/transport state separate from recording. No backend, analytics, generic output framework, 60 fps/HDR/camera switching or storage-estimation/polling/threshold subsystem.

Development media experiments stay at most 15 minutes; 30-minute/three-hour qualification needs a later explicit owner-agreed run. Never automatically delete originals, including failed/pending files. Never publish camera media without an explicit test/operator action. Secrets, token-bearing URLs, signing/tester information and raw recordings stay out of Git/issues/logs. Preserve normal signing and distinct test-runner branding.

## Delivery for this issue

1. Inspect the current files and prerequisite merged PRs; preserve unrelated local work. Implement in small changes, adding deterministic tests for material decisions and updating the relevant specification/guide/feasibility section with actual APIs and evidence.
2. Use the shared Stream14 scheme. Follow the plan’s exact baseline native build/test commands, resolve packages if changed, and add focused tests for this issue. Report command/build/device/OS/result and missing external evidence honestly; do not close an unmet device/API acceptance gate on Simulator evidence.
3. Open a focused PR into `main`, reference this issue/epic and record validation/limits. A separate agent must inspect actual files and the full PR diff against current main, focusing on correctness/data loss/privacy/build/media reliability. Resolve material findings, rerun affected checks and record the review. Do not merge automatically without explicit merge authorization; specifying a PR destination alone does not authorize a merge.
4. Leave a fresh-agent handoff: resulting files/public APIs, ownership decisions, exact reproducible commands, nonsecret configuration, evidence locations and unresolved requirements. Dependent work starts after prerequisite PRs merge unless the owner explicitly coordinates stacked work.

## GitHub issue index

[Full-app epic #13](https://github.com/smith3v/stream14/issues/13) tracks these independently implementable stages:

- [F1: #14 — Full app F1: Verify dual-output media APIs and choose the encoding path](https://github.com/smith3v/stream14/issues/14)
- [F2: #15 — Full app F2: Implement YouTube authorization and owner setup](https://github.com/smith3v/stream14/issues/15)
- [F3: #16 — Full app F3: Add the YouTube REST client, channel identity and event selection](https://github.com/smith3v/stream14/issues/16)
- [F4: #17 — Full app F4: Add fixed session profiles, microphone controls and camera zoom](https://github.com/smith3v/stream14/issues/17)
- [F5: #18 — Full app F5: Resolve safe ingestion bindings without duplicate resources](https://github.com/smith3v/stream14/issues/18)
- [F6: #19 — Full app F6: Implement bounded RTMPS output and independent local writing](https://github.com/smith3v/stream14/issues/19)
- [F7: #20 — Full app F7: Coordinate confirmed Go Live and bounded End broadcast](https://github.com/smith3v/stream14/issues/20)
- [F8: #21 — Full app F8: Reconnect only to the same eligible event and supervise remote state](https://github.com/smith3v/stream14/issues/21)
- [F9: #22 — Full app F9: Handle whole-session interruptions, heat and asymmetric failures](https://github.com/smith3v/stream14/issues/22)
- [F10: #23 — Full app F10: Finish the native preparation, live and recordings interface](https://github.com/smith3v/stream14/issues/23)
- [F11: #24 — Full app F11: Add honest fragment recovery and persistent recording review](https://github.com/smith3v/stream14/issues/24)
- [F12: #25 — Full app F12: Add private qualification metrics for the delivered app](https://github.com/smith3v/stream14/issues/25)
- [F13: #26 — Full app F13: Prepare and deliver a full-app TestFlight qualification candidate](https://github.com/smith3v/stream14/issues/26)
- [F14: #27 — Full app F14: Qualify A1–A9 and record full-app release readiness](https://github.com/smith3v/stream14/issues/27)

## Stages and dependencies

### Task F1: Verify dual-output media APIs and choose the encoding path

**Dependencies:** Baseline; no other full-app stage.

**Requirement trace:** M1, R5–R8; A1/A2/A4.

**Files:** Existing: Stream14/Media/{MediaSession,LocalRecorder,WebOverlayLayer}.swift; Stream14Tests/{LocalRecorderTests,WebOverlayCompositionTests,MediaDeviceTests}.swift. Proposed: focused dual-output experiment/tests, not a new generic media framework.

**Prompt:**

Inspect the pinned HaishinKit 2.3.0 source and current stable release before changing packages. Trace MediaMixerOutput, RTMPStream, outgoing codecs, StreamOutput, publish/close behavior and AVAssetWriter compressed-input support. Record exact public APIs and ownership; a raw mixer output and a stream observer do not establish encoded fan-out.

Build the smallest opt-in dual-output experiment around Stream14/Media/MediaSession.swift and LocalRecorder.swift with a synthetic changing alpha fixture. Keep one camera/mixer and the current local-only path. Evaluate shared compressed H.264/AAC samples first, including encoding while disconnected and file timestamps after reconnect. If that is unsupported, document the precise limitation and measure the minimum separate-encoder candidate on the 13 mini before recommending it. A separate encoder or capture/compositor replacement needs an explicit evidence-backed owner decision before production adoption.

Add only RTMPHaishinKit if actually used; inspect license/notices, transitive and linked footprint, maintenance, TLS, Swift 6/iOS 27 compatibility and package pins. Do not add SRT/RTC/MoQT/Firebase. Use an explicitly configured private test destination; no media is published on launch or by ordinary unit tests.

Write the selected boundary, queue limits, timestamp/codec/container ownership and disconnect semantics into docs/feasibility.md and specification sections 6–7. Hand the production transport agent exact API calls, a reproducible experiment and the selected design; do not leave an architecture choice implicit.

**Validation and acceptance:**

Evidence includes local-only encoding without an ingest connection, simultaneous composed file/preview/upload, and transport connect failure/disconnect without interrupting the writer. Inject writer failure and confirm upload remains healthy. Inspect original media, not only callbacks.

Record short physical 13 mini build/OS/profile, file properties, drops/stalls, A/V markers, memory/thermal observations and queue bounds. Runs stay at most 15 minutes. Synthetic and Simulator checks may support implementation but do not prove device performance. If hardware or a design decision is unavailable, leave the gate pending and specify the exact missing evidence; F6 cannot assume it passed.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F2: Implement YouTube authorization and owner setup

**Dependencies:** Baseline; no other full-app stage.

**Requirement trace:** R3; A6/A9.

**Files:** Existing: Stream14/App/{Stream14App,SetupView}.swift, Stream14.xcodeproj/project.pbxproj. Proposed: Stream14/YouTube/YouTubeAuthorization.swift and focused auth tests. Keep new types concrete; inject only boundaries needed by deterministic tests.

**Prompt:**

Inspect Google’s current supported iOS authorization flow and stable GoogleSignIn package. Document the native alternative, license, maintenance, transitive footprint and Swift 6/iOS 27 compatibility before pinning only needed products in Package.resolved. Add a concrete Stream14/YouTube/YouTubeAuthorization.swift adapter and app callback handling; use SDK-managed Keychain tokens, supported refresh and the youtube.force-ssl scope. Do not duplicate SDK tokens, add Firebase/backend/server secrets, or authenticate inside the overlay WKWebView.

Implement connect, cancel, restore authorization without publishing, account switching, local sign-out and explicit revoke/disconnect with honest failure reporting. Publish only safe auth readiness to the app. Account change invalidates channel/event/binding state and in-flight responses; local files and overlay URL survive. Defer account changes during an active broadcast through an explicit end-first flow.

Update docs/ios-development-guide.md with owner-controlled Cloud project/API enablement, consent audience/test users, iOS client for com.smith3v.stream14, callback scheme and supported signing. Public client IDs may be configured; never invent values or request secrets. Missing setup produces a useful disabled connection state while local rehearsal still works. Explain testing-token expiry and distinguish Google testers from Apple testers. Check current privacy/branding requirements and document them for F13.

**Validation and acceptance:**

Deterministic tests cover cancellation, unavailable config, denied/missing scope, expired/revoked tokens, refresh failure, late callbacks after account switch and disconnect data clearing. Native Release and Simulator checks pass. When owner setup is available, verify supported browser sign-in/callback, actual channel authorization handoff, sign-out/revoke and no automatic camera upload on a signed phone. Pending owner setup stays explicit; do not replace live auth evidence with a mock success.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F3: Add the YouTube REST client, channel identity and event selection

**Dependencies:** F2.

**Requirement trace:** R3; A3/A6.

**Files:** Existing: Stream14/App/SetupView.swift and F2 authorization. Proposed: Stream14/YouTube/{YouTubeClient,YouTubeModels}.swift; Stream14Tests/YouTubeClientTests.swift and sanitized fixture JSON. Minimal channel/event picker may be added now and refined by F10.

**Prompt:**

Use URLSession/Codable in Stream14/YouTube/YouTubeClient.swift with SDK-supplied fresh access tokens. Add minimal models for channel, event, stream and API errors; sanitized fixtures under Stream14Tests/Fixtures/YouTube. Read current endpoint references rather than inferring JSON fields. No broad API SDK or raw-response persistence.

Resolve channels.list(mine=true) and show the actual authorized channel, including Brand Account behavior. Fetch every page of liveBroadcasts.list(broadcastStatus=upcoming, broadcastType=event) with needed snippet/status/contentDetails. broadcastStatus, id and mine are mutually exclusive filters. Add by-ID reads for later reconciliation, plus liveStreams reads. Guard pagination cycles, cancellations and stale account generations.

Provide refresh, localized event title/date/time/visibility, empty/scheduling instructions and eligibility explanations. Clear selection when account changes or event becomes ineligible. Recheck by ID before use. Channel identity is not a Google email or an assumed Studio delegation.

Map disabled live, wrong channel, missing event, scope/consent, quota/rate-limit and transient network/service failures into safe actionable errors. Retry only idempotent reads with bounded backoff/Retry-After; at most a supported refresh/retry for authentication. Keep write retry policy separate for F5/F7. Do not log headers, keys or sensitive API bodies.

**Validation and acceptance:**

Tests prove correct requests/filters/parts, multi-page and empty results, unknown/missing optional values, wrong-channel results, cancellation/account-switch races, quota/403/401 distinctions, bounded retries and safe failures. Selecting or refreshing never mutates an event or sends camera media. A signed owner-configured run displays the real channel and scheduled unlisted event; if unavailable, record that external check pending.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F4: Add fixed session profiles, microphone controls and camera zoom

**Dependencies:** Baseline; no other full-app stage.

**Requirement trace:** R1/R2/R5/R8; A1/A2/A8.

**Files:** Existing: Stream14/Media/{MediaSession,LocalRecorder,WebOverlayRenderer,WebOverlayLayer}.swift, Stream14/App/SetupView.swift. Proposed: Stream14/Media/SessionProfile.swift and focused profile/control tests.

**Prompt:**

Replace hard-coded 1920×1080 assumptions with one concrete immutable session profile used by capture, mixer canvas, overlay CSS/raster, preview and writer, and later transport. Start with 1080p30 at 14 Mbps and 720p30 at 8 Mbps, SDR Rec.709 H.264, two-second keyframes and AAC 128 kbps stereo 44.1 kHz. Verify current YouTube recommendations and public library controls; document any unsupported CBR/color/rate behavior instead of claiming it from requested settings.

Keep a fixed landscape canvas/orientation throughout a session; configure before preview/recording or safely rebuild idle preview. Active event/profile/URL remain frozen; later preference changes apply next session. Persist nonsecret profile preference only; existing secure overlay URL stays in Keychain.

Implement built-in rear-wide camera zoom within supported device limits, microphone mute on mixed audio before both outputs, a bounded UI level meter and active audio-route label. Verify public HaishinKit controls before use. Meter updates must not create unbounded tasks or block capture. No extra camera, lens switching, exposure panel, 60 fps, HDR or background capture.

Preserve the existing 10-second source/render health and manual-hide behavior with either exact canvas size. Keep attached WebKit view, alpha and explicit layer visibility. Local rehearsal stays independent of Google.

**Validation and acceptance:**

Tests verify profile consistency, invalid mid-session changes, both overlay viewport/raster sizes and shared mute semantics. Physical short recordings for each profile confirm codec/dimensions/orientation, changing alpha overlay/no controls, zoom, meter/mute and original playback/export. Inspect both landscape phone orientations and route/interruption behavior; unsupported hardware cases remain pending. No claim of long-run profile qualification.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F5: Resolve safe ingestion bindings without duplicate resources

**Dependencies:** F3.

**Requirement trace:** R4; A3/A6.

**Files:** Existing: F3 YouTube client/models; Stream14/Media/ExperimentSample.swift as a pattern, not a place for keys. Proposed: Stream14/YouTube/YouTubeBinding.swift and a small separate pending-broadcast intent model with tests.

**Prompt:**

Add a concrete binding workflow in Stream14/YouTube/YouTubeBinding.swift using the REST client. Re-fetch the selected event and any bound liveStream. Reuse only a compatible dedicated inactive binding; refuse active streams or streams shared with another unfinished event. Paginate the relevant broadcasts to detect shared bindings, inspect lifecycle/health and explain how to fix configuration in Studio. Fail closed when dedication/compatibility cannot be established.

For an unbound eligible event, create one app-owned non-reusable RTMP stream (variable resolution/frame rate when supported), persist the returned resource ID immediately with minimal session intent, then bind it. Validate the returned rtmpsIngestionAddress and stream name; never fabricate an insecure RTMP fallback. Keep stream keys in memory or appropriate device-only Keychain only if verified persistence is necessary; never in a JSON manifest/log.

No writes while merely listing/selecting/previewing: invoke this workflow from confirmed Go Live. Preserve title, visibility, audience and auto-start/auto-stop. Auto-stop must be disabled by the owner in Studio; surface a blocker rather than silently editing it. Auto-start is handled by F7.

Use by-ID reads to reconcile timed-out binds. Ambiguous inserts must enter an unresolved state with conservative reconciliation/operator instructions; never blindly insert again. Track known created IDs for retries; do not automatically delete remote resources, unbind unrelated streams or take over another encoder.

**Validation and acceptance:**

Fixture tests cover reused/unbound/shared/active/incompatible streams, absent RTMPS fields, auto-stop, pagination, repeated taps, cancellation, create success followed by bind failure, timeout before/after response and app relaunch with pending intent. Prove retry does not create duplicates. With owner setup, use only an explicitly selected unlisted event and verify readback binding; do not publish media in this issue. Record missing external evidence.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F6: Implement bounded RTMPS output and independent local writing

**Dependencies:** F1, F4.

**Requirement trace:** R4–R8/R11; A1/A2/A4.

**Files:** Existing: Stream14/Media/{MediaSession,LocalRecorder,WebOverlayLayer}.swift. Proposed: RTMPSPublisher.swift and focused media integration tests; project package products/notices only as justified by F1.

**Prompt:**

Implement the media path selected and evidenced in F1, using only verified public HaishinKit APIs. Add a concrete Stream14/Media/RTMPSPublisher.swift and the minimum encoder/file adapter required by that decision. Preserve one camera/mixer, common composed video/audio and local-only rehearsal. Do not adopt an unapproved second encoder or invent encoded fan-out.

Attach recording and transport as independently owned consumers. Transport connect/publish/close/failure never owns LocalRecorder start/stop/finalize; file failure never closes healthy upload. Encoding needed by recording must continue without a connection and through transport reconnect. Maintain one common media timeline, correct codec format headers, bounded buffering with documented limits and a keyframe-safe restart/drop policy. Avoid per-sample unbounded Task submission and network writes in the recorder callback.

Use actual returned RTMPS endpoint/key with standard certificate/hostname validation. Expose safe connection/publishing/failed state, cancellation and bounded connection timeout; a socket connection does not report YouTube Live. Redact library diagnostics as well as app logs. Close safely on cancellation without blocking file finalization.

Preserve checked writer final status, retained incomplete files and original-file export with no transcoding. Document actual encoder count/ownership, compressed/uncompressed boundaries, queue/drop counters and disconnect semantics in specification/feasibility. Do not enable publishing from ordinary app launch or local Record.

**Validation and acceptance:**

Synthetic/fault tests cover stalled sender, queue overflow, connect rejection, disconnect/reconnect, cancellation, writer initialization/append/finalize failure and repeated attach/detach without leaks. A short physical 13 mini simultaneous test shows identical changing composition/audio, continuous local file through a two-minute upload outage, upload surviving injected writer failure and finite queues. Inspect saved media and receiver output. If F1 is unresolved, this issue remains blocked rather than silently selecting another architecture.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F7: Coordinate confirmed Go Live and bounded End broadcast

**Dependencies:** F2, F3, F4, F5, F6.

**Requirement trace:** R3–R7; A3/A4/A6.

**Files:** Existing: MediaSession.swift and F2–F6 services. Proposed: Stream14/Broadcast/BroadcastSession.swift and BroadcastSessionTests.swift. Add only minimum temporary controls needed to exercise behavior; F10 finishes the interface.

**Prompt:**

Add a concrete Stream14/Broadcast/BroadcastSession.swift coordinator with independent local-recording, transport and YouTube states. Preserve local rehearsal. Capture immutable account/channel/event/profile/overlay intent and protect asynchronous work with session generation/cancellation; deduplicate rapid start/end actions.

Before confirmed Go Live, show channel, event title and visibility. Revalidate permission/capture/profile/auth/event/binding and configured overlay readiness; an unavailable configured overlay requires explicit disable and recheck. Start and confirm local writer readiness before any media publication, including auto-start events. If writer initialization fails, do not publish. Once writing starts, any binding/API/startup failure leaves healthy recording running with Stop recording available.

After confirmation only, resolve F5 binding, connect/publish, and poll ingestion/broadcast at about two seconds for at most 60 seconds. For manual events wait for active ingestion before transition(live); for auto-start allow the confirmed publish to trigger it and poll without a redundant transition. Reconcile timed-out mutations by reading current remote state before retry. Declare Live only when YouTube confirms it. Startup timeout disconnects upload, retains recording and requires reconciliation before another start.

End broadcast requires confirmation. Run bounded remote complete/reconciliation, disconnect transport and finalize local writing regardless of API failure. Unknown completion is persistent and offers Studio; it must not block local finalization or falsely claim the event ended. No new event creation, settings mutation or optional testing-state flow.

**Validation and acceptance:**

State/side-effect tests verify start ordering, init failure sends zero media, auto/manual start, stale callbacks, duplicate taps, startup timeout, unknown/late transitions, cancellation at each phase and end despite hung API. Cover recording surviving every startup failure and no Live label from transport state. A short unlisted end-to-end check confirms the selected event starts/ends and plays with correct overlay/audio on a second device (A3); keep real setup pending if unavailable.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F8: Reconnect only to the same eligible event and supervise remote state

**Dependencies:** F7.

**Requirement trace:** R6/R11; A4/A6.

**Files:** Existing: Stream14/Broadcast/BroadcastSession.swift, YouTubeClient.swift, RTMPSPublisher.swift. Proposed focused reconnect policy/state tests; avoid a general job/retry framework.

**Prompt:**

Extend the coordinator with cancellable bounded retries and remote supervision. Use a controllable monotonic clock for tests. While live, poll broadcast/ingestion health about every ten seconds; back off on service/rate-limit errors and respect Retry-After. Status API failure alone never tears down healthy transport or local writing.

On transport failure keep capture/recording and overlay work running, reconnect only to the same event/binding after reconciliation, with delays capped at 30 seconds. Define/document a finite retry budget and explicit Retry/Stop recording behavior on exhaustion; do not spin forever or replace the event. Authentication errors that need user interaction are distinct from network retries. Keep an existing healthy media connection where possible if control-plane authorization expires; no sign-in UI is forced over an active capture.

If YouTube is completed elsewhere, stop transmission, keep healthy recording and show remote-ended state. For ambiguous startup/reconnect/transition results re-read remote state; no duplicate inserts, binds or blind transitions. Re-fetch/validate keys without exposing them. Unknown health does not mean complete.

Cancel timers and in-flight work on end, interruption, account/session replacement and explicit cancellation. Late replies cannot reconnect an ended session. Network path hints may help scheduling but do not prove server reachability or eligibility.

**Validation and acceptance:**

Deterministic tests cover delay cap/budget, Retry-After, flaky reads, token refresh/revocation, completed/missing events, old-session callbacks, reconnect/end races and exhausted retries with uninterrupted recorder. Physical short checks include a two-minute actual phone internet outage and Wi-Fi/cellular change where available; verify same-event recovery and local continuity independently from overlay timeout/hide/recovery. Record receiver gaps separately from file cadence.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F9: Handle whole-session interruptions, heat and asymmetric failures

**Dependencies:** F7, F8.

**Requirement trace:** R6/R7/R11; A4/A6/A8.

**Files:** Existing: MediaSession.swift observers/background task/idle timer; BroadcastSession.swift, LocalRecorder.swift. Add focused interruption and independence tests, updating MediaDeviceTests.swift only as needed.

**Prompt:**

Extend current MediaSession interruption/thermal behavior across both outputs without combining their state. Camera/audio interruption, background/lock or capture runtime error stops upload and finalizes writing within available background time; no fake audio/background entitlement. Bound tasks and restore the previous idle-timer state. Do not rely on a successful remote complete request during background suspension.

For an interrupted recording/broadcast, on foreground return/relaunch show interruption and remote uncertainty, recheck permissions/capture/auth/event state and require explicit resume. Preview-only app-switch return is different: restore the user's explicitly opened camera after completed teardown, without starting a file or upload, as specified in the canonical foreground lifecycle contract. Resume only the same eligible event with a new local UUID/timeline; never append to a finalized movie or auto-publish. Reconcile remote state on return without forcing background camera work.

Preserve R6/R7 in every phase: transport/API/remote-ended failures never stop healthy writing; writer append/finalization/storage failures retain original files and keep healthy live upload with a persistent backup-failed warning. Test writer-init failure separately: initial Go Live stays blocked.

At serious thermal pressure reduce/skip overlay work before sacrificing camera; critical/capture-unavailable pressure interrupts cleanly. Do not silently change profile/resolution. Handle active audio-route changes and loss honestly. Integrate cancellation of all F8 work and explain unconfirmed remote end; avoid warning sounds picked up by the microphone.

**Validation and acceptance:**

A deterministic cross-product failure table covers init/active/ending recorder and upload states, audio/camera interruptions, late callbacks, exhausted background time and repeated stops. Inject disk/write/finalize faults without filling the phone. Physical short runs cover Home/lock, real audio interruption when feasible, explicit resume/new file and idle-timer restoration. Test thermal decisions with injection and record real heat evidence separately; no artificial long soak now.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F10: Finish the native preparation, live and recordings interface

**Dependencies:** F4, F7, F8, F9.

**Requirement trace:** R1–R7/R11; A3/A6/A8.

**Files:** Existing: Stream14/App/{SetupView,Stream14App}.swift, OverlayTestView.swift, Stream14UITests/SetupScreenTests.swift. Proposed small screens under Stream14/App; avoid a redesign unrelated to the specified operator flow.

**Prompt:**

Refine SetupView into small SwiftUI preparation/settings, active-session and recordings screens with explicit ownership of the existing coordinator. Use native controls and navigation, no architecture/UI framework. Local preview/rehearsal works without Google; selecting an event or opening settings never publishes.

Preparation shows camera/microphone/route/overlay/profile readiness, real channel identity, paginated event picker/refresh/eligibility and exact Go Live confirmation. Empty overlay is explicitly disabled; configured failed overlay needs explicit disable. Settings exposes URL test/load/profile and privacy/help/disconnect. Freeze session event/profile/orientation/URL; reload and manual hide/show remain available while active.

Active landscape UI gives a large letterboxed full-canvas preview, elapsed time, levels/mute, zoom and separate recording/upload/YouTube/overlay labels. Present reconnecting with recording continues, backup failed while live, remote ended and status unavailable as distinct persistent states. Offer explicit Stop recording when upload is unavailable and confirmed End broadcast; show uncertain end plus Studio action. Native warnings/buttons must not enter video.

Recordings retain playback, original export and confirmed per-file deletion, including pending/failed records, with no automatic cleanup. Integrate F11 metadata/recovery when it lands; avoid moving/deleting legacy files as cosmetic cleanup. Explain app deletion loses app-contained originals.

Keep 44-point targets, text/icon status alongside color, VoiceOver and larger text for setup/recordings. Inspect the 13 mini first, both landscape directions/safe areas, keyboard/permission denial, portrait setup and max text. Preserve branded normally signed UI runner.

**Validation and acceptance:**

UI tests use safe deterministic states to cover preflight blockers/confirmation, no implicit publish, reconnect/backup/unknown-end messages, locked settings, manual overlay controls and delete Cancel/Delete. Run accessibility audits and inspect screenshots; manual VoiceOver and physical smallest-screen operation remain required. Confirm actual receiver/file contain no controls or warnings. Do not infer UX acceptance from a view snapshot alone.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F11: Add honest fragment recovery and persistent recording review

**Dependencies:** F6, F9.

**Requirement trace:** R5/R7; A5/A6/A8.

**Files:** Existing: Stream14/Media/{LocalRecorder,ExperimentSample}.swift, MediaSession.refreshSamples, RecordingDeletionTests.swift and F10 recordings UI. Proposed focused native recovery helper only if needed; no database or custom movie parser.

**Prompt:**

Evaluate native fragmented writing/recovery on the selected F1/F6 encoder/container path, initially a ten-second movieFragmentInterval. Inspect public AVAssetWriter recovery APIs/requirements; an interval alone does not prove a killed file is playable. Keep normal MP4 unless a measured simpler native MOV route is justified. No decoding/re-encoding or export transcode.

Extend the small Codable per-session manifest with versioned backward-compatible status, profile, duration/size and minimum nonsecret reconciliation IDs only. Continue reading existing UUID files in MediaExperiments; do not rename/move/remove originals on launch. Corrupt/missing metadata and orphaned media must remain visible for inspection/export or deliberate deletion rather than disappearing from the list.

On launch inspect pending/interrupted files, validate what actually plays/reads and offer supported recovery. Preserve the original; if native repair/remux is needed, keep a distinct recovered artifact and disclose truncated duration/lost fragments. Never promote an old pending/failed record to complete merely because a path exists. No automatic publishing, fragment deletion, or recursive cleanup.

Populate recordings UI with date/duration/size and complete/interrupted/failed/recovered status. Export original or explicitly identified recovered file, confirmed deletion only for selected artifacts, metadata last with retry on partial failure. Sign-out/export/app upgrade must not erase recordings. Storage prediction/stats/polling/thresholds remain out of scope.

**Validation and acceptance:**

Tests cover legacy manifests, malformed/missing sidecars, orphaned media, recovery failure, partial deletion and relaunch status. Short physical forced-process-termination tests at multiple points (including before first fragment and after fragments) verify recovered A/V reads/playback/export and measured loss; keep originals. Clean stop still yields one normal playable file. If public recovery cannot meet A5, document the blocker and required owner design decision; do not close as crash recovery proven.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F12: Add private qualification metrics for the delivered app

**Dependencies:** F6, F8, F9, F11.

**Requirement trace:** A2/A4/A7/A9; M3 measurement distinction.

**Files:** Existing: LocalRecorder.Metrics, ExperimentSample.swift, Stream14Tests/MediaDeviceTests.swift observations, PrivacyInfo.xcprivacy and docs/feasibility.md. Proposed small session diagnostics/analysis utilities and a sanitized report template.

**Prompt:**

Define and implement minimal on-device instrumentation usable in the actual Release/TestFlight app, independent of hosted tests. Track per-output sample admissions/drops, video gaps, bounded queue high-water marks, codec/session identity, monotonic elapsed time, thermal state and supported charged-memory observations. Distinguish estimated missing 30 Hz file intervals from measured pipeline drops, and resident mappings from charged footprint. Document API/measurement limits; lack of crash is not memory stability.

Extend existing per-record metrics/sidecars with bounded sampling/checkpoints outside media callbacks. Keep diagnostics private, backup-excluded and under deliberate export. No analytics/cloud/crash SDK. Export only sanitized summaries: no overlay URL/path/query, auth headers/tokens, stream keys, raw API payloads, tester identity or private media. SDK descriptions/error strings must be sanitized too.

Add a small useful diagnostic export/control and instructions for start/end visible+audible clap markers, original-file analysis, receiver observation and power/network/ambient conditions. A generic internal debug panel is unnecessary. Maintain the development harness 900-second cap; never auto-run 30-minute or three-hour tests. Normal user recording has no artificial limit.

Provide reproducible native tools/scripts for analyzing original sample timestamps/decodability and a qualification report template mapping A1–A9. If measurement hooks differ by build type, prove the delivered build uses the claimed route. Scope new instrumentation as a normal PR into main; it does not retroactively change the evidence for the earlier MVP build.

**Validation and acceptance:**

Tests validate counter meaning/bounds, checkpoint recovery and redaction using representative secret-shaped values, including failing assertions/log paths. Measure instrumentation overhead with a short 13 mini run, check no unbounded memory/disk/task growth, and inspect an actual exported diagnostic artifact. Release packaging preserves required privacy-reason declarations. Exact A/V sync stays pending without both physical markers.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F13: Prepare and deliver a full-app TestFlight qualification candidate

**Dependencies:** F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12.

**Requirement trace:** A3/A6/A9.

**Files:** Existing: Stream14/PrivacyInfo.xcprivacy, ThirdPartyNotices.txt, project/scheme, docs/{privacy,support,testflight-delivery,ios-development-guide}.md. Add a separate full-app delivery record so MVP build evidence remains identifiable.

**Prompt:**

Prepare the streaming beta without rewriting the historical local-only MVP evidence. Update docs/privacy.md, docs/support.md, service terms/YouTube links and in-app disclosures for actual Google token/API, direct RTMPS and overlay data flows. Explain disconnect/revocation and API-data deletion separately from user recordings. Check current Google/YouTube policies, OAuth scope/consent/branding and Apple third-party login rules; no unrelated app account or added Sign in with Apple merely by assumption. Ask owner only for actual account/legal decisions; never fabricate contact details.

Audit selected dependencies, linked binary/license notices, SDK privacy manifests/required-reason APIs, purpose strings, TLS and export compliance using current submission rules. Publish and verify the exact policy/support URLs used by the build. Use verified published URLs matching the beta’s actual behavior; coordinate policy changes with the delivered build rather than describing unreleased behavior as already available.

Document/verify owner Cloud/OAuth configuration, real channel eligibility, unlisted dedicated manual/auto-start test events with auto-stop off, tester access, quota/verification limitations and normal signing. Google setup and Apple enrollment are separate dependencies. Keep secrets/tester lists outside Git.

Build a normally signed distinct full-app version/build, archive/validate/upload, wait for processing/review, install through TestFlight on the 13 mini and verify the installed identity. Issue #6 is closed; preserve its local-only delivery/review evidence and recorded limits when producing the later full-app candidate. No invitation is sent without owner-specified recipients. Document beta limitations, reproducible test flow and expiry/replacement.

**Validation and acceptance:**

Unsigned Release archive/bundle audit and relevant native tests pass; real signed validation/upload/processing/install are recorded separately. Verify exact policy URLs signed out and in installed app. A3 short unlisted smoke check works on the full TestFlight candidate with private media; longer qualification belongs to F14. Unavailable Apple/OAuth/review/tester prerequisites remain explicit blockers, not simulated delivery. Retain/export valuable app files before any potentially destructive installation; never uninstall as routine cleanup.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

### Task F14: Qualify A1–A9 and record full-app release readiness

**Dependencies:** F13.

**Requirement trace:** A1–A9; R1–R11.

**Files:** Existing: canonical specification sections 10–11, docs/feasibility.md, full-app delivery record, F12 report/analysis tools and all app/test sources. Scope is evidence, focused fixes and reviewed promotion, not new product features.

**Prompt:**

Use the actual full-app TestFlight candidate from F13 and complete the specification’s A1–A9 matrix. Issue #6 is closed following MVP delivery/owner review, with objective measurement limits retained; this issue must independently prove the full-product gates. Before any 30-minute or three-hour recording, obtain the owner’s explicit agreement on that run/time and physical markers. Current development experiments remain capped at 15 minutes.

On 13 mini/iOS 27, qualify both profiles with exact-canvas alpha/reloads and common preview/file/remote composition. Cover manual/auto-start, confirmed remote start/end and second-device playback. Exercise permission denial, empty/disabled/missing/wrong-channel events, expired/revoked consent, quota/rate-limit, startup reject/timeout, two-minute real network loss, retry exhaustion, remote completion, overlay freshness/manual hide, writer faults, route/audio/camera interruptions, background/lock/explicit resume and A5 forced-termination recovery.

Run the agreed 30-minute A2 and powered three-hour 1080p30 broadcast+recording A7 on stable qualified network: <1% measured pipeline drops, no repeated video stalls ≥500 ms, no monotonic memory/queue growth, A/V offset ≤100 ms at start/end with uncertainty. Record delivered build/commit/device/OS/profile, power/mount/case/brightness/airflow/ambient/network, original-file and receiver analysis, instrumentation limits and private evidence locations. Test without external cooling first. Do not silently lower resolution or substitute a newer device if 13 mini fails.

Validate available iPhone 15/17 representatives including Pro variants, 720p, VoiceOver/larger text and full Files export/delete flows. Record unavailable required coverage as pending and resolve with owner before full-release acceptance. Fix material failures through PRs into main, deliver a new candidate and rerun affected gates; never infer a changed build passed from old media.

Present private samples and sanitized report for owner acceptance. Prepare any remaining qualification fixes and release documentation as focused reviewed PRs into current main. Resolve conflicts/regressions without rewriting shared history. There is no integration-branch promotion step; merging each PR still needs explicit owner authorization.

**Validation and acceptance:**

Every A1–A9 row has measured pass evidence for the relevant delivered build or is explicitly pending/failed; missing markers and missing hardware do not count as passes. Owner reviews working app/report, historical #6 evidence remains unchanged, recordings remain retained, and release readiness includes independent review, current-main regression results, dependency/privacy audit and remaining agreed limits. Full-app completion is blocked by unmet acceptance, even if all code PRs merged.

Perform the common delivery steps above, including focused tests, documentation, independent review/fixes and commits. Leave unmet evidence pending.

---

## Native validation commands

Run from the checkout root. First inspect `git status --short`, the shared scheme and installed destinations. The baseline machine has Xcode 27.2/iOS 27.2 and the named 13 mini Simulator; use the actual available destination on another Mac. None of these commands ran as part of this documentation-only plan.

```sh
xcodebuild -list -project Stream14.xcodeproj
xcodebuild -showdestinations -project Stream14.xcodeproj -scheme Stream14
xcodebuild -resolvePackageDependencies -project Stream14.xcodeproj -scheme Stream14 \
  -clonedSourcePackagesDirPath /tmp/stream14-full-app-packages
```

Use a fresh local run identifier, e.g. `STREAM14_RUN_ID=F3-first`; never delete old evidence to reuse a result path. After package resolution:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' \
  -clonedSourcePackagesDirPath /tmp/stream14-full-app-packages \
  -derivedDataPath "/tmp/stream14-full-app-${STREAM14_RUN_ID}-release" \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -clonedSourcePackagesDirPath /tmp/stream14-full-app-packages \
  -derivedDataPath "/tmp/stream14-full-app-${STREAM14_RUN_ID}-simulator" \
  -disableAutomaticPackageResolution \
  -resultBundlePath "/tmp/stream14-full-app-${STREAM14_RUN_ID}.xcresult" test
```

Expected: native build/test succeed with no new concurrency errors; opt-in physical/reference checks remain explicitly skipped unless configured. Add `-only-testing:<target>/<suite>` for focused iteration, then run relevant regression coverage. Use the guide’s normally signed physical-device commands after checking owner/device availability, using local team overrides and branded test products. Never invoke live publishing, crash tests or long recording experiments from the default suite. Keep external prerequisites explicit; missing Google configuration does not block fixture-driven development or local rehearsal.

For each issue: inspect requirements → implement a small step → write meaningful tests for that decision → run affected checks → update evidence/docs → review actual diff and fix material findings → commit a focused change → prepare PR into main. Independent review inspects the actual full PR diff against current main, with prerequisite evidence. Do not merge automatically. Documentation-only edits need content/link checks and `git diff --check`, not artificial app tests.

## Acceptance evidence and delivery boundaries

Issue #6 is closed after local-only TestFlight delivery and owner review, with formal qualification limits retained in the report. F13 delivers a distinct later full-app candidate; F14 proves A1–A9 on that delivered build. Do not infer start/end sync from track endpoints or reuse the prior run with a missed end clap. Device availability, OAuth setup, native recovery limitations and media decisions are real dependencies; leave issues/gates pending if unmet.

Each issue must leave exact APIs/ownership, test commands/results, build/device/profile, sanitized measurements, private sample locations and unresolved acceptance. A code-complete PR is not milestone completion. All referenced future APIs and policy details must be checked at implementation time.

## Primary references checked for planning

- [YouTube broadcast list/filter/pagination reference](https://developers.google.com/youtube/data/live/reference/rest/v3/liveBroadcasts/list)
- [YouTube broadcast transition rules](https://developers.google.com/youtube/data/live/reference/rest/v3/liveBroadcasts/transition)
- [YouTube ingestion stream creation](https://developers.google.com/youtube/data/live/reference/rest/v3/liveStreams/insert)
- [YouTube RTMPS ingestion](https://developers.google.com/youtube/data/live/guides/rtmps-ingestion)
- [Google Sign-In iOS setup](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [YouTube developer policies](https://developers.google.com/youtube/terms/developer-policies)
- [Apple movie fragment interval](https://developer.apple.com/documentation/avfoundation/avassetwriter/moviefragmentinterval) (API candidate, not proof of recovery)

HaishinKit 2.3.0 Package.swift and RTMPStream.swift were inspected from the existing pinned local checkout. Public compressed fan-out, its timing/connection behavior and the current stable package decision remain F1 evidence requirements. No new dependency has been adopted by this plan.
