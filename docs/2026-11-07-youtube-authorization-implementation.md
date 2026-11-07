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

## Dependency audit and resume handoff

Worktree `/private/tmp/stream14-epic13-f2`, branch
`codex/issue-15-youtube-authorization`, baseline `origin/main` at `ededeb1`.
Initial checkpoint `3202fa8`; subsequent validation fixes/tests/docs are separate
commits. Parent coordination will merge committed F1 work to form the authorized
PR chain; do not independently rewrite or merge shared branches.

Latest stable SDK release was checked through the official GitHub release API:
10.1.0, published 2026-10-23. The SDK uses Swift tools 6.0 and supports iOS 15+.
Only GoogleSignIn is selected; GoogleSignInSwift, Firebase and broad Google API
products are not linked. Native Release compilation confirms Swift 6/iOS 27.2
compatibility. The target graph additionally links AppAuth/Core, GTMAppAuth,
GTMSessionFetcherCore, AppCheckCore and GoogleUtilities environment/preferences/
logger/IsAppEncrypted; exact pins and licenses are in Package.resolved, the canonical
specification and bundled ThirdPartyNotices.txt. Existing HaishinKit 2.3.0 remains
pinned. Upstream's wider package resolution includes unused products; do not
mistake a resolved OpenSSL/libsrt/libdatachannel package for a linked dependency.

SDK reference contracts inspected directly at tag 10.1.0:
`GIDSignIn.h` signIn/restore/signOut/disconnect/handleURL and `GIDGoogleUser.h`
refreshTokensIfNeeded. Their completion callbacks run on the main queue. Callback
bodies synchronously extract immutable Sendable snapshots, never pass SDK user
objects to another task/actor and never persist access tokens in app storage.
No concurrency diagnostics are suppressed.

Reproducible native checks (choose fresh result-bundle paths on rerun):

```sh
xcodebuild -resolvePackageDependencies -project Stream14.xcodeproj -scheme Stream14 \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f2-packages
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/stream14-f2-release \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f2-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,id=D6BEAF78-D273-4952-8349-B50B2824E6A9' \
  -derivedDataPath /private/tmp/stream14-f2-simulator \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f2-packages \
  -disableAutomaticPackageResolution \
  -only-testing:Stream14Tests/YouTubeAuthorizationTests \
  -only-testing:Stream14Tests/AppConfigurationTests \
  -resultBundlePath /private/tmp/stream14-f2-auth-tests.xcresult test
```

Release build passed (log `/private/tmp/stream14-f2-release-pass.log`); initial
failed compiler attempts are retained in the same private directory. Hosted tests
were running at this checkpoint; append their actual result before PR delivery.
No physical media is captured or uploaded by these deterministic tests. Required
independent code review, owner configuration and signed-device Google checks remain
pending. Later F3 must pass/capture `generation` for every API result and must not
confuse Google account readiness with an actual YouTube channel or live state.
