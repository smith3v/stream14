# Web overlay implementation plan

**Goal:** Implement issue #4's public WebKit renderer, outage policy and device test surface.

**Architecture:** A main-actor renderer owns a nonpersistent WKWebView attached to a visible, scaled UIKit host. A small monotonic-time policy keeps source access, usable raster and manual visibility independent. Immutable CGImage snapshots form the stage #5 handoff; capture and recording remain untouched.

**Tech Stack:** Swift 6, SwiftUI/UIKit, WebKit, CoreGraphics, Swift Testing/XCTest.

---

### Task 1: Freshness policy

**Prompt:** Add `Stream14/Media/OverlayHealth.swift`. Test independent source/render deadlines before, at and after ten seconds, reload grace, cached snapshots, recovery and manual hiding in `Stream14Tests/OverlayHealthTests.swift`. Use supplied TimeInterval values rather than wall-clock sleeps.

### Task 2: Renderer and attached test surface

**Prompt:** Add `Stream14/Media/WebOverlayRenderer.swift` and an overlay test sheet reachable from `Stream14/App/SetupView.swift`. Use a fixed 1920×1080 attached web view, transparent backing, single-flight public snapshots normalized to video pixels, navigation generation checks, bounded resource readiness and source-only retry after failure. Restrict navigation to HTTPS; deny native capabilities/downloads/popups; never persist/log URLs. Keep last-good images independently of page reloads. Add a self-contained alpha/viewport fixture in `Stream14Tests/Fixtures/` and native renderer tests. Compare attached scaled hosting with detached/hidden hosting (unsupported assumptions) and native recreation (breaks configurable HTML); select attached hosting.

### Task 3: Verification and handoff

**Prompt:** Run unsigned Release build and native tests with shared Stream14 scheme, packages at `/tmp/stream14-issue3-packages`, derived data `/tmp/stream14-issue4-device` and `/tmp/stream14-issue4-simulator`. Inspect 13 mini device availability and qualify fixture/reference rendering if available. Update design, feasibility and development guide with actual evidence and unresolved device gates. Run `git diff --check`. Request independent agent review of actual diff against main, fix material issues, rerun affected checks, commit focused files excluding local signing settings and open a PR referencing #4 without claiming unpassed gates.
