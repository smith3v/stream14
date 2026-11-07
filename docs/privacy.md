# stream14 beta privacy

Effective: 2026-11-07. This policy covers local recording and optional Google
authorization. YouTube media upload and cloud recording are not implemented by
the authorization stage.

## Camera, microphone and local files

stream14 requests camera and microphone permission when you open the camera to
prepare recording. It saves camera video, microphone audio and the visible web
overlay in MP4 files on your iPhone. Recording metadata includes creation time,
completion/failure state and writer frame/drop measurements. These files stay in
the app's container, excluded from device backup. The developer does not receive
your recordings or metadata automatically. No Photos permission is requested.

You choose whether to export an original recording through Apple's share interface.
The selected destination or recipient then handles that copy under its own policies.
Delete recording requires confirmation and removes the selected original and its
metadata from the app. Exported copies remain where you saved them. Deleting the
app removes its local recordings; export anything you want to keep first.

## Web overlays and network requests

Applying an overlay URL contacts the HTTPS address you choose and any
resources requested by its webpage. The reference-overlay button selects a public
webpage; Apply URL saves it and starts requests while the app is active. A saved
overlay also resumes requests when the app becomes active. The website and its providers can receive ordinary
web-request information, including your IP address, requested URL and browser
information. URLs can contain private tokens: choose trusted services and do not
post such URLs in public reports. The website's own privacy policy applies to its
handling of those requests. stream14 does not upload camera/microphone recordings
to the overlay website and denies webpage camera, microphone, location and motion
permission requests.

The complete configured URL is saved in this iPhone's device-only Keychain and is
accessible to the app while unlocked. WebKit uses a nonpersistent website data
store. No native credentials or media access are exposed to webpage JavaScript.
Applying an empty URL removes the saved URL and disables the overlay.

## Optional Google and YouTube authorization

Connect YouTube opens Google's supported system-browser authorization through the
Google Sign-In SDK. Google receives authorization requests and handles account
selection, consent and token services under its [privacy policy](https://policies.google.com/privacy).
The app requests YouTube access to manage the selected broadcast in later stages;
connecting alone never uploads camera or microphone media. Without Google setup,
local recording remains available and no Google authorization request is made.

The SDK stores its credentials in the iPhone Keychain. stream14 does not copy them
to preferences, files, an app backend or overlay JavaScript. A fresh access token
is held in memory only for authorized API use. Sign out removes this iPhone's SDK
session; Revoke Google access additionally requests revocation from Google. If
revocation fails, the app says so and you can review access in your Google Account.
These actions clear the app's in-memory YouTube channel/event information and keep
local recordings and overlay settings. When you explicitly refresh scheduled events,
the app sends authorized read requests directly to YouTube and holds channel/event
metadata in memory for selection. It does not save raw API responses or ingestion
keys, and selecting an event alone does not publish or change it.

GoogleSignIn 10.1.0's bundled privacy manifest declares Google-side account/contact,
coarse location, user/device identifiers and usage/other data for app functionality
and some analytics purposes, with tracking declared false. The SDK's included
AppCheckCore and GoogleUtilities products are required dependencies; stream14
adds no separate analytics or crash SDK and does not configure optional App Check
attestation. Review Google's disclosures and the aggregate archive privacy report
before distributing a build with accounts enabled. Provider processing is distinct
from collection by the stream14 developer.

## Developer collection and Apple beta services

stream14 has no developer-operated collection backend, advertising, analytics or
third-party crash-reporting SDK. The app does not track you across apps or websites.
It uses HaishinKit and Logboard locally for media processing and local diagnostic
logging. The app privacy manifest declares elapsed-time calculations for overlay
freshness, app-container file metadata for safe deletion, and app-only UserDefaults
for the selected nonsecret session profile. These are not used for
fingerprinting or sent to the developer by stream14.

Apple operates TestFlight and may provide beta feedback and crash information under
Apple's terms and your settings. If you voluntarily send feedback or attach files,
the developer receives what you submit. Do not include private recordings or
secret-bearing overlay URLs in public GitHub issues.

## Questions and changes

Use the [support instructions](support.md) for privacy questions or problems. This
policy must be reviewed before adding broadcasting, accounts, telemetry or other
new data flows. The source-code license is separate from this privacy policy.
