# Working on stream14

## Project and sources of truth

stream14 is a native iPhone app for broadcasting camera video and microphone audio
to an existing scheduled YouTube event, compositing a transparent web overlay into
the outgoing video, and keeping a local copy of that composition.

- Read [the application specification](docs/2026-11-01-stream14-design.md) before
  changing behavior. It distinguishes confirmed requirements from starting defaults
  and capabilities that still need device evidence.
- Use [the development guide](docs/ios-development-guide.md) for Apple, Google, and
  TestFlight setup, and [the implementation plan](docs/2026-11-01-stream14-implementation.md)
  for the order of work.
- Keep these documents consistent with implementation. Record a material technical
  decision and its evidence in the relevant specification section; create a separate
  decision document only when the explanation no longer fits there.
- The repository initially contains documentation only. Do not claim there is a
  working app, a build pipeline, or a passed device test until it exists.

## Owner workflow update — 2026-11-06

Use current `main` as the base for focused development branches and the merge target
for every new PR, including full-app work. This supersedes the 2026-11-05 temporary
`codex/full-app` integration workflow. No integration-branch promotion or MVP backport
step is needed. Do not delete old branches or rewrite history as part of this change.

Full-app development remains authorized under the
[full-app plan](docs/2026-11-05-full-app-implementation.md) and epic #13. Earlier
MVP-only sequencing below describes the local milestone and does not block planned
YouTube/OAuth, RTMPS or 720p implementation on focused branches from main.
Issue #6 is closed after TestFlight delivery and owner review; preserve its documented
measurement limits rather than claiming every formal qualification gate passed.

Prepare reviewed PRs into main; the target change does not authorize automatic
merging. Keep independent review, the 15-minute development-experiment cap, explicit
agreement for longer qualification, retained originals and all reliability/privacy
requirements.

## Current milestone: local-recording MVP

- Build only rear camera + microphone → HaishinKit capture/composition/encoding →
  local video file, with a configurable transparent WKWebView overlay at about 1 Hz.
  Preview and the file must show the same composition.
- The implementation plan ends at this first milestone's M1–M5 validation, TestFlight
  installation/use on the testing iPhone, and owner review. Xcode installation alone
  is development evidence, not MVP delivery.
  Keep future broadcasting requirements in the specification; write its implementation
  plan separately after MVP review rather than executing a whole-app roadmap now.
- Defer available-storage stats, recording-time estimates, periodic capacity polling,
  and proactive capacity thresholds. The MVP must still handle disk-full/write errors,
  report recording failure, and preserve usable or incomplete files without claiming
  they are complete. Do not add a storage-estimation subsystem or dependency.
- Keep recording ownership/start/stop independent from a future streaming output.
  Document the actual composed-media/output boundary so streaming can be added later
  without controlling the recorder. Do not add streaming stubs, generic output
  abstractions, or a second encoder to demonstrate extensibility in the MVP.
- Evaluate HaishinKit as the primary media pipeline first. Do not first build custom
  AVFoundation capture, a Core Image compositor, or VideoToolbox encoding. Use one
  camera session; add a small native recording adapter only if the verified library
  API needs it. If the approach fails, document evidence and review the fallback
  before replacing it with a custom pipeline.
- Verify the stable package's actual overlay-update and local-recording APIs, license,
  dependency footprint, and iOS 27/Swift 6 compatibility before adoption. Link only
  the products needed for local capture/composition/recording; no RTMP product merely
  in anticipation of streaming. Do not open an ingestion connection to enable recording.
- Defer YouTube/OAuth, RTMPS transmission, reconnect logic, 720p/60 fps options, extensive controls,
  until after MVP review. TestFlight distribution is part of the MVP. The full-product requirements
  below apply when those features are implemented, not as MVP completion criteria.
- Pass the specification's M1–M5 gates on the 13 mini and present the files/measurements
  for owner review before continuing with broadcasting. A short local demo does not
  qualify a three-hour stream or prove simultaneous recording/RTMPS independence.
- Compose before encoding; use one necessary local video/audio encode path and avoid
  decode/re-encode, duplicate encoders, and post-record/export transcoding. Prefer
  the library's native writer/default container (currently MP4); use MOV if a verified
  path avoids additional work. Neither extension alone establishes lower resource use.
  Document codec/container and encoding ownership before claiming encode-once or
  shared encoded output. Do not force a custom pipeline solely to change containers.

## Current owner development preferences (2026-11-05)

- Limit development recording experiments to 15 minutes for now. Keep longer
  integrated whole-app qualification for a later agreed run; do not repeatedly
  launch 30-minute experiments or treat 15 minutes as proof of the deferred gate.
- Provide deliberate per-recording deletion with confirmation so the owner can
  reclaim space. Never automatically delete recordings, including failed/pending
  files, as routine experiment cleanup.
- The main app must have a recognizable icon. Every separately installed test app
  must have its own distinct generated icon and clear display name. Hosted unit
  tests use the main app; the separate UI-test runner uses the purple UI icon.
  Use the shared scheme's branding action before installation; if using an already
  built xctestrun product, verify it was branded and normally signed first.

## Keep the implementation small

- Use Swift 6 and SwiftUI. Bridge to UIKit only where an Apple API requires it.
- Prefer Apple frameworks: AVFoundation, WebKit, Core Image, VideoToolbox,
  AuthenticationServices, Security, Foundation, and OSLog as needed.
- Use a normal Xcode project and Swift Package Manager. Do not add a project
  generator, CocoaPods, a cross-platform UI framework, a backend, or an architecture
  framework to solve a problem the app does not have.
- A dependency needs a concrete reason: the native alternative, maintenance and
  security tradeoffs, license, selected version, and transitive footprint. Record
  this before adding it. HaishinKit is the chosen MVP experiment, not yet an installed
  or proven dependency. Google Sign-In and RTMP products are deferred candidates.
- Link only the package products actually used. Commit Package.resolved when the
  app acquires packages. Do not follow a moving branch for release builds.
- Prefer straightforward types and explicit ownership. Avoid speculative protocols,
  generic service layers, global mutable state, and duplicate sources of truth.

## Media and reliability rules

- The iPhone 13 mini on iOS 27 is the minimum performance target. Test on it before
  claiming support for long 1080p30 broadcasts. Newer or Pro phones do not substitute
  for this test.
- Composite the overlay into the actual video frames. Placing a web view above a
  camera preview is insufficient. Preview, network output, and recording must use
  the same composition, without including app buttons or alerts.
- Lay out the web page at the stream's canvas dimensions, independently of screen
  points, safe areas, and display scale. Preserve alpha and aspect ratio.
- Start with about one overlay raster capture per second and reuse the last image
  between captures. Smooth camera video takes priority over overlay update latency.
  Prefer a small in-place update change in the overlay project if full reloads cause
  trouble; do not add animation-rate capture requirements to v1.
- Validate the WebKit capture approach with public APIs on a physical device before
  building the rest of the media pipeline around it. Do not promise OBS-equivalent
  browser-source compatibility or animation performance without measurements.
- Keep the last good overlay frame through brief reloads/errors, then automatically
  hide it after 10 seconds without confirmed source access or a usable render.
  Restore it after source access and a fresh render recover, unless manually hidden.
  An unchanged score is healthy when source access succeeds; re-snapshotting cached
  content does not prove freshness. Apply visibility to preview and all media outputs.
  A browser/network failure must not block capture or local recording.
- Keep capture and media processing off the main thread, except APIs that require
  the main actor, such as WebKit and UI. Use explicit serial ownership or actors for
  state. Never suppress concurrency diagnostics with unchecked annotations without
  a documented, verified ownership argument.
- Use a common media timeline, bounded queues, and measured backpressure. A slow
  uploader must not stop the recorder. Prefer sharing encoded samples where the
  selected library permits it; verify this rather than assuming it.
- Recording continues independently of streaming availability while storage and
  capture/writing remain healthy, including stream-start failure, disconnect,
  reconnect exhaustion, or a remotely ended event. Do not stop the local writer
  merely because streaming fails. If recording fails after going
  live, keep broadcasting, preserve saved footage, and show a persistent warning.
- Handle cancellation, audio/camera interruptions, thermal pressure, backgrounding,
  and file finalization explicitly. Do not promise background or locked-screen
  camera broadcasting in v1.

## Apple interface and platform practices

- Follow the current Apple Human Interface Guidelines and use standard controls,
  system typography, SF Symbols, safe areas, and meaningful accessibility labels.
- Design and inspect the smallest supported screen first. Support Dynamic Type in
  setup screens, VoiceOver, adequate contrast, and status labels that do not rely
  on color alone. Keep important touch targets at least 44 by 44 points.
- Separate the user's local recording state, transport connection, and YouTube
  broadcast state. Never show "Live" just because a socket connected.
- Make the channel, event title, and visibility clear before publishing. Confirm
  the user's intention to end an event. Reconcile remote state before retrying an
  ambiguous state-changing API call.
- Request camera and microphone permissions in context with honest purpose strings.
  Do not request Photos access merely to save in the app's own container or export
  through the Files/share interface.
- Use public APIs for their intended purpose. Do not use private WebKit APIs,
  certificate bypasses, fake background audio, or other App Review workarounds.
- Recheck Apple's current submission requirements, privacy-manifest requirements,
  and SDK rules before a TestFlight upload; a beta is not exempt from them.

## Security, privacy, and license

- Use Google authorization through a supported system-browser flow or SDK. Never
  collect Google passwords or authenticate Google inside the overlay WKWebView.
- Store credentials using Keychain-backed storage. Treat stream keys and overlay
  URLs containing access tokens as secrets. Do not duplicate SDK-managed tokens in
  a second persistence mechanism.
- Keep credentials, signing identities, provisioning profiles, recordings, and private
  tester information out of Git, issue attachments, screenshots, and logs. An OAuth
  client ID is public configuration; it is not a confidential client secret.
- Do not expose native capabilities or Google tokens to overlay JavaScript. Use
  HTTPS and RTMPS with normal certificate validation.
- Do not add analytics, advertising, cloud recording, or crash-reporting SDKs by
  default. Redact OSLog messages and user-exported diagnostics.
- Preserve the BSD-3-Clause license and the notices required by any dependencies.
  The privacy policy and service terms are separate from the source-code license.

## Development and verification

- Explain unfamiliar iOS concepts, why a manual step is needed, what to click or run,
  and how the user can recognize success. Never ask the user to paste secrets into
  chat or put them in a committed configuration file.
- Codex implements the application. Explain architecture and owner-only setup without
  expecting the owner to learn Swift or manually write application code.
- Make small, reviewable changes. Check the working tree before editing; preserve
  unrelated work. Use focused branches after the initial repository setup, and do
  not force-push, rewrite shared history, or delete user recordings as routine cleanup.
- Build and test with Xcode's native tools. Once the project exists, document the
  actual shared scheme and runnable simulator/device commands in the guide. Until
  then, do not invent successful xcodebuild or CI results.
- Add meaningful tests for lifecycle decisions, API parsing, retries, and recording
  behavior. Use deterministic fixtures and unlisted test broadcasts. UI layout and
  media performance need manual inspection on real phones as well as automation.
- Documentation-only changes need link/content checks and git diff --check, not
  artificial app tests. Run checks appropriate to the change and state limitations.
- Prepare a GitHub pull request (the project's MR) from a focused branch into main.
  Describe the resulting behavior, relevant test results, and material limitations.
  Keep changes as simple as possible while preserving required behavior and reliability.
- Before handing off the PR, run an independent review using a separate agent that
  did not author the change. Give it the full diff against main, relevant requirements,
  and validation results; ask it to inspect the actual files, not only the PR summary.
- Focus review on actionable, material issues: correctness, data loss, security/privacy,
  broken builds, media reliability/performance, or important requirement/test gaps.
  Include evidence, affected location, and practical impact. Minor style preferences,
  speculative edge cases without meaningful impact, and unnecessary abstractions
  are not merge blockers and do not require cleanup. No findings is a valid result.
- Resolve material findings before handoff, or explicitly record an agreed deferral
  and its risk. Rerun affected checks after fixes, and request focused re-review when
  the fixes materially change the reviewed behavior; avoid repetitive review loops
  for cosmetic edits. Record the independent review outcome in the PR.
- Report what changed, what passed, and what remains unverified. Do not label a
  milestone complete with an unmet acceptance criterion. A prepared/reviewed PR
  does not itself authorize merging it.
