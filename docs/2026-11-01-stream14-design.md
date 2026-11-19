# stream14 application design

stream14 lets one operator broadcast a volleyball event from an iPhone to an
existing scheduled YouTube event, with an optional web scoreboard and a local
backup. The app uploads directly to YouTube; it has no relay, login of its own,
analytics, or cloud recording. Local rehearsal works without Google.

The performance target is landscape 1080p30 for one- to three-hour events, with
an iPhone 13 mini on iOS 27 as the minimum test device. The endurance acceptance
gate is one continuous hour; the target is not a qualification claim. See the
[device evidence and acceptance gates](qualification-report-template.md).

## Operator workflow

- **Session** progresses from preparation through active session and finish.
  **Recordings** stays a separate tab. In landscape the preview is on the left,
  the controls scroll on the right, and **More → Navigate** replaces the hidden
  tab bar. Navigation and rotation don't start or stop media outputs.
- **Camera preview** opens the composed preview and requests camera and
  microphone permission in context. A denial points to Settings. Choose quality
  before opening the camera. The preview puts compatible rear-lens selection
  next to microphone mute. Wide is the
  default; Ultra Wide and Telephoto are shown when supported. Zoom is relative
  to the selected lens and limited by the device and the 10× app cap. Use the
  system-selected microphone route, with input label, meter and mute.
  Zoom adjustments retain the start controls in place, disabled while the camera
  is applying the change, to preserve the control panel's scroll position.
- The preview follows window orientation in portrait and both landscapes. The
  mixer rotates camera input before composition; portrait fits inside the fixed
  16:9 canvas. Start in landscape. Freeze the profile from camera open and the
  orientation from recording startup through active recording/upload. **Close
  camera** is for preview only and unlocks quality selection.
- **Choose event** shows the authorized channel, scheduled local time, title,
  visibility and eligibility for existing events. Settings and event selection
  never send camera media. No upload test is required. **Start recording and
  streaming** confirms the channel, event, visibility and profile. **Record only**
  is available independently of Google. Connection and account switch use the
  official YouTube wordmark; event data is attributed with a link to Studio.
- During the event, show the complete picture, elapsed time, overlay status,
  microphone controls, and independent **Local saving**, **Upload**, and
  YouTube states. Only a confirmed YouTube state displays **Live**. Starting,
  reconnecting, uncertain remote state, and backup failure have distinct text.
  Settings changes apply to the next session. App controls and warnings stay out
  of the picture, and warnings don't play into the microphone.
- Show **Start recording and streaming** in green when the selected destination,
  landscape preview, overlay and local writer are ready. **Record only** is
  neutral and appears when local recording can start. The landscape prompt
  appears by the start actions in bold headline text with a rotate-phone icon and
  Dynamic Type support. Use consistent button heights that accommodate
  Dynamic Type and matching destructive styling for the three stop actions.
- **Stop recording only** confirms file finalization and preserves an active
  upload. **Stop streaming only** confirms detaching the upload and cancelling
  reconnect attempts, preserving local recording and the session destination.
  Show **End session** while both outputs are active. After either stops, use the
  remaining output's stop action. Stopping the final output closes capture and
  finishes the session, including remote completion for a connected event as
  explained in its confirmation. Pending remote completion keeps **Finish YouTube
  event**, reconciliation and Studio controls available. A saved-key event can
  end by Auto-stop after ingest stops.
- **End session** confirms the operation and reports local finalization separately
  from remote completion. An unknown remote result offers reconciliation and
  Studio; a stopped upload is not proof the event ended. **Prepare next session**
  is blocked by active outputs, finalization or unresolved remote work. It clears
  the selected event and reevaluates destination availability without starting media.
  The completed workspace hides **Camera preview** until the next session is prepared.
- **Recordings** shows date, size, status and elapsed `HH:MM:SS` when available,
  with spoken duration and recovery warnings for VoiceOver. Support original
  playback, explicit Files/share export and confirmed deletion. Missing metadata
  is shown as unavailable. Use native controls, Dynamic Type, at least 44-point
  targets and readable status without color.

## Media architecture

```text
Rear camera + system microphone
  → HaishinKit MediaMixer (camera orientation, full-canvas alpha overlay, audio)
     ├─ Metal preview
     └─ SharedMediaEncoder (H.264 / AAC, common media timeline)
        ├─ LocalRecorder (passthrough AVAssetWriter → fragmented MP4)
        └─ RTMPSPublisher (bounded transport → YouTube)
```

| Profile | Canvas | Video target |
| --- | --- | --- |
| 1080p30 (default) | 1920 × 1080 | 14 Mbps |
| 720p30 | 1280 × 720 | 8 Mbps |

Both profiles use 30 fps, SDR Rec. 709 H.264 with a two-second maximum keyframe
interval, and AAC-LC stereo at 44.1 kHz / 128 kbps. VideoToolbox targets average
bitrate. There is no adaptive resolution or second encode for the local copy.
Keep the scene and audio timeline shared through recording and streaming.
Portrait broadcasting, multi-camera, 60 fps, HDR, and background or locked-screen
capture are outside scope.

- [MediaSession](../Stream14/Media/MediaSession.swift) owns capture, composition
  and output lifecycle. SwiftUI and WebKit use the main actor. The mixer,
  encoder, writer and publisher isolate serial media work and use bounded
  admission. File and RTMPS consumers share compressed samples and a common
  source clock; RTMPS rebases each publisher to a new keyframe and discards
  pre-origin audio. Keep AAC format metadata stable across converter buffers
  when the codec configuration is unchanged, so the writer retains one audio track.
- [SharedMediaDestinations](../Stream14/Media/SharedMediaDestinations.swift)
  mediates independent writer/transport admission. A slow or failed publisher
  cannot block the file. Writer failure after startup leaves a healthy upload
  running and keeps a persistent warning; a new recording needs a new session.
  A failure of the shared capture/encoder itself can stop both outputs.
- The pinned owner-maintained [HaishinKit fork](https://github.com/smith3v/HaishinKit.swift)
  supplies capture, offscreen composition, and RTMPS protocol/TLS integration.
  The fork provides bounded, acknowledged transport, explicit timestamp origin
  and audio-start handling without implementing RTMP framing and connection
  lifecycle in the app. The [lockfile](../Stream14.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)
  is the source of exact revisions. The app links HaishinKit and RTMPHaishinKit
  (with Logboard); SRT, RTC and their native packages are resolved but not linked.
  Recheck fork compatibility, clock, queue, and lifecycle behavior on updates.
  Google Sign-In handles browser authorization and Keychain credentials; the
  YouTube REST surface uses URLSession/Codable. See [notices](../Stream14/ThirdPartyNotices.txt).

## Web overlay

An optional operator-supplied HTTPS URL is stored in Keychain. Edit a draft and
explicitly apply it while idle or in preview. Invalid input or storage failure
leaves the active source unchanged. Clearing the URL explicitly disables the
overlay; an example URL is opt-in. A configured overlay must be ready before
Go Live. The operator can reload it or hide/show it manually.
Keep the overlay status current while allowing 10 seconds of continuous
unavailability before showing the recovery warning, **Retry overlay** and
**Overlay settings**. A new profile or explicit reload restarts this delay.

[WebOverlayRenderer](../Stream14/Media/WebOverlayRenderer.swift) uses an attached
WKWebView at the selected canvas dimensions in CSS pixels and normalizes the
snapshot to that same raster size. Use a nonpersistent WebKit data store.
Preserve alpha and placement, independent
of display points, scale, and safe areas. Use one outstanding snapshot about
once per second and reuse the last good image between captures. Bound resource
readiness and skip overlay work rather than stall video. Browser audio, popups,
downloads, site login flows and native permission/message bridges are unsupported.

Keep source-access and usable-render freshness separate. An unchanged score with
successful access is healthy; snapshots of stale cached content do not prove
access. Keep the last good image through brief outages, then hide it in all
outputs after 10 seconds without confirmed access or a usable render. Restore only
after confirmed access and a fresh usable image, unless manually hidden.
In-place page updates need a source-health signal to establish their own backend
freshness. At serious thermal pressure, snapshot less often without changing the
media profile.

## YouTube authorization and broadcast lifecycle

Connect and restore require explicit agreement to the current privacy and
service/YouTube terms. Google Sign-In uses the supported system-browser flow
and one YouTube scope, `youtube.force-ssl`, for channel/event reads and
stream binding and broadcast transitions. The actual API channel is authoritative;
an account email or delegated Studio access does not identify it. Fence in-flight
work by authorization generation. When the configured OAuth client changes, clear
a mismatched restored grant and require reconnection while retaining local files
and reconciliation state. See [OAuth setup](ios-development-guide.md#google-oauth-and-youtube).

[BroadcastSession](../Stream14/Broadcast/BroadcastSession.swift) coordinates the
same media owner used for rehearsal. An explicit start freezes the account,
event, settings and confirmation metadata, rechecks readiness and waits for the
local writer to accept media before starting upload. An initial writer failure
blocks publishing. API/startup failure, lost transport and a
remotely ended event do not stop a healthy writer.

For a **Connected YouTube event**, use the following lifecycle.

- Resolve the exact selected event and its binding. Reuse a compatible inactive
  binding, including a default reusable stream key. If unbound, create and bind a
  non-reusable stream only after confirmation. Never silently unbind, change
  event settings, or create a replacement event. Use YouTube's RTMPS address
  and stream key with normal TLS. Shared keys are not exclusive: sibling events
  configured for auto-start and parallel encoders can race the inactive check
  ([issue #65](https://github.com/smith3v/stream14/issues/65)).
- Require auto-stop off in Studio. If auto-start is enabled, first upload can
  start the event; poll instead of issuing a redundant transition. Otherwise wait
  for active ingestion. If monitor stream is enabled, request the required
  testing transition and confirm testing before requesting Live. If disabled,
  skip testing; an unknown required setting blocks manual startup. A
  read-confirmed live event is the only success signal. Startup is bounded at
  60 seconds and the remote End attempt at 15 seconds.
- Keep protected, backup-excluded journals for uncertain create/bind and
  testing/live/complete operations. Record intent before mutation and keep a
  known created stream ID before retrying a bind. Read exact-event state before
  retrying a mutation; an ambiguous create or transition must not be blindly
  repeated. Keep publishing blocked when journal state is corrupt or status
  cannot be safely reconciled. End starts local shutdown independently of the
  bounded remote Complete attempt.
- While the shared capture and encoder pipeline is active, retry a dropped
  transport using the same admitted event, binding and profile. Back off
  between attempts and respect service retry delays. Stop retries on operator
  stop, event completion or an unsafe destination. Temporary status-read
  failures leave healthy outputs running. Never create a replacement event or
  repeat the Live transition on reconnect.
- Sign-out retains reconciliation state. Explicit local data deletion, revoke
  and confirmed access loss clear saved API-derived IDs and invalidate readiness,
  retaining recordings and overlay settings. Local deletion does not revoke
  remotely or end an event. On use, age out stored API IDs at 30 days (including
  undated or clock-invalid records). Erasing pending context leaves a
  nonidentifying Studio-resolution guard across relaunch; failed erasure blocks
  publishing. The operator must resolve the old operation before clearing it.

### Saved YouTube stream key

Studio Managers and operators with a reusable key can use **Settings → YouTube →
Stream key** without Google sign-in. Save one key in the device-only,
nonsynchronizing Keychain. Replacement updates the existing item in place. Removal is separately confirmed. YouTube Settings groups account
actions and key configuration above the policy and account links.

Session prefers an authorized YouTube account, including one restored at launch.
After the account check finishes, Session uses the saved key when no YouTube
account is connected. An authorized account still requires an eligible event.
An unresolved API session retains its reconciliation controls and blocks a new
stream. A confirmed or active session keeps its captured destination.

In YouTube Studio, assign the key to one upcoming encoder event with Auto-start
if the event should go live on ingest. Turn Auto-stop off to keep the event open
through an outage. End it in Studio after stopping the saved-key upload.
In Session, the Start confirmation identifies the saved-key destination and
warns that sending video can start the assigned event. The app uses the
existing writer and RTMPS publisher with YouTube’s primary ingest endpoint
(`rtmps://a.rtmps.youtube.com:443/live2`). It makes no event API calls or changes
to the Studio event. End stops upload and local capture and finalizes the file.
YouTube normally ends an Auto-stop event around a minute after ingest stops.
The app reports the connection and local saving states. Verify the event itself
in Studio. See [YouTube’s RTMPS requirements](https://developers.google.com/youtube/data/live/guides/rtmps-ingestion)
and [Auto-start and Auto-stop](https://developers.google.com/youtube/data/live/life-of-a-broadcast).

After an admitted upload drops, a healthy recording continues while the app
retries the frozen ingest destination. An extended outage can trigger Auto-stop
if enabled. For an initial connection failure, check the assignment in Studio,
then explicitly confirm a retry while local recording continues. Use the same
saved key for the next event by assigning it in Studio and choosing **Prepare
next session** in the app.

## Interruptions, files and recovery

Keep the phone awake during recording and restore the previous idle-timer
setting at teardown. Background/lock, capture or encoder failure, loss of
required audio input, and critical heat can stop both outputs. Preserve the
file and pending event; an interruption does not send Complete. Preview-only
intent may restore in foreground using a fresh mixer and moving-frame readiness;
manual Close cancels it. After process termination, **Resume streaming** is
available for a previously admitted saved-key upload. Its profile is stored
with the key in Keychain and is cleared on key replacement or explicit stop.
The operator starts recovery in the foreground. For a connected event,
**Resume same event** checks the original compatible inactive binding and
absence of uncertain mutations, opens the preview if needed, and asks the
operator to confirm the event and visibility. If resuming an already-live
event, publication requires it to remain live and never repeats the Live
transition. Either recovery creates a new file and timeline.

On a device with multitasking camera access, Picture-in-Picture keeps the same
capture, writer and admitted upload running while the PiP window is active.
The web overlay pauses in the
background and refreshes on return. An upload failure retries the frozen ingest
destination with bounded backoff and service retry delays. Returning to the app
leaves a healthy transport in place. A connected event must still be live and
match its original channel, event, binding and RTMPS destination. A native
capture interruption finalizes the original file. When Stream14 can reopen
capture in the foreground with previously granted permissions, it starts a new
local file before reattaching upload to the same destination. The recovery
control shows why capture cannot reopen yet and lets the operator retry after
automatic attempts stop. Saved-key retries use the frozen RTMPS key. YouTube Studio
determines which event receives the stream if the key is reassigned.
An explicit upload stop or End
disarms recovery, including after relaunch. Stopping local recording leaves
transport recovery available while capture stays open and disarms recovery that
would start a new file. If the Keychain or journal update fails, a protected
local marker blocks old recovery until a newly confirmed upload succeeds.

The writer requests ten-second MP4 fragments and declares completion only after
confirmed finalization and bounded structural validation. Wait at most five
seconds for native writer finalization; an outstanding native
finalizer keeps ownership and blocks a new writer until it returns. A timeout
preserves the original and a late result cannot mark it complete. Disk/write
faults or interrupted sessions retain usable or partial files. Files lacking
metadata remain visible, with
incomplete provenance when appropriate. Native readable-start inspection does
not prove whole-file integrity. Recovery attempts an explicit passthrough export
to a separate file, may lose unfinished fragments or trim the tail, and can fail
before a usable fragment exists. Never rewrite or automatically delete originals.
Deletion explicitly targets a selected original group or an individual recovery
copy; export neither deletes nor transcodes the original. Storage estimates and
proactive space polling are out of scope.

Per-recording diagnostic checkpoints are bounded, backup-excluded and local.
They contain numeric measurements and fixed diagnostic categories, including the
most recent RTMPS startup failure and the encoder failure when available. They contain no URLs,
account/event IDs, raw payloads or media. Checkpoint/export success is not
qualification; see the [measurement procedure](qualification-report-template.md).
