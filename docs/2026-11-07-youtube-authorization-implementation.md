# YouTube Authorization Implementation Plan

**Goal:** Add supported Google authorization without requiring it for local rehearsal.

**Architecture:** One MainActor observable authorization owner wraps Google's SDK through a narrow test seam. The SDK owns Keychain credentials; the app exposes only readiness, account generation and short-lived access tokens to later API stages. Account operations invalidate dependent state before awaiting; stale callbacks cannot restore readiness.

**Tech Stack:** Swift 6, SwiftUI, GoogleSignIn 10.1.0, native Xcode/SPM.

---

### Task 1: Verify dependencies and configuration

**Prompt:** Inspect official GoogleSignIn 10.1.0 headers, package and licenses. Compared with manual ASWebAuthenticationSession plus app-owned OAuth/Keychain/revocation, use the maintained SDK to avoid duplicate credential machinery; a broad YouTube/Firebase SDK is unnecessary. Pin only GoogleSignIn, retain Package.resolved, add callback configuration through Config/Google.xcconfig with optional ignored Local.xcconfig. Invalid or absent configuration must not invoke SDK sign-in. Document actual linked transitive products and licenses before delivery.

### Task 2: Implement authorization ownership and UI

**Prompt:** Add Stream14/YouTube/YouTubeAuthorization.swift and GoogleAuthorizationDriver.swift. Implement explicit connect/restore/sign-out/revoke, youtube.force-ssl scope validation, generation changes, safe errors and refreshed token handoff. Serialize interactive SDK ownership and reject stale callbacks. Add app URL handling and a native setup section. No camera or media operation depends on authorization; do not publish automatically. Active-broadcast guard is supplied by later session coordinator.

### Task 3: Verify and review

**Prompt:** Add deterministic tests for missing config/scope, cancellation, refresh/revoke errors, account generations and late results. Run hosted tests with the shared Stream14 scheme on the dedicated 13 mini Simulator and unsigned generic-iOS Release build. Run git diff --check. Request a separate review against origin/main, resolve material findings, rerun affected checks, commit. Keep actual browser callback, Keychain restore/revocation and owner channel authorization pending until Google setup and signed-device checks exist.
