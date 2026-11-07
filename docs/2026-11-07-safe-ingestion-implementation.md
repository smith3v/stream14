# Safe YouTube Ingestion Implementation Plan

**Goal:** Resolve a confirmed scheduled event to one compatible dedicated RTMPS stream without duplicate creation or silent event changes.

**Architecture:** A concrete MainActor binding workflow uses the existing small YouTube client. An atomic, backup-excluded pending intent stores only resource IDs, profile and mutation phase before dispatch; credentials remain short-lived in redacted memory-only values. Reads may use the existing bounded retry policy, while insert/bind are dispatched once and reconciled conservatively.

**Tech Stack:** Swift 6, Foundation URLSession/Codable, Swift Testing, native Xcode/SPM; no new dependency.

---

### Task 1: Verify endpoint and safety contracts

**Prompt:** Read issue #18, canonical specification sections 6–7, the F3 client and Google's current official [stream insert](https://developers.google.com/youtube/data/live/reference/rest/v3/liveStreams/insert), [binding](https://developers.google.com/youtube/data/live/reference/rest/v3/liveBroadcasts/bind), [stream resource](https://developers.google.com/youtube/data/live/reference/rest/v3/liveStreams), [broadcast listing](https://developers.google.com/youtube/data/live/reference/rest/v3/liveBroadcasts/list) and [RTMPS guide](https://developers.google.com/youtube/data/live/guides/rtmps-ingestion). Use paired `variable` resolution/frame rate and `contentDetails.isReusable=false` for new app-owned streams. Bind uses query parameters with no body. Reuse only compatible ready/inactive streams after paginated `broadcastStatus=all,broadcastType=all` checks establish no other unfinished event uses them; unknown metadata fails closed. Never mutate auto-stop or any event editorial settings.

### Task 2: Add concrete state and request methods

**Prompt:** Add `Stream14/YouTube/PendingBroadcastIntent.swift` for atomic phase/ID persistence and `Stream14/YouTube/YouTubeBinding.swift` for explicit `prepareConfirmed` operation ownership, deadlines, fresh identity/event checks, stream validation and reconciliation. Add focused write-once and ingestion reads in `YouTubeClient.swift`; keep the existing F3 read-only stream model free of stream keys. Persist `inserting` before POST and the returned resource ID immediately after a successful response, before stale-generation/cancellation rejection. An ambiguous insert never repeats automatically; a known ID survives binding errors/relaunch and is read before any later bind retry. API errors expose only safe categories. RTMPS values have redacted descriptions/reflection and never encode into an intent.

### Task 3: Exercise meaningful fixtures

**Prompt:** Add deterministic `Stream14Tests/YouTubeBindingTests.swift` coverage for dedicated reuse, paginated shared/unknown/active/incompatible streams, RTMPS validation, auto-stop rejection, unbound create/bind/readback, malformed or timed-out insert, bind timeout before/after remote application, repeated taps, cancellation/account changes, persistence failures and relaunch. Prove one insert maximum across ambiguous retries and successful-create/bind-failure retries. No tests call Google or publish camera media.

### Task 4: Integrate, validate and hand off

**Prompt:** Merge the committed F3 prerequisite (including F4 profile controls) normally without rewriting history. Run generic-iOS unsigned Release and focused hosted tests using the Stream14 scheme; coordinate the Simulator lease with root. Run plist/documentation-link/fence and `git diff --check` checks. Have a separate agent inspect actual files and full diff against main plus incremental F3 delta, resolve material findings and rerun affected checks. Commit precise validation/limitations and prepare a PR body stacked on F3; root opens the PR after independent review. Keep real signed-account/unlisted-event binding acceptance pending.

## Decisions and limits

The selected design uses persisted intent rather than an in-memory-only flag (which permits duplicate creation after relaunch), and conservative unresolved state rather than retrying ambiguous insert responses. Reusable existing streams may be reused only when current paginated broadcast metadata proves dedication; the app never changes their reuse setting or takes over active ingestion. A later coordinator must freeze event/profile/account context and recheck before transmitting; F5 does not start media or authorize background mutations.

Initial worktree `/private/tmp/stream14-epic13-f5`, branch `codex/issue-18-safe-ingestion`, created from F3 checkpoint `e7941fb`. Root coordinates the authorized PR chain and later prerequisite updates. The owner has now prepared Google console/client/channel setup in a concurrent original-checkout note, but actual OAuth scope/callback and a dedicated unlisted test event remain unverified. Do not import or overwrite that separate local work.

## API and persistence handoff

- `YouTubeBinding.prepareConfirmed(eventID:channelID:profile:generation:)` is the only workflow entry. The later F7 coordinator owns one instance, freezes the selected account/channel/event/profile, obtains explicit Go Live confirmation, and invokes it. No current view, startup callback, event picker or camera preview invokes writes.
- `PreparedYouTubeIngestion` carries the freshly verified broadcast, stream ID, immutable `SessionProfile`, authorization generation and memory-only `YouTubeIngestionDestination`. The destination exposes the returned RTMPS endpoint and publish name to F6, but is not Codable and redacts descriptions/reflection. Later callers must keep these values out of logs/errors/exports and clear them with session/account state.
- `YouTubeClient` keeps F3's ordinary `YouTubeStream` free of ingestion keys. Separate `ingestionStream`, `allBroadcasts`, `insertDedicatedStream` and `bindBroadcast` methods implement this stage. Reads use F3's bounded retry policy. A mutation sends one POST, never follows redirects and never automatically retries. `bind` has no request body. New streams have a generated `stream14 <UUID>` title, paired variable resolution/frame rate and `isReusable=false`.
- Dedicated reuse requires a current compatible `ready`/`inactive` stream and known healthy/no-data state; active, unhealthy, unknown or incompatible streams fail closed. All broadcast pages/types are inspected for other unfinished bindings. A reusable stream is allowed only when that current dedication is established. Auto-stop must already be disabled; event title, visibility, audience and auto-start/auto-stop are never updated.
- `PendingBroadcastIntentStore` atomically saves the nonsecret journal at backup-excluded Application Support/PendingYouTube/binding-intent.json. Entries are keyed by channel/event, with operation UUID, profile, phase and any known created ID. There is no remote deletion, local-recording deletion or credential persistence. The early single-intent checkpoint can be read and migrated without dropping its guard.
- `inserting` is durable before POST. The successful insert ID is saved before rejecting a changed account/cancelled operation. Ambiguous insert, malformed success and uncertain server/network outcomes never cause another blind insert, including after relaunch. A definitive API rejection/credential preflight failure permits a later explicit retry. A known ID is always read and reused through bind failures.
- The whole workflow has a 45-second deadline and one operation per owner; persisted pre-dispatch claims also prevent duplicate insertion from a second owner instance. State-changing requests may have succeeded despite cancellation; journal protection is therefore retained. F7 must recheck current remote identity/binding immediately before media transmission; API snapshots do not create a lock against external Studio changes.

## Independent-review correction

The first review identified a material lifecycle issue: a single global intent slot would permanently block a later unbound event after an earlier successful preparation. The fix is a context journal rather than deleting old records. Sequential-event/relaunch tests prove that event B can create its own stream while event A's known or ambiguous outcome remains protected. If Studio manually binds an event after an ambiguous insert, verified readback marks its entry prepared without inventing a known app-created ID. If that event later becomes unbound, its unknown-create guard still blocks blind insertion. No remote resources are automatically removed or replaced.

## Reproducible checks

Run from `/private/tmp/stream14-epic13-f5`, choosing a fresh result bundle on repeats:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/stream14-f5-release \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f3-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,id=D6BEAF78-D273-4952-8349-B50B2824E6A9' \
  -derivedDataPath /private/tmp/stream14-f5-simulator \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f3-packages \
  -disableAutomaticPackageResolution \
  -only-testing:Stream14Tests/YouTubeBindingTests \
  -only-testing:Stream14Tests/YouTubeClientTests \
  -only-testing:Stream14Tests/YouTubeAuthorizationTests \
  -only-testing:Stream14Tests/AppConfigurationTests \
  -resultBundlePath /private/tmp/stream14-f5-review-tests.xcresult test
```

The initial pre-review run executed all 43 tests successfully (17 binding, 13 client, 11 authorization and two app-configuration checks), with no skips, network calls or media capture. `/private/tmp/stream14-f5-tests.xcresult` and its log retain that evidence. The journal fix adds three binding lifecycle tests; final results are appended below rather than inferred from the earlier run. Initial failed concurrency-checker and nested SwiftTesting macro compilation attempts remain in private logs; fixes use normal actor isolation, without unchecked annotations or diagnostics suppression.

## Pending phone/service checks

Console project/API/client/testing audience setup is prepared in the owner's concurrent setup record. Real app OAuth scope/callback/channel identity and a dedicated unlisted test event remain pending. A connected-phone F5 acceptance run requires normal signing, actual SDK authorization and an explicitly selected **unlisted** event with auto-stop disabled. First validate a compatible dedicated inactive existing binding without writes; then use a separately confirmed unbound event to verify one stream creation, binding/readback and retry reuse. Keep auto-start's media consequences for F7; F5 sends no media.

There is no F5 test-only on-device entry or Go Live UI in this PR. Codex must supply the later coordinator/integration runner before those service checks are runnable; the owner should not write Swift or call REST endpoints manually. Root owns the consolidated connected-iPhone test plan and will batch these checks when executable prerequisites and owner availability exist. Until then, deterministic fixtures establish implementation decisions, not successful real YouTube binding or broadcast qualification.

## Final validation checkpoint (2026-11-07)

After the independent-review journal correction, **all 46 tests in four suites
executed successfully, with no skipped tests**: 20 binding decisions/recovery
checks, 13 YouTube client fixtures, 11 authorization checks and two app-configuration
checks. Evidence: `/private/tmp/stream14-f5-review-tests.xcresult` and
`/private/tmp/stream14-f5-review-tests.log`. The final native generic-iOS unsigned
Release build passed (`/private/tmp/stream14-f5-release-final.log`). Existing
library/writer deprecation and unused AppIntents metadata warnings remain;
no concurrency diagnostics are suppressed.

Privacy/project plist lint, all relative Markdown links/fences and
`git diff --check` pass. All requests use synthetic in-memory fixture transports;
no Google request, phone install, camera capture, media upload, remote mutation or
recording deletion occurred. The Simulator lease has been released.

The independent reviewer is checking the focused journal fix before PR publication.
Root coordinates the latest docs-only predecessor merge, PR target, remote push
and final review outcome. Do not merge automatically or close #18 with real-service
acceptance still pending.
