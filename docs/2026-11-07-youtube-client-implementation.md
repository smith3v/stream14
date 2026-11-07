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

Worktree `/private/tmp/stream14-epic13-f3`, branch `codex/issue-16-youtube-client`, initial stacked baseline `524c582` (F2 plus F1). Root coordinates later F4 merge and PR chain. The original owner checkout and its local signing settings remain untouched. Owner Google setup and signed-phone acceptance are not yet available. Simulator execution requires a root-coordinated lease.
