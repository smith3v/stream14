# stream14 Privacy Policy

Effective November 9, 2026.

## Recordings and app data

With your permission, stream14 uses your camera and microphone to preview and
record video and audio, including any visible web overlay. Recordings,
associated metadata and numeric diagnostics are stored on your iPhone and
excluded from device backups. Diagnostics describe recording performance and
contain no account or event identifiers, URLs, credentials or media. The app
stores settings and your policy acceptance on the device.

Recordings and their diagnostics stay in the app until you delete them or
remove the app. Delete a recording in **Recordings** to remove its associated
local data. If you export a file, the destination you choose handles that copy.
Manage exported copies at their destination.

## Google Sign-In and YouTube

stream14 uses YouTube API Services. Local recording requires no Google account.
Before connecting YouTube, you agree to this policy and the service terms.
Google processes your sign-in and consent. Its SDK stores credentials in the
iPhone Keychain and may contact Google to restore your saved sign-in or refresh
access. The SDK's privacy disclosures cover account and contact information,
approximate location, user and device identifiers, and usage and other data
for functionality and analytics. See the [Google Privacy Policy](https://policies.google.com/privacy).

With your consent, stream14 uses your Google account identifier and reads your
YouTube channel, scheduled events, stream configuration and broadcast status.
It uses that information to show events, manage the stream you confirm and
check the status of an interrupted broadcast. The app keeps API-provided stream
keys in memory for upload. It stores channel, event and stream identifiers and request
status in protected local files excluded from backups to avoid repeating
unresolved requests. Stored identifiers expire after 30 days and are cleared
when the app next runs its data check.

For events prepared in YouTube Studio, you can save a reusable stream key
in the device-only Keychain. Stream14 uses the key to send video
to YouTube. This option requires no Google sign-in and uses no YouTube event API.
The key stays out of recording metadata, diagnostics and exports.

When you confirm a broadcast, stream14 sends camera video, microphone audio
and the visible overlay directly to YouTube over an encrypted connection.
Google processes that media and connection information. Your event's visibility
settings determine who can watch. See the [stream14 service terms](terms.md)
and [YouTube Terms of Service](https://www.youtube.com/t/terms).

## Web overlays

stream14 loads your saved overlay while the app is active, even when the camera
is closed. The site and the services it loads may receive your IP address,
requested URLs and browser details, and may use cookies during the session.
Their privacy policies apply. stream14 stores your overlay URL in the
device-only Keychain and gives the page no access to camera, microphone or Google
credentials. Clear the URL in Overlay settings to remove it.

## Deleting YouTube data and revoking access

- **Sign out on this iPhone** clears the saved sign-in. The app keeps pending
  request records so it can resolve them safely.
- **Delete saved YouTube API data** signs you out and removes the API data saved
  by stream14 on your iPhone. This leaves your local recordings, Google grant
  and YouTube content in place. Manage your broadcasts in [YouTube Studio](https://studio.youtube.com/).
- **Revoke Google access** requests revocation from Google and clears saved
  YouTube API data on your iPhone. You can also revoke access in [Google Account permissions](https://security.google.com/settings/security/permissions).
  If you revoke access there, the app clears stored YouTube data when it detects
  that access has been withdrawn.
- **Remove stream key** in YouTube settings deletes the manually saved credential
  from this iPhone. Manage or reset the key in YouTube Studio.

After deletion or expiry, the app may retain a marker without account or event
identifiers until you resolve pending requests in YouTube Studio and confirm
their resolution in the app.

## Developer access and contact

The developer does not run a server that collects your recordings, account data
or usage analytics. stream14 does not sell personal data or use it for advertising
or cross-app tracking. Apple may share feedback and crash information with
the developer through TestFlight according to your settings.

For privacy questions, complaints or requests about information you shared with
the developer, contact us through TestFlight feedback. See [Support](support.md).
