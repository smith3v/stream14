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

## Stage 4: integrated local recording (issue #5)

Implementation decision, 2026-11-04: retain HaishinKit 2.3.0 capture, mixed PCM
and ScreenActor offscreen composition. MediaSession owns preview/capture;
LocalRecorder owns only local writing. The exact shared boundary is
`MediaMixer.addOutput(_:)` / `removeOutput(_:)`, receiving composed
`CMSampleBuffer` video and `AVAudioPCMBuffer` with `AVAudioTime`. Track IDs `.max`
select mixed/composed output. WebOverlayLayer applies both immutable CGImage and
visibility, retaining no second preview composition. A 100 ms serialized handoff
checks visibility; the layer explicitly sets HaishinKit `isVisible` because nil
image sources do not clear its renderer cache; image identity prevents re-installing an unchanged raster.
The WebKit source stays visibly attached outside reusable/lazy UI rows.

The upstream StreamRecorder does not inspect status after `finishWriting()` and
submits an unbounded Task for each incoming callback. The small concrete
LocalRecorder adapter uses the same public raw-output route and AVAssetWriter
settings, with mutex-owned synchronous writer/input access and no app sample queue.
It checks writer creation/start, canAdd, append and final status/error. Input
backpressure drops rather than retaining samples; counters include video/audio
drops, delivery gaps and estimated missing 30 Hz output intervals. Failures trigger
visible stop/finalization; partial files and pending/failed sidecars survive. Native
writer/input objects never cross the lock during append; finish detaches them
before awaiting finalization, so late callbacks cannot append. No unchecked
Sendable conformance or second capture session is introduced.

Video: composed uncompressed NV12 → AVAssetWriter H.264, 1920×1080, 30 fps hint,
14 Mbps target, two-second keyframes. Audio: mixed PCM → public CoreMedia buffer
copy → AVAssetWriter AAC, stereo 44.1 kHz/128 kbps. Host timestamps share the
mixer's media clock; video establishes the session origin and earlier audio is
rejected. MP4 is written directly, one necessary encode per track, with no
post-save/export conversion. This version uses public synchronous AVAssetWriter
input APIs matching the verified 2.3.0 route. Xcode 27 marks those APIs deprecated
in favor of input receivers; they remain available and build. No replacement
capture/compositor/codec pipeline or added package is needed. A future streaming
output must own its own lifecycle on the mixer boundary. This does not prove
sharing already encoded local samples with a transport encoder.

Files remain in `Application Support/MediaExperiments` for compatibility with
stage 2; the directory is excluded from backup. UUID MP4 + atomic JSON sidecar
states are pending, completed, interrupted, failed and legacy needsInspection.
Only a checked final writer + audio/video tracks + duration can complete a new
file; pending/legacy states stay unqualified on relaunch. Files are never deleted
automatically. A failed sidecar save leaves the prior pending marker and visible
warning. Playback of retained incomplete files is offered for inspection and may
fail if they are not playable. There is no crash-fragment repair guarantee.

Complete URLs use Security generic-password Keychain records, with
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; empty configuration deletes only
the URL record. Values stay out of logs and diagnostics. Browser storage remains
nonpersistent and HTTPS certificate validation is unchanged. No Photos permission,
telemetry, transport product or capacity estimator is added.

Physical landscape qualification found WebKit applying host safe-area adjustment:
the reference loaded successfully but reported 1870×1080 CSS pixels. The renderer
correctly refused this wrong-size output. Setting
`scrollView.contentInsetAdjustmentBehavior = .never` and disabling safe-area layout
margins restored 1920×1080 on the 13 mini. Do not remove the explicit viewport
validation or qualify only portrait source hosting.

Early evidence (signed Debug 0.1/build 1, physical iPhone 13 mini/iOS 27.2,
Xcode 27.2): isolated integrated test passed after the inset fix. Original
30.098-second H.264/AAC sample was copied privately and inspected with AVFoundation:
1920×1080, nominal 29.669 fps, transparent/translucent reference overlay over
actual rear camera, no controls in extracted frames. Writer counters reported
893 video deliveries/writes, zero admission/audio drops, zero gaps ≥500 ms and
maximum gap 340 ms. AVAssetReader confirms 893 nonempty video buffers; empty timing-marker buffers
are excluded from cadence measurements. Video starts at PTS 88.3 ms and AAC at
zero. Track endpoints are **not** measured lip/clap sync. Encoded AAC reader buffers group packets, so
their ~0.5-second timestamp gaps are not evidence of audio stalls. Raw files,
frames and raw diagnostics stay outside Git.

These writer counters do not measure sensor drops or detect a compositor repeating
stale camera frames. Estimated missing-output intervals and saved-file timestamps
provide additional output cadence evidence; real scene motion and A/V markers are
still needed for camera freshness/sync. Capture runtime errors conservatively stop
and fail the recording, rather than accepting a frozen-camera output as healthy.
Serious thermal state reduces snapshots to one every three seconds with a native
warning; critical state stops/finalizes and requires explicit restart. Thermal
policy does not establish sustained performance at high temperature.

Current default checks: unsigned Release build passed; the complete Simulator
suite passed (13 deterministic hosted tests and three UI tests, two opt-in skips).
All three UI accessibility audits passed, including largest Dynamic Type landscape
and overlay settings. A final hosted rerun adds the cadence/legacy-metadata test
and passes 14 deterministic hosted tests, with the two opt-in skips. Generated
media tests cover repeated real writing and injected initialization/append/final
failures, plus a real writer-start filesystem error and empty-session rejection.
Independent agent review inspected actual files/diff and checks: runtime-error
handling, thermal policy, URL retention copy and a fixture compile error were fixed;
focused re-review found no remaining material implementation issue. The final complete Simulator suite then passed 14 active hosted tests and three
UI/accessibility tests, with four opt-in skips. Denied-camera UI was separately
enabled after Simulator permission revocation and passed; permission was reset
afterwards. Layout screenshots were inspected privately. Native device fault checks and the long report are detailed below, with remaining qualification limits.

The first long device run ended after about 130 seconds with a remote-process
communication failure while the owner disabled networking. The owner observed
that the app closed/relaunched. Logs show camera/writer delivery continuing while
source requests returned offline errors and visibility was false. The retained
240 MB partial MP4 remains pending, not completed. No matching Stream14 crash
report was listed on the phone; this does not establish why it terminated.
The run does not count as successful outage recovery or 30-minute qualification.
The restarted run uses a two-minute public WebKit document-request block, distinct
from disabling the phone's actual networking, and leaves the debugging link alone.

Validation evidence and remaining qualification are recorded below. A development run never completes M3/M5; final qualification must
use the TestFlight-installed build. Two-minute real outage, live fixture replacement,
manual hide/recovery, actual interruptions, playback/export owner review, permission
denial and physical A/V offset measurements must not be inferred from a build or
writer-only generated-media tests.


### First 30-minute development run and corrections

The signed Debug 0.1/build 1 run at commit `c72c261` completed a 1,807.308-second
original MP4 (3,186,184,593 bytes). The test runner passed its assertions, but
saved-frame inspection and memory review exposed qualification gaps, so this is
**not** a complete preliminary M3/M4 pass. Private evidence is under
`/tmp/stream14-issue5-soak-evidence/`; result bundle/log are
`/tmp/stream14-issue5-physical-soak-injected.xcresult` / `.log`.

AVAssetReader independently confirms 54,114 nonempty H.264 video buffers,
276 estimated missing 30 Hz output intervals (0.507%), maximum sorted PTS gap
376.7 ms, zero gaps ≥500 ms, and complete video/audio reader status. Writer
counters agree: zero admission/video/audio drops and maximum callback gap 378.1 ms.
The WebKit request block ran from seconds 30–150; renderer visibility was false
by the 40-second observation and true again by 160 seconds. However, the original
frame at 60 seconds still contains the overlay: HaishinKit
`ScreenRendererByGPU.layout` returns on a nil image without clearing its cached
image. Clearing `ImageScreenObject.ciImage` therefore cannot implement hiding.
WebOverlayLayer now explicitly gates drawing with `isVisible`; a new regression
observes actual NV12 compositor output through show → hide → restore, not merely
model flags. This fixes automatic expiry and manual hiding at the shared preview/
writer boundary. Corrected device output was rechecked separately below.

Host resident memory sampled every ten seconds ranged 45.8–521.7 MiB, ending
442.5 MiB. First/last five-minute means were 82.5/358.3 MiB, with a full-run linear
trend +10.54 MiB/min. Large drops (including ~396 MiB around minute 24) mean these
values do not prove a strictly monotonic object leak. They also do not establish
stable qualified memory behavior. Only the host process was measured, not all
WebKit processes or GPU allocations. Thermal states nominal/fair/serious occurred;
the serious-state policy reduced snapshot cadence. Observed elapsed snapshot time
was 18.2–128.9 ms (median 37.5 ms), including scheduling.

The app holds bounded image references and has no application writer sample queue.
HaishinKit's composition CIContext uses default intermediate caching and its preview
submits per-frame MainActor tasks; those and autoreleased/Metal caches need
profiling before assigning a cause. No mutable dependency checkout patch or custom
capture/compositor has been adopted. Follow-up diagnostics add `TASK_VM_INFO`'s
physical-footprint value alongside resident bytes to distinguish charged footprint
from resident mappings. The recording qualification remains pending until memory
and physical A/V markers are evaluated; track timestamp endpoints alone do not
satisfy the ≤100 ms sync gate. Final M3/M5 still require TestFlight.

### Corrected composition and failure/device checks

After the explicit visibility correction, the physical iPhone 13 mini suite passed
three tests: injected writer initialization/append/finalization failures plus
established-recording interruption, the corrected five-minute integrated run, and
the actual NV12 composition show/hide/restore regression. Failed recordings stayed
failed, screen sleep was restored and camera restart required explicit action.
The interruption assertion identifies a newly created sample; it does not claim
that `Task.yield()` proves an in-flight initialization checkpoint. Results:
`/tmp/stream14-issue5-physical-corrected.xcresult` / `.log`.

The corrected original is 301.121 seconds with 9,012 video frames and 54 estimated
missing 30 Hz intervals (0.596%), zero writer/audio admission drops, maximum sorted
PTS gap 286.7 ms and no gaps ≥500 ms. Both native video/audio decodes completed.
Saved frames before outage, during outage (60 s) and after recovery (170 s) were
inspected privately: the overlay is **absent during the outage** and restored
later, with camera frames still present and no app controls. Files/analysis are
under `/tmp/stream14-issue5-corrected-evidence/`. This shorter run rechecks the
changed visibility behavior; it does not replace the required thirty-minute run.

The five-minute diagnostic captures `TASK_VM_INFO.phys_footprint`: 121.7–130.2 MiB,
ending 130.0 MiB (one-minute means 124.6, 121.8, 123.2, 127.3, 127.4 MiB), all
thermal nominal. Resident bytes rose 116.4→361.1 MiB with a 418.4 MiB peak while
charged footprint stayed in that narrow range. This distinguishes resident
mappings/caches from charged physical memory and is reassuring; it is not proof
of a thirty-minute footprint plateau or of all WebKit/GPU memory. No speculative
package patch or pipeline replacement was made. Repeat full-length footprint
profiling in the actual TestFlight build before claiming M3.

A physical XCTest UI check exercises the actual app: Record, Home/background,
return without automatic capture restart, Play, close player and original-export
control presence. Its first run exposed an empty first playback sheet caused by
separate Boolean presentation and optional URL state. Playback now uses a single
item-backed sheet with its URL. The corrected check passes at
`/tmp/stream14-issue5-device-ui-fixed.xcresult` / `.log`. This verifies native player
presentation and export-control availability, not a completed Files save or
subjective audio/video playback review. Owner review/export and precise physical
sync remain distinct evidence. The early long-run clap is near a frame edge and
does not support a confident ≤100 ms measurement; endpoint timestamps must not be
substituted for it.

Independent review inspected each material correction and regression, including
actual dependency cache behavior, failure/interruption tests and playback state.
No remaining material implementation finding was identified after the fixes.
Release and Simulator/device results are listed in the development guide. Issue #5
stays open while the PR is prepared for review; long-run qualification remains deferred, and M3/M5 and broadcasting are not claimed complete.


### Owner short-flow review

On 2026-11-04 the owner confirmed playback and saving the original to Files worked,
and the camera/overlay/sound looked right. The newly reviewed 5.825-second MP4 and
completed sidecar were copied privately to `/tmp/stream14-issue5-owner-review/`;
no media or private face/scene images are published. Native video/audio decode
completes. The clap's 10 ms audio RMS peak bin starts at 2.64 s; timestamped
adjacent frames place visible hand contact around 2.68–2.71 s. This suggests video
roughly 40–70 ms later, with about one 30 fps frame of visual/contact uncertainty.
It is useful short-sample physical sync evidence, not a precision instrument or a
measurement of drift at both ends of the thirty-minute run. Keep full-length
start/end sync and charged-footprint qualification pending for the next validation
pass; do not promote M3/M5 from this short owner review.

### Owner cleanup/experiment update (2026-11-05)

The owner requested a way to remove old recordings because phone storage is low,
fifteen-minute development experiments for now, and recognizable main/test icons.
These are implemented; see the [focused plan/results](2026-11-05-recording-cleanup-implementation.md)
and [icon assets/prompts](app-icons.md).

Deletion is explicit and scoped to one selected UUID's MP4 and sidecars, with
Cancel/Delete confirmation. Metadata is removed last for retry after partial
failure; unexpected directories are refused. Removal is disabled during lifecycle
operations, and an affected latest-playback URL is cleared. No automatic deletion,
available-space polling, storage estimates or recursive directory cleanup was
added. Exported Files copies are outside the removal scope.

Development requests now cap at 900 seconds with monotonic absolute sleep deadlines,
while short smoke checks remain. Atomic minute-by-minute diagnostic checkpoints
reduce evidence loss after unexpected exit. The app's ordinary Record/Stop operation
has no artificial fifteen-minute limit. Longer integrated-app qualification is
deferred under the owner's instruction; no new long experiment should be launched
until it is agreed. The owner clarified on 2026-11-05 that the previous thirty-minute validation was
interrupted around 25 minutes when the assistant session ran out of tokens. That
run remains incomplete evidence, not a confirmed application reliability failure.
This does not alter or erase the earlier completed runs and their stated limits.

Deletion's three focused tests and isolated synthetic-recording UI Cancel/Delete
check pass; the regular Simulator suite, signed build-for-testing and unsigned
Release pass. Independent review found no remaining material issues after a test
branding-signature syntax correction. Both updated app products were installed
in place on the physical 13 mini; before/after recording artifact filenames and
sizes match. No owner recording was automatically deleted and no new recording
experiment was launched during this update. Owner can now deliberately reclaim
space through the installed UI. TestFlight and longer whole-app qualification
remain later work; shorter experiments are not promoted to those gates.


### Owner acceptance and PR handoff (2026-11-05)

The owner deleted old recordings in the installed app and confirmed that device
storage was reclaimed. The owner also confirmed that the main and separate test-app
icons are in place. This completes the manual cleanup/icon acceptance in addition
to the earlier playback and original Files-export review.

At the owner's request, PR #10 is finalized for review rather than merged.
Development experiments remain capped at fifteen minutes; longer integrated
whole-app qualification is deferred. The existing failed/limited long-run evidence
is retained honestly and does not become a passed M3/M5 gate through this handoff.
No new recording experiment or automatic deletion was performed for closeout.


### Post-merge verification setup (2026-11-05)

The owner clarified that the earlier roughly 25-minute validation could not be
continued after the assistant session reached its token limit. Do not present it
as an established application crash or reliability defect. Native runner-exit
messages alone do not establish that causal claim.

The first new fifteen-minute attempt received a real capture/audio interruption
after about a minute; the owner confirmed contemporaneous phone activity or an
interruption. The app finalized the file, stored interrupted status, returned to
idle and required explicit restart. This is useful interruption-handling evidence,
not a completed fifteen-minute performance run. The test's explicit recording-state
assertion correctly failed rather than reporting an incomplete run as passing.
The independent writer-failure/interruption test, including the iOS 27 audio-inactive
notification path, passed before this attempt. Private logs/result:
`/tmp/stream14-issue5-verification-15m.log` / `.xcresult`.

The owner then prepared the phone again and authorized a fresh uninterrupted
fifteen-minute check. It uses the same source tree as merged main, USB connection,
foreground/unlocked capture, the existing two-minute injected WebKit document-request
outage, manual hiding through source recovery, ten-second resident/charged-footprint
observations and requested start/end physical clap markers. The completed results
and missing end-marker limitation follow below.


### Completed fifteen-minute verification (2026-11-05)

The retry on the USB-connected iPhone 13 mini/iOS 27.2 completed successfully
using the merged PR #10 source (main `0dd269c`). `combinedDeviceRecording` passed
in 911.901 seconds including setup and follow-up checks; the original main MP4 is
900.034 seconds, 1920×1080 H.264 with stereo 44.1 kHz AAC. Recording finalized as
completed. Independent native AVAssetReader video and decoded-audio reads both
finished with `.completed` status.

| Measurement | Result and interpretation |
| --- | --- |
| Nonempty video frames | 26,976 |
| Estimated missing 30 Hz output intervals | 128 / 0.472%; below the 1% development target |
| Largest video timestamp gap | 393.3 ms; no gaps ≥500 ms |
| Writer admission drops | Zero video and zero audio; no recorded writer stalls |
| Charged physical footprint, sampled every 10 s | 119.0–150.3 MiB; first 134.9, final 135.3 MiB |
| Resident size | 50.5–437.4 MiB; final 252.5 MiB; mappings/caches differ from charged footprint |
| Thermal state | Nominal in all 90 observations |
| Overlay snapshot time | Median 40.1 ms; maximum 72.1 ms |

Cadence uses nonempty video sample presentation timestamps sorted into order and
counts estimated missing 30 Hz intervals. It is not a direct sensor-frame-drop
measurement and does not detect all upstream losses or duplicated stale images.
Writer counters measure its own bounded admission; library-internal queues are not
fully observable. Charged footprint returned near its initial value without
continuous runaway growth during this run; these samples do not establish total
WebKit/GPU memory or longer whole-app stability.

The existing test blocked WebKit document requests for two minutes, from recording
second 30 to 150. This is an injected request outage, not a Wi-Fi/cellular radio
outage. Recording continued, the overlay hid after the source-access deadline,
and source access recovered. Manual hiding persisted through recovery (asserted
at second 175); the overlay returned after manual unhide at second 200. Saved
frames at 20, 60, 170 and 210 seconds were inspected: visible, hidden, still manually
hidden and restored respectively, without app controls in the composition.

The owner missed the end clap and explicitly requested moving on without it.
No end A/V offset or start-to-end drift is claimed for this run, and its start
marker has not been quantified. The earlier short owner-reviewed sample remains
short-sample evidence only. Carry measured start/end A/V offset ≤100 ms into the
later TestFlight/whole-app qualification in issue #6. This agreed deferral does not
turn the sync acceptance item or M3/M5 into a pass. Do not launch another recording
merely to replace the missed marker.

Reproduction uses the existing shared scheme and physical-device destination from
the development guide (substitute the locally configured device ID/signing team):

```sh
TEST_RUNNER_STREAM14_DEVICE_RECORDING=1 \
TEST_RUNNER_STREAM14_RECORDING_SECONDS=900 \
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS,id=<device-id>' \
  -derivedDataPath /tmp/stream14-issue5-update-phone \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  -only-testing:Stream14Tests/MediaDeviceTests \
  -resultBundlePath /tmp/stream14-issue5-verification-15m-retry.xcresult \
  DEVELOPMENT_TEAM='<local-team>' test
```

Private evidence, excluded from Git: `/tmp/stream14-issue5-verification-15m-retry.log`,
the corresponding `.xcresult`, and `/tmp/stream14-issue5-verification-15m-evidence/`
(original MP4, completed status, observations, native-reader analysis and inspected
frames). These temporary paths are local evidence, not durable shared artifacts.
The original recording remains on the phone; no owner recordings were deleted.
USB was needed for this automated run and copying evidence, not for ordinary
standalone recording; the completed check no longer requires it.


Independent closeout review found that direct session-property expressions in
Swift Testing macros can reflect the entire session on failure. The interrupted
run's private raw log demonstrates this path, including URL-bearing session and
renderer fields. Device assertions and the launch-state unit test now evaluate
safe local values before invoking macros, so neither object enters macro failure
diagnostics. Production app behavior is unchanged. Existing raw logs remain
private; do not attach them to issues or PRs without separate redaction.

Focused Simulator `MediaExperimentTests` passed after the safe-local change, and
both modified test files compiled. Independent re-review found no remaining
material privacy/correctness issue in these assertions. Documentation local-link
and Markdown-fence checks and `git diff --check` passed. No physical-device rerun
was needed for this test-only diagnostics change.

## Stage 5: TestFlight preparation (issue #6, 2026-11-05)

Prerequisites #10/#11 are merged; source baseline is main 122c69c. App identity
remains com.smith3v.stream14, version 0.1 (1) pending an App Store Connect
unused-build check. No media behavior or dependency pins change in this preparation. Setup gains
a standard Privacy policy link before camera permissions, pointing to the
canonical public main-branch policy. Publishing and checking that URL signed
out is an explicit pre-upload blocker; no merge is authorized by this task.

Source audit: WebOverlayRenderer uses ProcessInfo.systemUptime only for elapsed
freshness, retry and raster timing. ExperimentSample.delete uses
FileManager.attributesOfItem only on selected UUID artifacts in the app container
to refuse recursive removal. The manifest declares Apple's 35F9.1 and C617.1
reasons respectively; there is no disk-capacity subsystem or declaration.
The selected HaishinKit 2.3.0 core and Logboard 2.6.0 source targets have no
additional matched required-reason calls or supplied privacy manifests in the
local pinned checkouts. Unselected SRT/RTC/OpenSSL package resolution is not
evidence those binaries ship. Inspect the archive's actual dependencies.

See Apple's [required-reason API documentation](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
and [manifest guidance](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk).
The app manifest declares no developer collection/tracking; the
[privacy policy](privacy.md) describes ordinary overlay website requests, original
export destinations, local Keychain/file storage and Apple TestFlight feedback.
Final App Store Connect disclosures require review of actual service flows.

Prepared [delivery instructions and beta text](testflight-delivery.md) cover
activation, archive/upload, groups, installation, expiry/replacement and remaining
acceptance. Owner reports enrollment is in progress and is waiting for Apple confirmation;
activation and App Store Connect access are not verified. No signed upload, invitation, TestFlight
installation or new physical recording has occurred. No recordings were deleted.
M3/M5 remain pending, including ≤100 ms physical sync at both ends and actual
delivered-build memory/queue measurements. The development harness cannot itself
measure a TestFlight install. Do not run another long experiment before agreeing
the measurement route and owner attention slot.

### Release packaging evidence

The native unsigned Release archive succeeded on 2026-11-05 with Xcode 27.2
(27B52), iOS SDK 27.2, Swift 6 and existing package pins:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/stream14-issue6-release \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution \
  -archivePath /tmp/stream14-issue6-final-unsigned.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
```

Private local log: /tmp/stream14-issue6-final-archive.log. The archived Stream14.app
reports version 0.1 (1), iPhone/iOS 27.0 minimum, both permission descriptions
and AppIcon. Its PrivacyInfo.xcprivacy matches the source plist exactly;
ThirdPartyNotices.txt and Assets.car are present. No xctest bundle, recording
or private signing-key file was found in the app. The target dependency graph
contains Stream14, HaishinKit and Logboard; otool -L lists only Apple system
frameworks/libraries, with no embedded transport/OpenSSL framework. Package
pins and media code are unchanged. This is packaging evidence, not Apple's signed
upload validation or approval.

plutil -lint, documentation relative-link/fence checks and git diff --check
pass. Existing iOS 27 AVAssetWriter deprecation warnings and the unused
AppIntents metadata-extraction warning remain; no new compilation error occurred.
No physical media run was repeated. The privacy-link UI change is checked
separately below.

Independent review inspected the full actual diff/source/resources. It found the
missing in-app privacy link; a standard SwiftUI Link near the top of setup now
addresses it. Focused re-review found no remaining material findings. The guide
explicitly blocks upload until owner-authorized publication makes the exact
main-branch policy URL publicly readable. Signed upload, actual TestFlight
installation, delivered-build checks and owner review remain pending.

### Setup verification after the privacy link

Two hosted AppConfigurationTests passed on the dedicated iPhone 13 mini / iOS
27.2 Simulator in /tmp/stream14-issue6-ui.xcresult. The initial portrait audit
reported contrast on the existing overlay-status caption. Its exported element
image shows black text on white; this did not reproduce on the focused rerun,
with no code changes. Both portrait and largest accessibility-text landscape
tests passed with full accessibility audits in
/tmp/stream14-issue6-ui-recheck.xcresult. Portrait and landscape screenshots were
exported and inspected; the privacy control is visible on initial portrait setup.
This is Simulator evidence only. The initial failed result is retained.

Exact passing UI command (log: /tmp/stream14-issue6-ui-recheck.log):

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,id=D6BEAF78-D273-4952-8349-B50B2824E6A9' \
  -derivedDataPath /tmp/stream14-issue6-simulator \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution \
  -only-testing:Stream14UITests/SetupScreenTests/testLaunchShowsHonestSetupStatus \
  -only-testing:Stream14UITests/SetupScreenTests/testLargestTextRemainsAccessibleInLandscape \
  -resultBundlePath /tmp/stream14-issue6-ui-recheck.xcresult test
```

Use a fresh result path on repeat runs and choose the corresponding Simulator
identifier on another Mac. The app privacy URL also appears in the final archived
binary. Its remote main-branch publication is still a pre-upload check, not
established by a compiled URL or a visible Link.

## Signed upload progress (issue #6, 2026-11-05)

The owner confirmed completed enrollment. The Apple Developer portal shows active
Program membership, and Xcode's account exposes the paid developer team.
App Store Connect initially contained no apps or builds. Created the Stream14
iOS record with the existing com.smith3v.stream14 identifier, English (U.S.) and
SKU stream14-ios. The owner had selected the display-name casing and language
during setup; the stable bundle ID is unchanged. No public App Store release was
submitted.

The exact public main-branch privacy and support URLs returned HTTP 200 without
authentication after the owner's merge of PR #12. Media source and package pins
are unchanged from main 4f831e1.

Signed Release archive command (local team remains uncommitted):

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/stream14-issue6-signed-release \
  -clonedSourcePackagesDirPath /tmp/stream14-issue3-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  -archivePath /tmp/stream14-issue6-signed.xcarchive archive
```

Archive succeeded. Strict deep codesign verification passed; identity is
com.smith3v.stream14, version 0.1, build 1, and the privacy resource matches the
reviewed manifest. Local log: /tmp/stream14-issue6-signed-archive.log.
Private signing material and raw account/tester information are not committed.

Organizer initially rejected validation because its cached account still labeled
the team Personal Team. The local archive's development provisioning profile was
the older seven-day profile, not evidence of paid distribution. Downloaded profiles
and restarted Xcode to refresh membership; Organizer then recognized the paid team.
The unmodified archive passed all App Store Connect validation checks and Organizer
reported successful upload of Stream14 0.1 (1). There was no signing bypass or
manual archive mutation.

Beta description, public privacy URL and no-login local-recording review notes
were saved in TestFlight Test Information. The owner explicitly authorized use of
existing Apple profile contact details; those remain only in Apple's designated
fields. Created the internal Owner MVP group with automatic distribution disabled
and added only the existing owner account. No third-party testers or public links
were added.

Apple processing, export-compliance status, build assignment, installation,
expiry and delivered-build acceptance are being checked separately. Owner reports
the TestFlight app is installed and ready. No new phone recording or cleanup has
run, and no M3/M5 completion is claimed.

### Processing, compliance and owner availability

Apple completed processing and displayed Missing Compliance. In the build's
App Encryption Documentation dialog, selected None of the algorithms mentioned
above: the app uses only Apple's OS-provided HTTPS/WebKit/Keychain encryption,
without proprietary algorithms or standard algorithms implemented outside the OS.
This matches the reviewed core-only dependency graph. Saved the declaration;
the build advanced to Ready to Submit without an encryption-document upload.
The app's Info.plist was not changed, so a replacement build must answer the
questions again unless a separately reviewed declaration key is added later.

Assigned 0.1 (1) to Owner MVP. App Store Connect then showed one internal tester,
one build, status Testing and Expires in 90 days (observed 2026-11-05). The existing
owner tester's invitation status is Invited. Saved build-specific What to Test
instructions covering a short recording, manual overlay hide/show, playback,
original Files export and privacy link. No external group/public invite or
external beta review was used.

Phone installation and the actual short flow remain pending owner confirmation.
A successful upload, Testing status and invitation do not establish installation,
M2/M4 or final M3/M5. The owner may answer later and needs no USB connection to
install. No long run has been started.

Focused independent review of the resolved compliance/group status update found
no material findings. The review confirmed the encryption rationale and the
separation between internal beta availability, unconfirmed installation and
pending acceptance gates. Documentation whitespace checks pass.

## Owner TestFlight recording and review (2026-11-05)

The owner reports recording approximately 35 minutes using the TestFlight app
and exporting the original MP4 to the laptop. This follows the invitation/install
flow for the only distributed local-only candidate, version 0.1 (1), main 4f831e1.
The session's testing device is the iPhone 13 mini/iOS 27.2; the owner did not
separately reconfirm the model/OS/build fields in this final message, so file
analysis itself is not independent proof of those device metadata fields.

The owner confirms picture, sound and overlay look correct, believes the audio
is correct, and requests updating PR #29 so it can be merged and issue #6 closed.
There were no visible/audible sync markers at the start/end. Treat this as actual
TestFlight use, original-file export and subjective owner review, not a measured
≤100 ms physical A/V offset or a complete formal M1–M5 qualification.

### Original-file verification

Native AVFoundation inspection and an independent compressed-sample/timing read
produced the following evidence. No app changes or new recording experiment were
needed, and the original file was neither modified nor deleted.

| Check | Observed result |
| --- | --- |
| Duration | 2,126.410430839 s — 35 min 26.410 s |
| Original file size | 3,751,346,827 bytes |
| Video | One 1920×1080 H.264/avc1 track; identity orientation transform |
| Audio | One stereo AAC track, 44,100 Hz |
| Video metadata nominal frame rate | 29.835510 fps; cadence assessed against the 30 Hz target |
| Nonempty compressed video samples | 63,440 |
| Estimated missing 30 Hz intervals | 631 / 0.98484494%, below 1% as an output-timing estimate |
| Largest sorted video PTS gap | 400 ms |
| Sorted video PTS gaps ≥500 ms | Zero |
| Duplicate video presentation timestamps | Four, near 32.908, 37.807, 39.307 and 39.573 s |
| Full native decoded-video read | Completed; 63,436 decoded buffers |
| Full native decoded-audio read | Completed; 11,448 decoded buffers |
| Owner playback/export review | Picture, sound and overlay look correct; original exported to laptop |

Cadence sorts nonempty compressed video presentation timestamps and uses exact
CMTime differences converted to 30 Hz with round-half-away-from-zero, counting
positive intervals beyond one. An initial Double subtraction produced 630 rather
than 631 estimated intervals at a half-frame rounding boundary; the independent
rational calculation above is the recorded result. This is not a direct
camera-drop or writer-admission counter, does not establish all internal queue
behavior and cannot detect every duplicated/stale picture. The full decode readers
reached completed status; do not claim every compressed sample yielded a decoded
buffer. Four duplicate timestamps match the magnitude of the count difference,
but their causal relationship has not been established.

The video's edit list accounts for a 66.7 ms compressed/decoded timeline-origin
difference. Audio has its own priming/edit structure. Comparing track endpoints
or those origins does not measure physical lip/clap sync. No numerical start/end
offset or drift is established without identifiable synchronized visual/audio
events.

Private original-derived thumbnails at 0.5, 20, 300, 900, 1,800 seconds and near
the end show real camera footage with a stable translucent scoreboard overlay;
app buttons/alerts do not appear in those inspected frames. The sampled scoreboard
is unchanged. Sparse samples and owner playback are not a new deterministic
changing-score, manual-hide, network-outage or interruption test on this build.
Earlier development evidence for these behaviors remains separately labeled.

### Acceptance and closeout limits

TestFlight installation/use, a longer-than-30-minute original file, stop/export
and owner review now have evidence. The owner requests closeout on that basis.
This does not make the formal M3/M5 criteria an unconditional pass:

- Start/end physical A/V offset ≤100 ms was not measured; subjective audio
  correctness is owner-confirmed.
- No time series for this TestFlight run's charged memory, WebKit/GPU memory,
  thermal state, queues or writer-admission metrics was exported. Do not import
  the earlier development harness's values into this run.
- Output cadence and timestamp-gap checks support the stated targets only within
  the method's limits; no complete sensor-frame-drop/frozen-frame proof is claimed.
- Prior failure/outage checks are development-build evidence, not newly repeated
  delivered-build qualification. There is no three-hour or simultaneous
  recording/broadcasting qualification.

PR #29 records the owner-requested delivery handoff with these unverified
criteria visible. Issue #6 stays open until the owner's merge/closure decision;
closing an owner-accepted delivery stage must not rewrite the formal gates as
all passed. Preserve local-only 0.1 (1) and its samples while the separately
owner-coordinated full-app work proceeds on codex/full-app (epic #13); this
verification change adds no broadcasting behavior and does not silently replace
the local-only candidate or retarget an existing PR.

Private evidence directory: /tmp/stream14-testflight-owner-verification/.
It contains inspect.swift, inspection.json/log, the independent timing reader and
JSON, edit-list analysis, verification-summary.json, original.sha256 and sampled
PNGs. The original remains at the owner-provided Downloads path. Raw footage,
thumbnails, audio-derived data, signing material and tester identity are excluded
from Git and public PR/issue attachments. The native inspection executable accepts
the original path and the private output directory; it reads the original and
writes only derived evidence there. Full video/audio decode completed on the Mac;
no new build or physical-device test was necessary for this documentation change.

Independent final review inspected the actual five-document diff and private
original-file evidence, independently reproduced the exact cadence calculation
and inspected the edit lists. It found no remaining material findings. Markdown
relative-link/fence checks and git diff --check pass. Existing local signing
settings remain excluded. The PR is prepared for the owner's merge; no merge,
issue closure or new recording is performed by this verification update.
