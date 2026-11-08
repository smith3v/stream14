# Local bounded-output patch candidate

This is a reviewable **unadopted experiment**, not a fork publication or an app
dependency change. Apply only to HaishinKit 2.3.0 commit
`aa2149df822f2e965adf2410a106db959b2e1962`. The app remains pinned to upstream.
The BSD-3-Clause source license is retained in LICENSE.md. No new dependency or
transport product is added by this patch.

## Why it exists

In upstream, compressed append schedules a Task in RTMPStream, another Task in
RTMPConnection, then yields bytes into an unbounded RTMPSocket AsyncStream.
A bounded application frame queue cannot bound those retained messages.

The candidate replaces per-message handoff Tasks with synchronous admission into
one connection-wide FIFO and one drain worker. A second scalar-event worker aborts
the socket on the first output failure. Neither worker is created per sample.
Admission reserves payload bytes plus conservative chunk-header overhead and counts
queued **and in-flight** messages. Default limits are 4 MiB and 128 messages.
Serialization can additionally retain one in-flight chunk expansion, bounded by
that message's reservation; the logical byte limit is not a measured total process
memory limit. Handshake C0C1/C2 use the same acknowledged socket path before RTMP commands; the old independent AsyncStream sender is removed. Socket admission has an additional 4 MiB cap.
Overflow closes the complete transport generation; arbitrary RTMP chunks are never
dropped while a connection continues.

On cancellation/close, every pending completion is removed under the queue lock
and resumed once outside it. One socket-owned in-flight message remains charged
until its actual completion. Reusing a connection while that completion is still
outstanding is rejected, rather than granting false credit to a new generation.

## Exact API changes

- RTMPConnection initializer gains `maximumPendingOutputBytes` and
  `maximumPendingOutputMessages` with the finite defaults above.
- RTMPStream gains `sendCompressedVideo(_:) async throws` and
  `sendCompressedAudio(_:when:) async throws`. They validate publishing state,
  queue codec headers before payload in the same FIFO, propagate timestamp/errors
  and await Network.framework `contentProcessed`. This acknowledges local network
  processing, **not server receipt or decoded media**. The application still needs
  one bounded pump and a keyframe-safe reconnect policy.
- Existing void append APIs use the bounded handoff too, but retain their original
  error-reporting contract. App code must use the new throwing APIs for explicit
  admission/completion failures.

This patch deliberately preserves upstream's separate first-track timestamp
rebasing. It does **not** resolve initial A/V offset, AAC priming across reconnect,
stream metadata for externally encoded media, receiver delivery, or physical
performance. Those remain required before any production selection. Publishing
still starts the upstream outgoing-codec workers; with only externally compressed
input no native codec session is fed, but a reviewed explicit external-encoding
mode may be preferable before adoption.

## Lock ownership

The new queue uses NSLock to retain the package's deployment support. Its
`@unchecked Sendable` declaration has a narrow ownership argument: all mutable
state is private behind the same lock; immutable message/lease snapshots are
Sendable; callbacks leave the lock before resumption. Concurrent admission,
close/ack races and exactly-once callback tests exercise that argument. This is
isolated package-candidate code, not a suppressed app concurrency diagnostic.

## Reproduce

From an isolated exact-revision clone, never a shared SwiftPM checkout:

```sh
git checkout --detach aa2149df822f2e965adf2410a106db959b2e1962
git apply --check /absolute/path/to/0001-bounded-output.patch
git apply /absolute/path/to/0001-bounded-output.patch
```

For the recorded reduced-manifest test, copy the patched HaishinKit and
RTMPHaishinKit directories into a new temporary directory, and copy the adjacent
ValidationPackage.swift there as Package.swift. The manifest builds the **actual
complete source targets**, with only Logboard, excluding unrelated binary transport
products. Optionally set STREAM14_LOGBOARD_PATH to an existing read-only Logboard
2.6.0 checkout; otherwise the exact public version is resolved normally.

```sh
swift test --package-path /private/tmp/your-new-validation-directory --skip releaseWhenClose
```

The excluded upstream test tries a localhost RTMP server. No test here publishes
camera/audio or connects to an external destination.

Recorded final reduced-manifest run: `/private/tmp/stream14-f6-patch-tests-5.log`,
**34 tests in 15 suites passed**, including eight new queue/ordering tests. A focused recheck after tightening the lifecycle-ready assertion also passed at `/private/tmp/stream14-f6-patch-ordering-recheck.log`. The original full
manifest attempt was stopped while downloading unrelated binary artifacts; it is
not a passed full-package validation. The app's package pins were never changed.

## Adoption work and maintenance risks

Independent review must inspect both the patch and its actual applied source.
Before selecting this candidate, build the real patched RTMP iOS product through
the intended package manifest/toolchain and qualify private RTMPS with normal TLS
and server/receiver evidence. Test real send cancellation/force-close callback
behavior, not only the deterministic mailbox seam. Resolve shared A/V origins,
AAC delay/trim, reconnect headers/keyframes and public stream-state recovery.

This touches connection-wide scheduling, including control messages, and changes
legacy behavior under overflow to fail closed. It needs upstream/fork maintenance,
compatibility tests and exact pin/notices if later adopted. The current upstream
release has no such API; the app must not call these methods until a separately
reviewed dependency decision adopts a verified implementation. No runtime pipeline,
recording lifecycle or distribution behavior changes in this experiment.

## Independent review corrections

The first review found two material races. The original candidate had separate
handshake and queued-command socket writers, permitting connect bytes to overtake
C2; both handshake messages now await the same completion path and the independent
legacy sender is removed. A delayed-completion regression covers this contract.
The second race admitted reconnect while old stream cleanup was awaiting; connect
now rejects closing/aborting state until the entire cleanup finishes. A controlled
actual close-critical-section regression verifies rejection during the wait and
release afterward. Connect's continuation is registered before a throwing handshake
send so failure can complete it, rather than orphaning it. Focused independent re-review found both races resolved and no new material findings.

## Original-manifest iOS product compile evidence

A detached app copy referenced this actual patched local package with its ORIGINAL
full Package.swift. The app's hosted test target selected RTMPHaishinKit through
normal Xcode resolution; the validation did not replace the package manifest.
Generic-iOS unsigned build-for-testing passed at
`/private/tmp/stream14-f6-patched-ios-build.log`, compiling RTMPOutputQueue.swift
from the isolated clone for arm64/iphoneos with the library's iOS 15 deployment
target and Swift 6. A private APFS-copy of the package cache was used; the tracked
app project and upstream pins remain untouched. Exact reproduction and paths are
in [the F6 plan](../../docs/2026-11-07-independent-transport-implementation.md#original-manifest-patched-ios-product-build-2026-11-07).
This is compile/link evidence, not physical execution, receiver delivery or
production dependency adoption. The full-package all-tests manifest attempt remains
separately documented as stopped; normal Xcode iOS product selection passed.

## Follow-on common-origin candidate (2026-11-08, unadopted)

`0002-common-origin.patch` applies after `0001-bounded-output.patch` and adds
`RTMPStream.setCompressedTimestampOrigin(_:)`. A caller sets this once after
publish succeeds and before acknowledged compressed media. Both tracks measure
integer-millisecond positions from the same CoreMedia epoch, preserving the first
AAC packet's offset rather than independently resetting it to zero. Rational
positions are quantized before subtracting the previous position, preventing
independent fractional-clock drift. Nonfinite, pre-origin, nonincreasing and
UInt32-overflow positions throw without advancing the clock. Re-publish clears
the epoch; changing an active epoch is rejected. The legacy raw append APIs keep
their existing semantics and must not be mixed with the new compressed mode.

A new connection must begin at a video random-access frame; the app must omit AAC
packets with decode/presentation time before the chosen transport epoch. This
patch does not identify keyframes, re-encode audio, remove priming, conceal missing
audio, or guarantee receiver synchronization. Codec headers use the existing
bounded FIFO before acknowledged payload; receiver decode remains a separate gate.

The private source copy `/private/tmp/stream14-integration-haishinkit` uses the
reduced validation manifest; `swift test --package-path` there passes 39 tests in
16 suites at `/private/tmp/stream14-integration-package-1.log`. Four new clock
tests cover track-arrival order, exact first offsets, 10,000 AAC packet positions,
invalid/regressing/overflow times and a fresh reconnect epoch. This is not actual
network/receiver or production dependency evidence. Independent review, normal
iOS-product compile and immutable fork publication are still pending; root alone
coordinates publication/adoption. No app package pin or shared cache was changed.


## Receiver-discovered native AAC / CTS corrections (2026-11-08)

`0003-native-aac-header.patch` follows0002 and handles canonical native AAC-LC
flags zero when constructing the AAC sequence header, preserving legacy object-ID
flags. `0004-compressed-video-cts.patch` follows0003 and removes legacy66ms
compensation only from the explicit compressed video API. Native payload regressions
and the reduced full-source suite pass40 tests in18 suites. See the
[actual receiver record](../../docs/2026-11-08-private-rtmps-receiver-validation.md)
for the original protocol rejection, normal TLS proof, two receiver recordings,
remaining decoded59–70ms audio lead and exact scope. The focused main-based correction now selects published immutable revision
`497f742c5f2c04cf3ca085378e660a273e351788` from the existing owned fork. Independent
actual-source review found no material fork issues; the app fixture scope finding
was resolved by restricting its entry points to Debug Simulator builds. Historical
sections above preserve the original experiment status. No wire/playback alignment
or physical RTMPS qualification is claimed.
