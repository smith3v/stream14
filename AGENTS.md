# Working on stream14

- Read the [application design](docs/2026-11-01-stream14-design.md) before changing
  behavior. Use the [development guide](docs/ios-development-guide.md) for build,
  signing and release steps and the [qualification guide](docs/qualification-report-template.md)
  for device acceptance. Update the relevant canonical section when a decision
  changes. Keep implementation plans, task status, and one-off handoffs in issues
  and PRs.
- Check the worktree and preserve unrelated edits. Branch from current `main` and
  target every PR to `main`. Keep changes focused; do not rewrite shared history
  or merge without explicit authorization.
- Use Swift 6, SwiftUI, the native Xcode project and Swift Package Manager. Prefer
  Apple frameworks, public APIs and clear ownership. Before adding a dependency,
  document the native alternative, license, maintenance/security cost, version,
  and linked footprint. Commit Package.resolved and avoid moving dependency refs.
- Keep one capture session, one composition and one encode per media type. Bound
  queues and isolate capture/media work from UI and WebKit's main-actor work.
  Preserve local recording through upload failure and a healthy upload through
  post-start writer failure. Follow the design's overlay freshness, interruption,
  and file finalization rules. Do not introduce unchecked concurrency annotations
  without documenting and verifying ownership.
- Use native controls, VoiceOver labels, Dynamic Type, at least 44×44-point targets
  and status that is readable without color. Inspect the iPhone 13 mini in both
  landscape directions. Camera/microphone permission belongs at preview; app-local
  storage and Files/share export need no Photos permission.
- Get explicit agreement before private capture, live tests, or disruptive device
  actions. Routine attended phone visits are five minutes total; individual
  development recordings are capped at 15 minutes. Agree on longer qualification
  separately. Keep originals and never uninstall/reset a device to clean up tests.
  Deletion inside the app is always deliberate and confirmed. Use the shared
  scheme's branding before installing the separate UI test runner.
- Keep credentials, signing material, account/device identities and private media
  or diagnostic artifacts out of Git, logs, and issue attachments. Public OAuth
  client identifiers are configuration. Use the supported Google flow, Keychain
  storage, standard TLS, and no native bridge to arbitrary overlay JavaScript.
  Preserve BSD-3-Clause and required dependency notices.
- Run checks appropriate to the change: native Xcode build and meaningful tests for
  code, link/content checks and `git diff --check` for docs. Report the tested
  build/device and limitations. Simulator, development installs, and an available
  TestFlight build do not establish exact-build physical acceptance.
- Before handoff, give a separate agent that did not author the change the full
  diff against `main`, relevant requirements and validation results. Have it inspect
  actual files for material correctness, data loss, security/privacy, build,
  media reliability/performance or acceptance gaps. Resolve material findings or
  record an agreed deferral, rerun affected checks, and request focused re-review
  when the fix changes the reviewed behavior. Record the review outcome in the PR.
