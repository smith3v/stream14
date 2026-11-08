# Same-event reconnect Implementation Plan

**Goal:** Supervise only the operator-confirmed event and recover transport without stopping healthy local writing.

**Architecture:** Extend BroadcastSession's existing epoch ownership with a cancellable supervision task and RAM-only prepared destination. Use read-only channel/event/stream reconciliation before every reconnect; never invoke binding preparation or transitions from retry work. Preserve the durable F7 mutation ambiguity barrier.

**Tech Stack:** Swift 6, Observation, existing YouTubeClient and MediaSession, deterministic Swift Testing fixtures.

---

### Task 1: Freeze interfaces and policy

**Prompt:** Add a focused policy with six reconnect attempts per outage, 180-second elapsed budget, exponential delays with bounded jitter capped at 30 seconds. Inject monotonic now/sleep/jitter closures. Expose transport supervision status, retry count, and explicit retry/cancel actions on BroadcastSession. No credentials are persisted.

### Task 2: Integrate read-only supervision

**Prompt:** Retain the admitted prepared context in RAM. Check transport every second and remote state about every ten seconds. Read channel, exact event/binding, stream/profile and destination before reconnect. Terminal/changed/missing/auth-required state stops retries and transport only; transient reads preserve healthy transport. Retry never sends POST. End, account changes, cancellation and replacement cancel work and reject stale results. Overlay failure remains independent.

### Task 3: Validate and document

**Prompt:** Add fixtures for budgets/delays/cancellation, remote completion, changed binding, auth loss, healthy transport with read failure, exhausted transport and stale replies. Run shared-scheme hosted tests and native build with isolated cache; no physical device or actual API/media calls. Update canonical specification and development guide with precise limits. Commit checkpoints, then have an independent agent review actual full diff and resolve material findings before root publishes the reviewed stacked PR.

## Report interfaces and evidence

Planned public coordinator surface: `reconnectStatus`, `reconnectAttempts`, `retryUpload()`, `cancelReconnect()`. Existing recording controls remain available. Final handoff must report exact commits, commands/results, inherited parent SHA, review outcome and unresolved physical receiver/outage evidence. No milestone acceptance is inferred from fixtures.
