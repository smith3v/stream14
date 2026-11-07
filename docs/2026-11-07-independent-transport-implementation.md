# Independent Transport Implementation Plan

**Goal:** Resolve the remaining single-encoder and transport-admission feasibility questions before wiring a production broadcaster.

**Architecture:** Keep the existing HaishinKit capture/composition and production LocalRecorder unchanged while F1 remains unqualified. A test-target-only native H.264/AAC prototype can evaluate one encoder per media track and compressed MP4 fan-out. Pinned RTMP output currently lacks acknowledged bounded admission, so an application queue alone is not evidence of a bounded complete sender.

**Tech Stack:** Swift 6, native Xcode/Swift Testing, VideoToolbox, AVAudioConverter, AVAssetWriter, pinned HaishinKit/RTMPHaishinKit 2.3.0 test product.

---

## Scope and gate

This stage follows the owner's explicit stacked-PR authorization and begins from F4 branch `codex/issue-17-session-controls` at `9152d05`. The isolated worktree is `/private/tmp/stream14-epic13-f6`, branch `codex/issue-19-independent-transport`. F3/F5 prerequisites will join through a later root-coordinated merge, without rewriting shared history.

Issue #19 explicitly says it remains blocked if F1 is unresolved. F1 PR #40 establishes public signatures and offline compressed-writer passthrough, not successful live compressed ingestion, initial A/V-origin handling, reconnect behavior or physical performance. Production adoption is not authorized by a prototype result. No second production encoder, capture/compositor replacement, network publication or production MediaSession wiring is part of the initial checkpoint.

## Source audit — 2026-11-07

The pinned revision is `aa2149df822f2e965adf2410a106db959b2e1962` (HaishinKit 2.3.0):

- `RTMPStream.append` accepts H.264 CMSampleBuffer and AAC AVAudioCompressedBuffer. It returns Void, catches/logs timestamp errors, and independently rebases each track's first strictly positive timestamp to zero. A positive common capture timeline is necessary, but does not itself preserve the original initial A/V offset on the wire.
- `RTMPStream.doOutput` creates a Task per encoded message. `RTMPConnection.doOutput` serializes chunks and creates another Task to send them. `RTMPSocket.send` increments private `queueBytesOut` then yields into an unbounded AsyncStream. Its consumer awaits Network.framework send completion.
- Public `setVideoInputBufferCounts` bounds raw encoder input only. Awaiting public compressed append does not await socket admission or completion. Public network reports are observational, not a reliable admission acknowledgment. A finite app queue cannot alone prove finite library tasks/socket backlog.
- A concrete app-owned single native encoder after the mixer could avoid duplicate encoding without replacing capture/composition. It is a candidate requiring explicit architecture review and physical evidence, not the currently selected production path.

Relevant exact source paths are `RTMPHaishinKit/Sources/RTMP/{RTMPStream,RTMPConnection,RTMPSocket,RTMPTimestamp}.swift` at that revision. Apple's installed iOS 27.2 SDK declares a Sendable VTCompressionOutputHandler; buffers must remain immutable after submission and timestamps strictly increase. VTCompressionSessionCompleteFrames can bound prototype in-flight work synchronously without a per-sample Task. AVAudioConverter provides the native PCM-to-AAC adapter.

## Task 1: Review the decision before production changes

**Prompt:** Present the audit and alternatives to the root coordinator: retain the current local-only production path while resolving F1; investigate a single native shared encoder; or obtain a reviewed library change exposing bounded acknowledged compressed admission. Do not choose a duplicate encoder or claim full F6 completion. Commit this plan, then wait for the root's scope response before production-path edits.

## Task 2: Test the native single-encoder candidate, if approved

**Prompt:** Add a test-only `Stream14Tests/SharedEncodingPrototypeTests.swift` with generated deterministic video/audio. Encode with one VTCompressionSession and one AVAudioConverter, retaining at most one in-flight video frame in this finite prototype. Feed the resulting compressed packets to two independently owned MP4 passthrough writers and compare actual codec bytes/timestamps, including one writer's injected failure. Exercise compressed RTMP calls only with positive strictly ordered timestamps, explicitly distinguishing API calls from receiver acceptance. Do not capture camera/microphone or open a connection. Keep private synthetic artifacts disposable; never delete device originals. Commit meaningful checkpoints.

## Task 3: Validate and hand off

**Prompt:** Build with the native shared Stream14 scheme, using private paths and the installed package cache; request the root's Simulator lease before execution. Run only the relevant deterministic tests plus affected existing tests; document actual counts/commands and any compile failures honestly. Run plist/content/link checks and git diff --check. Obtain independent review of the actual full diff against main and focused predecessor delta before PR handoff; resolve material findings, rerun affected checks and commit. Root creates the stacked PR after review. Physical upload/file comparison, two-minute outage, surviving writer failure, sync markers, finite transport backlog and 13 mini thermal/memory remain pending.

## Owner setup at this checkpoint

The root reports Google Cloud/API/iOS public client and owner tester setup now exists; real in-app authorization/scope and a dedicated unlisted event/RTMPS destination remain pending. Phone readiness is unconfirmed. No real client ID, credential, private endpoint, stream key or raw recording belongs in this document.

## Checkpoints and concrete experiment

- `3089be3`: initial source audit and gate plan.
- `2c5233c`: compiled finite native encoder prototype; its initial runtime tests did not pass and were retained.
- `710fd0b`: concrete unadopted [bounded-output patch](../Experiments/HaishinKit-2.3.0-bounded-output/README.md), original BSD-3-Clause license, reproducible validation manifest and explicit adoption limits. Applied source lives in `/private/tmp/stream14-f6-haishinkit`; this is never a shared package cache.

`Stream14Tests/SharedEncodingPrototypeTests.swift` generates a one-second 720p
brightness transition and stereo tone transition at the midpoint. Each clip uses
one VTCompressionSession and one AVAudioConverter. Both compressed file consumers
receive the same packet objects; packet comparison normalizes AAC grouping and
explicitly records the encoder-priming/container timestamp adjustment. Decoded
video and PCM midpoint detection is separate from that normalization. The encoder
flushes one frame before submitting the next; this bounds in-flight prototype work
but is not a realtime capture-performance design or measurement.

The native AAC writer initially rejected samples without the required encoder-delay
trim attachments. Actual converter magic cookies and leading/trailing trim metadata
now accompany the native compressed packets. Subsequent file readback showed a
2112-frame / 44100 Hz AAC packet-origin normalization; this is not evidence that a
future RTMP sender preserves the same initial A/V origin. A playable-file marker
check and the live transport timing problem must remain distinct.

An additional synthetic fault experiment stalls its finite sender seam while one
consumer is marked failed, then finalizes the retained partial file with that
failure flag intact. `cancelWriting` is not used for this failure path: the observed
native API removes its output file. The test-only failed flag is not a production
recording manifest, and no actual disk-full, camera or receiver failure was run.
Current production LocalRecorder/MediaSession failure behavior is unchanged.

### Package candidate checks

The actual full HaishinKit and RTMP source targets from the local patched clone
compiled in the reduced manifest. `/private/tmp/stream14-f6-patch-tests-5.log`
records 34 passing tests in 15 suites, including eight new admission/lifecycle/ordering tests.
The original full manifest was stopped while downloading unrelated binary products;
it is not reported as a pass. The committed validation manifest parses with the
documented optional local Logboard path. Reverse-apply checking confirms the patch
artifact matches the isolated applied source. Independent review is pending.

The proposed sender acknowledges local Network.framework processing, not receiver
receipt. Its queue reserves finite bytes/messages before task retention, keeps the
in-flight message charged even after close, and fails the entire connection on
overflow. Its NSLock ownership argument and tests are recorded beside the patch.
Actual patched-iOS product building, live socket cancellation, TLS/receiver output,
initial A/V-origin semantics, reconnect and phone performance remain adoption gates.

### Native prototype and stack evidence

The two synthetic hosted tests passed on the dedicated iPhone 13 mini/iOS 27.2
Simulator at `/private/tmp/stream14-f6-prototype-4.xcresult` (log beside it). Both
compressed file consumers preserved packet bytes and explicitly normalized
encoder-priming timestamps. Independent decoded midpoint markers satisfied
video position within 5 ms of 0.5 seconds and relative generated A/V onset within
35 ms. This is an offline synthetic-file result, not camera/receiver/physical
synchronization evidence.

The reviewed F5 predecessor `ce00961` merged cleanly as `e2a3b66`. Combined
prototype/LocalRecorder/AppConfiguration build-for-testing passes; eight hosted
checks in three suites passed without skips at
`/private/tmp/stream14-f6-stack-checks.xcresult` (log beside it). The application dependency pins and
production media path remain unchanged.

Independent package review found handshake/command ordering and reconnect-during-
close races in the first candidate. Both were corrected with awaited common socket
output and guarded cleanup lifecycle; deterministic regressions pass. The actual
source and exported patch await focused re-review.

Exact merged Simulator reproduction (choose a fresh result path):

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,id=D6BEAF78-D273-4952-8349-B50B2824E6A9' \
  -derivedDataPath /private/tmp/stream14-f6-simulator \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f2-packages \
  -disableAutomaticPackageResolution \
  -only-testing:Stream14Tests/SharedEncodingPrototypeTests \
  -only-testing:Stream14Tests/LocalRecorderTests \
  -only-testing:Stream14Tests/AppConfigurationTests \
  -resultBundlePath /private/tmp/stream14-f6-stack-repeat.xcresult test
```

The physical-SDK build-for-testing uses the same selectors with
`-destination 'generic/platform=iOS'`, its own DerivedData and
`CODE_SIGNING_ALLOWED=NO build-for-testing`; it is compile-only and cannot be
installed unsigned. A signed on-phone synthetic run remains separately pending.

Retained failed prototype bundles are `/private/tmp/stream14-f6-prototype.xcresult`,
`-2.xcresult` and `-3.xcresult`. They exposed missing AAC trim metadata, then a
container/priming timestamp normalization assumption and the destructive effect of
synthetic cancelWriting. The final marker test is not substituted for those
failures or for any physical transport acceptance.

### Final compile checkpoint

The merged-stack physical iPhone SDK build-for-testing passed at
`/private/tmp/stream14-f6-device-build-tests.log`, using the native shared scheme,
`generic/platform=iOS`, the same three focused selectors and
`CODE_SIGNING_ALLOWED=NO`. This compiles the prototype and existing conditional
physical-test code; no unsigned product was installed and no phone/camera/network
run occurred. The app dependency still resolves unmodified upstream HaishinKit.
This is distinct from building the unadopted patched library as the intended iOS
product, which remains pending before adoption.

The owner reduced routine connected-phone checks to a five-minute budget. The
consolidated phone-plan branch owns that revised smoke schedule; this stage does
not start any physical experiment. Longer F1/F6 acceptance scenarios remain
coverage backlog requiring a separately agreed slot, with the development cap
still applicable unless the owner explicitly agrees otherwise.

Independent native-prototype review found no material findings; the focused
package-patch re-review is being coordinated by the root after both race fixes.
The root handles reviewed chained PR publication and subsequent ledger updates.
