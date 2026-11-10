# iOS development and TestFlight: a first-project guide

> Owner workflow update (2026-11-06): all new PRs target main and start from
> current main. The temporary codex/full-app integration workflow is superseded.
> Follow the [full-app plan](2026-11-05-full-app-implementation.md) for authorized
> Google/RTMPS development. Issue #6 is closed after TestFlight delivery/owner
> review; retain the documented measurement limits and independently qualify
> later builds. Review and explicit merge authorization remain required.


Checked: 2026-11-05. Read the [application specification](2026-11-01-stream14-design.md)
for product behavior and the [implementation plan](2026-11-01-stream14-implementation.md)
for development order. This guide explains setup; it does not mean those steps have
already been performed.

## Current stage: local MVP first

The current native app records rear-camera video and microphone audio with an
attached transparent webpage overlay through HaishinKit 2.3.0 core and a checked
local MP4 writer. It provides secure URL settings, composed preview, Record/Stop,
playback/original export and confirmed per-recording deletion. See the
[feasibility report](feasibility.md) for actual evidence and remaining qualification.
The owner reviews the result before broadcasting is added.
Codex writes and integrates the app; the owner supplies account/device access and
reviews behavior. Learning Swift or manually writing app code is not a prerequisite.

For this stage, follow Xcode/device setup and the MVP tasks in the implementation
plan. Develop and debug using Xcode, then follow the TestFlight section below to
deliver the MVP to the testing iPhone 13 mini. Installation/use through TestFlight
is required for completion; repeat the final recording/overlay/export checks and
30-minute qualification on that build. Google Cloud, YouTube events, RTMPS, and OAuth
are later-stage setup; none is needed to start a local recording. The overlay URL may
still need internet access. Do not grant extra accounts/permissions or configure an
ingestion key merely to make the library recorder work.

The MVP needs only URL settings, composed preview, Record/Stop, status/duration,
basic playback/export and deliberate deletion. Development experiments are capped
at 15 minutes under the owner’s 2026-11-05 instruction. Longer integrated whole-app
qualification is deferred until the app is ready; review M1–M5 after TestFlight
delivery before expanding into streaming. A three-hour broadcasting
qualification remains a later milestone.

## The essential terms

| Term | What it means for this project |
| --- | --- |
| Xcode | Apple's Mac application for editing, building, debugging, signing, and uploading iOS apps. Command Line Tools alone are insufficient. |
| Swift / SwiftUI | The programming language / Apple's native UI framework. |
| Simulator | A simulated iPhone on the Mac; useful for screens and tests, insufficient for proving this app's camera, heat, or streaming reliability. |
| SDK / deployment target | The APIs available to build against / the oldest iOS version allowed to run the app. We initially target iOS 27.0. |
| Bundle identifier | The app's stable unique identity, usually reverse-domain text. It connects signing, App Store Connect, and Google's iOS OAuth client. |
| Signing / provisioning | Apple's mechanism for identifying the developer and permitting a build to run on devices. Start with Xcode's automatic signing. |
| Scheme / target | A saved build/test configuration / a product such as the app or its tests. The committed shared scheme is Stream14. |
| Archive | A distribution build produced by Xcode, then validated/uploaded through Organizer. |
| App Store Connect | Apple's portal for app records, builds, TestFlight invitations, feedback, and distribution information. |
| TestFlight | Apple's beta distribution service. It does not require publishing the app publicly on the App Store. |
| OAuth | Giving the app permission to act on YouTube through Google, without giving the app your Google password. |
| Broadcast / ingestion stream | The scheduled YouTube event viewers watch / the endpoint and stream key an encoder sends media to. They are different API resources. |

## 1. Install full Xcode

Xcode 27.2 (27B52) is now installed at /Applications/Xcode.app, including the iOS
27.2 SDK and Simulator runtime. The owner selected Xcode as the system developer tools during stage 1;
`xcode-select -p` now points inside Xcode.app. Commands below also set
DEVELOPER_DIR explicitly for a reproducible terminal session. On another Mac,
install a current Xcode release that supports the phone's iOS 27 version and macOS. Check
[Apple's live compatibility table](https://developer.apple.com/xcode/system-requirements)
rather than copying an outdated version requirement.

Install from the Mac App Store or Apple's developer downloads, launch Xcode, and
finish its license/component prompts. Install iOS platform/simulator support when
offered. In Xcode Settings, select the installed Xcode under Locations → Command
Line Tools if needed. Terminal checks should then work:

```sh
xcode-select -p
xcodebuild -version
xcrun simctl list devices available
```

Success means the developer directory points inside Xcode.app and xcodebuild prints
an Xcode version, not a Command Line Tools error. If the UI setting is insufficient
and Xcode is installed at the default location, this optional administrator command
selects it:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Do not run this before that application exists. It changes the Mac's selected
developer tools; installing Xcode does not itself create the stream14 application.

## 2. Prepare Apple access and a real phone

Add your Apple Account in Xcode Settings → Accounts. Free personal signing can be
used for initial device experiments, subject to Apple's personal-team limitations.
An [Apple Developer Program membership](https://developer.apple.com/programs/)
is required for our TestFlight distribution. Review enrollment and payment yourself;
do not share account credentials or signing keys with an agent.

Connect the iPhone 13 mini to the Mac, trust the computer when prompted, and enable
Developer Mode if Xcode/iOS requests it. Select the phone as the run destination.
Use Xcode's normal signing diagnostics rather than downloading random provisioning
profiles or disabling security settings.

The owner confirmed `com.smith3v.stream14` on 2026-11-02; it is now the app target's
bundle identifier. Automatic development signing and a physical install were
verified on 2026-11-04; TestFlight provisioning remains separate. Keep the identifier
identical in Xcode, Apple identifiers,
App Store Connect, and Google's iOS OAuth client. Avoid renaming it casually after
distribution begins.

Open Stream14.xcodeproj. Select the blue project in the navigator, then TARGETS →
Stream14 → Signing & Capabilities. Keep Automatically manage signing enabled and
select your own Team. No team is fabricated or committed by this stage. Select the
connected 13 mini in the toolbar and press Run (▶ or ⌘R). Success is the stream14
screen with “App setup ready” and an explanation that recording is not available.
Check it in portrait and both landscape orientations. If signing fails, use the
displayed Xcode diagnostic; share only error text, never credentials or keys.

macOS may ask for your Mac login password to let codesign use the Apple Development
key. Handle that prompt in the system dialog. On the testing phone, the first
installation also required Settings → General → VPN & Device Management → Developer
App → the owner's development account → Trust. This was verified on 2026-11-04;
trust only the expected developer entry for your own build. Keep the phone connected
and unlocked through installation and launch.

Selecting a team may edit project.pbxproj. Keep personal signing changes local;
inspect the diff before committing. For terminal builds, pass DEVELOPMENT_TEAM as
a local build-setting override instead of saving it in the shared project. The
test targets also need your team if running tests on a physical phone.

The original stage-1 build requested no media permissions. The stage-2 experiment
now requests camera and microphone when you explicitly open it, with local-recording
purpose strings. It does not request Photos access. Simulator success does not
qualify real camera capture or sustained performance.

See [Apple's developer-account guidance](https://developer.apple.com/help/account/basics/about-your-developer-account)
for personal-team restrictions and membership capabilities.

## 3. Prepare Google and YouTube

These steps are needed for YouTube integration, not for the initial local capture
experiment.

1. Make sure the intended YouTube channel is allowed to broadcast and has live
   streaming enabled. In YouTube Studio, create an **encoder** event for testing,
   preferably unlisted, using its existing/default stream key with auto-stop disabled.
2. Create/select a Google Cloud project owned by you and enable YouTube Data API v3.
3. Configure the Google Auth Platform/OAuth consent screen with the real app name,
   support contact, and the scope specified in the app specification. For the small
   early beta, use the external Testing audience and explicitly add each Google
   account that will test.
4. Create an OAuth client of type **iOS**, using the final bundle identifier and
   requested Apple team information. Follow [Google's iOS setup guide](https://developers.google.com/identity/sign-in/ios/start-integrating).
5. At the authorization implementation milestone, add only the selected Google
   Sign-In products through Swift Package Manager and configure the iOS client ID
   and reversed-client-ID callback scheme. Do not add Firebase or a web-server client
   secret to this native-only app.
6. Verify the returned YouTube channel identity in the app before selecting a test
   event. A Google email address, Brand Account channel, and delegated Studio role
   are not interchangeable identities.

Google OAuth test users and TestFlight testers are separate lists. An invitation to
one does not add the person to the other. In Google's external Testing state,
refresh tokens for the YouTube scopes normally expire after seven days, so expect
reauthorization during the early beta. Before expanding the audience, check Google's
current OAuth verification and publishing requirements. See [Google's OAuth token
rules](https://developers.google.com/identity/protocols/oauth2).

Client IDs and bundle IDs are configuration rather than confidential client secrets.
User tokens and stream keys are secrets. Never put those secrets in Git or share
them in screenshots. Use Keychain-backed runtime storage; use ignored local
configuration for development-only values when needed.

Owner update (2026-11-07): routine connected-phone validation targets five minutes TOTAL. Build/fixtures/Simulator checks run on the laptop beforehand; select a smoke path instead of the full backlog. Historical longer examples below do not authorize automatic extended runs.

The [connected-iPhone test session plan](2026-11-07-connected-iphone-test-plan.md) consolidates the pending physical checks, exact existing opt-in commands, later-stage gates and per-run evidence sheet for one coordinated laptop/phone session. Run capture tests sequentially; long qualification remains separately agreed.

## 4. How we will build and test

The root-level Stream14.xcodeproj is an ordinary SwiftUI/Swift 6 project with no
project generator. Stage 2 pins HaishinKit 2.3.0 core and its Logboard runtime
dependency. Its original stage-1 foundation contains:

- Stream14/App/Stream14App.swift: application entry point.
- Stream14/App/SetupView.swift: native scrollable setup screen.
- Stream14Tests/AppConfigurationTests.swift: hosted Swift Testing checks of the
  built app's identity, deployment target, device family, and supported orientations.
- Stream14UITests/SetupScreenTests.swift: launch/status checks, landscape at the
  largest accessibility text size, screenshots, and system accessibility audits.
- Stream14.xcodeproj/xcshareddata/xcschemes/Stream14.xcscheme: shared build/test/run/archive scheme.

Run these commands from the repository root. The export applies to this terminal
session only. Confirm the scheme and available destinations:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -list -project Stream14.xcodeproj
xcodebuild -showdestinations -project Stream14.xcodeproj -scheme Stream14
```

Build Release against the iPhone SDK without provisioning/signing:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/stream14-issue2-device CODE_SIGNING_ALLOWED=NO build
```

The installed iOS 27.2 runtime includes an iPhone 13 mini device type. A dedicated
simulator named Stream14 iPhone 13 mini was created for the smallest-screen checks.
On another Mac with this runtime, create it once if absent:

```sh
xcrun simctl create 'Stream14 iPhone 13 mini' \
  com.apple.CoreSimulator.SimDeviceType.iPhone-13-mini \
  com.apple.CoreSimulator.SimRuntime.iOS-27-2
```

Run the hosted and UI tests on it:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /tmp/stream14-issue2-simulator \
  -resultBundlePath /tmp/stream14-issue2-verified-layout-2.xcresult test
```

Result bundle paths must be new for each run; choose a new filename when repeating
tests rather than deleting evidence. CI is not configured. Build logs and xcresult
bundles are local artifacts, not repository content.

### Stage 1 verification record: 2026-11-02

- Toolchain: Xcode 27.2 (27B52), Swift 6 language mode, iOS SDK/Simulator 27.2.
- App: com.smith3v.stream14, version 0.1, build 1, iPhone only, minimum iOS 27.0.
  Owner confirmed the bundle identifier in chat; no Apple team value is committed.
- `xcodebuild -list` finds Stream14, Stream14Tests, Stream14UITests and the shared
  Stream14 scheme. `-showdestinations` finds the installed iOS 27.2 simulators.
- The unsigned generic-iOS Release build above passed. Local log:
  /tmp/stream14-issue2-device-build.log. This is compilation, not a signed install.
- All four tests passed on Stream14 iPhone 13 mini / iOS 27.2 Simulator: two
  hosted Swift Testing checks and two UI tests with full accessibility audits.
  Largest accessibility text in landscape and default text in portrait passed.
  Final log: /tmp/stream14-issue2-verified-layout-2-test.log; result bundle:
  /tmp/stream14-issue2-verified-layout-2.xcresult. UI screenshots are kept in that bundle.
  Earlier runs exposed status-label clipping and section-header contrast issues;
  the final view uses wrapping headline text and an explicit adaptive system text
  color. An initial iPhone 17 automation launch failed and was interrupted; that
  run is not counted as a pass.
- Physical iPhone 13 mini: connected by USB, iOS 27.2, Developer Mode enabled.
  Automatic signing registered the device and generated a development profile.
  The owner ended the session and disconnected the phone before signing completed;
  the waiting build/codesign operation was canceled. Installation/launch was
  pending at the end of that session. It was completed on 2026-11-04 in the physical
  setup verification below. Local canceled-build log:
  /tmp/stream14-issue2-signed-device-build.log (contains private signing/device
  details; never attach it publicly). No media gate or TestFlight upload passed.
- No packages, camera/microphone permission strings, networking, entitlements,
  credentials, recordings, or signing profiles are added. User-local Xcode state,
  build/test results, signing material, and captured media remain ignored.
- Independent review: a separate agent inspected the full diff and actual project,
  scheme, app, tests, docs, and ignore rules; no material code/project/privacy
  findings. Focused review caught the unresolved contrast audit; explicit
  Color.primary fixed it and all four native tests then passed. Physical launch
  was still pending at that review and was completed in the resumed check below.
- Next stage, after this stage's PR merges and device acceptance: Task 3,
  HaishinKit feasibility. Re-run the scheme/destination and build/test commands above
  before selecting a stable package; do not implement recording APIs from guesses.
  TestFlight still needs owner membership/agreements, app registration, signing,
  metadata/privacy review, and the later local-media implementation and M1–M5 checks.

### Physical setup verification: 2026-11-04

- Same application source as commit `436c041` (subsequent commits only update docs).
  Xcode 27.2 (27B52), iOS SDK 27.2, Swift 6 language mode. Signed Debug app
  com.smith3v.stream14, version 0.1, build 1; deployment target iOS 27.0.
- Physical iPhone 13 mini, iOS 27.2 (24B119), connected by USB with Developer Mode
  enabled. Signed build passed after the owner allowed the normal macOS Keychain
  prompt. `codesign --verify --deep --strict` passed. The embedded profile is
  unexpired, includes this phone, and matches the signed app's application identifier.
- `devicectl device install app` succeeded. The first launch was refused until the
  owner trusted their development certificate on the phone. The owner then saw
  “App setup ready”; a repeated `devicectl device process launch` returned success
  and a running process identifier. The owner confirmed readable setup content in
  portrait, landscape left, and landscape right, with scrolling available if needed.
- No application code changed during the resumed check. The four Simulator tests
  and unsigned Release results above remain evidence for this same code; native
  tests were not rerun on the physical phone. The device run establishes native
  setup only: no camera, microphone, overlay, recording, performance, or TestFlight
  capability has been tested or added.
- Private local evidence: /tmp/stream14-issue2-20261104-signed-build.log,
  /tmp/stream14-issue2-20261104-install.json, and
  /tmp/stream14-issue2-20261104-launch-trusted.json. These include signing/device
  details and remain outside Git and public PR attachments. The owner's local
  DEVELOPMENT_TEAM selections are preserved only in the working project.
- Independent closeout review inspected the full branch diff, actual files, and
  private build/install/launch evidence, and independently checked the signature
  and profile. No material findings. No new app tests were needed for this
  documentation-only closeout.

The verified physical commands below use the connected phone's identifier, selected
privately from `xcrun devicectl list devices`; set STREAM14_DEVICE_ID locally to that
value. No real device identifier or team value belongs in this guide. The build
uses the owner's local Xcode signing selection described above.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun devicectl list devices
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination "id=$STREAM14_DEVICE_ID" \
  -derivedDataPath /tmp/stream14-issue2-signed \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
codesign --verify --deep --strict \
  /tmp/stream14-issue2-signed/Build/Products/Debug-iphoneos/Stream14.app
xcrun devicectl device install app --device "$STREAM14_DEVICE_ID" \
  /tmp/stream14-issue2-signed/Build/Products/Debug-iphoneos/Stream14.app
xcrun devicectl device process launch --device "$STREAM14_DEVICE_ID" \
  com.smith3v.stream14
```

Task 2 / issue #2 acceptance is met and PR #7 merged on 2026-11-04. Task 3's
HaishinKit experiment and commands are described next. Apple Developer
Program membership/agreements, App Store Connect setup, distribution signing,
privacy/metadata review, media implementation, and M1–M5/TestFlight qualification
remain later work. Development signing does not establish those prerequisites.

### Stage 2: local media experiment, 2026-11-04

Files: `Stream14/Media/MediaExperiment.swift` orchestrates explicit permissions,
capture, recording and interruption finalization; `SyntheticOverlay.swift` owns
one reusable ScreenActor image layer; `ExperimentSample.swift` persists sample
status alongside original MP4 files in backup-excluded Application Support.
`SetupView` offers composed preview, Record/Stop, native playback, original-file
share and bundled third-party notices. It shows inspection status, not a claim
that the native writer has completed production qualification.

Verified commands (result bundle paths must be new on a repeat):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -resolvePackageDependencies -project Stream14.xcodeproj -scheme Stream14 \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -derivedDataPath /tmp/stream14-issue3-device CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -derivedDataPath /tmp/stream14-issue3-simulator \
  -resultBundlePath /tmp/stream14-issue3-tests-2.xcresult test
```

On 2026-11-04 the unsigned Release build passed, followed by six hosted Swift
Testing tests and two XCTest UI tests. The tests verify configuration, idle launch,
retention of pending/failed sample manifests and media, non-accumulating image
layers, full-canvas alpha and image changes, portrait/maximum-text landscape
layout, and full accessibility audits. An initial portrait audit exposed a button
contrast issue; adaptive primary tint fixed it. Inspected test screenshots.

Signed Debug build, signature verification, development installation and devicectl
launch succeeded on the connected iPhone 13 mini, iOS 27.2. The owner allowed the
normal macOS Keychain prompt. Launch used devicectl without attaching a debugger;
upstream documents a possible recorder freeze under an Xcode debugger. These are
local development results, not TestFlight delivery. The owner then recorded a
53.53-second sample and confirmed correct playback/sound and changing counter.
Private file inspection confirms H.264 1920×1080, AAC stereo 44.1 kHz, actual
alpha composition and layer replacement. M1 is demonstrated; no M2–M5 or measured
acoustic-sync/performance claim follows. See the feasibility report for frame timing.
Keep personal team selection
local or use a `DEVELOPMENT_TEAM` command-line override for signing.

Device procedure: open **Open camera experiment**, allow camera/microphone access,
hold the rear camera upright in landscape, then **Record sample**. Capture a visible
clap and about 15–20 seconds of a moving scene. Confirm the synthetic alpha panel
and changing counter in preview. Stop and **Play sample**; check sound/clap alignment,
orientation, visible alpha and counter changes with no app controls. **Export original
sample** shares the MP4 without conversion. Close/reopen the camera and repeat;
backgrounding/interruption must stop it without automatically resuming. This is
stage-2 evidence, not the stage-5 full failure/performance matrix.

Private logs/results: `/tmp/stream14-issue3-release-build-2.log`,
`/tmp/stream14-issue3-tests-2.xcresult`, `/tmp/stream14-issue3-signed-build-2.log`,
`/tmp/stream14-issue3-install.log`. Device/signing details and raw recordings stay
outside Git and public PRs. Copy sample evidence privately with the device
identifier selected locally as in the physical setup section:

```sh
xcrun devicectl device copy from --device "$STREAM14_DEVICE_ID" \
  --source 'Library/Application Support/MediaExperiments' \
  --domain-type appDataContainer --domain-identifier com.smith3v.stream14 \
  --destination /tmp/stream14-issue3-private-samples
```

See [feasibility.md](feasibility.md) for actual sample
measurements, exact API boundary, remaining writer limitations and next-agent handoff.

Use unit tests for state/API behavior, UI tests and manual inspection for screens,
and physical phones for real video/audio, transparent browser capture, network
recovery, heat, and long recordings. Test broadcasts should be unlisted and identified
clearly as tests. Do not experiment on a real scheduled public event.

## 5. TestFlight, step by step

Issue #6 now has a [concrete delivery record](testflight-delivery.md) with owner
setup, prepared beta text, privacy/support sources, packaging checks and pending
acceptance. Paid membership, signed upload, internal TestFlight availability and
owner recording/export review are now verified. The 35 min 26.410 s original-file
checks and unmeasured formal sync/memory/queue criteria are recorded in
[feasibility](feasibility.md#owner-testflight-recording-and-review-2026-11-05).
Archive/upload need no connected phone; additional device work waits for owner
availability and a separate agreed run.
The [focused plan](2026-11-05-testflight-implementation.md) separates these stages.


1. Enroll in the Apple Developer Program and complete required account agreements.
   Register the chosen bundle identifier and create the app record in App Store
   Connect. These are owner/team setup actions, not part of the current docs change.
2. Configure automatic distribution signing, app version and a unique increasing
   build number, app icon, permissions, and the release configuration. Verify that
   release builds contain no development credentials or debug recording paths.
3. Inspect the app and selected SDKs for required privacy manifests, required-reason
   API declarations, data disclosures, and licensing notices. Do not assume "we have
   no backend" means there are no third-party data flows.
4. Prepare public privacy/support/terms pages and the accurate App Store Connect
   privacy and age-rating information required for the current submission flow.
   Answer export-compliance questions based on the actual app and SDKs; using TLS
   does not justify guessing the answer or including an exemption blindly.
5. In Xcode, select a distribution device destination, Product → Archive, then use
   Organizer to validate and upload to App Store Connect. Wait for processing and
   resolve any reported issues.
6. Add the build to a TestFlight group. Start with the owner. Internal testers need
   suitable App Store Connect access; ordinary friends/testers should use an
   external group rather than being granted development-team roles just to install.
7. For external testing, provide beta description, feedback contact, review notes,
   and clear steps for the reviewer. Explain camera/microphone use, local recording,
   and a reproducible overlay/demo. The MVP needs no Google/YouTube login; add those
   review instructions only when streaming is implemented. Arrange review access
   through Apple's designated review-information fields, never in this public repo.
   The first external build needs beta review; later builds can also require review.
8. Invite the testers, verify installation on a real phone, and collect feedback.
   Use a small private email group initially; a public invitation link is unnecessary.

A TestFlight build is usable for up to 90 days. Upload replacement builds during
ongoing testing; TestFlight is not a permanent production-install mechanism. App
Review rules still matter for beta distribution. Consult [Apple's TestFlight
overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
before each distribution milestone.

## 6. Apple interface and review basics

Use [Apple's Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
for navigation, typography, accessibility, color, and controls, and the [App Review
Guidelines](https://developer.apple.com/app-store/review/guidelines/) for permitted
behavior. In this app, the immediate requirements are honest permission prompts,
visible recording status, explicit publishing intent, public APIs, and correct
handling when camera capture is interrupted.

Connecting YouTube is access to a specific third-party service; it does not create
a separate stream14 account. Review guideline 4.8 contains a relevant exception for
third-party service clients. Do not add an unrelated account system or Sign in with
Apple automatically; reassess if the app's authentication purpose changes. Apple's
review decision cannot be guaranteed in advance.

The first release keeps the app open while broadcasting. Do not advertise
locked-screen or background video capture, misuse background audio, or use private
WebKit functions to make the overlay experiment pass.

## 7. GitHub and project hygiene

The agreed destination is the public repository smith3v/stream14, on main, under
BSD-3-Clause. Use focused branches and reviewed changes after the initial commit.
Track small technical decisions and qualification evidence in the project docs.
Do not add large process templates or release infrastructure before they are useful.

For each focused change, run checks appropriate to its impact, prepare a GitHub pull
request (PR, equivalent to an MR), and have a separate agent independently review
the full diff against main. Code changes need relevant native build/tests and device
evidence where applicable; docs-only changes need content/link and whitespace checks.
Record the results and limitations in the PR. Review should identify material bugs,
data-loss/security risks, reliability failures, and important requirement/test gaps.
Fix those issues, not every minor style preference or theoretical concern. Preserve
necessary safeguards while keeping implementation and process small. A no-findings
review is valid, and preparing/reviewing a PR does not mean it has been merged.

GitHub CLI access should identify the intended owner, smith3v. Check authentication
with normal permitted network/credential access before concluding that a credential
is invalid; a restricted sandbox can prevent a valid check. If reauthentication is
needed, the owner can run:

```sh
gh auth login --hostname github.com --web
gh auth status --active
```

Authenticate through the normal GitHub browser flow; never paste a token into chat.
No agent should print authentication tokens, replace a credential file manually,
or publish a different repository/visibility as a workaround.

After authentication and a reviewed local initial commit, the intended creation
command is:

```sh
gh repo create smith3v/stream14 --public --source=. --remote=origin --push
```

Run it only from the repository root and only if that exact destination does not
already exist. If the name exists, inspect ownership and contents before doing
anything; do not overwrite or force-push. Verify the resulting visibility, license,
default branch, and local/remote commit match. Update this guide with the actual
result rather than leaving an intended action described as completed.

### Initialization record: 2026-11-01

- Created [smith3v/stream14](https://github.com/smith3v/stream14) as a public repository
  with default branch main. GitHub recognizes LICENSE as BSD-3-Clause.
- Initial commit: `33426485fd299c0ee3bbac867989deb8e045781e`. Verified that the remote
  main branch matched it immediately after publication. Later documentation commits
  naturally advance both branches.
- Added the seven intended files: AGENTS.md, README.md, LICENSE, .gitignore, the
  application specification, implementation plan, and this guide. Validated local
  Markdown links, reference labels, code fences, requirements R1–R10, acceptance gates
  A1–A9, ignored secret/media/build paths, and git diff --check.
- Used the owner's GitHub noreply address for the initial commit. No credentials,
  signing material, recordings, external packages, or application code were added.
- Full Xcode was not installed and app compilation/device tests were not run.
  Apple team enrollment, bundle registration, Google OAuth setup, media feasibility,
  and TestFlight distribution remain future work.

### Stage 3 WebKit renderer verification: 2026-11-04

Open the app's **Overlay** toolbar button. Enter an HTTPS URL (or choose **Use
reference URL**, then **Load overlay**). Nothing is fetched merely by opening the
sheet. The attached browser is the source surface; the separate retained raster
below is the renderer output and obeys automatic/manual hiding. This screen does
not start camera/microphone capture. URL values remain in memory and are not
included in diagnostics. Existing camera recordings still use the synthetic layer.

`WebOverlayRenderer.image`, `.visible`, `.healthy` and `.health` on MainActor are
the next-stage handoff. Copy an immutable CGImage to the retained ScreenActor image
object and honor visibility for the common camera preview/writer composition.
Keep the source WKWebView attached/rendered; never replace it with a hidden or
detached view based only on Simulator evidence. See [feasibility](feasibility.md#stage-3-webkit-renderer-issue-4-2026-11-04)
for source freshness versus in-place backend health, readiness, retry and ownership.

From the repository root, using installed Xcode 27.2 / SDK 27.2:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/stream14-issue4-device \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build

xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /tmp/stream14-issue4-simulator \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution \
  -resultBundlePath /tmp/stream14-issue4-simulator-new.xcresult test
```

The live reference test is disabled by default to keep normal tests deterministic.
To run it and the fixture/health tests on the physical phone, first list devices
with `xcrun devicectl list devices`, unlock the testing 13 mini, then use local
shell variables DEVICE_ID and APPLE_TEAM with your own device/team values. They
are not repository configuration and must not contain passwords or signing keys:

```sh
TEST_RUNNER_STREAM14_REFERENCE_TEST=1 xcodebuild \
  -project Stream14.xcodeproj -scheme Stream14 \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath /tmp/stream14-issue4-physical \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  -resultBundlePath /tmp/stream14-issue4-device-new.xcresult \
  -only-testing:Stream14Tests DEVELOPMENT_TEAM="$APPLE_TEAM" test
```

The environment prefix is Xcode's mechanism for passing a variable into its test
runner. The external test must appear as **passed**, not skipped, for reference
page evidence. Automatic provisioning may register development test-target profiles
using your configured Xcode account. A locked phone causes Xcode to wait for unlock.
On another Mac, resolve the committed package pins first or omit the local package
cache option; do not replace the pins with a moving branch.

Physical renderer tests passed on iPhone 13 mini / iOS 27.2, signed Debug 0.1/build 1:
12 hosted Swift Testing tests including the opt-in reference test. Final fixture capture
elapsed latency was 445.5ms (an earlier passing run measured 43.7ms); sampled
reference latency was 22.6–44.4ms. These variable startup/elapsed costs are not CPU
time or evidence that camera performance remains unaffected. The reference
remained visible through eight source confirmations over a 15-second observation.
Both PNGs were copied from **only** the test-generated temporary files and visually
inspected: 1920×1080, desktop layout, alpha, logo/text edges and opposite-corner
placement. Final device logs/result bundle: `/tmp/stream14-issue4-physical-complete.log`
and `/tmp/stream14-issue4-physical-complete.xcresult`. PNG evidence:
`/tmp/stream14-issue4-evidence/final-fixture.png` and `final-reference.png`. These are generated
renderer fixtures, not camera recordings. Keep raw device/signing logs private.

Earlier validation exposed an initial watchdog race (fixed before the passing
physical run) and an unsupported WKNavigation constructor in a regression test
(replaced by a real, superseded public load handle). Those failed result bundles
are retained locally and are not counted as passing evidence. The first physical
attempt also required enabling normal automatic development provisioning for the
test targets; no signing setting/profile is committed.

The independent review found superseded navigation failures invalidating the new
load, missing initial-failure status, and missing explicit download rejection.
All were corrected and independently re-reviewed. A further review caught the
risk of WebKit detachment inside reusable Form rows; the source now lives in a
stable visible sibling above the Form. Final focused review found no remaining
material issues.

Final unsigned iOS Release build passed (`/tmp/stream14-issue4-release-verified.log`).
Final Simulator suite passed 14 tests with one intentional opt-in reference skip:
11 deterministic hosted tests plus three UI tests, all UI accessibility audits
passed (portrait and maximum Dynamic Type landscape, including overlay settings).
Results: `/tmp/stream14-issue4-complete.log` and
`/tmp/stream14-issue4-complete.xcresult`; inspected exported screenshots under
`/tmp/stream14-issue4-complete-attachments/`. Earlier UI tests exposed an unreachable
entry/field, a textual toolbar Dynamic Type issue, and controls overlapping a
translucent inset. Standard toolbar entry, source-first Form, labeled 44pt close
icon, and stable opaque sibling hosting resolve them. One later device rerun
stalled awaiting WebKit snapshots; the final clean run passes with the test harness
disabling/restoring automatic display sleep. This does not prove why that earlier
run stalled. At that stage the production sheet stopped when backgrounded and required explicit
Load. Issue #38 supersedes this with foreground overlay recovery; see below.
Markdown local links/fences and `git diff --check` passed. No personal signing
settings, raw device diagnostics or camera recordings are committed. M2 saved
web-overlay composition, camera performance under WebKit load, two-minute combined
media outage, M3–M5 and TestFlight remain stage #5/#6 work. A short renderer test
does not qualify a long recording or broadcasting.

### Stage 4 integrated recording checks

Use **Overlay**, enter an HTTPS URL (or **Use reference URL**), then **Apply URL**
and close the settings sheet. Applying stores the complete URL in device-only
Keychain and begins foreground network access. Applying an empty URL explicitly
disables it. Since issue #38, opening/returning to the app automatically loads a
saved valid URL; typing and dismissing unapplied edits leave it unchanged. **Open camera** requests camera/microphone
permission and starts the composed preview. Keep the phone landscape with the rear
camera upright, then **Record** / **Stop recording**. The timer/status are native
UI, excluded from output. Manual hiding changes both preview and file composition.
The separate source-browser strip is removed by issue #34. Its WebKit host remains
attached behind the opaque scrolling screen for snapshots, without reserving space.
Inspect the overlay in the composed camera preview; the status and manual-hide
control remain in the main screen and URL setup remains under **Overlay**.

Finished/retained samples are listed with actual status. Play them using the system
player, or **Export original file** through Files/share. No conversion or Photos
access is involved. Files stay in backup-excluded Application Support; deleting the
app removes them. Export important footage first. Pending/failed files may not be
playable; they are retained and never automatically marked complete. Backgrounding,
camera/audio interruption and critical heat stop capture and require an explicit
restart. Serious heat shows a warning and reduces overlay snapshots to three seconds.

The following use the installed Xcode 27.2 and shared Stream14 scheme. Keep package
pins unchanged. Commands use the existing local cache; another Mac should resolve
the committed packages first. Use a new result-bundle path on every rerun.

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/stream14-issue5-device \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build

xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /tmp/stream14-issue5-simulator \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution \
  -resultBundlePath /tmp/stream14-issue5-tests-new.xcresult test
```

Hosted generated-media tests write real H.264/AAC files from synthetic raw buffers,
repeat start/stop and check actual audio/video tracks. They inject initialization,
append and finalization failures; a missing directory additionally exercises a
real writer-start filesystem error. Empty sessions never complete. Temporary test
fixtures are removed; user recordings are never deleted. Default tests skip live
service and camera recording checks.

For the authorized physical recording check, use the local `DEVICE_ID` and
`APPLE_TEAM` values as in stage 3. Leave the phone unlocked, landscape and aimed
at a scene suitable for a private recording. The opt-in test records camera/mic;
do not enable it on an unprepared device. Select only this suite, so another
renderer test cannot replace its key UIWindow. During runs of at least 180 seconds, the test blocks WebKit document requests
using a public WKContentRuleList from second 30 through 150, then removes the rule
and reloads. This injects a two-minute source-request failure without changing
radios or certificate validation. It checks hidden output before recovery and
restored output afterwards. This is distinct from a real device-network outage.
After the long reference sample, it records a changing HTML fixture, repeats recording and injects a capture-runtime
error to check failed status/explicit restart. This is an automated development
harness; also exercise the actual app's controls and real interruptions manually.

```sh
TEST_RUNNER_STREAM14_DEVICE_RECORDING=1 \
TEST_RUNNER_STREAM14_RECORDING_SECONDS=900 xcodebuild \
  -project Stream14.xcodeproj -scheme Stream14 \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath /tmp/stream14-issue5-physical \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  -only-testing:Stream14Tests/MediaDeviceTests \
  -resultBundlePath /tmp/stream14-issue5-physical-new.xcresult \
  DEVELOPMENT_TEAM="$APPLE_TEAM" test
```

`TEST_RUNNER_` passes values into the test runner. Seconds defaults to 30 if omitted.
The test writes UUID MP4/JSON plus observations every ten seconds under the app's
`Library/Application Support/MediaExperiments`. Observations contain writer metrics,
resident-memory bytes, thermal enum, visibility and elapsed snapshot time, never
URLs. Record a clap with hands visible at start/end to measure actual A/V alignment.
Do not substitute track timestamp endpoints for physical sync. During a real outage
check, disable both phone Wi-Fi and cellular for two minutes without backgrounding
capture, then restore them. Check last-good grace, automatic hide/recovery and local
A/V continuity in the original saved file. Also exercise brief outage, healthy
unchanged score and manual hiding through recovery. Avoid filling the phone to
check write failure; use the explicit injected fault tests.

Copy only finalized test files with `xcrun devicectl device copy from`,
`--domain-type appDataContainer --domain-identifier com.smith3v.stream14`, and source
`Library/Application Support/MediaExperiments/<UUID>.mp4` (and its JSON/observations).
Use a private directory outside Git. Do not copy a whole directory while a large
recording is being written: its changing content can break the transfer. Leave
files on the phone; no removal flag is needed. Inspect original codec/dimensions,
sorted frame timestamps, marker sync, alpha/edges, changing fixture, outage and
absence of app controls with native AVFoundation tools/player.

Current private short-sample evidence: `/tmp/stream14-issue5-short-original.mp4`,
`/tmp/stream14-issue5-short-inspection.txt` and sibling extracted PNGs. Passing
isolated device result: `/tmp/stream14-issue5-physical-insets.xcresult` / `.log`.
Passing final hosted result: `/tmp/stream14-issue5-hosted-final.xcresult` / `.log`.
Passing default Simulator result: `/tmp/stream14-issue5-tests4.xcresult` / `.log`.
Earlier failures are retained locally and not counted as passing: initial test
fixture redeclaration, lazy writer-start expectation, textual close-button Dynamic
Type audit, missing test-team configuration and landscape safe-area viewport.
See [feasibility](feasibility.md#stage-4-integrated-local-recording-issue-5) for
remaining acceptance and measurement limits. TestFlight remains issue #6.

Additional opt-in failure checks (use fresh result paths and the same local signing
variables; these create private short camera/microphone files):

```sh
TEST_RUNNER_STREAM14_DEVICE_FAILURES=1 xcodebuild \
  -project Stream14.xcodeproj -scheme Stream14 \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath /tmp/stream14-issue5-physical \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  -only-testing:Stream14Tests/MediaDeviceTests \
  -resultBundlePath /tmp/stream14-issue5-failures-new.xcresult \
  DEVELOPMENT_TEAM="$APPLE_TEAM" test
```

This uses the concrete recorder's internal fault injection, never actual device
exhaustion. It checks failed durable state, explicit camera restart, restored screen
sleep, and finalization of an established new recording after an explicit interruption. It does not simulate a
real incoming phone call or change permissions on the physical phone.

The denied-camera UI check uses only the booted test Simulator. Set `SIMULATOR_ID`
from `xcrun simctl list devices booted`; revoke/reset is test setup, not an app API.
Always run the reset even if the test fails:

```sh
xcrun simctl privacy "$SIMULATOR_ID" revoke camera com.smith3v.stream14
TEST_RUNNER_STREAM14_DENIED_PERMISSION_TEST=1 xcodebuild \
  -project Stream14.xcodeproj -scheme Stream14 \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath /tmp/stream14-issue5-simulator \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution \
  -only-testing:Stream14UITests/SetupScreenTests/testDeniedCameraShowsSettingsGuidance \
  -resultBundlePath /tmp/stream14-issue5-denied-new.xcresult test
xcrun simctl privacy "$SIMULATOR_ID" reset camera com.smith3v.stream14
```

Denied-permission check passed at `/tmp/stream14-issue5-denied-permission.xcresult`
/ `.log`. Final default suite passed at `/tmp/stream14-issue5-suite-final.xcresult`
/ `.log`: 14 active hosted tests, three active UI tests and four intentional opt-in
skips (live reference, device recording, device fault check, denied-permission UI).
Passing screenshots from the earlier complete suite were exported under
`/tmp/stream14-issue5-final-ui-attachments/` and inspected for portrait, maximum
Dynamic Type landscape and URL settings. A subsequent footer copy change clarifies
“no media upload”; it does not claim the HTTPS overlay operates without a server.

Corrected visibility and final device evidence:

- `/tmp/stream14-issue5-physical-corrected.xcresult` / `.log`: all three selected
  physical tests passed, including five-minute request outage with saved-frame
  inspection, writer-failure/interruption handling and actual NV12 hide/restore.
- `/tmp/stream14-issue5-fixed-suite.xcresult` / `.log`: 15 active hosted tests and
  three UI/accessibility tests passed, with opt-in checks skipped.
- `/tmp/stream14-issue5-fixed-release.log`: unsigned iOS Release passed after the
  visibility correction. The playback state correction is additionally checked in
  `/tmp/stream14-issue5-final-playback-release.log`.
- `/tmp/stream14-issue5-device-ui-fixed.xcresult` / `.log`: actual physical
  background/return and playback presentation passed. An earlier empty first
  playback sheet was fixed using item-backed presentation. The test checks the
  original export control, not a completed Files save or subjective sync.

To reproduce both writer-failure and five-minute corrected media checks, set both
`TEST_RUNNER_STREAM14_DEVICE_FAILURES=1` and
`TEST_RUNNER_STREAM14_DEVICE_RECORDING=1`, with
`TEST_RUNNER_STREAM14_RECORDING_SECONDS=300`, using the physical command above.
Add `-only-testing:Stream14Tests/WebOverlayCompositionTests` to include the public
mixer's actual rendered-pixel regression. The observation JSON now records resident
bytes **and** charged physical footprint. Do not infer a leak solely from resident
memory; the full report distinguishes reclamation cycles and measurement limits.

The actual-app Home/playback UI test records a short private clip. Run only after
other capture tests finish, with the phone unlocked:

```sh
TEST_RUNNER_STREAM14_DEVICE_UI=1 xcodebuild \
  -project Stream14.xcodeproj -scheme Stream14 \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath /tmp/stream14-issue5-device-ui \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  -only-testing:Stream14UITests/SetupScreenTests/testDeviceBackgroundFinalizesAndPlaybackOpens \
  -resultBundlePath /tmp/stream14-issue5-device-ui-new.xcresult \
  DEVELOPMENT_TEAM="$APPLE_TEAM" test
```

For owner review, load the reference or own HTTPS overlay explicitly, record a
short clip, and make a sharp clap with both hands fully inside the center of the
rear-camera image (not cropped at an edge). Stop, play and export the original to
Files. Record the actual review outcome separately; neither a test runner's pass
nor opening a player proves perceived sync or a successful Files export. Full M3
qualification still needs the TestFlight build and fresh start/end sync markers.


Owner short-flow review was completed on 2026-11-04: playback, original save to
Files and subjective camera/overlay/audio appearance were confirmed. Private
reviewed clip/sidecar and timestamped clap analysis are under
`/tmp/stream14-issue5-owner-review/`. Estimated short-sample video delay is about
40–70 ms with one-frame visual uncertainty. This does not replace full-length
start/end physical sync or TestFlight qualification. See feasibility for the
remaining evidence rather than treating every issue #5 acceptance box as passed.


### Owner update: deletion, shorter experiments and icons (2026-11-05)

On the saved recording's row, choose **Delete recording**, check its date in the
confirmation, then choose **Delete recording** or **Cancel**. Confirmed deletion
removes only that UUID's original video, status and test-observation sidecars from
the app. Exported copies stay in Files. The action is unavailable while recording,
preparing or finalizing. Pending/failed files can also be deleted deliberately.
If removal fails partway, remaining metadata stays listed so the action can be
retried; no directory is recursively removed. No automatic cleanup has run on the
owner's phone.

Development recording experiments now hard-cap requested durations at 900 seconds.
Thirty-second smoke checks remain available. Actual recording through the app's
Record/Stop button has no artificial fifteen-minute limit. Longer integrated-app
qualification is deliberately deferred, not passed by a shorter run. The latest
old 30-minute attempt was interrupted around 25 minutes when the assistant session
ran out of tokens, as the owner clarified on 2026-11-05. It is incomplete validation,
not a confirmed application reliability failure.
No further long experiment should be started now. Test observations are checkpointed
atomically every minute so an unexpected exit loses less diagnostic evidence.

stream14 uses the teal camera/14 home-screen icon. The separate UI-test app is
named **s14 UI Tests** and uses a purple flask/UI icon; hosted unit tests use the
main app. The shared scheme's build post-action brands and normally signs the
built test wrapper before installation. Do not edit Xcode's template app or bypass
signing. When reusing an xctestrun product, verify it was already branded/signed.
Assets and exact built-in generation prompts are in [app-icons.md](app-icons.md).


## Recording list polish (issue #30)

Setup now ends with Privacy policy and Third-party notices; these stack when
larger text needs more space. Each saved entry has wrapping date/time and original
MP4 size, status, then one horizontal Play/Export/Delete icon row. VoiceOver labels
include the recording date and time. Targets are at least 44×44 points, deletion
still confirms, and export still shares the original file. Missing/unavailable
metadata says “File size unavailable” and disables Play/Export. Actual empty files
can report zero. Size is read with Foundation file attributes when rendering a
row; no stored estimate, available-capacity API or polling is added.

The focused implementation/handoff is in
[the recording UI plan](2026-11-05-recording-ui-implementation.md). Issue #23 must
retain these details when splitting the full-app screens. PR #31 first integrated this change into `codex/full-app`. After issue #6 closed
and the owner authorized merge/TestFlight delivery, a focused backport carries
only this UI change onto main. The released app source is byte-identical to
reviewed `efeb462`; no broadcasting implementation is promoted.

Native hosted tests and Release build:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /tmp/stream14-issue30-build \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution -only-testing:Stream14Tests \
  -resultBundlePath /tmp/stream14-issue30-unit2.xcresult test

xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/stream14-issue30-release \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

Use fresh result-bundle paths on reruns. `RecordingFileSizeTests` checks a missing
MP4 despite a present sidecar, actual bytes after rewrite, a real empty file,
removal and an unexpected directory. The complete hosted suite passes 23 tests
in 9 suites; the unsigned iPhone Release build passes with Xcode 27.2.

The opt-in UI checks use **only synthetic Simulator fixtures**. Seed three fresh
UUID status JSONs under the Simulator app's `Library/Application Support/MediaExperiments`:
one completed entry with a generated playable MP4, one pending entry without a
video, and a separate pending entry to delete. Use JSONEncoder-compatible seconds
since 2001 for `created`; assign the video the newest date. Never reuse an owner's
UUID or run this against a phone container. Pass their UUIDs as follows, alongside
the same scheme/destination/cache options above and `-only-testing:Stream14UITests`:

```sh
TEST_RUNNER_STREAM14_RECORDING_UI_FIXTURE_ID="$VIDEO_FIXTURE_ID" \
TEST_RUNNER_STREAM14_RECORDING_UI_MISSING_ID="$MISSING_FIXTURE_ID" \
TEST_RUNNER_STREAM14_DELETE_FIXTURE_ID="$DELETE_FIXTURE_ID" \
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /tmp/stream14-issue30-build \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution -only-testing:Stream14UITests \
  -resultBundlePath /tmp/stream14-issue30-ui.xcresult test
```

The UI checks cover portrait and both landscape directions at normal and largest
accessibility text, horizontal action alignment/targets/labels, missing-file
actions, footer placement, accessibility audits, playback sheet, Save to Files
availability, and Cancel/confirmed deletion of only the separate deletion fixture.
They do not certify actual media playback or exported-file readback. Keep physical
13 mini layout, spoken VoiceOver navigation, real playback and completed Files
export as manual acceptance; Simulator audits do not replace those checks.

The recording-list audit excludes only contrast findings on static text that
intersects the scroll viewport but extends vertically beyond it, within its
horizontal bounds. Xcode reported a contrast failure on the black overlay-status
line partly covered by the fixed WebKit surface after scrolling. This exception
does not suppress fully visible text, controls, text-clipping or other audit types.

Final evidence: all six seeded layout combinations pass in
`/tmp/stream14-issue30-layout7.xcresult`; retained screenshots in
`/tmp/stream14-issue30-final-attachments` were visually inspected. The final
Release log is `/tmp/stream14-issue30-release-final2.log`. Focused playback/export
availability passes in `/tmp/stream14-issue30-ui2.xcresult`; selected-only deletion
and baseline setup checks passed in `/tmp/stream14-issue30-ui.xcresult`, which also
contains earlier superseded footer/test failures. Final independent review of the
actual source and both branch diffs found no material issue. Physical acceptance
above remains pending; no phone installation or recording was performed here.

### Rear-camera lens selection, issue #33 (2026-11-06)

Open **stream14 → Open camera**, then use the compact camera-icon button beside the preview (initially **1×**).
Choose **0.5× · Ultra Wide** for a wider view, or another compatible rear lens when
present. The native lens-choice dialog reflects the phone's actual capture capabilities. Wide is the
default on a fresh launch; the choice is retained while closing/reopening the
camera in the same app session. Selection briefly pauses preview and is disabled
during recording/finalization. The selector disappears with Close camera, and its
short label preserves a 44-point minimum target; reopening remembers the current
lens. The dialog and VoiceOver retain full lens names. A failed change restores the prior camera, or stops
capture with guidance to reopen if recovery fails. There is no mid-recording lens
switching or new output/encoder.

The initial test target is the paired iPhone 13 mini/iOS 27.2, using a normally
signed development build installed over the existing app without uninstalling or
deleting recordings. This is development evidence, not a TestFlight upload or
long-run qualification. The owner prepared the phone unlocked/in landscape and
explicitly authorized short private camera/microphone tests.

Reproduce with the shared Stream14 scheme (set `DEVICE_ID` and `APPLE_TEAM` locally
as above; never commit real values). Use new result paths on repeat:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /tmp/stream14-issue33-simulator \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution \
  -resultBundlePath /tmp/stream14-issue33-simulator-new.xcresult test

TEST_RUNNER_STREAM14_DEVICE_LENSES=1 TEST_RUNNER_STREAM14_DEVICE_LENS_UI=1 \
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath /tmp/stream14-issue33-physical \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$APPLE_TEAM" -parallel-testing-enabled NO \
  -only-testing:Stream14Tests/RearCameraLensTests \
  -only-testing:Stream14UITests/SetupScreenTests/testDeviceRearLensSelector \
  -resultBundlePath /tmp/stream14-issue33-device-new.xcresult test

xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/stream14-issue33-release \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

Select the entire Swift Testing suite for the hosted device check. Default tests
skip private device capture; opt in only with the prepared, unlocked testing phone.
The shared scheme brands/signs the separate purple UI runner before installation.
No recording is automatically removed, including failed/pending files.

Final development evidence (2026-11-07):

- The default simulator suite passed in `/tmp/stream14-issue33-resume-simulator-final.xcresult`: 26 Swift Testing cases (including opt-in skips), three ordinary UI passes and six opt-in UI skips. The final unsigned Release build passed in `/tmp/stream14-issue33-resume-release-final.log`.
- The iPhone 13 mini/iOS 27.2 hosted suite passed all three lens tests in `/tmp/stream14-issue33-device-final.xcresult`. Runtime choices were Ultra Wide and Wide, with no Telephoto. Actual 1920×1080/30 fps capture formats reported horizontal fields of view 106.97° and 69.47°. Short clips contained audio/video and decoded overlay pixels, and finalized as complete. Selection during recording was rejected. Injected configuration failure restored the prior lens and another recording completed; failed restoration stopped capture; interruption during a change required explicit reopen. This combined result's earlier UI failure is superseded by the final UI result below, not by the hosted pass.
- The final native Camera button/dialog passed physical UI checks in `/tmp/stream14-issue33-resume-device-ui-2.xcresult`: Ultra Wide selection/value, actual touch target at least 44 points in both landscape orientations, recording lock, stop and playback sheet. Private screenshots were visually inspected. A menu-style Picker was replaced because its intrinsic target measured only 34.33 points despite an outer 44-point frame. The final button puts the minimum inside its label and exposes an explicit accessible name/value.
- Independent full-diff and focused UI re-review found no remaining material issues after adding failure/interruption coverage. `git diff --check` passed. All original recordings remain in the app's private MediaExperiments directory; raw media and UUID associations remain in private test logs/results outside Git and issue/PR attachments.

The tested development app was reopened on the phone for owner review. Compare
Wide and Ultra Wide from the same fixed position, inspect preview and original
recordings, and check comfortable operation in both landscape orientations.
On 2026-11-07 the owner confirmed that Ultra Wide shows the wider scene from the
same position and landscape controls work as expected. Spoken VoiceOver navigation
remains pending. Telephoto hardware, other iPhones, long-run performance and actual broadcast output need
separate evidence. Field-of-view metadata and structural file checks do not
establish subjective picture quality or measured A/V alignment. No TestFlight
upload is included in this change.

The compact/preview-only refinement passed physical UI regression in
`/tmp/stream14-issue33-compact-device-2.xcresult`: absent before Open camera and
after Close camera, present with remembered Ultra Wide after reopen, compact
normal-text dimensions in both landscape orientations, and recording lock/stop/
playback. Focused Simulator lens/setup checks passed in
`/tmp/stream14-issue33-compact-simulator.xcresult`; the Release build passed in
`/tmp/stream14-issue33-compact-release.log`. Independent review found no material
issues. Private screenshots remain outside Git.

### Separate overlay preview removed, issue #34 (2026-11-07)

The main screen no longer reserves a 60-point source-browser strip. A top-aligned
ZStack retains the attached, nonzero WebKit host behind the opaque system-background
ScrollView. The source itself stays unhidden at alpha 1; its full-canvas snapshots
still feed the existing composed preview and recorder. Status, manual hiding and
Overlay URL settings remain available. No recording/output lifecycle is changed.
See the [focused plan](2026-11-07-remove-overlay-preview-implementation.md).

Reproduce with fresh result paths:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /tmp/stream14-issue34-simulator \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution \
  -resultBundlePath /tmp/stream14-issue34-new.xcresult test

xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/stream14-issue34-release \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

Evidence: the hosted suite passed 26 cases (including opt-in skips) in ten suites
in `/tmp/stream14-issue34-simulator.xcresult`. The covered 60-point WebKit host
produced full 1920×1080 alpha snapshots, including changing score pixels, and
manual hiding still worked. The actual HaishinKit NV12 hide/restore regression and
recorder tests passed. Unsigned iPhone Release passed in
`/tmp/stream14-issue34-release.log`. The initial UI run's new gap assertion used the
ScrollView accessibility frame, which includes navigation insets, and failed;
the corrected assertion measures the heading from the navigation bar's bottom.
Final UI evidence is `/tmp/stream14-issue34-ui-final.xcresult`: ordinary portrait,
landscape largest-text and overlay-settings checks pass, including accessibility
audits; six fixture/device opt-in tests are skipped. Retained portrait/landscape
screenshots are inspected for removal of the strip and retained content.

Independent source review found no material implementation issues. The paired
physical phone was disconnected; covered-host rendering with camera preview,
recording/playback and spoken VoiceOver remain unverified by those automated
checks. Subsequently the signed development app was installed in place and launched
on the test phone, preserving its container; the owner reported “All good” on
2026-11-07. This is owner development acceptance, separate from delivered-build
TestFlight evidence. No camera/microphone capture, private recording
deletion, TestFlight upload or long-run qualification was performed.


### TestFlight version convention (2026-11-07)

The release after merged #33/#34 is **0.2 (3)**, now Testing in Owner MVP. At each TestFlight release
of newly merged main changes, increment the minor marketing version; replacement
uploads within that release keep the marketing version and increment the build.
Build numbers continue increasing across minor versions. Update both app project
configurations and the hosted app-identity test together, verify the archive's actual
Info.plist, and check App Store Connect for collisions. See the
[0.2 release record](2026-11-07-testflight-0.2.md) for packaging/distribution evidence.

### Issue #38 overlay recovery and safe URL editing

The saved URL controls foreground overlay intent independently of camera/recording.
**Overlay → Apply URL** commits a validated HTTPS URL; close without applying to
discard edits. The reference button only fills the draft. Apply an empty/whitespace
value to disable and remove the saved URL. Invalid input/Keychain errors leave the
active configuration intact. Editing/applying is locked during capture transitions,
recording and finalization. Token-bearing URLs remain private and device-only.

**Overlay disabled** means no configured source/work; **Overlay paused** means the
configured source is suspended in the background; **Loading/Overlay unavailable** means
a configured source is trying/recovering. **Overlay manually hidden** preserves the
operator's visibility choice even while source/render health recovers. Opening the
app resumes only overlay work, never camera, recording or publishing.

Reproduction and focused checks:

1. Apply a public test HTTPS overlay and close settings. Reopen/foreground the app;
   verify loading proceeds without Load and without starting the camera. Repeated
   appearances must not reload a healthy source.
2. Reopen settings, edit/clear the draft and dismiss. Reopen: the committed URL is
   unchanged. Apply invalid HTTP/credential-bearing input: an error appears without
   replacing the active source. Never include private URLs in screenshots/test logs.
3. Apply a different valid URL before recording. No image/result from the retired
   browser may replace the new source. Apply an empty value: the layer disappears,
   all overlay work stops, and relaunch/foreground return leaves it disabled.
4. During a short composed camera recording, interrupt source access, then restore.
   The last frame remains briefly, disappears after ten seconds, then recovers from
   confirmed source access plus a fresh render. Recording continues. Repeat with
   manual hiding; recovery must not override it. Keep originals and stay within the
   fifteen-minute development-experiment cap.

The hosted `OverlayConfigurationTests` inject read/save failures without altering
owner Keychain configuration. `WebOverlayRendererTests` use an attached local fixture,
injected monotonic time and Debug-only capture/ticker failures to exercise stopped
work, capture deadlines, unusable rendering, process-termination delegate handling,
old callbacks and disabling. No private WebKit process-kill API is used. Default tests
do not depend on the live scoreboard. `SetupScreenTests` exercise draft cancellation,
invalid Apply and largest-text landscape settings. The existing actual HaishinKit
NV12 hide/restore and local-recorder tests remain relevant regressions.

Run from the focused checkout, using fresh result paths for repetitions:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /tmp/stream14-issue38-simulator \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution \
  -resultBundlePath /tmp/stream14-issue38-new-hosted.xcresult \
  -only-testing:Stream14Tests test

xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/stream14-issue38-release \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

Builds and Simulator evidence alone do not qualify physical WebKit/media performance,
real OS web-process termination, all failure reasons or long-event stability.

Verification on 2026-11-07:

- Hosted suite: 32 cases in 12 suites passed (including intentional opt-in skips),
  `/tmp/stream14-issue38-hosted-final.xcresult`. Includes initial navigation cancelled
  before commit, stopped ticker/renderer, stalled capture, unusable render,
  process-delegate recovery, stale callback rejection, configuration failure,
  empty disable, actual HaishinKit NV12 hide/restore and recorder regressions.
- Four focused UI tests passed in `/tmp/stream14-issue38-ui.xcresult`: portrait setup,
  maximum Dynamic Type landscape, URL draft dismissal/invalid Apply, and accessible
  overlay settings without camera. Accessibility audits passed; exported largest-text
  settings screenshot was visually inspected. A real VoiceOver session is unverified.
- Unsigned generic-iPhone Release passed in `/tmp/stream14-issue38-release-final.log`.
  The Debug-only opt-in media harness is excluded from Release.
- Signed development test on iPhone 13 mini, iOS 27.2 (24B119), passed in
  `/tmp/stream14-issue38-device-final.xcresult` in 31.594 seconds. One recording
  survived capture/ticker interruption, blocked real document requests, ten-second
  stale hiding, recovery while manually hidden, and process-termination delegate
  handling. Applying an empty URL was rejected during recording and succeeded after
  stop; foreground return kept it disabled. The test uses injected URL persistence,
  so the owner's Keychain URL is preserved. It never disables radios or bypasses TLS.
- The final original is retained on the phone and copied locally as
  `/tmp/stream14-issue38-final-original.mp4`. Full native AVFoundation decode passed
  for video and audio: 27.7275 seconds, 1920×1080, 813 video frames, nominal track
  cadence 29.325 fps, maximum video interval 225 ms, no intervals >=500 ms. Writer
  metrics report zero audio/video admission drops and 22 estimated missing camera
  output intervals. Extracted frames verify an initially composed overlay, its
  absence during the outage/manual hide, and a fresh overlay in the final recorded
  composition. These are failure-recovery checks, not a passed smooth-30/long-run gate.
- Two earlier short originals are also retained. The first revealed that the test
  stopped before final compositor handoff; two-second settling intervals now retain
  the recovered picture. Review also found a strongly retained retired test browser
  and possible duplicate root overlay. The final harness compares ObjectIdentifier
  without retaining the old browser, and suppresses root supervision only for the
  explicit Debug opt-in test. Earlier cadence figures are therefore confounded.
  No raw recordings, screenshots of private media, device IDs or signing data are
  committed or attached publicly.

Opt-in reproduction (after connecting/unlocking the phone and selecting local
signing; `DEVICE_ID`/`STREAM14_TEAM` are owner-local values):

```sh
TEST_RUNNER_STREAM14_OVERLAY_RECOVERY_DEVICE=1 xcodebuild \
  -project Stream14.xcodeproj -scheme Stream14 \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath /tmp/stream14-issue38-device \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$STREAM14_TEAM" \
  -resultBundlePath /tmp/stream14-issue38-new-device.xcresult \
  -only-testing:Stream14Tests/OverlayRecoveryDeviceTests test
```

This test deliberately records private camera/microphone media and retains it.
Do not run it without owner agreement. The shared scheme brands/signs the separate
UI-test runner before installation. This is a development build, not a TestFlight
release. Actual OS process termination, physical VoiceOver, A/V sync measurements,
steady-state/long-run frame-drop and thermal qualification remain unverified.

Independent review inspected the actual diff/files against main. It found that
transient `.inactive` scenes (such as Control Center) would clear the overlay while
recording continued. Fixed by suspending only on `.background`, preserving
`.inactive`, and reconciling on `.active`. Focused re-review of this fix, device
harness corrections and docs found no remaining material code issues.

## F2 Google authorization setup (2026-11-07)

The app pins Google's supported [GoogleSignIn iOS SDK 10.1.0](https://github.com/google/GoogleSignIn-iOS/releases/tag/10.1.0)
and uses its system-browser sign-in, callback and Keychain-managed credentials.
Local preview/recording needs no Google account. Connecting does not upload media.
No real Google client is included in source; an absent/mismatched client leaves
YouTube disconnected with a setup explanation.

After completing the Google Cloud/API/consent steps in section 3:

1. In Google Auth Platform → Clients, create an **iOS** client with bundle identifier
   `com.smith3v.stream14`. Use the app's normal Apple signing team if requested.
   There is no backend/client secret. Enable YouTube Data API v3, include the
   `https://www.googleapis.com/auth/youtube.force-ssl` scope in consent configuration,
   and add the intended Google account under Audience → Test users while Testing.
2. Copy the public iOS client ID, which ends in `.apps.googleusercontent.com`.
   Create ignored `Config/Local.xcconfig` beside `Config/Google.xcconfig`:

   ```xcconfig
   GOOGLE_CLIENT_ID = YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
   GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.YOUR_IOS_CLIENT_ID
   ```

   Replace both placeholders with the same actual client prefix. These IDs are
   public configuration; never paste a user token, stream key or client secret.
   `Config/AppInfo.plist` expands the client ID and matching URL scheme. The
   configuration loader rejects missing or mismatched values before invoking SDK.
3. Build and normally sign the app, then choose **Connect YouTube**. The system
   browser should show Google account choice and consent, then return to stream14.
   Grant the requested YouTube permission. A successful F2 status says Google is
   authorized; it does not yet prove the actual YouTube channel (F3 owns that).
4. Test Cancel, Switch Google account, Sign out on this iPhone, Restore saved
   connection after relaunch, and confirmed Revoke Google access. Local recordings
   and overlay settings must survive. Sign-out alone is not server revocation;
   a failed revoke is reported honestly. The app never resumes camera capture or
   uploads because a Google session was restored.
5. Google Testing users and TestFlight testers are separate lists. YouTube-scope
   testing grants normally need reauthorization after seven days. Before external
   distribution review current [Google verification requirements](https://developers.google.com/identity/protocols/oauth2/production-readiness/policy-compliance),
   [branding](https://developers.google.com/identity/branding-guidelines), SDK privacy
   manifests and the App Store Connect aggregate privacy disclosures. No external
   consent verification, Google branding approval or signed-phone callback is
   established by compiling this change.

F2 API handoff: `YouTubeAuthorization.freshAccessToken(expectedGeneration:)`
returns a short-lived in-memory token only for the current authorized account.
Capture `generation` before API work and discard results if it changes. Cancellation
of an API read preserves authorization; actual refresh failure clears readiness.
`connect`, `restore`, `signOut` and `disconnect` invalidate old channel/event state
through the generation. Later broadcast coordination must pass `broadcastActive`
for account actions and disable account UI until end; F2 has no broadcast state.

The owner reported on 2026-11-07 that Google setup is not complete. Supported
browser callback, signed-device Keychain restoration, actual channel authorization,
revocation and multi-account/Brand Account behavior remain pending. Unit tests use
in-memory fixtures and never call Google or send camera media.

## Full app F1 dual-output feasibility checks (2026-11-07)

The [F1 plan](2026-11-07-dual-output-implementation.md) and
[API audit](feasibility.md#full-app-f1-public-dual-output-api-audit-2026-11-07)
record the public boundary and pending architecture/physical gates. The app target
still links only HaishinKit; RTMPHaishinKit is linked by Stream14Tests only.
Ordinary tests do not publish or open a transport connection.

Run the focused synthetic checks with a fresh result path:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /tmp/stream14-f1-simulator \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution \
  -only-testing:Stream14Tests/DualOutputFeasibilityTests \
  -resultBundlePath /tmp/stream14-f1-check.xcresult test
```

The deterministic checks create short synthetic files, prove independent local
writing with a disconnected raw RTMP observer, check compile/call compatibility
of public compressed H.264/AAC overloads without a destination, and compare packet bytes/timestamps
through MP4 compressed passthrough. Removing these disposable generated fixtures
is test cleanup; physical originals are never automatically removed.

### Optional private physical candidate

This experiment captures and **publishes camera/microphone media**. Run it only
after the owner explicitly chooses the private test event/destination and connects
and unlocks the iPhone 13 mini. It uses two encoders solely to measure the smallest
library-native candidate; it is not enabled in production and does not select the
production architecture. Verify the event is unlisted/private and the operator is
ready before any run.

Configure test process variables privately: `STREAM14_DUAL_OUTPUT=1`,
`STREAM14_PRIVATE_RTMPS_URL` (RTMPS application URL without credentials/query/fragment),
`STREAM14_PRIVATE_STREAM_KEY`, and optionally `STREAM14_DUAL_OUTPUT_SECONDS`
(default 30 seconds; clamped to 12–600 seconds, leaving setup/reconnect margin below
the fifteen-minute development cap). Xcode CLI forwarding uses corresponding
`TEST_RUNNER_` names; do not type secret values into a shared command, chat, screenshot
or committed scheme. Use a private local environment/configuration mechanism.
The test disables upstream RTMP logging and substitutes generic safe errors.
Treat the resulting xctestrun, xcresult and build/test logs as private: configuration
artifacts may contain environment values even when application logs are redacted.
Do not attach these artifacts to public PRs/issues; export sanitized summaries only.

Use the guide's existing normal signing, test-runner branding and physical-device
destination workflow, choosing only
`Stream14Tests/DualOutputFeasibilityTests/privateDeviceDualOutputCandidate`.
Do not use unsigned products for installation. The test opens the existing media
session, adds a changing alpha fixture and local recording, publishes with the
public `connect`/`publish` API, closes/reconnects RTMPS once while checking recording
continues, and retains original MP4/status metadata in the normal recording list.
Connection failure finalizes/retains the recording before reporting a safe error.

Inspect both the original local file and private remote capture: changing overlay,
orientation, tracks/profile, no app controls, cadence, reconnect continuity and
start/end A/V markers. Collect the existing private physical-footprint/thermal
measurement series and writer metrics. A publishing state callback alone does not
prove receiver delivery. The candidate's library queue setting covers three raw
video buffers only, not task/encoded/socket backlog. Writer-failure/upload
independence and bounded queues remain F6/F9 implementation/measurement work;
the existing MVP coordinator still stops capture on writer failure.
No physical dual-output acceptance or production second-encoder approval is claimed.

F1 validation: Xcode 27.2 (27B52)/iOS SDK and Simulator 27.2 unsigned Release,
Simulator build-for-testing and device-SDK build-for-testing pass. The focused
Simulator run at `/tmp/stream14-f1-tests-5.xcresult` passes both deterministic tests;
the physical publishing test is skipped. Its log is `/tmp/stream14-f1-tests-5.log`.
Initial failed compile/comparison bundles are retained; the passing comparator
normalizes AAC packet grouping and ignores zero-sample trim markers. The resulting
proof is offline MP4 passthrough and disconnected local ownership, not successful
RTMP compressed-format acceptance or physical broadcast qualification. Shared encoding while disconnected/reconnecting remains
unimplemented and must not be inferred from the offline remux test.

The disconnected compressed calls establish compile/call compatibility only.
The passing run logs `invalidSequence` for initial zero/nonpositive timestamps:
RTMP append returns Void and catches/logs timestamp errors. A future live adapter
must supply a common positive capture timeline, enforce per-track order and verify
first-origin/A/V behavior after publish/reconnect; separate track-origin resets
mean a positive bias alone does not prove initial A/V offset preservation. Neither
idle state nor absent observer callbacks establish successful media acceptance.

## Full-app F4: profiles and microphone/camera controls (2026-11-07)

Choose the Session profile button before Open camera: 1080p30 at a requested
14 Mbps, or 720p30 at 8 Mbps. Both use the same fixed landscape composition and
H.264/AAC original MP4 path. Close camera to change profile; profile preference is
saved without touching the Keychain overlay URL. The rear-lens dialog retains
supported Ultra Wide/Wide/Telephoto choices for that profile. Preview and recording
allow microphone mute and a zoom slider, which applies on release. Zoom is relative
to the selected physical lens; the lens selector still supplies the owner's 0.5×
Ultra Wide view. Input shows the actual system microphone route. The level display
is an approximate peak of shared mixed audio, so it shows silence when muted.

Verified public source boundaries at pinned HaishinKit 2.3.0:

- `AudioMixerSettings.isMuted`, `MediaMixer.setAudioMixerSettings(_:)` and mixed
  `MediaMixerOutput.audioTrackId == UInt8.max` apply mute before output fan-out.
- `MediaMixer.configuration(video:configuration:)` permits throwing device zoom
  configuration on its actor. No AVCaptureDevice crosses into UI ownership.
- `.sdr` composition uses Rec.709 Core Image context and video-range NV12; the
  writer requests Rec.709 tags. AVAssetWriter average bitrate is not proof of CBR.

Reproduce the native checks from the F4 worktree, choosing a valid Simulator ID
and fresh result path on another Mac. Build logs/results stay private local files:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/stream14-f4-build \
  -clonedSourcePackagesDirPath /tmp/stream14-f2-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,id=D6BEAF78-D273-4952-8349-B50B2824E6A9' \
  -derivedDataPath /tmp/stream14-f4-simulator \
  -clonedSourcePackagesDirPath /tmp/stream14-f2-packages \
  -disableAutomaticPackageResolution -only-testing:Stream14Tests/SessionProfileTests \
  -resultBundlePath /tmp/stream14-f4-profiles.xcresult test
```

Repeat focused regression suites with `-only-testing:Stream14Tests/LocalRecorderTests`,
`WebOverlayRendererTests`, `WebOverlayCompositionTests`, `RearCameraLensTests`,
`OverlayHealthTests` and `AppConfigurationTests`. Actual command/result paths and
review status are recorded in the [stage handoff](2026-11-07-session-controls-implementation.md).
Physical tests remain opt-in, wait for the owner to connect/unlock the 13 mini,
retain originals, and never exceed 15 minutes for a development experiment.

Pending physical F4 acceptance: record short changing alpha-overlay samples in
both profiles and landscape orientations; confirm camera/writer dimensions,
H.264/AAC, orientation, visible mute/unmute and audible silence/recovery, zoom,
level/route/interruption behavior, profile/lens lock during recording, original
playback/export, and ten-second overlay hide/recovery at 720p. Inspect originals;
requested settings, callback counts and a Simulator are not substitute evidence.
No new TestFlight build or long qualification run is established by F4.

## F3 channel and scheduled-event checks (2026-11-07)

After Google authorization succeeds, use **Refresh** in Scheduled YouTube event.
The app displays the actual API-returned channel, then reads every upcoming-event
page. Confirm the channel title/identifier before selecting a row; the Google email
is not the channel identity. If the wrong channel/Brand Account is returned, reconnect
using the intended channel. Schedule a dedicated encoder event in YouTube Studio,
preferably unlisted, with auto-stop disabled. Refresh again. The row shows local
date/time, visibility and any reason it cannot be selected. Missing/unknown essential
metadata cannot silently become an eligible event. An enabled auto-start setting
is disclosed after selection. There is no Go Live/media upload action in this stage.

Account changes clear channel/event state. Refresh clears a disappeared or now
ineligible selection. The selected event must be read again by ID before later
binding/start work; an old selection is not proof of current eligibility. API metadata
is memory-only, with no raw-response archive. Do not put access tokens, response
bodies, ingestion details or screenshots of secrets into reports.

The owner-controlled Google Cloud/API/iOS client/testing audience are prepared.
Actual signed-phone sign-in, callback, channel/Brand Account identity, event listing
and selection remain pending; Console setup and fixture tests do not establish them.

Reproduce the focused fixture and authorization checks from the F3 worktree:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /private/tmp/stream14-f3-simulator \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f2-packages \
  -disableAutomaticPackageResolution \
  -only-testing:Stream14Tests/YouTubeClientTests \
  -only-testing:Stream14Tests/YouTubeAuthorizationTests \
  -only-testing:Stream14Tests/AppConfigurationTests \
  -resultBundlePath /private/tmp/stream14-f3-tests.xcresult test
```

Choose a new result-bundle path for another run. The recorded run passed **26 tests
in three suites** (13 F3, 11 authorization and two configuration tests), log
`/private/tmp/stream14-f3-tests.log`. Fixtures under Stream14Tests/Fixtures/YouTube
contain only invented channel/event data and a clearly fake stream name/address.
No actual Google request, media publishing, phone recording or deletion occurred.
The [F3 implementation handoff](2026-11-07-youtube-client-implementation.md) records
build/integration/review status separately from live-owner acceptance.

After merging F4, the combined F3/auth/config/profile run passed 32 hosted tests at
`/private/tmp/stream14-f3-merged-tests.xcresult`. Final Release passed in
`/private/tmp/stream14-f3-release-final-2.log`. The first portrait audit found low
contrast on an unavailable disabled Refresh label; Refresh is now shown only
after authorization, with an explicit 44-point target. The final recheck passed
13 F3 tests and both portrait/largest-text landscape setup accessibility tests at
`/private/tmp/stream14-f3-ui-recheck.xcresult`. Private screenshots were inspected;
authenticated event rows and physical VoiceOver remain pending. The initial failed
UI result is retained, and no audit issue was suppressed.

## F5 safe ingestion preparation (2026-11-07)

The [F5 handoff](2026-11-07-safe-ingestion-implementation.md) documents a
write-once/reconcile component for the later confirmed Go Live flow. Merely
connecting, refreshing/selecting an event or opening local preview does not
create or bind streams. Auto-stop must already be disabled in YouTube Studio;
this component never silently changes event settings.

Pending mutation IDs and phases are stored in a small backup-excluded local
journal. An ambiguous creation is not repeated blindly after retry/relaunch.
If the app reports an unknown creation outcome, inspect streams in Studio and
resolve the intended binding there; do not repeatedly create new resources.
A known created ID survives binding failures and is reused on reconciliation.
No stream key or token is stored in that journal, and no remote resources or
recordings are automatically deleted.

Fixture tests use no real Google service or camera. Actual signed-account
acceptance requires a dedicated unlisted event and explicit operator action;
F5 has no standalone phone runner or Go Live UI yet. The later F7 integration
must make those checks executable before a connected-phone test is scheduled.

## F6 draft transport dependency (2026-11-08)

The draft shared-media integration selects the owner-maintained HaishinKit fork
at revision `8dc2ecce781d320ef0f2576ff5195411c91505ad`, based on upstream 2.3.0.
See the canonical specification's F6 dependency selection and the
[implementation/evidence record](2026-11-08-shared-media-integration-implementation.md).
Only core and RTMP products are linked; original BSD notices remain in the app.
An immutable revision and committed Package.resolved replace any local path or
moving branch. Future fork updates require source review and regression checks.
No production credentials, local package path or actual receiver acceptance is
implied by this selection. F7's confirmed operator flow is still required before
an upload; local rehearsal needs no internet connection or Google setup.

## F7 confirmed Go Live and End (2026-11-08)

This flow is an implementation candidate; real channel/OAuth/unlisted receiver
acceptance remains pending. Do not open a public event as a routine test. The
owner must choose the intended dedicated event and explicitly confirm publishing;
opening the app, restoring authorization, refreshing/selecting an event or opening
local preview does not upload camera or microphone media.

1. Choose the profile, open the camera, and check the preview/audio route. Apply
   the intended overlay URL and wait for a fresh usable render. If the configured
   overlay is unavailable, explicitly apply an empty URL to disable it before
   rechecking readiness. Preview/local recording still work without Google.
2. Connect YouTube, Refresh, and check the actual channel/Brand Account. Select
   the intended scheduled encoder event with auto-stop already disabled in Studio.
   This action does not change title, visibility, audience or event settings.
3. Tap **Go Live** and review the confirmation's channel name/ID, event title,
   visibility and profile. Confirm only when ready to upload. The app starts or
   retains the actual local writer before any binding or upload; a writer startup
   failure publishes no media. Changed confirmation metadata requires review again.
4. Watch the independent local recording, Upload and YouTube messages. Socket
   connection is not Live. Manual events wait for active ingestion. When the
   existing event enables its monitor stream, the app automatically requests testing
   and waits for YouTube to confirm it before requesting live, under the same Go Live
   intent. Testing is not Live. Disabled monitor streams go directly to live. If the
   monitor setting is unavailable on an authoritative refresh, no binding/upload
   starts; refresh or inspect Studio. Auto-start events may become visible from the confirmed first upload and are
   polled without a redundant transition. Startup is bounded to 60 seconds.
5. **Cancel YouTube startup** or a startup/API failure stops the upload while a
   healthy local file continues. **Stop recording** remains deliberate. A failed
   broadcast attempt never automatically deletes files. If the app requests
   reconciliation, use **Reconcile YouTube status** or **Open YouTube Studio**;
   reconciliation is read only and does not restart upload or repeat a mutation.
   An uncertain testing/Live request remains blocked even if an early read says upcoming;
   the earlier request could still apply. Resolve that exact event in Studio, then
   reconcile a confirmed live/finished state. The app never silently discards this
   transition barrier. While a previous request is still outstanding, wait for its
   outcome before reconciliation or another completion request.
6. **End broadcast** requires confirmation naming the frozen event. It requests
   local capture/output stop immediately while remote completion is checked
   separately within 15 seconds. Local finalization status stays visible in the
   recording list. **YouTube end not confirmed** means the remote event might still
   be live; check Studio and reconcile before explicitly retrying End. Stopping a
   socket is not proof the YouTube event ended.
7. On relaunch an unresolved event is shown for read-only reconciliation; the app
   never silently resumes publishing. Reconnect authorization to its original
   channel if required. Account actions are end-first during startup/live/End,
   and available again after startup/upload has stopped for reconciliation.

Reproducible offline validation (use a fresh result path per run):

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /private/tmp/stream14-f7-simulator \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages \
  -disableAutomaticPackageResolution \
  -only-testing:Stream14Tests/BroadcastSessionTests \
  -resultBundlePath /private/tmp/stream14-f7-fixtures-new.xcresult test
```

The [stage handoff](2026-11-08-broadcast-session-implementation.md) records actual
results and exact API/ownership boundaries. Fixture credentials and API bodies are
invented; no real Google requests or camera/network media are used. Preserve the
Debug short-phone-smoke host isolation and normally signed distinct UI runner.
Routine physical validation stays **five minutes TOTAL** including setup/wrap-up;
OAuth/setup blockers stop within that budget, and longer qualification requires a
separate agreement. No actual receiver, A/V sync, CBR, thermal/memory or three-hour
broadcast acceptance follows from a native build or fixture run.

## F8 same-event reconnect fixtures (2026-11-08)

`BroadcastSession.reconnectStatus` distinguishes monitoring, waiting, connecting,
exhausted, authorization attention and stopped recovery. `retryUpload()` only
retries the same RAM-admitted context after the finite outage budget; it cannot
create/rebind or repeat Go Live. `cancelReconnect()` cancels owned transport work
without requesting whole-session stop. `MediaSession.broadcastPipelineRunning`
lets supervision ignore temporary file-control busy state and overlay outages.

Run laptop fixtures without physical media or Google calls:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /private/tmp/stream14-f8-tests \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages \
  -only-testing:Stream14Tests test
```

The controllable monotonic `ReconnectClock` supplies now/sleep/jitter for outage,
budget and cancellation fixtures. Physical two-minute outage, Wi-Fi/cellular
handover and receiver/file continuity checks are deferred to a separately attended
run; this stage uses no physical device or real YouTube API/media calls.

F8's held-finalization regressions use DEBUG-only fixture installation of an
encoder with no media input and a publisher with fixture I/O. They verify actual
MediaSession upload detachment while busy and supervision across temporary writer
`.stopping`, without installing on a phone or opening a network connection.

## F9 interruption and explicit resume workflow

Keep the phone foreground while capturing. Home/lock, camera/audio interruption,
critical heat, capture/encoder failure or microphone input loss stops the whole
session. The app finalizes the file within available time and retains failed or
pending originals. YouTube can remain Live: an interruption never promises End.
Serious heat reduces overlay raster work without changing the media profile.

On return, read-only reconciliation checks the original channel/event. Open the
camera explicitly and check permissions, microphone, original profile and overlay.
Choose **Resume same event…**, review the channel/event/visibility confirmation,
then confirm Resume. The app requires the original compatible inactive stream and
starts a new local file before publishing. If ingestion is still active, wait or
inspect Studio. An ended/replaced/ambiguous event cannot resume automatically.
Unknown transition outcomes stay blocked until reconciliation resolves them.
Older journals without admission profile/binding remain conservative and may need
Studio resolution before a fresh session. No camera or upload resumes on launch.

`SessionInterruptionTests` uses no camera/microphone/network: it drives the real
MediaSession cleanup with synthetic encoded packets and fixture publishers,
including append/finalize faults, held control operations, background expiry and
idle-timer restoration. `BroadcastSessionTests` uses injected API responses for
same-event resume, changed/terminal/active bindings, mutation barriers and late
startup/reconnect results. Run:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,id=D6BEAF78-D273-4952-8349-B50B2824E6A9' \
  -derivedDataPath /private/tmp/stream14-f9-tests \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages \
  -only-testing:Stream14Tests test
```

Native writer completion has a five-second control deadline; late completion does
not silently change the conservative metadata. Background expiry immediately
persists incomplete status and restores idle-timer ownership. Original files are
retained, without cancelWriting, repair, transcode or routine cleanup. A persistent
backup failure warning remains separate from healthy upload/remote Live status.
Physical Home/lock, audio interruption, resumed-file/receiver inspection and real
thermal evidence remain a separately attended acceptance run; this stage uses no
phone or real service calls and does not establish the long qualification gates.

## F10 preparation, session and recordings interface (issue #23)

Use Preparation for profile, YouTube connection/channel/event and help/privacy.
Open Session to open the camera, rehearse or record locally without Google. Choosing
a tab, event or settings does not publish. Go Live shows the channel title/ID,
event, visibility and profile for explicit confirmation. While active, profile and
URL edits remain locked; Overlay settings explains the lock while Session retains
manual hide and Reload overlay. Watch the distinct Recording, Upload, YouTube and
Overlay messages. A backup warning is independent of upload; uncertain End offers
read-only reconciliation and Studio. Interrupted sessions require the F9 explicit
camera reopen and same-event Resume confirmation.

Recordings keeps the original MP4, status, date and size, with Play, Export and
confirmed Delete. Cancel preserves the file. Exported copies remain after deletion;
deleting the app loses originals still contained in the app. No migration or
recovery claim is added by this interface stage.

Safe Debug UI fixture mode uses `STREAM14_INTERFACE_FIXTURE` only in the test
launch environment (`idle`, `ready`, `overlay-unavailable`, `reconnecting`,
`backup-failed`, `unknown-end`, `ended`). It is compiled out of Release and never
opens capture, Google, WebKit networking or a publisher. Do not infer actual
recording/receiver behavior from those presentation fixtures. Reproduce the focused
native interface suite using the shared scheme and a fresh result path:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,id=D6BEAF78-D273-4952-8349-B50B2824E6A9' \
  -derivedDataPath /private/tmp/stream14-f10-simulator \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -disableAutomaticPackageResolution \
  -only-testing:Stream14UITests/SetupScreenTests/testNativeDestinationsNeverStartCaptureOrPublishing \
  -only-testing:Stream14UITests/SetupScreenTests/testPreflightBlockersAndExactPublishingConfirmation \
  -only-testing:Stream14UITests/SetupScreenTests/testPersistentFailureStatesAndLockedSettings \
  -only-testing:Stream14UITests/SetupScreenTests/testSessionLayoutsAndManualOverlayAtLargestText \
  -resultBundlePath /private/tmp/stream14-f10-ui-new.xcresult test
```

Normally signed branded UI runner is required. Actual test results and screenshots
are recorded in the [F10 stage handoff](2026-11-08-integrated-interface-implementation.md).
No phone or actual Google/media publishing was used for this interface work.
Physical VoiceOver/13 mini acceptance and actual file/receiver exclusion remain
pending; preserve the owner's five-minute total routine phone budget.

F10 Simulator contrast diagnostics can point to static text outside the visible
scroll area (for example the YouTube heading at y709 on a 375-point landscape
screen). The focused UI helper excludes only uniquely matched static text proven
vertically clipped/offscreen in both captured and callback geometries within the
native nav/tab bounds. It logs that proof; unknown elements, fully visible text,
controls and other audit types remain failures. This is a narrow native audit
limitation, not a general contrast waiver or physical VoiceOver evidence. See the
F10 handoff for exact retained failed/passing runs and independent review status.

## Private synthetic RTMPS receiver checkpoint (2026-11-08)

Use the [receiver procedure and actual measurements](2026-11-08-private-rtmps-receiver-validation.md)
for normal-TLS laptop-only wire/receiver checks. It uses a fixed Debug Simulator-only
localhost seam and generated media through the actual shared encoder, with no
camera, Google request or physical-device trust change. The untrusted TLS rejection,
trusted socket sends and corrected-header receiver decode were observed, but the
receiver A/V alignment gate still fails. Do not treat the successful hosted test
alone as receiver or physical qualification. The record preserves the remaining
AAC timing investigation and a future five-minute TOTAL phone script using the
existing Unlisted YouTube event and normal public trust, not a phone CA profile.

## F11 recording review and separate recovery

The Recordings library retains original completed/interrupted/failed provenance.
It also shows duration, readable-start review and distinct recovered/failed-copy
states. UUID files remain visible if metadata is absent or malformed. A readable
start is a lightweight native audio/video decode check, not proof of whole-file
integrity; inspect playback. Use **Try recovery to separate copy** on an incomplete
recording to request native passthrough remux. It may preserve only completed
fragments, omit the tail or fail before the first ten-second fragment. The original
is always retained, including after failed recovery. Export originals/copies
explicitly. Confirm deletion for a selected copy or the complete selected group.
App deletion still loses files held only inside the app.

See the [F11 handoff](2026-11-08-f11-recording-recovery-handoff.md) for production
codec/writer Mac evidence, exact commands, the measured native AAC-tail trim, and
remaining physical process-termination/relaunch/playback/export checks. This is
not A5 acceptance or evidence of three-hour recording/streaming reliability.

## F12 qualification summaries and original analysis

The delivered app collects private bounded numeric checkpoints for each new
recording in Debug and Release. Load/export the qualification summary from that
recording's row; exporting media remains a separate action. Old recordings can
legitimately have no report. A checkpoint can be incomplete after termination;
"stopped" describes the observer, not file/stream success. Check the latest
checkpoint time and observation count before relying on the report.

Follow the [qualification report template](qualification-report-template.md) for
clap markers, native original-file analysis, receiver observation, overhead and
power/network/ambient controls. The development device harness still clamps to
900 seconds, while normal app recording remains unlimited. No 30-minute or
three-hour run is implicitly authorized. Short instrumentation overhead on the
13 mini and actual installed-app diagnostic export remain pending.

## Private synthetic RTMPS receiver checkpoint (2026-11-08)

Use the [receiver procedure and actual measurements](2026-11-08-private-rtmps-receiver-validation.md)
for normal-TLS laptop-only wire/receiver checks. It uses a fixed Debug Simulator-only
localhost seam and generated media through the actual shared encoder, with no
camera, Google request or physical-device trust change. The untrusted TLS rejection,
trusted socket sends and corrected-header receiver decode were observed, but the
receiver A/V alignment gate still fails. Do not treat the successful hosted test
alone as receiver or physical qualification. The record preserves the remaining
AAC timing investigation and a future five-minute TOTAL phone script using the
existing Unlisted YouTube event and normal public trust, not a phone CA profile.

F11's 2026-11-09 combined source has fresh native validation: 160 hosted passes,
eight opt-in skips and zero failures; 16 focused ownership/recovery tests; unsigned
Release; and two actual simulator recovery UI flows. The UI evidence includes
native playback/export-sheet presentation, relaunch persistence, Cancel/confirmed
copy-only deletion and unreadable-source failure. Both synthetic originals remained
byte-identical. The documented F10 clipped-static-text audit allowance applies;
this is not physical VoiceOver, complete media integrity or A5 qualification.
The [F11 handoff](2026-11-08-f11-recording-recovery-handoff.md) records exact commands,
artifacts, independent review fixes and the still-pending phone acceptance.


## F13 policy consent and safe local YouTube-data deletion

The candidate requires explicit privacy/service/YouTube agreement before Connect
or Restore. Local recording remains usable without it. Preparation keeps direct
policy/terms/Google access links visible. Ordinary Sign out clears account
readiness but retains pending request IDs. Delete saved YouTube data additionally
removes those IDs; Revoke Google access also requests SDK revocation. Recordings,
recovery copies, private numeric diagnostics and the overlay URL remain. Remote
YouTube videos/events are managed separately in Studio. A failed revoke is reported;
local deletion does not claim remote revocation or remote event completion.

Deleted identifiers are replaced by a nonidentifying Studio-resolution guard.
Before confirming its removal, inspect/finish previous events and pending stream
requests in Studio. The app cannot reconcile identities it has deleted and never
silently clears this guard merely because you reconnect. Outstanding mutations
must settle before confirmation; failed local erasure blocks publishing until
storage is resolved and deletion retried. External revocation is only observable
when the SDK/API later reports lost access, not while the app is offline/unused.

Follow the [F13 preparation and archive checklist](2026-11-09-full-app-testflight-implementation.md).
It records proposed metadata and distinct validation/upload/processing/install
checkpoints. After owner sign-in on 2026-11-09, the read-only Build Uploads / All
Statuses inventory showed 0.2 (3), 0.1 (2), 0.1 (1), all Complete, and no newer or
processing upload. The next candidate is 0.3 (4); see its
[packaging checkpoint](2026-11-09-release-0.3-implementation.md). Recheck live
inventory before distribution; source identity does not reserve a build number.
No phone action is needed for source preparation; the five-minute total attended
limit still applies.

The candidate checks both saved API-ID journals on launch, foreground activation
and journal use. At 30 days (or for undated/future-dated legacy records) it writes
the Studio guard before erasing IDs. Saving a phase never refreshes their age.
No background cleanup while unused is promised; the next launch/activation checks
expiry. Unknown/offline Restore preserves fresh journals for safe exact-event retry.


## Full-app TestFlight 0.3 (4) — 2026-11-09

The owner merged #58–#60. The account-enabled 0.3 (4) archive was validated and
uploaded through Xcode's normal automatic distribution path. App Store Connect
completed processing; its actual encryption question was answered on the audited
OS-only encryption boundary. Build-specific test notes and full-app beta information
were saved, and the existing Owner MVP internal group now shows **0.3 (4) Testing**
with a 90-day expiry display. No tester/public-link expansion occurred.

The owner confirmed **Installed 0.3 (4) through TestFlight**. This establishes
owner-reported exact-build installation, not a phone media/receiver regression pass.
See the [full-app delivery record](2026-11-09-full-app-testflight.md) for separate
archive, validation, upload, compliance, availability and installation checkpoints.
Use the [attended cards](2026-11-08-attended-iphone-session.md): S0 for installed
policy links/consent/Google reauthorization after the earlier revoke, then S1 only
when ready and explicitly confirmed for a dedicated Unlisted event. Routine visits
stay within five minutes TOTAL including setup/wrap-up. Remaining physical and
long-duration qualification is pending; retain originals and never uninstall as
routine testing cleanup. No recording or YouTube publishing was performed for this
delivery checkpoint.


## Default stream-key reuse correction — 2026-11-10

YouTube permits multiple scheduled broadcasts to share the default stream key.
Use the selected event's existing key; no new key, key copy/paste or manual rebinding
is required solely because another scheduled event uses it. The corrected app
reads only the selected event and bound stream, preserving channel/profile,
inactive/ready health, RTMPS, generation and binding readback checks. The old
“Another unfinished event uses this stream” refusal was app policy, not a YouTube
restriction, and is removed. Creating a second scheduled event with the same key
could not bypass that old policy.

The owner explicitly deferred advanced concurrent-use mitigation to
[issue #65](https://github.com/smith3v/stream14/issues/65). Do not infer exclusivity
from these checks: another encoder or an auto-start sibling using the key can
conflict/race, and the app does not inspect/change other broadcasts. Initial start
and explicit resume still refuse active ingestion; existing same-event automatic
reconnect keeps its previous admitted-context rules. No conflict incident has been
observed. No Studio key/event settings were changed for this implementation.

For the next separately attended five-minute test, keep one disposable Unlisted
scheduled event selected, auto-stop off, and its current default stream key. Refresh
and verify the channel/title/visibility in the corrected build. Explicitly confirm
Go Live, check second-device reception, then confirm End and retain the local file.
Do not claim a physical pass from fixture/native checks. A failed preparation can
leave healthy local recording running; Stop recording and keep that file while
investigating rather than allowing an unintended long recording.

## Preview return after an app switch — 2026-11-10

TestFlight 0.3 (4) owner finding: after **Open camera**, switching to Codex and
returning showed the overlay over a black camera picture. This was preview only,
with the phone upright/portrait throughout and no rotation. The prior foreground
handler restored the overlay and read-only YouTube state, but not camera capture.
The reviewed fix will restore only explicitly requested preview after old capture
teardown; recording/upload interruption still requires deliberate restart. Native
startup now checks pending stop after its awaited work, and old capture callbacks
cannot stop a new generation. Preparing/closing shows a progress state.

Physical regression remains pending on a replacement build. Select one visit,
**five minutes TOTAL**, no Google or publishing:

1. Open camera in portrait, verify moving camera picture, switch to Codex for
   five seconds, return and verify moving camera picture plus overlay without
   tapping Open camera again. Repeat twice; repeat in landscape only if time permits.
2. Close camera, switch away/back: it must stay closed. A setup/permission failure
   must remain actionable without an automatic retry loop.
3. In a separate selected visit with a new expendable local clip, background while
   recording: file interruption remains honest and no new recording starts on
   return. Keep originals. After a normal foreground Stop recording, an app switch
   should again restore preview only.

No phone recording, publishing or TestFlight replacement delivery is established
by the deterministic native-boundary tests; they verify ownership and ordering,
not real camera pixels or physical audio.


The merged-main Development candidate at source `1960df2` is normally signed and
built, but not installed. Use the [prepared candidate handoff and timed preview-only
card](2026-11-10-merged-main-phone-candidate.md) for the next separately coordinated
visit; it includes installation/wrap-up in the five-minute total. No recording,
broadcast or TestFlight replacement is part of that card.
