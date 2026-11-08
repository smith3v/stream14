# F8 same-event reconnect handoff

Parent: `4891f0d` (F7 runtime `3de0c98`, reviewed). Plan: `c900646`.
Runtime/docs: `49d294b`; additional independence/Retry-After fixtures: `bc10f59`.
Local branch: `codex/issue-21-same-event-reconnect`, isolated non-iCloud clone.
Publication and independent review are coordinated by the root agent; no merge is
implied. Final reviewed parent documentation must be inherited before publication.

## Concrete ownership and API

`BroadcastSession` owns one additional supervision task, fenced by the existing
intent epoch and authorization generation. `reconnectStatus`, `reconnectAttempts`,
`retryUpload()` and `cancelReconnect()` expose honest recovery state. The production
media instance stays unchanged/shared. `MediaSession.broadcastPipelineRunning`
checks pipeline lifetime independently from file-control busy and overlay state.
`ReconnectClock` is a focused now/sleep/jitter fixture seam.

After initial F7 remote Live confirmation, transport failure triggers same-event
read-only channel/event/binding/stream/destination validation. The retry path calls
only `MediaSession.startUpload(prepared)` and never binding preparation or transition.
The SDK's acknowledged compressed-send error/overflow already feeds publisher
failure → MediaSession upload failure. No additional polling SDK observer was added.
Socket connection is separate from remote Live. The event can remain remote Live
through an interrupted upload; that lifecycle value comes from a read.

Twelve attempts and 180 elapsed seconds bound each outage; exponential positive
jitter delays cap at 30 seconds. API failures back off; `YouTubeReadBackoff` carries
Retry-After out of the bounded HTTP read loop. An explicit Retry cannot bypass its
RAM not-before time. Initial F7 startup ambiguity still uses F7 reconciliation;
recovery does not replay Go Live. Relaunch does not resume/publish automatically.

Completed/missing/changed identity or destination stops transport/retries only.
Authorization attention preserves an existing healthy connection when possible;
account/generation replacement retains the existing stricter stop policy. Overlay
and backup failures are independent from admitted upload. No recorder stop is
issued by generic retry or its exhaustion. End remains an explicit whole-session
operation. No original media are deleted.

## Verification

Unsigned native Release build passed using:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/stream14-f8-build \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages \
  CODE_SIGNING_ALLOWED=NO build
```

Log: `/private/tmp/stream14-f8-build-final.log`.
Hosted commands use the shared scheme and exact Simulator destination documented in
the development guide; all media/API operations in these tests are fixtures.
Initial focused run: 26/27 passed, elapsed-budget assertion corrected. Subsequent
full suite: 133 total, 126 passed, 7 physical-only skipped, 0 failed (24 suites), log
`/private/tmp/stream14-f8-tests-2.log`. Additional final fixtures and final result
are recorded below after completion. `git diff --check` passed.

Unverified: actual phone outage/handover; remote receiver gaps; actual SDK reconnection
under network loss; physical file continuity and long-session performance. Owner
baseline physical smoke predates this pipeline and is not F8 evidence. No phone,
Google credentials, external API mutation, real media upload or broadcast occurred.

Final hosted rerun after all code/test changes: **135 total, 128 passed, 7 skipped,
0 failed**, 24 suites, including **29 BroadcastSession tests passed**. Final log:
`/private/tmp/stream14-f8-tests-final.log`; result bundle under
`/private/tmp/stream14-f8-tests/Logs/Test/`. Release build remained passed with the
same runtime. Independent review and final parent inheritance remain coordinated
by the root agent before publication.

## Independent review fixes

Independent review found two material lifecycle races: a file-only finalization's
transient `.stopping` phase incorrectly ended supervision, and a remote-terminal
upload stop was silently dropped while a media operation was busy. Fix `2f456dd`
uses encoder lifetime rather than writer phase. `stopUpload()` now invalidates
in-flight admission and detaches the publisher immediately, while serializing
encoder-only cleanup after busy work. Pending cleanup blocks a new upload; whole
capture stop retains priority. This keeps file ownership independent.

Two deterministic regressions hold the actual MediaSession in file-finalization
busy state with a real encoder receiving no input and fixture publisher I/O. A
supervision tick preserves upload while `.stopping`; a remote-complete read stops
the publisher before the held operation releases, then cleans up the encoder.
Focused run: **31/31 passed**, log `/private/tmp/stream14-f8-reviewfix-tests.log`.
Final parent `e22a04c` was inherited with a normal merge (`f168649`), preserving
attended baseline results without claiming them as F8 evidence.

Post-fix validation on merged parent: **137 total, 130 passed, 7 physical-only
skipped, 0 failed**, 24 suites; **31 BroadcastSession tests passed**. Full log:
`/private/tmp/stream14-f8-postreview-full.log`. Native unsigned Release build passed:
`/private/tmp/stream14-f8-postreview-release.log`. `git diff --check` passed.
