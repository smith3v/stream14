# Private RTMPS receiver validation — 2026-11-08

This supplemental F6 / issue #19 stage adds a missing F1 evidence route:
real compressed media through the actual shared pipeline and acknowledged RTMPS
socket into an independent receiver. The decoded alignment gate remains failed
(see measurements below). It does not qualify physical camera/WebKit
composition, YouTube interoperability, physical A/V synchronization, 13 mini
performance, long-run queues/memory/thermal behavior, or full-app acceptance.

## Receiver selection

Docker is installed but its daemon is unavailable; ffmpeg and nginx are absent.
A new custom RTMP parser would make protocol correctness part of the fixture under
test. Use the official standalone MediaMTX v1.21.3 Darwin arm64 release instead.
It is MIT licensed, has no app linkage/transitive app dependencies, and is used only
as a private development receiver. The 27,617,580-byte compressed archive matched
its official release checksum:

`bc1a0762fd18ffb413bcd81dcb9a072ac159fbd1f27e79ac6f14598aaac5ed3f`

Sources: [pinned official release and checksums](https://github.com/bluenviron/mediamtx/releases/tag/v1.21.3),
[RTMPS configuration](https://mediamtx.org/docs/features/rtmp-specific-features),
[receiver fMP4 recording](https://mediamtx.org/docs/features/record).
No binary, private key, CA certificate, generated media or raw log belongs in Git.

## Repeating the laptop check

1. Download the pinned archive and `checksums.sha256` from the release, compare
   SHA256 before extracting, and retain the original release LICENSE with the tool.
2. Run `python3 Tools/private-rtmps-receiver.py PRIVATE_DIRECTORY --receiver ABSOLUTE_MEDIAMTX_PATH`.
   Choose a fresh private directory. The tool creates one-day localhost TLS
   credentials, binds only 127.0.0.1:19360, disables unrelated servers, retains all
   recordings, and saves a PID for deliberate shutdown. It never changes trust.
3. Create and boot a disposable iPhone Simulator. Build the shared Stream14 scheme
   with Debug `build-for-testing`, a private DerivedData directory and normal package
   resolution. The branding action runs. No camera permission or capture is used.
4. Copy the generated xctestrun alongside the original (so `__TESTROOT__` paths stay
   valid), remove the UI-test target, and set the hosted target's
   `EnvironmentVariables`: `STREAM14_PRIVATE_RECEIVER=1`,
   `STREAM14_EXPECT_UNTRUSTED=1`, and `STREAM14_RECEIVER_ARTIFACTS` to a fresh private
   absolute directory. Run only `Stream14Tests/PrivateRTMPSReceiverTests` with
   `xcodebuild test-without-building -xctestrun ... -destination 'platform=iOS Simulator,id=DISPOSABLE_UUID'`.
   Confirm it passes the expected rejection and private logs identify a TLS handshake
   failure, rather than a refused/unavailable socket. Independently verify the
   listener using OpenSSL with `-verify_return_error -CAfile PRIVATE_DIRECTORY/ca.crt`.
5. Add the generated root **only to that disposable Simulator** with
   `xcrun simctl keychain DISPOSABLE_UUID add-root-cert PRIVATE_DIRECTORY/ca.crt`.
   Never add host/system trust or disable certificate/hostname validation. Change
   `STREAM14_EXPECT_UNTRUSTED=0` in a second xctestrun and repeat.
6. The test generates thirteen seconds of synthetic 720p BGRA/44.1kHz stereo PCM through
   production `SharedMediaEncoder` → `SharedMediaDestinations`. One local MP4
   continues for all 390 video frames. Two real `RTMPSConnection`/`RTMPSPublisher`
   generations receive six seconds each, separated by one second of disconnected
   recording. Reconnect requests a random-access frame, with a fresh transport epoch.
   Socket sends must drain acknowledged media under finite time/queue bounds.
7. Compile `Tools/decode-private-rtmps.swift` with native Swift (`swiftc -swift-version 6
   -parse-as-library ... -o PRIVATE_DECODER`) and pass the two finalized receiver
   MP4 paths in chronological order. It decodes every video/audio sample with
   AVFoundation and checks codec/dimensions/rate/channels, ordering, duration,
   common-origin video markers, and measured audio/video marker offset ≤35ms.
   The hosted test separately decodes the local original and checks its marker.
8. Stop the receiver using its saved PID and shut down the disposable Simulator.
   Keep all originals. This fixture has no automatic media deletion.

The production entry still accepts only validated YouTube destinations. Its existing
connection body is private; a Debug-only test entry has a fixed localhost destination
and synthetic stream name. Release contains no private-receiver entry, configuration
or TLS exception. No legacy two-encoder feasibility fixture is used.

The disconnect is deliberate transport shutdown and a fresh connection, not an
abrupt packet-loss/slow-receiver endurance test. Packet acceptance alone is insufficient:
receiver decode must also pass before claiming wire delivery.

## Future physical slot: five minutes TOTAL, not executed here

Prepare the signed owner build, branding, package pin, laptop logs/original-file
retrieval and the existing dedicated **Unlisted** YouTube test event in advance.
Keep autoStart and autoStop off. Use the real app's normal Google account flow,
validated YouTube RTMPS destination and public certificate trust; no test CA/profile
is installed on the owner's phone. Confirm channel/title/visibility and explicit
operator publishing intent before any later real test. This document does not
execute or authorize an upstream change by itself.

- 0:00–1:00: install/open the prepared build and confirm the target/settings. Stop
  with incomplete evidence if setup consumes the slot.
- 1:00–2:00: start the local recording, then explicitly publish to the dedicated
  unlisted event; confirm remote ingestion and a receiver image containing the
  actual overlay. Record a clap/visible marker if measuring physical A/V sync.
- 2:00–3:00: one targeted transport interruption/recovery with recording still
  active; observe actual remote recovery and local continuity. Do not disable
  radios as a general test setup step or repeatedly cycle failures.
- 3:00–4:00: explicitly end/stop via the app's confirmations and finalize recording.
- 4:00–5:00: confirm the retained local item and export/retrieve the original.
  Decode/inspect evidence on the laptop after the phone slot.

Preflight account/event state and available exact controls must be checked before
that separate owner-approved slot. Five-minute evidence cannot establish endurance
or full F1/F6/F8/F9 qualification.

## Measured checkpoint and pending correction

The app dependency pin is unchanged. Measurements below used isolated local source
patches against fork base `8dc2ecce781d320ef0f2576ff5195411c91505ad`, not a published
or adopted replacement revision. No host trust or physical device was changed.

- Normal TLS rejected the untrusted receiver before any Simulator root was added;
  the same server's chain validated with OpenSSL using only its explicit private CA.
  After adding that one-day root only to a disposable Simulator, connect/publish and
  acknowledged media sends worked. No validation bypass was introduced.
- The original fork failed real receiver parsing: `received type 1 chunk without
  previous chunk`. Metadata-only private tracing found the first AAC CSID4 payload
  had no preceding sequence header. The canonical native AAC ASBD uses flags zero;
  the SDK incorrectly required an MPEG4ObjectID there.
- Fork candidate `79eaa938` maps only `kAudioFormatMPEG4AAC` with flags zero to
  AAC-LC, as explicitly specified by Apple's installed CoreAudioBaseTypes.h
  (kAudioFormatMPEG4AAC documentation). Older object-ID flags remain compatible.
  It changes no native app format, cookie, payload, trim attachment or file encoder.
  The real FLV AAC sequence-header regression and reduced native suite passed:
  **39 tests / 17 suites**. Real receiver H264/AAC recording then worked.
- The initial two-second transport clips were too short for the receiver's
  two-second track-analysis period. The final finite fixture uses two six-second
  transport generations and a one-second disconnected interval in one thirteen-second
  local original. It supplies a deterministic four-second random-access frame and
  4.5-second silence/tone + dark/bright marker in each transport generation.
- With only the AAC header correction, the first receiver's decoded video marker was
  4.500000s and audio 4.383786848s: **audio led by 116.213ms**. The legacy SDK adds
  66ms composition time even when native H264 DTS equals PTS.
- Fork candidate `497f742c` makes the explicit compressed API pass zero additional
  composition offset; legacy append keeps its existing 66ms default. Payload tests
  verify DTS=PTS gives CTS0, PTS−DTS=100ms gives CTS100, and legacy still gives66.
  The reduced native suite passed **40 tests / 18 suites**; normal full-manifest
  iOS Debug build-for-testing also passed against the isolated patched package.
- The final hosted synthetic run passed **390 local video frames**, local native
  decoded marker synchronization ≤35ms, disconnected file continuity, fresh keyframe
  reconnect, and two drained acknowledged socket generations. Local+receiver
  originals were retained. This is socket processing plus receiver decode evidence,
  not physical acceptance.
- **Receiver alignment still fails.** After CTS0, both receiver files decode H264
  1280×720 and AAC 44.1kHz stereo with monotonic samples. Each has179 decoded video
  frames, ending at5.9663s. Generation1 has256960 decoded PCM frames, marker4.430430839s
  versus video4.500000s (**audio leads69.569ms**). Generation2 has261056 PCM frames,
  marker4.441224490s (**audio leads58.776ms**). The native decoder deliberately exits
  unsuccessfully for the unmet35ms limit.
- Byte matching unique compressed packets against the local original found video
  timestamps agree within0.667ms after each generation's known origin; AAC matches
  differ by69.23–69.77ms in generation1 and58.21–58.87ms in generation2. This variable
  residual must be separated into encoder priming/trim and receiver/muxer normalization.
  Do not add a guessed fixed audio delay or claim alignment/qualification passed.

`0003-native-aac-header.patch` and `0004-compressed-video-cts.patch` in the existing
HaishinKit experiment directory reproduce the two independently reviewable fork
candidates. Root coordinates independent review, any immutable fork publication and
app pin update from current main. The original isolated stage did not publish or merge. A later diagnostic phone/YouTube
run needs a prepared signed candidate and explicit operator publishing confirmation;
it can measure the pending physical alignment and does not imply qualification.

## Raw encoder versus container timestamps: finite follow-up

The final fixture also retains a bounded private `encoded-packets.json` manifest
with each actual encoder output packet's SHA256, raw PTS/DTS, duration and start/end
trim. It contains only generated media metadata and is never committed. This makes
the raw encoder timeline distinct from the writer/receiver's container readback.
A completed repeat with the same candidate fork changes found:

- Raw video PTS starts1.000000s; matching local compressed packets subtract exactly1s.
  Receiver video matches subtract1s (generation1) or8s (generation2), within RTMP's
  millisecond quantization.
- Raw first AAC packets have PTS0.952108844,0.975328798,0.998548753,1.021768707s.
  Their respective start trims are1024,1024,64,0 PCM frames at44.1kHz. The bounded
  publisher omits packets before the video random-access origin, as designed.
- Matching local compressed AAC packets subtract0.952108844s, **not the video's1s**.
  The local MP4 readback is therefore not an authoritative copy of raw packet PTS.
- Matching receiver AAC packets subtract about1.02177s (generation1) and8.01066s
  (generation2), again different from the video origins. Those container/reader
  offsets account for the measured generation-dependent readback differences.
- Independently decoding the exact retained AAC packet bytes with native
  AVAudioConverter, outside MP4 timestamp/trim handling, gives the first tone at
 4.547981859s for both decoder `.none` and `.normal` prime methods. Decoder reported
  leading/trailing frames0/0. The actual encoded content thus carries about47.98ms
  latency, consistent with the raw encoder's leading-frame compensation.

These are finite measurements, not permission to remove compensation, add a guessed
audio delay, or relabel the failed receiver-file marker assertion as passing. They
show that encoder packet PTS, MP4 normalization, decoder priming and the actual RTMP
wire clock must be assessed separately. Normal TLS, real socket sends, independent
H264/AAC receiver parsing and decode are established for this synthetic case; actual
wire/playback A/V alignment and physical YouTube marker acceptance remain pending.


## Reviewed focused main correction

The two fork changes passed separate actual-source review and were published to the
existing owned fork at exact revision `497f742c5f2c04cf3ca085378e660a273e351788`.
The focused `codex/fix-native-rtmps-media` branch starts at main `eaf9389`; it imports
only the fixture, tools, patches and evidence changes, not the later F7 lifecycle
implementation. Both the project requirement and Package.resolved select this exact
revision; other package pins and dependency footprint are unchanged.

Review's sole app-scope finding was fixed: the localhost helper and private fixture
compile only for `DEBUG && targetEnvironment(simulator)`. Release and physical Debug
products retain only the validated YouTube entry point. Normal TLS and all publishing
authorization guards remain unchanged. The normal iPhone SDK Release build passed;
final hosted regression status is recorded in the PR handoff. No recording or
credential was deleted or exported. Receiver-file marker assertions remain failed
as described above; no encoder timestamp or guessed audio-delay correction was added.
