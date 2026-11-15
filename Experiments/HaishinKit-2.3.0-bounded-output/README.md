# HaishinKit bounded output patches

This directory contains an ordered patch set for HaishinKit 2.3.0 at
`aa2149df822f2e965adf2410a106db959b2e1962`. The
[application design](../../docs/2026-11-01-stream14-design.md#media-architecture)
describes the media pipeline. [Package.resolved](../../Stream14.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)
records the app's selected fork revision.

1. [Bounded output](0001-bounded-output.patch) adds one connection-wide queue
   for compressed media and RTMP messages. Admission counts queued and in-flight
   work. Overflow closes the transport. Network.framework completion acknowledges
   local processing. Receiver playback requires a separate check.
2. [Common origin](0002-common-origin.patch) gives compressed audio and video a
   shared timestamp origin for each publish. Start at a video keyframe and
   omit audio before that origin.
3. [Native AAC header](0003-native-aac-header.patch) handles native AAC-LC
   format flags when constructing the sequence header.
4. [Compressed video timing](0004-compressed-video-cts.patch) uses the
   input composition offset for compressed video.

The queue's mutable state is protected by a single lock and callbacks run
after releasing it. This ownership is the basis for its `@unchecked Sendable`
declaration.

## Validate the patches

Set `STREAM14_PATCH_DIR` to the absolute path of this directory. Use a clean,
isolated HaishinKit clone to apply the patch set:

```sh
git checkout --detach aa2149df822f2e965adf2410a106db959b2e1962
for patch in "$STREAM14_PATCH_DIR"/000[1-4]-*.patch; do
  git apply --check "$patch" && git apply "$patch" || exit 1
done
```

Copy the patched `HaishinKit` and `RTMPHaishinKit` directories to a temporary
directory. Copy [ValidationPackage.swift](ValidationPackage.swift) there as
`Package.swift` and run `swift test --skip releaseWhenClose` in that directory.
The skipped test needs a local RTMP server. The validation package resolves
Logboard 2.6.0, or uses the local checkout specified by `STREAM14_LOGBOARD_PATH`.
Use the normal iOS package manifest and physical qualification when changing
the app's dependency pin.
