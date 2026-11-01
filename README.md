# stream14

A native iPhone broadcasting app, currently at the specification stage.

Repository: [smith3v/stream14](https://github.com/smith3v/stream14).

The intended app combines camera video, microphone audio, and a full-frame transparent
web overlay; sends the result to a scheduled YouTube broadcast; and saves a local
video backup. The overlay URL is configurable. The first release targets landscape
1080p30 events lasting one to three hours and distribution through TestFlight.
That is the full-product goal; the immediate MVP records locally without streaming.

**There is no application implementation or Xcode project yet.** Browser-overlay
capture and sustained performance must first be proven on an iPhone 13 mini.

## Current MVP

Use HaishinKit for rear-camera/microphone capture and, where verified APIs support
it, composition, encoding, and local recording. Load a configurable HTTPS overlay
in WKWebView, capture its full-size transparent image about once per second, and
update the layer over the camera video. Provide a composed preview, Record/Stop,
and a way to play/export the resulting file. Smooth 1080p30 video takes priority
over overlay refresh latency.

Validate this on the 13 mini before continuing. YouTube login, RTMPS, simultaneous
streaming/backup, and TestFlight distribution follow the MVP review. See the
[MVP scope and gates](docs/2026-11-01-stream14-design.md#current-milestone-local-recording-mvp).

## Start here

- [Application specification and design](docs/2026-11-01-stream14-design.md)
- [iOS development and TestFlight guide](docs/ios-development-guide.md)
- [Implementation plan and acceptance gates](docs/2026-11-01-stream14-implementation.md)
- [Instructions for development agents](AGENTS.md)

## Initial choices

| Area | Decision |
| --- | --- |
| Platform | iPhone; initial deployment target iOS 27.0 |
| Minimum performance device | iPhone 13 mini; also validate iPhone 15 and 17 families |
| Interface | SwiftUI with small UIKit bridges where required |
| Media | HaishinKit as the first capture/composition/recording experiment; RTMPS deferred |
| Overlay | User-provided HTTPS URL, full video canvas, transparency preserved |
| Backup | Same composition and audio as the outgoing video; survives network outages |
| Distribution | Owner and a few invited TestFlight testers |
| Hosting | Public GitHub repository: smith3v/stream14 |
| License | BSD-3-Clause |

No third-party packages have been added. HaishinKit's public APIs and device behavior
must be verified during the MVP. Google Sign-In and RTMP products remain deferred.

## Next milestone

Install full Xcode, evaluate HaishinKit's stable APIs, and implement the local-recording
MVP on the iPhone 13 mini. Verify the saved composition, audio, overlay updates, and
a smooth 30-minute run, then review the evidence before adding broadcasting.
See the [implementation plan](docs/2026-11-01-stream14-implementation.md).

## License

[BSD 3-Clause](LICENSE), copyright 2026 Slava Kuznetsov. Dependency notices will be
added when dependencies are selected.
