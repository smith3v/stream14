# Default YouTube Stream Reuse Implementation Plan

**Goal:** Let the owner use YouTube's existing default stream key without assigning a separate key to each scheduled event.

**Architecture:** Keep the existing selected-event, channel, profile, inactive-ingestion, RTMPS, account-generation and durable mutation guards. Remove the separate all-events dedication scan; selected-event readback and existing reconnect rules remain unchanged. Concurrent use of a reusable key is an explicitly deferred risk, not an ownership guarantee.

**Tech Stack:** Swift 6, native YouTube REST client, Swift Testing, Xcode shared Stream14 scheme.

---

### Task 1: Apply the owner's minimal-configuration decision

**Prompt:**
The owner tried two scheduled events using the same default key and received the app's unfinished-event dedication error before RTMPS upload. YouTube supports one stream bound to multiple broadcasts. Alternatives were requiring new dedicated keys, implementing cross-event coordination now, or retaining existing selected-event safety and reporting concurrent use for later mitigation. The owner explicitly chose the third: “I do not expect a conflicting active stream for now. Let's report it as a potential issue for the future mitigation.” This supersedes the old F5 all-unfinished-events exclusion. Do not create a new key, change another event or add a replacement coordination scan.

### Task 2: Implement the narrow existing-binding change

**Prompt:**
In Stream14/YouTube/YouTubeBinding.swift remove calls to the dedication scan for existing preparation, app-created binding readback and explicit resume, and remove the now-unreachable scan/errors and its unused all-broadcast client method. Preserve native stream activity/health/reuse/profile validation, selected-event/by-ID readback, secure destination validation and all intent/mutation handling. Keep live supervision/reconnect behavior unchanged. Update YouTubeBindingTests to prove shared/default-key reuse sends only selected-event/stream reads and no remote writes or all-events scan. Preserve active stream, missing data, profile, auto-stop, channel, ambiguous mutation and stale-generation failures. Document the future concurrency risk in [issue #65](https://github.com/smith3v/stream14/issues/65) rather than inventing a current incident.

### Task 3: Validate and independently review

**Prompt:**
Run affected native binding/coordinator/client suites and an unsigned Release build, with pinned warmed packages, new result paths and an owned Simulator. No phone, camera, provider call or publishing. Update canonical F5/F8 wording, full plan and owner setup/test instructions to match the default-key workflow and deferred limitation. Have a new independent agent inspect actual full diff against main, requirements and validation. Resolve material findings, record exact results/limits and commit; root publishes the PR into main. No version bump or automatic merge.
