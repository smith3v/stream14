# stream14 local-recording beta privacy

Effective: 2026-11-05. This policy covers the local-recording beta. YouTube login,
streaming and cloud recording are not implemented.

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

Loading an overlay explicitly contacts the HTTPS address you choose and any
resources requested by its webpage. The reference-overlay button selects a public
webpage; Load starts requests. The website and its providers can receive ordinary
web-request information, including your IP address, requested URL and browser
information. URLs can contain private tokens: choose trusted services and do not
post such URLs in public reports. The website's own privacy policy applies to its
handling of those requests. stream14 does not upload camera/microphone recordings
to the overlay website and denies webpage camera, microphone, location and motion
permission requests.

The complete configured URL is saved in this iPhone's device-only Keychain and is
accessible to the app while unlocked. WebKit uses a nonpersistent website data
store. No native credentials or media access are exposed to webpage JavaScript.
Clearing the URL and choosing Load removes the saved URL and disables the overlay.

## Developer collection and Apple beta services

stream14 has no developer-operated collection backend, advertising, analytics or
third-party crash-reporting SDK. The app does not track you across apps or websites.
It uses HaishinKit and Logboard locally for media processing and local diagnostic
logging. The app privacy manifest declares elapsed-time calculations for overlay
freshness and app-container file metadata for safe deletion; neither is used for
fingerprinting or sent to the developer by stream14.

Apple operates TestFlight and may provide beta feedback and crash information under
Apple's terms and your settings. If you voluntarily send feedback or attach files,
the developer receives what you submit. Do not include private recordings or
secret-bearing overlay URLs in public GitHub issues.

## Questions and changes

Use the [support instructions](support.md) for privacy questions or problems. This
policy must be reviewed before adding broadcasting, accounts, telemetry or other
new data flows. The source-code license is separate from this privacy policy.
