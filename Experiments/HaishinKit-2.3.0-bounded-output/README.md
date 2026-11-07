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
memory limit. The separate legacy handshake path is capped at 4 MiB / 32 elements.
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

Recorded final reduced-manifest run: `/private/tmp/stream14-f6-patch-tests-4.log`,
**32 tests in 14 suites passed**, including six new queue tests. The original full
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
