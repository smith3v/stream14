# stream14 Implementation Plan

**Goal:** Deliver the smallest reliable iPhone camera broadcaster with a configurable
transparent web overlay, a scheduled YouTube destination, and an independent local backup.

**Architecture:** One native app uses Apple capture/compositing/recording APIs and a
main-actor WebKit renderer. A small YouTube REST client coordinates the selected
event; narrowly justified sign-in/RTMPS packages may supply protocol implementation.
Physical-device feasibility precedes full integration.

**Tech Stack:** Swift 6, SwiftUI, Xcode, AVFoundation, WebKit, Core Image,
VideoToolbox/Security/Foundation as needed, Swift Package Manager, native test tools.
Google Sign-In and HaishinKit RTMP products are candidates pending evaluation.

---

## How to use this plan

The [specification](2026-11-01-stream14-design.md) defines requirements and gates A1–A9.
Execute milestones in order. The prompts below define small deliverable slices,
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

## Task 3: Prove transparent WebKit capture before broad UI work

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

**Acceptance:** The recorded evidence establishes the WebKit half of A1. If capture
fails, document the failure and resolve it before depending on this approach elsewhere.

## Task 4: Capture, composite, and record locally

**Prompt:**
Implement one rear camera and the system-selected microphone in
Stream14/Media/CapturePipeline.swift, Core Image composition in
Stream14/Media/VideoCompositor.swift, and an AVAssetWriter-based local recorder in
Stream14/Media/LocalRecorder.swift. Add honest camera/microphone usage descriptions.
Feed the composed preview and recorder from the same video composition, with a
common A/V clock and bounded queues. Provide local rehearsal start/stop on the setup
screen. Add focused tests using synthetic timing/frames where they catch a real
failure. Save a device sample, inspect alpha/geometry and A/V synchronization, and
run the 30-minute test from A2. Log measured outcomes in docs/feasibility.md, review
against main, fix findings, and commit.

**Acceptance:** A1 and A2 pass for local capture/recording, including the reference
page's refresh behavior; no controls appear in the file.

## Task 5: Select and prove the RTMPS path

**Prompt:**
Inspect HaishinKit's current stable release and RTMPHaishinKit product APIs before
adding packages. Record the justification, version, products, transitive footprint,
license/notices, iOS 27/Swift 6 build result, and whether a common encoded sample
path can feed local recording and RTMPS in docs/feasibility.md. Add only necessary
products via SPM and commit Package.resolved. Keep protocol-specific integration in
Stream14/Media/StreamingOutput.swift. If the selected library needs to own part of
capture/encoding, adapt the proven pipeline with minimal duplication and document
the resulting ownership; do not maintain two competing camera sessions. Use an
unlisted test destination supplied securely at runtime. Demonstrate that stopping
the network path leaves the recorder healthy, inspect the result, and commit.

**Acceptance:** Real YouTube ingestion works securely and recording is independent;
the selected architecture is supported by actual library APIs and measurements.

## Task 6: Connect YouTube and select scheduled events

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

## Task 7: Implement one safe Go Live / End flow

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

## Task 8: Qualify recovery, local files, and operator controls

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

## Task 9: Qualify the event experience and add useful CI

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

## Task 10: Prepare the first TestFlight build

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

## Task 11: Review the complete branch against main

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
