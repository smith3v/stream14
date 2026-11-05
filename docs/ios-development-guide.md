# iOS development and TestFlight: a first-project guide

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
   preferably unlisted, with a dedicated ingestion stream and auto-stop disabled.
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
run stalled. The production sheet stops when backgrounded and requires explicit Load.
Markdown local links/fences and `git diff --check` passed. No personal signing
settings, raw device diagnostics or camera recordings are committed. M2 saved
web-overlay composition, camera performance under WebKit load, two-minute combined
media outage, M3–M5 and TestFlight remain stage #5/#6 work. A short renderer test
does not qualify a long recording or broadcasting.

### Stage 4 integrated recording checks

Use **Overlay**, enter an HTTPS URL (or **Use reference URL**), then **Load overlay**
and close the settings sheet. Loading stores the complete URL in device-only
Keychain and begins network access. An empty URL explicitly disables it. Opening
the app does not fetch a saved URL. **Open camera** requests camera/microphone
permission and starts the composed preview. Keep the phone landscape with the rear
camera upright, then **Record** / **Stop recording**. The timer/status are native
UI, excluded from output. Manual hiding changes both preview and file composition.
A small source-browser strip remains visibly attached; it is not the camera preview.

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
