# YouTube Client Implementation Plan

**Goal:** Read the authorized YouTube channel and every scheduled event page, and safely select an eligible event without sending media or changing remote state.

**Architecture:** A small Sendable URLSession/Codable client uses ephemeral requests and F2's SDK-refreshed in-memory token provider. One MainActor observable event-selection owner validates request/account generations, exposes safe errors and clears stale channel/event state. Explicit refresh and native event rows show actual channel identity, localized date/time, visibility and eligibility.

**Tech Stack:** Swift 6, SwiftUI, Foundation URLSession/Codable, existing GoogleSignIn authorization; no new package.

---

### Task 1: Verify API contracts and model only required fields

**Prompt:** Inspect official channels.list, liveBroadcasts.list/liveBroadcasts and liveStreams.list/liveStreams references. Add Stream14/YouTube/YouTubeModels.swift with safe optional resource fields and unknown-string handling. Read-only list filters must remain mutually exclusive. Do not store raw API responses, access tokens or ingestion keys.

### Task 2: Add bounded read requests and selection ownership

**Prompt:** Add YouTubeClient.swift with channels mine=true, paginated upcoming event reads, selected broadcast by-ID recheck, stream by-ID reads, bounded idempotent retries/Retry-After and safe status/reason mapping. Check cancellation and authorization generation across awaits. Add YouTubeEventSelection.swift and native picker showing eligibility and real channel identity; account changes clear state. No write methods or camera/media upload.

### Task 3: Verify behavior and prepare reviewed handoff

**Prompt:** Add sanitized fixture JSON and deterministic YouTubeClientTests.swift/selection tests covering exact filters/parts, pages/cycles/empty/missing/unknown values, ownership, retry limits/401/403/quota, and cancellation/account-change races. Run generic-iOS unsigned Release plus focused hosted Simulator tests using the shared Stream14 scheme. Inspect smallest-screen UI where practical; owner-configured signed phone channel/event remains pending. Update canonical specification/guide with actual behavior and evidence. Ask a separate agent to review full actual diff against main and stage predecessor, resolve material findings, rerun affected checks, commit and record outcome before PR handoff.

## Resume checkpoint

Worktree `/private/tmp/stream14-epic13-f3`, branch `codex/issue-16-youtube-client`, initial stacked baseline `524c582` (F2 plus F1). Root coordinates later F4 merge and PR chain. The original owner checkout and its local signing settings remain untouched. The Google Cloud/API/iOS client/testing audience are now prepared; actual signed-phone OAuth, API-returned channel identity and test-event acceptance remain pending. Simulator execution requires a root-coordinated lease.


## Implemented boundary and validation

`Stream14App` owns both authorization and one `YouTubeEventSelection`; future F5/F7
can consume that same owner. `YouTubeClient` is a concrete Sendable read client,
with a small injected send/token/current/sleep boundary for deterministic tests.
Its ephemeral URLSession disables cache, cookies and redirects. Models/decoding
are explicitly nonisolated under this project's default MainActor isolation.
No credentials, raw response data, ingestion keys or metadata are persisted.

Official endpoint/resource/error contracts are linked in the canonical specification.
Upcoming reads use mutually exclusive broadcastStatus/id/mine filters correctly,
all pages up to an explicit 100-page fail-closed safety guard, cycle detection,
owned-channel validation and by-ID recheck. Retry budget is two transient reads
plus at most one supported SDK refresh-if-needed/401 retry; Retry-After over ten
seconds returns a safe waiting message. No remote mutation or publishing exists.

Initial unsigned generic-iOS Release passed at
`/private/tmp/stream14-f3-release-2.log`; the first attempt's model-isolation compiler
failure is retained in `/private/tmp/stream14-f3-release.log`. Simulator
build-for-testing passed. Focused fixture/authorization/configuration tests passed
26 tests/3 suites at `/private/tmp/stream14-f3-tests.xcresult` and `.log`.
No Google or physical-device activity occurred. Final F4 stack integration,
affected checks and independent review are pending at this checkpoint.

Reproducible commands (new result paths on reruns):

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/stream14-f3-release \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f2-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,name=Stream14 iPhone 13 mini,OS=27.2' \
  -derivedDataPath /private/tmp/stream14-f3-simulator \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f2-packages \
  -disableAutomaticPackageResolution \
  -only-testing:Stream14Tests/YouTubeClientTests \
  -only-testing:Stream14Tests/YouTubeAuthorizationTests \
  -only-testing:Stream14Tests/AppConfigurationTests \
  -resultBundlePath /private/tmp/stream14-f3-tests.xcresult test
```

## Final merged-stack handoff (2026-11-07)

Merged reviewed F4 predecessor `ef1e7be` without rewriting history at `92c0953`.
The SetupView conflict retains both the app-owned YouTube selection and persisted
SessionProfile initialization; both specifications/guide sections and corrected F1
evidence remain. PR target is `codex/issue-17-session-controls` (PR #42), per the
owner's stacked workflow. The initial plan checkpoint is `d4f14ed`, implementation
`e7941fb`, and fixture/lifecycle/evidence checkpoint `d228825`.

The merged-stack native unsigned Release passed, including the final accessibility
change: `/private/tmp/stream14-f3-release-final-2.log`. Hosted integration passed
**32 tests in four suites** (13 F3, 11 authorization, two configuration, six
profile/control): `/private/tmp/stream14-f3-merged-tests.xcresult` and `.log`.

Initial portrait UI audit found low contrast on the unavailable disabled Refresh
label; that failed result is retained in `/private/tmp/stream14-f3-ui.xcresult`.
The action is now shown only while authorized, with an explicit 44-point label
height; disconnected instructions remain readable. No accessibility audit was
suppressed. Final recheck passed **13 F3 tests plus two setup UI tests** including
portrait and largest-text landscape accessibility audits:
`/private/tmp/stream14-f3-ui-recheck.xcresult` and `.log`. Exported original/final
private screenshots were inspected; final evidence lives in
`/private/tmp/stream14-f3-ui-recheck-attachments`. These default-config checks do
not establish authenticated event-row layout or physical VoiceOver acceptance.

Relative documentation-link/fence checks and `git diff --check` pass. Independent
review remains for the parent to arrange against actual final files/full main diff
and the F4 stage delta. PR body: `/private/tmp/stream14-f3-pr-body.md`. No remote
PR or issue mutation was performed by this stage agent. No actual Google request,
media publishing, phone recording or recording deletion occurred.

F5/F7 entry points: the app-owned `YouTubeEventSelection` exposes channel, events,
selected, refresh, select, invalidate/accountChanged and async recheckSelected.
`YouTubeClient` exposes authorizedChannel, upcomingBroadcasts, broadcast(id:channelID:
generation:) and stream(id:channelID:generation:). F5 must add its separately
reviewed write/reconciliation policy, short-lived key ownership and binding guards;
F3's bounded read retries must not be reused blindly for mutations. F7 must freeze
account/event/profile snapshots around confirmed Go Live and reconcile remote state.
