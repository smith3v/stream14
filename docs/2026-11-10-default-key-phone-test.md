# Default-key development phone check

Preparation date: 2026-11-10. **Short development-build broadcast succeeded; read-only original-file measurements are recorded below.**
The owner requested connected-phone testing without a new TestFlight upload.
The in-place development installation replaces TestFlight on that phone while
retaining the same bundle container. Never uninstall, reset, or delete recordings.

## Prepared source and binary

Own clone `/private/tmp/stream14-default-phone-check` starts from reviewed
`32bb4b3903c7442068d222b3e8f88005bb9375f9`, app source `625df2a`. It contains
only the default-key change, not unmerged PR #63 interface or #64 preview recovery.
The native Debug build succeeded with the shared Stream14 scheme and its branding
action, exact pinned fork `497f742`, and automatic normal development signing.
Existing public OAuth client/callback and Apple team remain in ignored local
configuration. The actual product is 0.3 (4), `com.smith3v.stream14`, teal AppIcon.
That identity is unchanged; installation route/source distinguishes it from the
previous TestFlight binary.

Strict signature verification passed. The unexpired development provisioning
profile includes the connected iPhone 13 mini. Public OAuth client and callback,
app identifier/entitlements, icon and unchanged tested runtime tree were checked.
Read-only device inventory showed iPhone 13 mini, iOS 27.2, wired/paired/connected,
Developer Mode enabled. Owner also confirmed recording stopped and phone unlocked.
Preparation initially performed only read-only device inspection. Installation and
ordinary launch subsequently completed as recorded below; this agent did not open
camera, record, authenticate or publish.

Private evidence: `/private/tmp/stream14-default-phone-preparation.json`,
`stream14-default-phone-readiness.json`, `stream14-default-phone-build.log`, and
`stream14-default-phone-signature.log`. Product:
`/private/tmp/stream14-default-phone-build/Build/Products/Debug-iphoneos/Stream14.app`.
The prepared install/ordinary-launch script and private device identifier remain
outside Git. It does not uninstall, terminate separately, seed fixtures or inject
media-test environments. It verifies the prepared binary hash before installation.

## Attended boundary

Wait for root's explicit operator go after the five-minute TOTAL clock starts.
Installation, prompts, setup, selected event confirmation, media test and wrap-up
all count. Root owns Firefox, operator Go Live/End confirmation and observations.
No test starts automatically from this document or the prepared script.

Use only the disposable Unlisted test event selected by the owner. Default key
sharing is permitted by this reviewed change; concurrent publisher/auto-start
coordination is explicitly deferred in issue #65. Do not create keys, rebind,
change or end unrelated events. Keep foreground for this test: preview recovery
from PR #64 is not in this candidate. Record actual receiver/YouTube/file state;
connection alone is not Live. Stop at wrap-up and preserve all originals.

An installation/launch success is development evidence, not a TestFlight regression
or a broadcasting pass. Record exact actual results separately after execution.


## In-place installation and ordinary launch

Root explicitly started the five-minute TOTAL operator clock and authorized the
in-place installation after the owner confirmed recording stopped and the phone
unlocked. Native `devicectl device install app` exited 0 in 6.722 seconds. No
uninstall, data reset, recording deletion or separate termination was used.

The first launch invocation stopped locally with exit 64: installed devicectl
rejected an empty JSON environment dictionary. It did not launch the app. The
corrected invocation omitted that option and stripped all `DEVICECTL_CHILD_`
variables from the CLI environment; ordinary launch exited 0 in 0.462 seconds,
with no app arguments or harness modes. The source and normal signed binary are
unchanged. This is a development installation of 0.3 (4), not a new TestFlight
build or a broadcasting pass.

Private evidence: `/private/tmp/stream14-default-phone-install.json`,
`stream14-default-phone-install-outcome.json`, `stream14-default-phone-launch-retry.json`,
`stream14-default-phone-launch-outcome.json`, and the updated preparation JSON.
Root owns any subsequent owner-confirmed media, event and receiver observations.


## Observed attended result

After in-place installation, the owner confirmed the intended channel and selected
Unlisted test event. The setup-only visit lasted 238 seconds. The owner then
explicitly authorized a separate five-minute broadcast visit, including sending
camera/microphone media and ending that disposable event. No YouTube setting,
stream key or unrelated event was changed.

The owner tapped Open camera, then confirmed Go Live in the app (not Record first).
They reported **YouTube shows Live**. On the laptop, the normal YouTube watch page
showed the actual camera image with the composited transparent overlay and active
playback, not merely a socket or Studio monitor. The owner subsequently confirmed
that the spoken test phrase was audible through that YouTube player.

The owner confirmed **End broadcast and local recording**, reported that the event
ended and the local recording was saved. The receiver then finished playback and
showed a past live stream with a finite 1:50 player timeline. This UI duration is
not a measured original-file duration or A/V-sync result. The owner played the new
local file and confirmed camera video, overlay and audible speech. The owner later
provided its exported MP4 locally for read-only offline analysis. No media or
private event/channel identifiers are included in this report or Git.

| Check | Evidence / result |
| --- | --- |
| Default-key preparation | Passed on development source `625df2a`; no new key or rebind |
| Channel/event/visibility | Owner confirmed intended channel and selected Unlisted event |
| Live | Owner reported app-confirmed Live; independent laptop watch playback observed |
| Composition | Camera and overlay visually observed on YouTube; owner confirmed local playback |
| Audio | Owner confirmed speech in both the local file and YouTube player |
| End/local backup | Owner confirmed event ended and local file saved; watch playback ended |
| Offline media measurements | Original read/decode completed; measured cadence and limits below |
| TestFlight regression | Not performed: installed build is Development 0.3 (4), not TestFlight |

The broadcast clock started separately from setup. The new movie's directory
modification time was within the planned five-minute window, consistent with the
owner-confirmed stop. Final playback/audio replies arrived later; no measured
five-minute end-to-end communication/confirmation guarantee is claimed. No further
test or capture was started. A read-only phone-directory listing identified the
new file (~226.75 MB), but the copy procedure reached its deadline before starting
any transfer and stopped. The original remains on the phone; the owner supplied
an export afterward. Private timing/listing/response evidence remains in
`/private/tmp/stream14-default-phone-attended.json` and
`/private/tmp/stream14-default-phone-media-list.json`.

This is a successful short end-to-end **development** observation. It does not
qualify a later TestFlight binary, numerical A/V offset, sustained cadence,
reconnect, interruptions, recovery, diagnostic overhead/export, multiple encoders
or long-run A2/A7. Concurrent-key coordination remains explicitly deferred in
[issue #65](https://github.com/smith3v/stream14/issues/65). The original remains
retained; no recording, failed file or recovery copy was deleted.


## Read-only exported-original measurements

The owner's local MP4 has the same recording filename and exact **226,749,360-byte**
size as the new phone-directory entry. Its local SHA-256 was unchanged before and
after all analysis. No phone-side hash was obtained, so this is filename/size and
owner-export provenance, not cryptographic phone-to-download equality. The source
file was never edited, transcoded or deleted. Exact path, identifier, hash and
sampled frame images remain private outside Git.

| Measurement | Result |
| --- | --- |
| Asset duration | 128.433 seconds |
| Video | H.264 / avc1, 1920×1080; 3,821 compressed and decoded media frames |
| Track-reported average rate | 29.762 fps; requested profile remains 30 fps |
| Audio | AAC, 44.1 kHz stereo; decoded audio reaches the asset duration |
| Native readers | Compressed video/audio and decoded video/audio all finished |
| Timestamp checks | No invalid or non-increasing PTS in those traversals |
| Largest video PTS interval | 296.667 ms, between 125.617 and 125.913 seconds |
| Video intervals ≥500 ms | Zero |
| Cadence inference | 39 estimated missing 30 Hz intervals; not an observed pipeline-drop counter |

Three privately sampled frames near the start, middle and end show camera and the
alpha overlay without app controls. This does not test a changing score, repeated
reloads, network outage or the entire recording's visual integrity. The cadence
estimate is rounded timestamp inference; it must not be presented as the app's
measured pipeline-drop percentage or an A2 pass. No qualification-counter JSON was
provided. The near-end timing gap has no established cause from this file alone.
No physical start/end clap alignment was measured, and the YouTube receiver file
was not downloaded/analyzed, so numerical local/receiver A/V sync remains pending.

Private reproducible evidence: `/private/tmp/stream14-default-original-analysis.json`,
`stream14-default-original-metadata.json`, `stream14-default-original-gaps.json`
and `stream14-default-original-provenance.json`. Analysis used the repository's
native qualification reader and public AVFoundation APIs, without additional
phone or provider operations. Successful speech playback is the owner's direct
observation, distinct from the numeric decoder/track checks above.
