# Native MP4 fragment recovery feasibility

This is an early F11 investigation for issue #24, based on `8af669f` (PR #47), not production F11 integration or A5 acceptance. No app code, shared encoder, manifest, recordings UI, or phone plan changed. F6/F9 prerequisites and the actual iPhone checks remain pending.

## Native candidate and API requirements

Use the existing MP4 container with `AVAssetWriter.movieFragmentInterval = CMTime(seconds: 10, preferredTimescale: 600)` **before** starting writing. Leave `initialMovieFragmentInterval` at its invalid default (same interval). Do not enable segment-delegate/HLS output, `producesCombinableFragments`, or a new parser. Read an interrupted original through `AVURLAsset` and `AVAssetReader`; if useful, export a **different** URL using `AVAssetExportPresetPassthrough` and `.mp4`. This is a remux candidate, not an in-place repair API. An unreadable pre-fragment original remains interrupted/unrecoverable by this measured path, visible and retained for export or deliberate deletion.

Apple's installed macOS 27.2 SDK headers were inspected directly:

- `AVAssetWriter.h`: fragments must be configured before writing; the default disables fragments. The initial interval defaults to the regular interval. `cancelWriting` deletes an output it created: never use cancellation on a valued partial file.
- `AVAssetReaderOutput.h`: nil output settings skip decoding and preserve decode order. Marker-only buffers can occur; identify them with zero sample count. Do not treat a marker's missing data buffer as lost media.
- `AVAssetExportSession.h`: passthrough is a supported preset; composition/mixing settings are ignored by this preset. This probe adds neither.

Official references: [fragment interval](https://developer.apple.com/documentation/avfoundation/avassetwriter/moviefragmentinterval), [initial interval](https://developer.apple.com/documentation/avfoundation/avassetwriter/initialmoviefragmentinterval), [reader track output](https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput), [passthrough preset](https://developer.apple.com/documentation/avfoundation/avassetexportpresetpassthrough), [Apple reader/writer/export guide](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/05_Export.html). Some modern web pages required JavaScript/returned unsupported Markdown to the browser tool; declarations and comments were checked in the actual Apple SDK, rather than inferred from secondary wrappers.

## Repeat on a Mac

From the repository root:

```sh
xcrun swiftc -O -swift-version 6 -module-cache-path /private/tmp/stream14-f11-module-cache -parse-as-library Tools/fragment-recovery/Probe.swift -o /private/tmp/stream14-fragment-probe
python3 Tools/fragment-recovery/run.py /private/tmp/stream14-fragment-probe /private/tmp/stream14-f11-native-new-run
```

The output directory **must not exist**. The harness never removes existing artifacts. In a restricted Codex sandbox, allow native codec-service access for the run: the sandbox-only attempt rejected the AAC writer input. Each writer is an owned child process. The parent sends SIGKILL only to that un-reaped child's PID; no camera, microphone, app, simulator, network, or user recording is accessed. Generated frames use a changing color pattern with a 440 Hz PCM tone, encoded to H.264/AAC by AVAssetWriter. Video is 320×180 at 30 fps; audio is mono 48 kHz. This tests native fragment behavior, not target-profile performance. Real-time input flags match the app; an earlier non-real-time prototype stalled waiting for readiness and was stopped by its own harness timeout. Those incomplete originals remain private as well.

The final command exits successfully only if decoded readers and compressed readers finish, both tracks have data, original and export compressed byte hashes/decoded sample counts match, the normal control has 750 video frames, the pre-fragment case fails honestly, and all original SHA-256 values remain unchanged. Reader buffers may regroup AAC packets during export, so buffer counts are not used as media identity. Only zero-sample marker buffers are skipped. Packet-byte identity is stronger than claiming passthrough from the preset name alone, but does not independently test every format attachment or metadata field.

## Measured results — 2026-11-08

macOS 27.2 build 26B123; Apple Swift 6 language mode; native Mac run, no simulator/device. The final private artifacts and detailed JSON are in `/private/tmp/stream14-f11-native-run8`; stdout is `/private/tmp/stream14-f11-native-run8.log`. Build log: `/private/tmp/stream14-f11-build.log`. The build passes with Apple's macOS 27 deprecation warnings for the older public reader/writer APIs used by the current app; no unchecked concurrency annotations or extra dependencies were added.

| Case | Appended media | Original bytes | Decoded video / PCM frames | Asset duration | Native passthrough result |
| --- | --- | --- | --- | --- | --- |
| Normal stop | 25 s | 326,413 | 750 / 1,200,000 | 25 s | Success; distinct 309,126-byte MP4 |
| SIGKILL before first fragment | 5 s, then 500 ms drain | 33,828 | Cannot open | Unavailable | Fails; no recovered artifact |
| SIGKILL after fragments | 25 s, then 500 ms drain | 302,826 | 600 / 959,424 | 20.033333 s | Success; distinct 242,567-byte MP4 |
| SIGKILL racing finalization | 25 s; after `finishWriting` called | 295,884 | 600 / 959,424 | 20.033333 s | Success; distinct 242,567-byte MP4 |

The killed readable cases lose 150 of 750 submitted video frames (5 s at the generated rate) and 240,576 of 1,200,000 PCM frames (5.012 s). AAC decoded end is 19.988 s. Asset duration is not an A/V sync measurement; the last decoded video PTS is 20 s and its endpoint estimate depends on available sample duration/frame-rate metadata. Both decoded readers reach `.completed` for originals and recovered files. Both compressed readers reach `.completed`, and per-track concatenated payload SHA-256 and byte count match original versus recovered in all successful cases. All four original files remain byte-identical after inspection/export.

Pre-fragment read fails with AVFoundation `-11829` / underlying `-12848` (cannot open/damaged media). Passthrough export fails with `-11800` / underlying `-16979`. File existence and nonzero size are clearly insufficient to label such a recording complete or recovered.

The finalization case records `finish-started`, no completion callback, and child exit `-9`; it retained only completed fragments in this run. The kill is a scheduling race after the asynchronous finalization API call, not proof that a particular filesystem instruction was interrupted. A future run that finishes before kill must be recorded as such, not silently counted as an interrupted finalization.

## Integration guidance and remaining evidence

F6 can reserve the concrete writer setup hook for setting the fragment interval before `startWriting`. Its compressed H.264/AAC passthrough inputs and production timing/format attachments still need this same probe repeated; these results use writer-owned encoding, not the selected shared encoder. Do not couple a streaming failure to local cancellation. Preserve independent status and original/recovered URLs; only finalization success marks the original complete. Readable fragments justify offering a recoverable/interrupted item, not promoting the original to completed. Any failed export must retain original and partial recovered artifacts without automatic cleanup.

No MOV comparison is justified yet: MP4 plus native passthrough already succeeds in the measured post-fragment cases. No custom parser, transcoder, movie surgery, database, or recovery architecture is proposed. The first ten seconds remain vulnerable; shortening the initial interval is a separately measured choice, not an implicit requirement change.

Later checks must use new expendable app files and fit within the owner's **five-minute total routine phone budget**, coordinated by the root agent with other stages. Prepare the fixture, install, tooling and exact steps off-phone first. If budget permits, target a clean 12-second stop, a termination around 5 seconds, and a termination after 22–25 seconds, then inspect originals/recovered exports off-phone with decoded reads and measured loss. An additional finalization-race check needs a deterministic app test hook and remaining shared budget. No long run, deletion, app reset or uninstall is authorized by this report. iPhone camera/overlay continuity, actual app relaunch statuses, playback/export UI, compressed production writer recovery and A5 all remain unverified.

Independent review is coordinated by the root agent before PR handoff. This feasibility checkpoint must not close issue #24.
