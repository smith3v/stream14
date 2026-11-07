# stream14

A native iPhone broadcasting app, currently testing a local HaishinKit media path.

Repository: [smith3v/stream14](https://github.com/smith3v/stream14).

The intended app combines camera video, microphone audio, and a full-frame transparent
web overlay; sends the result to a scheduled YouTube broadcast; and saves a local
video backup. The overlay URL is configurable. The first release targets landscape
1080p30 events lasting one to three hours and distribution through TestFlight.
That is the full-product goal; the immediate MVP records locally without streaming.

**The app now integrates local web-overlay recording.** HaishinKit 2.3.0 core owns
one rear-camera/microphone session and the common preview/file composition.
Open **Overlay** to save/load an HTTPS URL securely on this device, then **Open
camera** and **Record**. Record/Stop, elapsed time, manual overlay hiding, playback
and original-file export use native controls outside the video. Saved recordings
can be permanently deleted individually after confirmation; exported copies are kept. A small writer
adapter confirms AVAssetWriter completion and retains failed/pending files.
No media upload/ingestion connection or export transcode is used. See the
[feasibility evidence and outstanding qualification](docs/feasibility.md).
The integrated development build does not establish M3–M5 or TestFlight delivery.

## Full-app development

Use focused branches from current `main` and target all new PRs to `main`.
The owner restored this workflow on 2026-11-06, superseding the temporary
`codex/full-app` integration branch. [MVP issue #6](https://github.com/smith3v/stream14/issues/6)
is closed following TestFlight delivery/owner review, with qualification limits
retained in the evidence. Full-app implementation follows
[epic #13](https://github.com/smith3v/stream14/issues/13) and the
[full-app plan](docs/2026-11-05-full-app-implementation.md).
Earlier MVP-only sequencing below does not block that work. PRs still require
review and explicit merge authorization.

## Current MVP

Use HaishinKit for rear-camera/microphone capture and, where verified APIs support
it, composition, encoding, and local recording. Load a configurable HTTPS overlay
in WKWebView, capture its full-size transparent image about once per second, and
update the layer over the camera video. Provide a composed preview, Record/Stop,
and a way to play/export the resulting file. Smooth 1080p30 video takes priority
over overlay refresh latency.

Streaming failure must not stop a healthy local recording while storage is available.
If overlay source access/rendering cannot refresh for 10 seconds, hide the overlay
from preview and recorded/streamed video; restore it automatically after recovery.
An unchanged score with successful source access is not an outage.

Deliver and validate this through TestFlight on the testing iPhone 13 mini before
continuing. YouTube login, RTMPS, and simultaneous streaming/backup follow the MVP
review. Xcode-only installation does not complete the milestone. Prefer the native
HaishinKit writer (currently MP4 by default), encode the composition once, and avoid
transcoding on save/export; choose MOV only if it provides a simpler/lower-work path.
See the
[MVP scope and gates](docs/2026-11-01-stream14-design.md#current-milestone-local-recording-mvp).

## Start here

- [Application specification and design](docs/2026-11-01-stream14-design.md)
- [iOS development and TestFlight guide](docs/ios-development-guide.md)
- [Full-app implementation plan](docs/2026-11-05-full-app-implementation.md)
- [First-milestone implementation plan: local-recording MVP](docs/2026-11-01-stream14-implementation.md)
- [Instructions for development agents](AGENTS.md)

## Initial choices

| Area | Decision |
| --- | --- |
| Platform | iPhone; initial deployment target iOS 27.0 |
| Minimum performance device | iPhone 13 mini; also validate iPhone 15 and 17 families |
| Interface | SwiftUI with small UIKit bridges where required |
| App identity | com.smith3v.stream14; owner confirmed 2026-11-02 |
| Media | HaishinKit as the first capture/composition/recording experiment; RTMPS deferred |
| Overlay | User-provided HTTPS URL, full video canvas, transparency preserved |
| Backup | Same composition and audio as the outgoing video; survives network outages |
| Distribution | Owner and a few invited TestFlight testers |
| Hosting | Public GitHub repository: smith3v/stream14 |
| License | BSD-3-Clause |

HaishinKit 2.3.0 and its runtime dependency Logboard 2.6.0 are linked. Package.resolved
also records upstream package-level transport dependencies that are not linked to
the app. Google Sign-In and transport products remain deferred.

## Next milestone

[Issue #2](https://github.com/smith3v/stream14/issues/2) / [PR #7](https://github.com/smith3v/stream14/pull/7)
is merged. [Issue #3](https://github.com/smith3v/stream14/issues/3) / PR #8 is also
merged; its [report](docs/feasibility.md) records local-media evidence. Issue #4 / [PR #9](https://github.com/smith3v/stream14/pull/9) is merged.
Issue #5 integrates web-overlay recording with explicit writer failure handling; issue #6
qualifies and delivers the MVP through TestFlight. The implementation plan ends at
that review. Keep recording independent of future transport; broadcasting follows
MVP owner review.

## License

[BSD 3-Clause](LICENSE), copyright 2026 Slava Kuznetsov. Full dependency notices are bundled in
[ThirdPartyNotices.txt](Stream14/ThirdPartyNotices.txt) and accessible in the app.

Development experiments are currently limited to 15 minutes. Longer whole-app
qualification is deferred. The main app has a teal camera/14 icon; separate UI tests
use a purple flask/UI icon. See [icons and build integration](docs/app-icons.md).
