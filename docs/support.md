# stream14 beta support

The broadcasting beta is distributed through TestFlight and supports optional
broadcasting to an existing scheduled YouTube encoder event. The historical
0.2 (3) beta records locally.

Both versions target iOS 27 or later and the iPhone 13 mini. Camera video,
microphone audio and an optional HTTPS web overlay share the composed preview and
local H.264/AAC MP4. Long-run qualification remains pending. Keep the app foreground;
backgrounding or interruptions stop capture and require an explicit restart.

## Report a problem

For nonprivate reports, [open a GitHub issue](https://github.com/smith3v/stream14/issues/new).
Include app version/build from TestFlight, iPhone model, iOS version, the action
that failed and the visible status. Do not post private media, full overlay URLs
with tokens, device identifiers or signing/account information. TestFlight's
feedback option is another route for installed beta testers; check attachments
before submitting. Never send passwords or verification codes.

For privacy questions or complaints you want to keep private, contact the
developer through TestFlight feedback. Leave out sensitive attachments.

## Full-app candidate checks

- **Preparation** selects profile, connects YouTube and refreshes the actual
  channel/event. Read and agree to the privacy policy/service terms before Connect
  or Restore. Google is optional for local rehearsal. Google Testing users and
  TestFlight testers are separate; Testing authorization can expire after seven days.
- **Session** opens the camera for preview, local recording and manual overlay
  hide/reload. Allow camera/microphone in iOS Settings if previously denied.
  Apply an empty overlay URL to disable an unavailable source deliberately.
- Selecting a tab/event or opening preview never publishes. **Go Live** shows
  channel, event, visibility and profile for confirmation. Auto-start events may
  become Live from first confirmed upload. Check the intended Unlisted test event
  and its auto-stop setting in Studio before any qualification upload.
- Recording, Upload and YouTube states are separate. A healthy local file continues
  after upload failure. A backup warning does not establish YouTube failure.
  **End broadcast** requires confirmation; uncertain End needs Studio/read-only
  reconciliation. After interruption, reopen camera and explicitly confirm Resume
  for the same event. Nothing automatically resumes on app launch.
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

The old local-only beta uses its historical Overlay/Open camera controls. Its
[delivery record](https://github.com/smith3v/stream14/blob/main/docs/testflight-delivery.md) remains separate. A routine attended phone
check has a five-minute total budget including setup; longer qualification needs
explicit agreement. Beta expiration does not delete recordings: install a verified
replacement in place and retain/export valuable files.

See the [privacy policy](privacy.md), [service terms](terms.md), [YouTube terms](https://www.youtube.com/t/terms) and the in-app Third-party notices. The
[BSD-3-Clause source license](https://github.com/smith3v/stream14/blob/main/LICENSE) covers the source; it is not a privacy
policy or a promise of uninterrupted beta availability.
