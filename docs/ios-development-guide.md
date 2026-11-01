# iOS development and TestFlight: a first-project guide

Checked: 2026-11-01. Read the [application specification](2026-11-01-stream14-design.md)
for product behavior and the [implementation plan](2026-11-01-stream14-implementation.md)
for development order. This guide explains setup; it does not mean those steps have
already been performed.

## The essential terms

| Term | What it means for this project |
| --- | --- |
| Xcode | Apple's Mac application for editing, building, debugging, signing, and uploading iOS apps. Command Line Tools alone are insufficient. |
| Swift / SwiftUI | The programming language / Apple's native UI framework. |
| Simulator | A simulated iPhone on the Mac; useful for screens and tests, insufficient for proving this app's camera, heat, or streaming reliability. |
| SDK / deployment target | The APIs available to build against / the oldest iOS version allowed to run the app. We initially target iOS 27.0. |
| Bundle identifier | The app's stable unique identity, usually reverse-domain text. It connects signing, App Store Connect, and Google's iOS OAuth client. |
| Signing / provisioning | Apple's mechanism for identifying the developer and permitting a build to run on devices. Start with Xcode's automatic signing. |
| Scheme / target | A saved build/test configuration / a product such as the app or its tests. Our future shared scheme will be Stream14. |
| Archive | A distribution build produced by Xcode, then validated/uploaded through Organizer. |
| App Store Connect | Apple's portal for app records, builds, TestFlight invitations, feedback, and distribution information. |
| TestFlight | Apple's beta distribution service. It does not require publishing the app publicly on the App Store. |
| OAuth | Giving the app permission to act on YouTube through Google, without giving the app your Google password. |
| Broadcast / ingestion stream | The scheduled YouTube event viewers watch / the endpoint and stream key an encoder sends media to. They are different API resources. |

## 1. Install full Xcode

The initial environment inspection found Apple Command Line Tools selected and no
full Xcode application in /Applications. Install a current stable Xcode release
that supports the phone's iOS 27 version and the Mac's installed macOS. Check
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

Before the first signed app target is created, choose a bundle identifier controlled
by the owner's team; `com.smith3v.stream14` is a proposed value, not a registered
identifier. Keep the chosen identifier identical in Xcode, Apple identifiers,
App Store Connect, and Google's iOS OAuth client. Avoid renaming it casually after
distribution begins.

When the project exists, its first milestone is a basic app running on the phone.
Then test camera access with meaningful permission strings. A preview on Simulator
does not qualify a real camera or sustained media performance.

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

Create one ordinary Xcode iOS App project at the repository root using SwiftUI and
Swift, with project Stream14.xcodeproj and shared scheme Stream14. Do not create a
second Git repository from Xcode. Keep shared project/scheme files in Git and
user-specific Xcode state out of it. The initial repository deliberately has no
generated project yet.

After the project exists, confirm its actual scheme and destinations:

```sh
xcodebuild -list -project Stream14.xcodeproj
xcodebuild -showdestinations -project Stream14.xcodeproj -scheme Stream14
```

Record an installed simulator name and OS in this guide before adopting a concrete
test command. The future command shape is:

```text
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=<installed device>,OS=<installed OS>' test
```

Angle-bracket values above are placeholders, not a currently runnable command or
evidence that a test passed. CI must use the same verified shared scheme and a
runner with the required Xcode/SDK; do not add a workflow that only looks plausible.

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
   and clear steps for the reviewer. Explain camera/microphone use, Google/YouTube
   setup, local rehearsal, and a reproducible overlay/demo. Arrange review access
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
