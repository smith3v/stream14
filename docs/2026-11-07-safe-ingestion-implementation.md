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
