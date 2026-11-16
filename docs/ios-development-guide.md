# iOS development and release

Use the shared **Stream14** scheme in `Stream14.xcodeproj`. The app is
`com.smith3v.stream14`, targets iPhone on iOS 27 or later, and uses Swift 6.
The app builds and records locally without Google configuration.

## Xcode and Simulator

Install full Xcode with an SDK and Simulator runtime that support the deployment
target. Select that Xcode in Settings → Locations, or set `DEVELOPER_DIR` to
its `Contents/Developer` for the shell. From the repository root:

```sh
xcodebuild -list -project Stream14.xcodeproj
xcodebuild -showdestinations -project Stream14.xcodeproj -scheme Stream14
xcrun simctl list devices available
```

Create or select an iPhone 13 mini in Xcode's Devices and Simulators. Set
`STREAM14_SIMULATOR_ID` locally from the list, then run hosted and UI tests:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination "platform=iOS Simulator,id=$STREAM14_SIMULATOR_ID" test
```

Use `-only-testing:Stream14Tests` or `-only-testing:Stream14UITests` to select a
suite. Hosted tests run in the main app. The separate UI test runner has a
purple icon and display name **s14 UI Tests**. Use the shared scheme's post-build
branding action for physical installs; before using `test-without-building`,
verify the existing runner was branded and signed. Use distinct DerivedData
paths for concurrent builds and new paths for result bundles if you save them.
The main icon lives in `Stream14/Assets.xcassets/AppIcon.appiconset`; the
separate runner source and build hook are in `Tools/`.

An unsigned iPhone Release build checks the device SDK and linked packages:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## Development on iPhone

In Signing & Capabilities, select your Apple team locally and use automatic
signing for the app and test targets. Keep local team changes out of focused
commits. Connect an unlocked iPhone, approve Trust This Computer, and enable
**Settings → Privacy & Security → Developer Mode** if required. Select the
phone and run from Xcode to install in place. macOS may separately ask to use
the signing key in Keychain. If iOS rejects the developer signature, check
**Settings → General → VPN & Device Management** for developer trust. A
successful run opens stream14 on the phone; it is not a TestFlight install.

Use `xcrun devicectl list devices` to identify the phone for command-line builds.
With `STREAM14_DEVICE_ID` set privately, an alternative to Xcode Run is:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination "id=$STREAM14_DEVICE_ID" -derivedDataPath /tmp/stream14-device \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
xcrun devicectl device install app --device "$STREAM14_DEVICE_ID" \
  /tmp/stream14-device/Build/Products/Debug-iphoneos/Stream14.app
xcrun devicectl device process launch --device "$STREAM14_DEVICE_ID" com.smith3v.stream14
```

Explain any owner-only steps before an attended visit. Keep device identifiers,
signing details, recordings and result bundles private. Use
[device qualification](qualification-report-template.md) for smoke tests,
disruptions and endurance.

## Google OAuth and YouTube

Enable YouTube Data API v3 in the chosen Google Cloud project. Create an iOS
OAuth client for `com.smith3v.stream14`, with the app's signing team if requested.
Configure the consent screen and declare `youtube.force-ssl`. For a development
project in Testing, add the Google account under Audience → Test users; this
list is separate from TestFlight. Use the channel returned by the API and a
live-enabled YouTube channel with an Unlisted scheduled encoder event and
auto-stop off for testing.

Create the ignored `Config/Local.xcconfig` beside `Config/Google.xcconfig`:

```xcconfig
GOOGLE_CLIENT_ID = YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.YOUR_IOS_CLIENT_ID
```

Use the same client prefix in both values. These IDs are public; no server
client secret is needed. Never put account credentials, tokens or stream keys
in config. An absent or mismatched pair leaves YouTube disconnected.
For a signed build inspect `CFBundleIdentifier`, `GIDClientID` and the callback
in `CFBundleURLTypes` of the archived app's Info.plist.

### Production OAuth

Use a separate production project. Publish the public site, verify
`stream14.app` as a Search Console domain property via DNS TXT with a project
owner/editor, and add it under Branding → Authorized domains. Use stream14's
name, shipped icon, public homepage and privacy/terms URLs, and monitored support
and developer contacts. Use the same privacy URL in Branding as on the homepage.
Follow Google's [brand verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification)
and [scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
instructions. External / In production audience, approved branding and approved
YouTube scope are separate checks.

The only YouTube scope is `https://www.googleapis.com/auth/youtube.force-ssl`.
The app reads channels, scheduled broadcasts and ingestion status, and can
create/bind an ingestion stream and transition the selected existing event
after operator confirmation. Read-only access and `youtube.upload` cannot
perform those writes. The app does not manage uploaded videos or comments.

For the reviewer video, demonstrate the signed build's consent and callback,
actual channel, event selection with upload idle, confirmation, stream creation
and binding for an unbound Unlisted event, receiver playback and confirmed End.
Show the public client ID if requested; mask unrelated private parameters and
credentials. Keep the test scene non-private. Follow the console's demo and
submission instructions.

On the exact production-client build, verify policy links before consent,
cancel back to working local controls, and connect with an eligible account
never on the test-user list. Confirm callback, the intended channel/event and
idle upload through selection. Also test in-place upgrade from a development
grant: a mismatched grant requires connection again, production restore works
on relaunch, and recordings and reconciliation state survive. Verify sign-out,
revoke, local data deletion and the Studio-resolution guard separately; see the
[design](2026-11-01-stream14-design.md#youtube-authorization-and-broadcast-lifecycle).
Track verification and fresh-account results in [issue #80](https://github.com/smith3v/stream14/issues/80).

## Verify a saved YouTube stream key on iPhone

Use a Studio Manager account and two disposable Unlisted encoder events. In
Live Control Room, create one reusable stream key for the iPhone. Assign it to
one upcoming event at a time. Enable Auto-start and Auto-stop.

1. In **Settings → YouTube → Stream key**, paste and save the key with a display
   name. Relaunch and confirm the saved name. Test replacement and confirmed
   removal with a disposable key. Restore the test event’s key for publishing.
2. In **Session**, choose the saved stream-key destination. Check VoiceOver,
   larger text and both landscape orientations on iPhone 13 mini. Confirm that
   preview sends no video. Check that switching to a connected event restores
   its channel, event picker and controls. Saving or replacing a key must leave
   the chosen destination in place. Check **Record only** in both modes.
3. Keep Studio open on another device. Confirm Start names the saved destination
   and enables upload and local saving. Verify Live in Studio. End from Stream14
   and verify that local footage finalizes and Studio ends the event via Auto-stop.
   Prepare the next session. Repeat with the second event using the same key
   without revisiting Settings.
4. In an agreed outage test, interrupt the iPhone’s network while Stream14 is in
   the foreground. Verify upload failure and continued local saving. Check Studio
   before confirming a retry. A short outage may allow the same event to continue.
   Around a minute without ingest can end the event via Auto-stop. A retry then
   may fail or start another prepared event assigned to the key. Record what
   Studio shows and whether the original recording remains playable.

## TestFlight

1. Start from reviewed changes on `main`. Use a new minor version for a release
   containing new merged changes. Keep the build number increasing across
   releases and increment it for replacement uploads. Keep release changes
   separate from feature work.
2. Confirm Apple Developer Program membership, agreements, the matching App
   Store Connect record, and distribution signing. Set the intended OAuth
   configuration, then use **Product → Archive** on the shared scheme with a
   generic iOS device destination. Verify archive identity, version/build,
   signing, OAuth client/callback and third-party notices.
3. Recheck the current [Apple submission requirements](https://developer.apple.com/app-store/submitting/)
   and [privacy details](https://developer.apple.com/app-store/app-privacy-details/)
   against app and SDK behavior, including required reasons, manifests, privacy
   and support links, and encryption classification. Reassess encryption if
   the dependency/transport boundary changed. A successful build does not
   establish platform review or submission compliance.
4. In Organizer, validate and distribute to App Store Connect. Wait for
   processing, resolve any **Missing Compliance** state, set release-specific
   **What to Test**, assign the intended internal group, and confirm **Testing**.
   External TestFlight distribution may require Beta App Review.
5. Update the test iPhone in place via TestFlight and read back version/build.
   Confirm recording inventory and run the relevant [device checks](qualification-report-template.md).
   Report upload, availability, installation, and qualification separately.

### App Privacy disclosures

For public submission, use Organizer's aggregate privacy report from the exact
archive. Evaluate app and SDK flows together. The app's own manifest has an
empty collected-data array; Google Sign-In has its own declarations. Verify
version-specific evidence before omitting an SDK category or purpose. Assess
retained YouTube video/audio and account/event operations, and traffic to the
configured overlay provider. App-local originals and diagnostics are not
automatically uploaded. An aggregate manifest does not inventory network traffic
or establish an overlay provider's practices. Keep this public disclosure review
separate from internal beta validation and TestFlight fields.

## Public site and policies

[stream14.app](https://stream14.app/) is built with Hugo from the repository
root. Cloudflare Pages builds `main` with `HUGO_VERSION=0.169.0` and runs:

```sh
hugo --config website/hugo.toml --minify
```

Publish `website/public`. Watch `website/*`, `docs/privacy.md`,
`docs/terms.md` and `docs/support.md`. Attach `stream14.app` as the custom
domain and verify `/`, `/privacy/`, `/terms/`, and `/support/` over HTTPS
without sign-in. Hugo renders those same Markdown policy sources; edit them
in `docs/`. Policy text and third-party notices are distinct from the source license.
