# TestFlight Delivery Implementation Plan

**Goal:** Deliver the local-only MVP through TestFlight and record honest M1–M5 acceptance on the testing iPhone 13 mini.

**Architecture:** Keep the existing HaishinKit composition and concrete MP4 recorder unchanged. Add release resources, a standard privacy-policy link in setup, and delivery documentation; use native Xcode Archive/Organizer and App Store Connect. Separate preparation from Apple account activation, upload, installation and owner-agreed qualification.

**Tech Stack:** Swift 6, SwiftUI, WebKit, HaishinKit 2.3.0 core, Logboard 2.6.0, Xcode 27.2, Apple privacy manifest, App Store Connect and TestFlight.

---

### Task 1: Verify prerequisites and release resources

**Prompt:**
Read issue #6, merged PRs #10/#11, AGENTS.md and the canonical specification/guide. Start from current main on codex/issue-6-testflight; preserve the owner's uncommitted development-team settings without including them in commits. Inspect actual app and linked package sources. Add Stream14/PrivacyInfo.xcprivacy for elapsed in-app timing (35F9.1) and app-container file metadata (C617.1), no tracking or developer-collected data. Keep build 0.1 (1) until App Store Connect establishes whether that number is unused. Do not add encryption declarations without checking the final archive's linked code. Document evidence in docs/feasibility.md. Validate resources with plutil -lint and inspect the archive bundle.

---

### Task 2: Prepare release and owner instructions

**Prompt:**
Write docs/privacy.md, docs/support.md and docs/testflight-delivery.md. Describe local camera/microphone recording, explicit HTTPS overlay requests to third-party services, Keychain URL storage, original-file sharing and confirmed deletion. Add a standard Link near the top of Stream14/App/SetupView.swift to the canonical main-branch privacy policy; require publication and signed-out URL verification before upload. Supply beta description, What to Test, repeatable reference overlay instructions and remaining private contact fields. Update docs/ios-development-guide.md, the canonical specification, and implementation status to link the delivery record. Use Apple’s current submission/privacy/export/TestFlight documentation. Owner handles identity checks, payment and agreements; do not request secrets. Archive/upload do not need a connected iPhone. Device operations must tolerate disconnection and may not delete recordings. Do not launch another long recording without owner agreement.

---

### Task 3: Verify packaging and independently review

**Prompt:**
Run the shared scheme's native Release archive without signing while account access is pending, using the pinned local package cache. Inspect bundled icon, permissions, notices, privacy manifest, linked libraries and absence of test fixtures. Run existing hosted/Simulator checks appropriate to changes; avoid physical capture. Check documentation links and git diff --check. Ask a separate agent to inspect actual files and the full diff against main, with requirements and validation. Resolve material findings and rerun affected checks. Commit only intended files and prepare a focused PR referring to #6, recording review and pending delivery gates; do not merge.

---

### Task 4: Activate Apple access and upload

**Prompt:**
Wait for owner confirmation of active membership and App Store Connect Apps access. Register com.smith3v.stream14 and create an iOS app record (name stream14, English UK, SKU stream14-ios, full access) if absent. Confirm availability rather than changing identity silently. Select the active paid team locally, verify unique version/build, create a normally signed Release archive, and use Organizer Validate/Distribute App → App Store Connect. Resolve processing/compliance issues. Keep private account/contact/signing data outside Git. Use an internal owner group if eligible; use external testing and beta review for testers without App Store Connect access. Invitation recipients must be explicitly identified by the owner before sending invitations.

---

### Task 5: Install and qualify with owner attention

**Prompt:**
Wait for owner availability, then install from TestFlight on the 13 mini (USB unnecessary). Export important existing recordings before any uninstall; prefer in-place replacement. Record actual version/build, OS and installation evidence. Exercise short recording, changing overlay, manual hide/restore, two-minute source outage, Stop, playback and original Files export; repeat relevant M4 failures. Plan the 30-minute final M3 run with explicit owner agreement, visible/audible start/end claps and private original-file inspection. Define memory/queue measurement on the actual delivered build before running; the current development harness is not a TestFlight measurement route. If metrics need production changes, review that design and deliver a new build first. Record <1% measured pipeline frame drops (separately identifying estimated missing output intervals), no repeated ≥500 ms stalls, stable memory/queues, and ≤100 ms A/V offset at both ends with method/limits. Missing evidence stays pending. Present private samples/report for owner review and document 90-day replacement; propose the next milestone without starting broadcasting.
