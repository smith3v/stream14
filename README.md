# stream14

stream14 is a native iPhone app for streaming court sports to a scheduled YouTube
event. It combines a rear camera, microphone, and optional transparent web
scoreboard. The preview, YouTube upload, and local MP4 use the same composition.
A healthy local recording continues if the upload fails. You can also record
locally without a Google account.

## Use the app

1. For streaming, schedule an encoder event in YouTube Studio and turn off
   **Enable auto-stop**. In **Session**, connect YouTube and choose the event.
   Check the channel, title, and visibility.
2. Set an optional HTTPS overlay in **More → Settings → Overlay**. Choose
   **1080p30** (default) or **720p30** before opening the camera. Tap **Check
   camera and sound** and check the picture and microphone meter.
3. In landscape, tap **Record only** or **Start recording and streaming**.
   Confirm the event before going live. **Local saving**, **Upload**, and
   YouTube's **Live** status report different parts of the session.
4. Use **End session** to stop. In **Recordings**, play or export the original,
   try recovery to a separate copy if needed, or delete a recording after confirmation.

Requires an iPhone on iOS 27 or later. Keep the app foregrounded and the phone
unlocked while recording or streaming. See [support](docs/support.md) for help.

## Develop and release

- [Application design](docs/2026-11-01-stream14-design.md): behavior, media
  architecture, and failure handling.
- [iOS development and release guide](docs/ios-development-guide.md): Xcode,
  signing, Google OAuth, TestFlight, and the public site.
- [Device qualification](docs/qualification-report-template.md): runbook
  and acceptance gates.
- [Development workflow](AGENTS.md) and [project issues](https://github.com/smith3v/stream14/issues).

[Privacy](docs/privacy.md) · [Service terms](docs/terms.md) · [BSD 3-Clause
license](LICENSE) · [Third-party notices](Stream14/ThirdPartyNotices.txt)
