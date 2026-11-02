# iOS development and TestFlight: a first-project guide

Checked: 2026-11-02. Read the [application specification](2026-11-01-stream14-design.md)
for product behavior and the [implementation plan](2026-11-01-stream14-implementation.md)
for development order. This guide explains setup; it does not mean those steps have
already been performed.

## Current stage: local MVP first

The immediate milestone will record rear-camera video and microphone audio with a
configurable transparent webpage overlay. The current app only displays its setup
screen; recording and web overlays are not implemented. HaishinKit is the first capture/composition/encoding/
recording experiment. The owner reviews the result before broadcasting is added.
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
and basic playback/export. After a smooth 30-minute device test and failure checks,
review M1–M5 after TestFlight delivery before expanding UI or streaming. A three-hour broadcasting
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
bundle identifier. Confirmation does not establish Apple registration or signing.
Keep the identifier identical in Xcode, Apple identifiers,
App Store Connect, and Google's iOS OAuth client. Avoid renaming it casually after
distribution begins.

Open Stream14.xcodeproj. Select the blue project in the navigator, then TARGETS →
Stream14 → Signing & Capabilities. Keep Automatically manage signing enabled and
select your own Team. No team is fabricated or committed by this stage. Select the
connected 13 mini in the toolbar and press Run (▶ or ⌘R). Success is the stream14
screen with “App setup ready” and an explanation that recording is not available.
Check it in portrait and both landscape orientations. If signing fails, use the
displayed Xcode diagnostic; share only error text, never credentials or keys.

Selecting a team may edit project.pbxproj. Keep personal signing changes local;
inspect the diff before committing. For terminal builds, pass DEVELOPMENT_TEAM as
a local build-setting override instead of saving it in the shared project. The
test targets also need your team if running tests on a physical phone.

This stage requests no camera/microphone permissions. Camera access and honest
purpose strings belong to the media stage. Simulator success does not qualify a
real camera or sustained performance.

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
external packages or project generator. It contains:

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
  the waiting build/codesign operation was canceled. Installation/launch remains
  pending. Next session, reconnect/unlock the phone, run Stream14 from Xcode, and
  handle normal Keychain signing prompts in macOS. Do not count this stage's
  physical-device acceptance as complete. Local signed-build log:
  /tmp/stream14-issue2-signed-device-build.log (contains private signing/device
  details; never attach it publicly). No media gate or TestFlight upload passed.
- No packages, camera/microphone permission strings, networking, entitlements,
  credentials, recordings, or signing profiles are added. User-local Xcode state,
  build/test results, signing material, and captured media remain ignored.
- Independent review: a separate agent inspected the full diff and actual project,
  scheme, app, tests, docs, and ignore rules; no material code/project/privacy
  findings. Focused review caught the unresolved contrast audit; explicit
  Color.primary fixed it and all four native tests then passed. Physical launch
  remains the open acceptance item, not an agreed waiver.
- Next stage, after this stage's PR merges and device acceptance: Task 3,
  HaishinKit feasibility. Re-run the scheme/destination and build/test commands above
  before selecting a stable package; do not implement recording APIs from guesses.
  TestFlight still needs owner membership/agreements, app registration, signing,
  metadata/privacy review, and the later local-media implementation and M1–M5 checks.

Use unit tests for state/API behavior, UI tests and manual inspection for screens,
and physical phones for real video/audio, transparent browser capture, network
recovery, heat, and long recordings. Test broadcasts should be unlisted and identified
clearly as tests. Do not experiment on a real scheduled public event.

## 5. TestFlight, step by step

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
