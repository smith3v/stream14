# stream14 beta support

stream14 is currently a local-recording beta for iPhone with iOS 27 or later.
Rear-camera video, microphone audio and an optional HTTPS web overlay are saved
as a local H.264/AAC MP4. YouTube login and broadcasting are not available.
Performance qualification targets the iPhone 13 mini; longer-run qualification is
still pending. Keep the app in the foreground and the rear camera upright in
landscape while recording. Backgrounding or interruptions stop the session; start
again explicitly after returning.

## Report a problem

For nonprivate reports, [open a GitHub issue](https://github.com/smith3v/stream14/issues/new).
Include app version/build from TestFlight, iPhone model, iOS version, the action
that failed and the visible status. Do not post private media, full overlay URLs
with tokens, device identifiers or signing/account information. TestFlight's
feedback option is another route for installed beta testers; check attachments
before submitting. Never send passwords or verification codes.

## Common checks

- Allow camera and microphone in iOS Settings for stream14 if previously denied.
- Choose Overlay → Use reference URL → Load overlay to try the reference page.
  Close Overlay, open the camera and record. A separate scoring backend's health
  is not proved by a successful document load.
- Network loss should hide an unavailable overlay after approximately ten seconds;
  local camera/audio recording continues while capture and writing are healthy.
  A fresh successful page/render restores it unless Hide overlay manually is on.
- Stop before playback/export. Export original file uses the system share sheet;
  choose Save to Files and verify the saved file opens.
- To reclaim space, choose Delete recording, check the date and confirm. Exported
  copies remain. There is no automatic cleanup.
- Export important recordings before deleting/reinstalling the app. Prefer an
  in-place TestFlight update. A beta expires; install a replacement build from
  TestFlight when available. See the [delivery record](testflight-delivery.md).

See the [privacy policy](privacy.md) and the in-app Third-party notices. The
[BSD-3-Clause source license](../LICENSE) covers the source; it is not a privacy
policy or a promise of uninterrupted beta availability.
