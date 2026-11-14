# stream14 beta support

The TestFlight beta records locally or broadcasts to an existing scheduled
YouTube encoder event. It requires iOS 27 or later. Keep the app in the foreground
and the phone unlocked while recording or broadcasting. After an interruption,
recording and upload require an explicit restart.

## Report a problem

For nonprivate reports, [open a GitHub issue](https://github.com/smith3v/stream14/issues/new).
Include app version/build from TestFlight, iPhone model, iOS version, the action
that failed and the visible status. Do not post private media, full overlay URLs
with tokens, device identifiers or signing/account information. TestFlight's
feedback option is another route for installed beta testers; check attachments
before submitting. Never send passwords or verification codes.

For privacy questions or complaints you want to keep private, contact the
developer through TestFlight feedback. Leave out sensitive attachments.

## Using stream14

- In **Session**, choose the profile before opening the camera. Tap **Check
  camera and sound** for preview. Allow camera and microphone in iOS Settings
  if previously denied. Apply an empty URL in Overlay settings to disable an
  unavailable source.
- For streaming, agree to the privacy policy and terms, connect YouTube,
  and choose an event in the intended channel. Google is optional for local
  recording. Google OAuth test users and TestFlight testers are separate lists.
- Selecting an event or opening preview never publishes. **Start recording
  and streaming** confirms the channel, event, visibility and profile. Disable
  auto-stop for the event in Studio. Auto-start events can go live as soon as
  you confirm and upload begins; use an Unlisted event for rehearsal.
- Recording, Upload and YouTube states are separate. A healthy local file continues
  after upload failure. A backup warning does not establish YouTube failure.
  **End session** requires confirmation. If YouTube end is unconfirmed, check
  Studio and reconcile in the app. After interruption, reopen the camera and
  explicitly confirm **Resume same event** if offered.
- A source failure hides the overlay after about ten seconds; fresh source/render
  restores it unless manually hidden. Camera/local writing remain independent.
- **Recordings** retains originals and completion/failure provenance. Play and
  Export use the original; verify the Files copy opens. An incomplete file may
  offer recovery to a separate copy. Recovery may omit an unfinished tail or fail;
  a readable start does not prove the complete file is intact. Originals remain.
- A new recording's qualification summary is private numeric evidence; load/export
  it separately from media. Missing/incomplete reports and unavailable observations
  are legitimate and do not prove a successful broadcast.
- Delete only after checking the selected original/copy/group and confirming.
  Exported copies remain. No automatic cleanup occurs. Export important files
  before app removal; prefer in-place TestFlight updates.
- **Sign out on this iPhone** retains pending API request journals for safety.
  **Delete saved YouTube data** removes their identifiers and signs out locally;
  it does not end a remote event or revoke consent. **Revoke Google access** also
  requests remote SDK revocation. Use [Google access settings](https://security.google.com/settings/security/permissions)
  for external revocation. After data deletion/access loss, resolve previous
  requests in Studio and explicitly confirm resolution before publishing again.
  A nonidentifying guard remains until then. Recordings and overlay settings remain.

Beta expiration does not delete recordings. Install updates in place and
export valuable files before removing the app.

See the [privacy policy](privacy.md), [service terms](terms.md), [YouTube terms](https://www.youtube.com/t/terms) and the in-app Third-party notices. The
[BSD-3-Clause source license](https://github.com/smith3v/stream14/blob/main/LICENSE) covers the source; it is not a privacy
policy or a promise of uninterrupted beta availability.
