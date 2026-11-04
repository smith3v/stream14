# Local media feasibility

2026-11-04 — issue #3. M1 local library-fit experiment demonstrated on the physical
iPhone 13 mini. M2–M5 and production recording reliability remain unqualified.

## Dependency decision (before adoption)

Select stable [HaishinKit 2.3.0](https://github.com/HaishinKit/HaishinKit.swift/releases/tag/2.3.0),
released 2026-11-01, tag commit `aa2149d` (resolved full revision recorded in Package.resolved).
Inspected the exact tag, not main. Link only `HaishinKit`. It supplies MediaMixer,
Screen/ImageScreenObject, MTHKView and StreamRecorder; no transport product is needed.
The Apple-native alternative requires owning capture, timing, compositing and writing;
the existing library is the selected MVP experiment to avoid that work. Maintenance
risk: upstream media/concurrency behavior needs physical qualification; pin the release
and inspect upgrades. No connection, account, credentials, telemetry SDK, or browser is
needed for this experiment.

The [manifest](https://github.com/HaishinKit/HaishinKit.swift/blob/2.3.0/Package.swift)
uses Swift tools 6.0, supports Swift 6 and iOS 15+, and links Logboard 2.6.x from the
core target. It also declares libsrt-xcframework, libdatachannel-xcframework and
swift-docc-plugin at package scope: these may be resolved/downloaded even when their
transport products are not linked. The committed resolver pins HaishinKit 2.3.0 (`aa2149df822f2e965adf2410a106db959b2e1962`),
Logboard 2.6.0, libsrt-xcframework 1.5.7, libdatachannel-xcframework 0.24.6,
and its OpenSSL-Package 3.6.5000 dependency. The build graph contains only the app,
HaishinKit and Logboard products/targets; transport/OpenSSL binaries are not linked.
The declared docc plugin is not in this Xcode resolver result or runtime graph.
HaishinKit is BSD-3-Clause; retain its full notice in the app's third-party notices.
Logboard 2.6.0 is also BSD-3-Clause; both full notices are bundled and accessible in the app. Binary transport licenses
are not app-linked licenses for this core-only target.

## Verified source interface

- `MediaMixer(captureSessionMode: .single)` owns one library capture session.
  `attachVideo(_:track:configuration:)` / `attachAudio(_:track:configuration:)`,
  `setSessionPreset(.hd1920x1080)`, `setVideoOrientation(.landscapeRight)`,
  `setFrameRate(30)` and `startRunning()` / `stopRunning()` are public APIs.
- `setVideoMixerSettings(VideoMixerSettings(mode: .offscreen))` enables composition;
  passthrough mode would omit image layers. `mixer.screen.size` is 1920×1080.
  On `ScreenActor`, add one `ImageScreenObject` and replace `ciImage` in place;
  invalidation is built in. The synthetic image includes transparent, half-alpha,
  opaque and antialiased areas and a changing counter. The app does not composite
  camera pixels itself. A later WebKit renderer can supply immutable images here.
- `mixer.addOutput(MTHKView)` and `mixer.addOutput(StreamRecorder)` both select
  composed track `UInt8.max` (their default). Preview uses aspect fit. No UI is
  drawn into `screen`.
- Offscreen SDR video is uncompressed CVPixelBuffer-backed CMSampleBuffer (NV12 / 420v
  pixel format selected by DynamicRangeMode); audio is mixed PCM, explicitly 44.1 kHz,
  two channels. StreamRecorder converts PCM to CMSampleBuffer and supplies non-nil
  H.264/AAC settings to AVAssetWriterInput. AVAssetWriter owns the one local encode
  after composition. No Stream/VideoCodec or AudioCodec encoder is instantiated;
  there is no compressed decode, second encode, or export conversion.
- Use native MP4, 1920×1080/30, H.264 14 Mbps, two-second keyframes, AAC 128 kbps.
  `startRecording(fileURL, settings:)` starts writer state; `stopRecording()` finishes
  it. `recorder.error` reports append errors. MP4 is the library default; MOV would
  not remove an encode. These are source-path findings; file/device evidence follows.

## Limits found during source inspection

`StreamRecorder.stopRecording()` checks `.writing` before finishing, but does not
check `.completed` or writer.error after `finishWriting()`. A returned URL alone
cannot establish successful finalization. This experiment labels samples for
inspection, preserves every file, and writes a persistent pending/failed/inspection
sidecar rather than claiming production completion. Before stage #5's failure gate,
use a small writer adapter on MediaMixerOutput or an upstream fix exposing final
status; it must check initialization, append and finish errors. No alternative
capture/compositor is justified by this writer limitation.

Mixer output/preview/recorder dispatch use upstream per-sample Tasks/AsyncStreams;
recorder skips not-ready writer inputs and offers no public drop count. Queues and
backpressure are not established bounded by this experiment. M3 requires measurement
and resolution of any growth. Shared future network encoding/transport independence
is untested. Source-local recording uses raw mixer output; attaching a later stream
does not by itself share encoded samples.

## Evidence and handoff

Xcode 27.2 (27B52), iOS SDK/Simulator 27.2, Swift 6 app and HaishinKit compilation:
unsigned generic-iOS Release build passed. Final native test run passed all eight
tests (six Swift Testing, two XCTest UI), including full accessibility audits in
portrait and maximum Dynamic Type landscape. Signed Debug 0.1/build 1 passed,
`codesign --verify --deep --strict` passed, and development install/devicectl launch
succeeded on the physical iPhone 13 mini / iOS 27.2. The owner recorded and played
the sample, confirming correct picture/sound and changing counter. Exact commands
and private evidence paths are in the
[development guide](ios-development-guide.md#stage-2-local-media-experiment-2026-11-04).

Independent reviewer inspected the actual full implementation, project/dependency
path, tests and source claims. It found accumulated layers on reopen and an incorrect
pixel-format description; both are fixed and re-reviewed, with a non-accumulation
regression test. Final independent review inspected the full committed diff and canonical docs, confirmed
the native test/build/install evidence and independently verified the signed app.
No material findings remain. A focused independent closeout review checked the
original sample, frames, sidecar and updated docs, and independently decoded both
tracks successfully with nonzero audio. It confirmed the narrow M1 acceptance.

### Physical sample: M1 result

Installed source: `a034f49` (later commits update documentation only), Debug
0.1/build 1, iPhone 13 mini / iOS 27.2, development install/devicectl launch without
a debugger. No server, account, stream key, connection or publishing API was used.
The owner confirmed that playback looks and sounds correct and the counter changes
in response to the requested orientation/alpha/audio-alignment check. This is a
subjective A/V playback check; a measured acoustic clap/lip-sync offset is not established.

A private app-container copy of the original file was read with AVFoundation:

| Observation | Result |
| --- | --- |
| Original container / size | MP4 / 94,453,437 bytes, no export conversion |
| Duration | 53.529229 seconds |
| Video | H.264 (`avc1`), 1920×1080, 1,594 compressed video samples |
| Profile / reported nominal rate | Requested 30 fps; asset nominalFrameRate 29.716671 fps |
| Presentation timestamps | Video 0.068333–53.505011 s; largest sorted video PTS gap 80 ms |
| Audio | AAC, 44,100 Hz, two channels |
| Audio packet-buffer timestamps | 0.092880–53.529229 s; 109 reader buffers (each may contain multiple AAC packets) |
| Read result | AVAssetReader reached `.completed` for both tracks |
| Image inspection | Frames extracted near 1, 5 and 10 s; camera visible through translucent panel, opaque/antialiased graphics, changing counter/color, upright landscape, no app UI |
| Persistent sample marker | `needsInspection`; preserved with the original movie |

The ~24.5 ms difference between the first audio/video buffer PTS is a file-timeline
observation, not measured acoustic synchronization. The video gap was computed after
sorting presentation timestamps; H.264 packet/decode order can differ. Do not interpret
AAC reader-buffer spacing as audio gaps. No measured pipeline-drop percentage,
bounded-queue, thermal/memory, 30-minute or M3 claim follows from this short sample;
the asset nominal rate is recorded rather than rounded up to a proven 30 fps.

Private evidence remains outside Git: original MP4/sidecar and extracted frames under
`/tmp/stream14-issue3-private-samples/`, copy log `/tmp/stream14-issue3-copy-2.log`,
AVFoundation inspection output `/tmp/stream14-issue3-sample-inspection.txt`,
independent read-only decode report `/tmp/stream14-issue3-independent-inspection.txt`, and the
temporary inspector `/tmp/stream14-issue3-inspect.swift`. These paths are local evidence,
not public attachments or a permanent archive. Recordings were not deleted or altered.

M1's local camera/audio/composition/encode/write path is demonstrated. Proceed to
issue #4 only after this stage's PR review/merge. Full WebKit composition, reliable
writer failure handling, long-run measurements and TestFlight remain later gates.

For issue #4, run the commands above, explicitly open capture, and replace the
synthetic generator through the retained ScreenActor image object. Supply one
immutable, full-size alpha image after a successful WebKit render; do not mutate
layer state off ScreenActor or put a WKWebView above the preview. Keep `mode: .offscreen`
and composed track UInt8.max for both outputs. WebKit needs independent source-health
tracking; the counter experiment provides none. For issue #5, use the same mixer
boundary, keep writer lifecycle independent, address final-status/error propagation
and measured bounded backpressure before claiming M3/M4. Retain existing sample files
and pending markers; this experiment does not add automatic deletion/recovery UI. WebKit,
outage behavior, production recording UI/recovery, 30-minute qualification and
TestFlight are later issues. No gate is passed merely from upstream source inspection.

## Stage 3: WebKit renderer (issue #4, 2026-11-04)

`WebOverlayRenderer` owns a nonpersistent, noninteractive WKWebView. The separate
“Overlay” sheet attaches it to `OverlayViewport`, an ordinary visible
UIView in the active window. A stable sibling above the Form keeps it
attached while reusable settings/output rows scroll. Its bounds remain 1920×1080 points, pageZoom 1; a
presentation transform fits the source into the phone's available width without
changing layout. The fixture and reference meta viewport consequently report
1920×1080 CSS pixels, avoiding the reference's <=720px mobile breakpoint. The
source view is neither hidden nor alpha-zero/detached. This arrangement is a
renderer test, not a camera-preview overlay. Future integration must retain a
supported attachment and remeasure its resource cost with capture running.

Use public `takeSnapshot(configuration:)` with the full canvas rect, requesting
1920/displayScale snapshot points (1920 raster pixels). A defensive CoreGraphics
normalization runs in a detached utility task and produces an immutable RGBA
1920×1080 CGImage. Clear, nonopaque WKWebView/scroll backing preserves the page's
alpha; native code does not rewrite arbitrary page backgrounds. No native message
handlers, TLS exceptions, persistent browsing store, credentials, URL logs, Photos
access or new dependencies are added. Main-frame navigation requires HTTPS;
popups, downloads/attachment responses, camera/microphone, geolocation, motion
and JavaScript dialogs are denied/dismissed. Browser media requires interaction,
which the test source view does not permit.

A single serialized task captures at about 1 Hz; a busy guard also spans cancelled
sessions so a pending callback cannot overlap a new snapshot. Navigation identity
and generation checks reject superseded load/failure/snapshot callbacks. The
main actor owns WebKit/UI only; raster normalization runs off it. A separate
100ms monotonic ticker enforces visibility even if a WebKit request stalls. Do not
interpret the 100ms polling granularity as sub-frame deadline accuracy.

### Source freshness, resource readiness and recovery

Confirmed successful HTML response + document commit updates source time; capture
only updates render time. Main-frame requests use reloadIgnoringLocalCacheData
and no-cache/no-store headers. The inspected reference reloads every two seconds,
so its normal reloads provide source confirmations. There is no additional periodic
reload on top of those. Only if a page has not refreshed for eight seconds does
the renderer request a document refresh itself, before the ten-second grace ends.
Failed loads/timeouts retry after two seconds; each navigation has a six-second
watchdog. This is actual document access, not a separate network-reachability probe.
It does **not** establish that a page's independent in-place scoring API is healthy:
that requires a verified source-specific heartbeat in the overlay project. No
service-side modification or deployment was made. A service returning stale HTML
successfully is likewise outside what transport access can detect.

After commit, a laid-out DOM is required; fonts/images get a bounded 750ms wait,
then capture may proceed with missing resources. Navigation invalidates in-flight
capture results and preserves the last good image. Native code does not promote
the blank provisional loading surface. Ten seconds without either source access
or usable rendering makes output invisible. Expiry clears recovery eligibility;
source access plus a fresh usable raster is required to recover. Cached snapshots
never renew source time. Manual hiding takes precedence through failures/recovery.
Stopping/backgrounding hides output and requires explicit Load to resume.

### Renderer handoff and evidence

On MainActor read `image: CGImage?`, `visible: Bool`, `healthy: Bool`, `status`, and
`health` (separate monotonic source/render times). `image` remains immutable and
retained through failures; consumers **must** apply visibility, including automatic
expiry and manual hiding. Stage #5 should transfer the CGImage to the existing
ScreenActor ImageScreenObject and clear/hide its ciImage when invisible. Keep that
same composed mixer output for preview/recording. The existing synthetic recorder
is intentionally unchanged in this stage. This is no claim of M2 or M3–M5 success.

Physical iPhone 13 mini / iOS 27.2, Xcode 27.2, signed Debug 0.1/build 1 via hosted
native tests: the fixture has the full CSS viewport and normalized canvas, zero
alpha at the untouched corner, half alpha in the panel, opaque graphics, and the
red anchor at the bottom-right video corner. Its score changes while capturing.
The reference raster shows desktop layout, both logos, text and translucent panels.
A 15-second reference observation sampled output every 500ms through eight source
commits/reloads without lost output or white/transparent replacements. This is a
short renderer check, not a long-run camera/drop/backpressure qualification.
Exact final test results, measured costs and local evidence paths are recorded in
the development guide below. Capture costs include JavaScript, snapshot, scheduling
and normalization; they are elapsed latency, not a main-thread CPU-time measurement.

Tests use supplied times to cover before/at/after ten seconds, independent rendering
expiry, brief failure, unchanged healthy content, cached snapshots, recovery and
manual-hide precedence. Attached renderer tests exercise viewport, raster alpha,
corner placement, score updates, superseded navigation failure and stop visibility.
The live reference test is opt-in; normal deterministic tests do not depend on it.

Memory/thermal behavior under concurrent camera capture is not measured here;
qualify it during stage #5/#6 rather than inferring it from raster latency.
