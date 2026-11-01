# stream14

A native iPhone broadcasting app, currently at the specification stage.

The intended app combines camera video, microphone audio, and a full-frame transparent
web overlay; sends the result to a scheduled YouTube broadcast; and saves a local
video backup. The overlay URL is configurable. The first release targets landscape
1080p30 events lasting one to three hours and distribution through TestFlight.

**There is no application implementation or Xcode project yet.** Browser-overlay
capture and sustained performance must first be proven on an iPhone 13 mini.

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
| Media | Apple capture/compositing/recording frameworks; RTMPS transport to YouTube |
| Overlay | User-provided HTTPS URL, full video canvas, transparency preserved |
| Backup | Same composition and audio as the outgoing video; survives network outages |
| Distribution | Owner and a few invited TestFlight testers |
| Hosting | Public GitHub repository: smith3v/stream14 |
| License | BSD-3-Clause |

No third-party packages have been added. The specification identifies two candidates
that need evaluation before use: Google Sign-In and HaishinKit's RTMP products.

## Next milestone

Install full Xcode, run a minimal camera-and-overlay experiment on the iPhone 13 mini,
and verify that the saved video contains the transparent web overlay correctly.
See the [implementation plan](docs/2026-11-01-stream14-implementation.md).

## License

[BSD 3-Clause](LICENSE), copyright 2026 Slava Kuznetsov. Dependency notices will be
added when dependencies are selected.
