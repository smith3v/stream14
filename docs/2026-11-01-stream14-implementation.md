# stream14 Implementation Plan

**Goal:** First validate a HaishinKit-based local-recording MVP with camera, audio,
and a transparent web overlay; continue to broadcasting after the owner's MVP review.

**Architecture:** HaishinKit is the preferred owner of capture, image composition,
encoding, and local recording through verified public APIs. The app supplies a
main-actor WebKit renderer and minimal native controls. Custom media components are
a fallback following measured library limitations, not the starting implementation.

**Tech Stack:** Swift 6, SwiftUI, Xcode, WebKit, HaishinKit via Swift Package Manager,
native permission/audio-session/file APIs and tests. No Google Sign-In or speculative
RTMP product; no custom Core Image/VideoToolbox/Metal pipeline by default. If a local
API requires another product, document that need without adding network transmission.

---

## How to use this plan

The [specification](2026-11-01-stream14-design.md) defines MVP gates M1–M5 and later
full-product gates A1–A9. Tasks 2–6 deliver the MVP; Tasks 7–12 are deferred until
owner review. Execute milestones in order. The prompts below define small deliverable slices,
not claims that a feature is already implemented. Before each media integration,
inspect the selected stable API and write the concrete code against that API;
do not paste guessed library calls from an outdated tutorial. Split a large prompt
into focused changes rather than introducing the complete app at once.

For each task: inspect current code, add the smallest implementation, add meaningful
tests where the task introduces behavior, run the relevant checks, review the diff
against main, fix findings, and commit with a concrete summary. Document manual
device evidence and limitations; never mark a gate complete on Simulator evidence
alone. Follow [AGENTS.md](../AGENTS.md), and update the canonical specification if
measurements require a design change.

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

**Prompt:**
Inspect a current stable HaishinKit release's public APIs and examples for camera
and microphone capture, dynamically updated alpha-image layers, composed preview,
and recording the composed output without publishing or an ingest connection. Record
the exact APIs, ownership, container/codec support, dependency products and transitive
footprint, licenses/notices, and Swift 6/iOS 27 build result in docs/feasibility.md.
Add only products required for local operation through SPM and commit Package.resolved.
Try the smallest library-owned capture/recording sample on the 13 mini. No separate
AVCaptureSession or RTMP connection, and no Google setup. If a small native writer
adapter is needed, document the supported sample path; if the approach is unsuitable,
present the concrete limitation before adopting a custom pipeline. Review and commit.

**Acceptance:** M1 is demonstrated, with gaps explicitly reported. Package marketing
or an upstream example alone does not prove local composition/recording suitability.

## Task 4: Prove transparent WebKit capture before broad UI work

**Prompt:**
Add Stream14/Media/WebOverlayRenderer.swift with the smallest public-API WKWebView
capture experiment. Use a configurable HTTPS URL and the stream canvas viewport,
not phone screen dimensions. Exercise the reference page and a small synthetic
transparent HTML fixture in Stream14Tests/Fixtures/. Begin at 1 Hz with one capture
in flight, retaining the last valid alpha image during page reloads. Verify
1920×1080 layout/raster dimensions and partial transparency on the physical 13 mini.
Record observations in docs/feasibility.md, including attached-view requirements,
memory, capture latency, and any reload flashes. If necessary, propose the smallest
in-place DOM update change in the overlay's separate project; do not silently modify
that project while working in this one. Commit the experiment and evidence.

**Acceptance:** The recorded evidence establishes the WebKit half of M2. If capture
fails, document the failure and resolve it before depending on this approach elsewhere.

## Task 5: Integrate the local-recording MVP

**Prompt:**
Implement a small HaishinKit integration in Stream14/Media/MediaSession.swift,
using the actual API path established in Task 3. Supply WebOverlayRenderer's latest
alpha image to the library's composition layer and update it during recording.
Use one library-owned rear-camera/microphone pipeline for preview and recorded
output. Do not add a custom CapturePipeline/VideoCompositor/encoder in parallel.
Use a small native writer adapter only if Task 3 establishes the need and API path.
Add permission purpose strings, URL entry/settings, Record/Stop, elapsed time/status,
and system playback/export. Persist files in Application Support and protect URLs
as specified. MP4 is preferred; document a supported MOV choice if simpler. Restore
screen-sleep behavior after recording and finalize on interruption. Test repeated
recording, overlay updates/failure/outage, permission denial, interrupted capture,
and injected writer/storage errors. Save device samples and perform the 30-minute
M3 run. Record APIs, evidence, and limitations in docs/feasibility.md. Review and commit.

**Acceptance:** M2–M4 pass on the 13 mini. Files contain synchronized audio, video,
and the actual overlay, with no app UI; overlay-network failure does not stop recording.

## Task 6: Review the MVP before expanding scope

**Prompt:**
Review the complete MVP branch against main and M1–M4, fix findings, and rerun
affected checks. Present sample files privately and commit a concise feasibility
report: device/OS/build, library/version/products, exact capture/composition/recording
APIs, file format, duration, measured frame drops/stalls, A/V offset, memory/thermal
observations, failure behavior, and measurement limitations. Distinguish confirmed
capabilities from untested dual-output or three-hour behavior. Ask the owner to review
the result and proposed next step. Do not start the deferred tasks before that review.

**Acceptance:** M5 is complete. A working short sample alone does not authorize
claiming a fully reliable broadcaster. Record owner feedback before continuing.

## Task 7: Select and prove the RTMPS path (after MVP review)

**Prompt:**
Inspect HaishinKit's current stable release and RTMPHaishinKit product APIs before
adding packages. Record the justification, version, products, transitive footprint,
license/notices, iOS 27/Swift 6 build result, and whether a common encoded sample
path can feed local recording and RTMPS in docs/feasibility.md. Extend the MVP's
library-owned pipeline with only necessary RTMP products via SPM and commit
Package.resolved. Keep protocol-specific integration in
Stream14/Media/StreamingOutput.swift. Verify any required ownership change rather
than assuming an external encoded-input API; do not introduce a competing camera
session or rebuild a working pipeline without evidence. Use an
unlisted test destination supplied securely at runtime. Demonstrate that stopping
the network path leaves the recorder healthy, inspect the result, and commit.

**Acceptance:** Real YouTube ingestion works securely and recording is independent;
the selected architecture is supported by actual library APIs and measurements.

## Task 8: Connect YouTube and select scheduled events (deferred)

**Prompt:**
Guide owner-controlled Google Cloud/OAuth setup. Evaluate and add only the required
Google Sign-In products, pinned through SPM, with correct notices and callback
configuration. Implement Stream14/YouTube/Authorization.swift and
Stream14/YouTube/YouTubeClient.swift using URLSession/Codable for the specified REST
surface. Add a native channel/event selection screen and fixtures under
Stream14Tests/Fixtures/. Cover pagination, mutually exclusive list filters, wrong
channel, missing scope, no upcoming events, revoked tokens, and useful error messages.
Keep configuration examples free of tokens. Verify the actual authorized channel
and the unlisted test event on device, review the branch, and commit.

**Acceptance:** The intended channel's complete scheduled-event list can be used;
preview/selection performs no camera upload and no remote event transition.

## Task 9: Implement one safe Go Live / End flow (deferred)

**Prompt:**
Implement the session orchestration in Stream14/Session/SessionCoordinator.swift.
Apply the specification's dedicated-binding, auto-start/auto-stop, and reconciliation
rules. Start the local writer before transmitting. Read ingestion activity before
requesting live; verify the broadcast's actual state. Add distinct recording,
transport, overlay, and YouTube status presentation to the native live screen.
Use fake services to test ambiguous responses, double taps, cancellation, partial
startup failure, already completed events, and unconfirmed end. Demonstrate start,
viewing on a second device, and end on the real unlisted event. Review and commit.

**Acceptance:** A3 passes; the app never equates a socket connection with a confirmed
live broadcast and never retries a potentially successful mutation blindly.

## Task 10: Qualify recovery, local files, and operator controls (deferred)

**Prompt:**
Add capped reconnect backoff, independent output failures, overlay health/reload/hide,
background/capture interruption handling, and foreground resume. Add persistent
recording manifests plus Recordings playback, export, and confirmed deletion. Validate
fragmented MP4 interruption recovery rather than assuming it works. Cover storage
thresholds, thermal degradation of overlay work, audio-route changes, and diagnostics
redaction. Use focused state tests and physical failure exercises. Apply the specified
"keep broadcasting if backup fails" policy visibly. Review and commit.

**Acceptance:** A4–A6 pass and interruption limitations are documented accurately.
The same composed local video remains usable across a transport outage.

## Task 11: Qualify the event experience and add useful CI (deferred)

**Prompt:**
Run the three-hour 13 mini qualification and available iPhone 15/17 matrix from A7/A8.
Keep raw media private; commit a concise report with the measured metadata described
in the specification. Inspect the 13 mini landscape layout, larger text, VoiceOver,
warnings, input permissions, playback, and export. Fix failures before declaring
support. Once local build/test commands are verified, add a small GitHub Actions
workflow using an actually available macOS/Xcode runner and the shared Stream14
scheme. Keep distribution credentials out of initial CI. Review and commit.

**Acceptance:** A7/A8 pass with explicit evidence; CI runs the verified tests rather
than substituting for physical media qualification.

## Task 12: Prepare the first TestFlight build (deferred)

**Prompt:**
Walk the owner through program membership, app record, and normal automatic signing.
Finalize privacy/support/terms content and contact details based on the actual data
flows. Check current App Review, Google authorization, privacy-manifest, notices,
SDK, export-compliance, icon, version/build, and beta review requirements. Do not add
Sign in with Apple solely because the app connects YouTube. Archive, validate, and
upload using Xcode. Start with the owner, then the small external group with suitable
review instructions and separately authorized Google test users. Verify installation
and a rehearsal on a tester phone; record build number and limitations, then commit
documentation changes without private tester data.

**Acceptance:** A9 passes. Record build expiry and the replacement-build procedure;
do not describe TestFlight as a permanent public release.

## Task 13: Review the complete branch against main

**Prompt:**
Before merging each substantial milestone, inspect the full branch diff against
main, including project settings, dependencies, source, tests, and docs. Check
requirements and the milestone's acceptance evidence, identify defects or scope
drift, fix them, and rerun affected checks. Use git diff --check and the now-verified
build/test commands. Commit fix-ups with clear summaries and report unresolved
device/service limitations. Do not merge or publish an unfinished milestone as
qualified. Initial documentation setup uses a working-tree review because no
earlier main commit exists.

**Acceptance:** No unresolved findings invalidate the milestone; final behavior,
documentation, and recorded evidence agree.
