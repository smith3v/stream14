# stream14 Local-Recording MVP Implementation Plan

> Owner sequencing update (2026-11-05): issue #6 and all MVP acceptance remain
> pending while Apple enrollment completes. Full-app development is now authorized
> separately on `codex/full-app`; all new PRs target integration while MVP testing
> is pending. See the [full-app plan](2026-11-05-full-app-implementation.md).
> Older instructions here deferring all broadcasting work apply to the local-only
> candidate, not the newly authorized integration work. This MVP plan is retained.


Scope clarified: 2026-11-02. This plan covers the first milestone only.

**Goal:** Deliver an iPhone app that captures camera video and microphone audio,
adds a transparent HTML overlay, and saves the composition locally through
HaishinKit, with no streaming.

**Architecture:** HaishinKit is the preferred owner of capture, image composition,
encoding, and local recording through verified public APIs. The app supplies a
main-actor WebKit renderer and minimal native controls. Custom media components are
a fallback following measured library limitations, not the starting implementation.

**Tech Stack:** Swift 6, SwiftUI, Xcode, WebKit, HaishinKit via Swift Package Manager,
native permission/audio-session/file APIs and tests. No Google Sign-In or speculative
RTMP product; no custom Core Image/VideoToolbox/Metal pipeline by default. If a local
API requires another product, document that need without adding network transmission.

---

## First milestone and stopping point

Milestone 1 is a usable local-recording app on the iPhone 13 mini: configurable
overlay URL, composed preview, Record/Stop, and a playable/exportable video file
containing camera, audio, and overlay. Qualify landscape 1080p30, approximately
1 Hz overlay updates, the 10-second overlay outage hide/restore behavior, and a
smooth recording using specification gates M1–M5. Current development experiments
are capped at fifteen minutes; the longer integrated qualification is deferred
until the whole app is ready.
The delivered app must be installed and exercised through TestFlight on the testing
iPhone; a development build run from Xcode is not the finished milestone.

This plan ends with that MVP's TestFlight delivery/validation, independent PR review, and owner review.
It contains no YouTube login, stream selection, RTMPS transmission, reconnect,
or three-hour broadcasting implementation tasks. The full-product
requirements remain in the specification for context; they are not this milestone's
deliverables. Plan a later milestone separately after reviewing the MVP evidence.
Storage stats, remaining-time estimates, polling, and proactive capacity thresholds
are also deferred; retain straightforward disk-full/write-error handling.

## How to use this plan

The [specification](2026-11-01-stream14-design.md) defines MVP gates M1–M5.
Task 1 records completed setup; Tasks 2–5 build and provisionally validate the MVP,
Task 6 delivers it through TestFlight and completes device/owner review, and Task 7
defines the PR/review process for each focused change
before handoff. Execute implementation tasks in order. The prompts below define small deliverable slices,
not claims that a feature is already implemented. Before each media integration,
inspect the selected stable API and write the concrete code against that API;
do not paste guessed library calls from an outdated tutorial. Split a large prompt
into focused changes rather than introducing the complete app at once.

For each task: inspect current code, add the smallest implementation, add meaningful
tests where the task introduces behavior, run the relevant checks, and commit with
a concrete summary. Prepare a focused PR into main and have a separate agent review
the actual diff and requirements for material issues only. Resolve material findings
and rerun affected checks; record validation, review outcome, and limitations in the PR.
Do not expand work to satisfy minor nits or speculative concerns. Document manual
device evidence and limitations; never mark a gate complete on Simulator evidence
alone. Follow [AGENTS.md](../AGENTS.md), and update the canonical specification if
measurements require a design change.

## Allow independent streaming later without building it now

- Keep capture/composition ownership distinct from local recording's start/stop and
  writer state. Use one HaishinKit media pipeline and a small concrete integration;
  do not make recording depend on a publisher, connection, account, or stream key.
- Document the actual library boundary used for composed media and local output in
  the feasibility report. Prefer a path that permits another output to be attached
  later, if supported, without replacing the camera/composition pipeline. Do not
  assume a shared encoder or external encoded-input API exists.
- A future streaming output must have independent start/stop/error handling: stream
  startup, shutdown, or failure must not stop an active healthy recorder while
  storage remains available. This constrains ownership now; network-failure tests
  and simultaneous-output qualification belong to the later streaming milestone.
- Do not implement a streaming adapter, placeholder network state machine, generic
  output framework, or second encoder in this MVP just to anticipate that extension.
  If library ownership would prevent independent outputs, document that limitation
  during MVP review before committing to a broader architecture.
- Compose before the initial necessary encode; avoid duplicate encoders, decoding
  and re-encoding already compressed media, or post-save/export transcoding. Prefer
  HaishinKit's native writer/default MP4 path; use MOV if verified to avoid extra work.
  Record the sample formats and encoder ownership. Do not infer lower cost from a
  container extension or assume the library exposes compressed passthrough samples.

## Task 1: Establish the documented repository

**Status (2026-11-01): Complete.** The public repository is created; main and the
BSD-3-Clause license are verified. See the initialization record in the development guide.

**Prompt:**
Create AGENTS.md, README.md, LICENSE, .gitignore, and the three linked project
documents. Confirm the agreed priorities: 13 mini/iOS 27, smooth 1080p30 video,
approximately 1 Hz web-overlay raster updates, configurable full-size transparent
canvas, and independent local recording. Validate local links, requirement coverage,
license text, absence of credentials/private media, and whitespace. Initialize main,
make the initial documentation commit, create the agreed public GitHub repository
when authentication permits, and verify local/remote identities. Report any blocked
publication separately from the completed local documents.

**Acceptance:** Documents are readable and mutually consistent; Git contains only
the intended files. No app implementation is claimed.

## Task 2: Create and run the smallest native app

**Status (2026-11-04): Implemented and device-verified in issue #2.** The project,
minimal native screen, shared scheme, and native test targets are implemented.
The signed app runs on the physical 13 mini; the owner confirmed readable setup
content in portrait and both landscape orientations. [PR #7](https://github.com/smith3v/stream14/pull/7)
merged on 2026-11-04. See the [device verification record](ios-development-guide.md#physical-setup-verification-2026-11-04)
and [focused implementation plan](2026-11-02-native-app-implementation.md).
Do not begin Task 3 until this stage's prerequisite PR merges unless the owner
explicitly coordinates stacked work.

**Prompt:**
Guide the owner through installing full Xcode and configuring a development team
without requesting secrets. Confirm the bundle identifier before registration.
Create Stream14.xcodeproj, the Stream14 shared scheme, and an iPhone SwiftUI target
with deployment target iOS 27.0. Keep the entry point at
Stream14/App/Stream14App.swift and start with a simple native setup screen; no
external packages yet. Add focused test targets using Xcode's current native tools.
Run the empty application on the 13 mini, inspect the project with xcodebuild -list,
and replace guide placeholders with verified destinations and build/test commands.
Review signing settings for accidental team secrets or user-local paths, then commit.

**Acceptance:** A basic native app runs on the real phone and builds/tests from
the documented shared scheme. Camera/streaming capability is not yet claimed.

## Task 3: Verify the HaishinKit local media path

**Status (2026-11-04): Implemented; M1 demonstrated on the testing phone.**
HaishinKit 2.3.0 core-only experiment records a playable 53.53-second camera/audio
sample with an updated synthetic alpha layer. The owner confirmed correct playback. See [feasibility.md](feasibility.md) for exact
API/encoder path, package footprint and measured evidence; see the
[focused plan](2026-11-04-haishinkit-implementation.md) for reproducible checks.
Native recorder final-status observability and queue/drop instrumentation are
explicit reliability handoffs for Task 5. [PR #8](https://github.com/smith3v/stream14/pull/8)
merged on 2026-11-04; Task 4 builds on that merged prerequisite. No M2–M5 acceptance is claimed.

**Prompt:**
Inspect a current stable HaishinKit release's public APIs and examples for camera
and microphone capture, dynamically updated alpha-image layers, composed preview,
and recording the composed output without publishing or an ingest connection. Record
the exact APIs, capture/encoder ownership, sample formats, container/codec support, dependency products and transitive
footprint, licenses/notices, and Swift 6/iOS 27 build result in docs/feasibility.md.
Add only products required for local operation through SPM and commit Package.resolved.
Try the smallest library-owned capture/recording sample on the 13 mini. No separate
AVCaptureSession or RTMP connection, and no Google setup. If a small native writer
adapter is needed, document the supported sample path; if the approach is unsuitable,
present the concrete limitation before adopting a custom pipeline. Review and commit.

**Acceptance:** M1 is demonstrated, with gaps explicitly reported. Package marketing
or an upstream example alone does not prove local composition/recording suitability.

## Task 4: Prove transparent WebKit capture before broad UI work

**Status (2026-11-04): Renderer implemented; physical WebKit evidence recorded.**
The fixture/reference have a 1920×1080 CSS viewport and alpha raster, with
source/render freshness, retained output through reloads and manual-hide precedence.
See the [focused plan](2026-11-04-web-overlay-implementation.md) and
[feasibility record](feasibility.md#stage-3-webkit-renderer-issue-4-2026-11-04).
Independent review found no remaining material issues; native build/tests and
physical fixture/reference checks passed (see the development guide). Memory/thermal behavior
under camera load is not established; Task 5/#6 must qualify combined media and
M3–M5. WebKit output is not yet integrated into saved camera recordings.

**Prompt:**
Add Stream14/Media/WebOverlayRenderer.swift with the smallest public-API WKWebView
capture experiment. Use a configurable HTTPS URL and the stream canvas viewport,
not phone screen dimensions. Exercise the reference page and a small synthetic
transparent HTML fixture in Stream14Tests/Fixtures/. Begin at 1 Hz with one capture
in flight, retaining the last valid alpha image during brief page reloads. Track
source access independently of cached snapshots: hide after a 10-second freshness/
rendering failure and automatically restore a fresh image after recovery unless
manually hidden. An unchanged score with successful source access stays visible. Verify
1920×1080 layout/raster dimensions and partial transparency on the physical 13 mini.
Record observations in docs/feasibility.md, including attached-view requirements,
memory, capture latency, and any reload flashes. If necessary, propose the smallest
in-place DOM update change in the overlay's separate project; do not silently modify
that project while working in this one. Commit the experiment and evidence.

**Acceptance:** The recorded evidence establishes the WebKit half of M2. If capture
fails, document the failure and resolve it before depending on this approach elsewhere.

## Task 5: Integrate the local-recording MVP

**Status (2026-11-05): Implemented; owner playback/export, storage reclamation and icons reviewed. PR #10 is ready for review; longer whole-app qualification is deferred.**
MediaSession, attached web-raster composition, the concrete final-status-aware
writer, secure URL settings and native recording/playback/export are implemented.
See the [focused plan](2026-11-04-local-recorder-implementation.md) and
[stage 4 evidence](feasibility.md#stage-4-integrated-local-recording-issue-5).
Do not treat implementation or a short development sample as completed M2/M4,
preliminary M3 or TestFlight qualification.

**Prompt:**
Implement a small HaishinKit integration in Stream14/Media/MediaSession.swift,
using the actual API path established in Task 3. Supply WebOverlayRenderer's latest
alpha image to the library's composition layer and update it during recording.
Use one library-owned rear-camera/microphone pipeline for preview and recorded
output. Do not add a custom CapturePipeline/VideoCompositor/encoder in parallel.
Keep recorder state and start/stop independent from any future transport lifecycle;
document the concrete composition/output boundary without creating streaming stubs.
Use a small native writer adapter only if Task 3 establishes the need and API path.
Add permission purpose strings, URL entry/settings, Record/Stop, elapsed time/status,
and system playback/export. Persist files in Application Support and protect URLs
as specified. Start with the native writer's MP4 default; choose MOV if it avoids
additional encoding/conversion. Verify one necessary local encoding stage and no
save/export transcode; don't add a format picker or duplicate encoder. Restore
screen-sleep behavior after recording and finalize on interruption. Test repeated
recording, overlay updates/failure/outage (before and after the 10-second hide
deadline, automatic fresh-image restoration, unchanged healthy scores, stale cached
snapshots, and manual hiding), permission denial, interrupted capture,
and injected disk-full/write errors, including initialization and finalization failure.
Preserve usable/incomplete files and do not mark failures complete; no remaining-space
or time estimator, capacity polling, or reserve-threshold logic is required.
Save device samples and perform development runs capped at 15 minutes under the owner’s 2026-11-05 update. Longer whole-app qualification is deferred. Record APIs, evidence,
and limitations in docs/feasibility.md. Final M3 qualification is on the delivered
TestFlight build in Task 6. Review and commit.

**Acceptance:** M2/M4 and fifteen-minute development checks pass on the 13 mini, with longer integrated qualification explicitly deferred. Files contain synchronized audio, video,
and the actual overlay, with no app UI; overlay-network failure does not stop recording.

**2026-11-05 evidence:** PR #10 is merged. The fifteen-minute device retry passed
cadence, writer admission, charged-footprint and injected overlay-outage/manual-hide
checks; see [measurements and limits](feasibility.md#completed-fifteen-minute-verification-2026-11-05).
The owner missed the end clap and requested moving on. Start/end A/V offset for
this run remains unverified and is deferred to Task 6 with longer integrated
qualification; M3/M5 are not complete.

## Task 6: Deliver the MVP through TestFlight and review it

**Status (2026-11-05): Release preparation in progress; Apple activation, upload,
TestFlight installation and delivered-build acceptance pending.** Prerequisite
PRs #10/#11 are merged. See the [focused plan](2026-11-05-testflight-implementation.md)
and [delivery record](testflight-delivery.md). The owner submitted enrollment and is waiting for Apple confirmation;
active membership remains unverified. No longer recording is authorized
without a separate agreed slot.


**Prompt:**
Follow the development guide's TestFlight steps: owner-controlled Apple Developer
Program membership, app record/bundle identifier, automatic signing, version/build,
icon, actual permissions/privacy manifests/disclosures, support/privacy information,
and export compliance. No Google setup or YouTube integration is required. Use
Xcode Archive/Organizer to validate/upload the signed local-only MVP and resolve
processing errors. Invite the testing device's user to the appropriate internal or
external TestFlight group; complete beta review if required. Install via TestFlight
on the iPhone 13 mini and exercise capture, overlay updates/outage hide/restore,
stop, playback/export, and a 30-minute M3 run. Record build/device/OS/install route
and results without private tester data. Do not substitute an Xcode install.
Review the complete MVP branch against main and M1–M4, fix findings, and rerun
affected checks in the updated TestFlight build if the tested behavior changes.
Present sample files privately and commit a concise feasibility
report: device/OS/build, library/version/products, exact capture/composition/recording
APIs, encoder ownership/sample formats, file format, TestFlight version/build, duration, measured frame drops/stalls, A/V offset, memory/thermal
observations, failure behavior, and measurement limitations. Distinguish confirmed
capabilities from untested dual-output or three-hour behavior. Ask the owner to review
the result and proposed next step. Do not begin a streaming milestone before that review.

**Acceptance:** M1–M5 pass for the TestFlight-installed MVP on the testing phone.
A working short sample or Xcode-only install alone does not authorize
claiming a fully reliable broadcaster. Record owner feedback before continuing.

## Task 7: Prepare a PR and independently review the branch against main

**Prompt:**
Prepare a GitHub pull request (MR) into main describing the final behavior and
relevant checks. Assign a separate agent that did not author the change to inspect
the full branch diff, requirements, and actual files, including applicable project
settings, dependencies, tests, and docs. Review only material correctness, data-loss,
security/privacy, build, media-reliability/performance, and important requirement or
test gaps. Require evidence and practical impact; do not request cosmetic changes,
speculative hardening, or extra abstractions. No findings is valid. Resolve material
findings or record an agreed deferral/risk, rerun affected checks, and request focused
re-review only when meaningful changes justify it. Use git diff --check plus the
verified build/test commands when code exists; documentation-only work uses content
and link checks. Record the independent outcome and outstanding device/service
limitations in the PR. Keep the design simple without removing necessary safeguards.
Do not merge automatically or claim an unfinished milestone is qualified.

**Acceptance:** The PR contains relevant check results and an independent agent review
focused on major issues; no unresolved material findings invalidate the milestone.
Final behavior, documentation, and recorded evidence agree. Minor nits do not block handoff.
