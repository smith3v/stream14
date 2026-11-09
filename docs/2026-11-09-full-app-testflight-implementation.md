# Full-app TestFlight Candidate Implementation Plan

**Goal:** Prepare issue #26's full-app candidate and record delivery only after the exact signed build reaches each independently verified checkpoint.

**Architecture:** Release from current main after the reviewed F10/F11/F12 changes and recording finalization fixes are available. Keep packaging separate from physical qualification, retain the historical MVP delivery record, and use Xcode automatic signing and the existing internal TestFlight route.

**Tech Stack:** Swift 6, SwiftUI, Xcode 27.2 (27B52), iOS SDK 27.2, SPM, App Store Connect/TestFlight.

---

## Preparation snapshot — 2026-11-09

This is preparation, not a delivery claim. The working baseline is stacked F12
`b30dc5f`; final F11 writer-finalization corrections must still be inherited.
Issue [#26](https://github.com/smith3v/stream14/issues/26) was read live and remains
open. F10–F12 issues #23–#25 also remain open. Do not upload, change App Store
settings, bump versions, install on the phone, start capture or contact YouTube as
part of this preparation. Root coordinates final review and authorization.

Project Debug/Release metadata is still 0.2 (3), bundle
`com.smith3v.stream14`, automatic signing, iOS deployment target 27.0. These are
source values, not a live App Store Connect inventory. The historical delivered
0.2 (3) is recorded in [its release record](2026-11-07-testflight-0.2.md).
Live App Store Connect version/build availability has not been inspected here.
If 0.2 (3) is still latest, propose 0.3 (4); first check all existing/processing
builds and increase the build number if necessary. Update both configurations
and the app identity test only after final source and metadata are confirmed.

## Task 1: Settle prerequisites and policy behavior

**Prompt:**
Read AGENTS.md, the canonical design A3/A6/A9, the full-app plan F13, issue #26,
all prerequisite handoffs, and final F10/F11/F12 diffs. Use @brainstorming for any
behavior decisions and @writing-plans for the focused implementation. Preserve
unrelated local signing/configuration and all original recordings. Inherit final
writer fixes before building a candidate. Record exact main SHA and reviewed PRs.

The following preparation findings need resolution before release:

- `docs/support.md` still describes YouTube as unavailable. Update it to distinguish
  the existing local-only delivered builds from the future full-app candidate;
  describe Preparation/Session/Recordings, independent output states, uncertainty,
  explicit Resume, original/copy recovery and private diagnostic export.
- `docs/privacy.md` already describes Google/API/RTMPS but needs F11 recovery/copy
  provenance and F12 bounded private diagnostic checkpoints, retention/deletion,
  plus direct Google revocation and YouTube terms links. Do not describe all
  retained API identifiers as merely in-memory: both journals persist identifiers.
- `Stream14/App/SetupView.swift` currently links privacy and notices only. Resolve
  YouTube terms/privacy agreement before authorization/API features; provide clear
  policy links and deliberate consent without gating local rehearsal on Google.
  Do not invent a legal contact or silently accept terms on the owner's behalf.
- Audit retained channel/event/stream identifiers in the two request journals.
  Current sign-out/revocation retains reconciliation data. Provide an explicit
  API-data deletion procedure with clear Studio/remote-state instructions and a
  conservative nonidentifying barrier where needed; deleting identifiers must not
  silently enable a duplicate create/start after an ambiguous mutation. Check
  externally revoked authorization and retention, not only the in-app revoke path.
- `Stream14/ThirdPartyNotices.txt` names fork revision `8dc2ecc`, while the prepared
  `Package.resolved` pins `497f742`. Correct the notice to the final adopted revision.

Current [YouTube Developer Policies](https://developers.google.com/youtube/terms/developer-policies)
III.A require a YouTube Terms link, own-terms acknowledgement and privacy agreement;
III.E covers authorized-data deletion/revocation. This is the reason for the audit,
not an assertion that the current implementation satisfies those requirements.
Use `https://www.youtube.com/t/terms`,
`https://policies.google.com/privacy`, and
`https://security.google.com/settings/security/permissions` as direct provider links.
Proposed narrow service wording for owner review: “stream14 uses YouTube API
Services. By using its YouTube features, you agree to be bound by the YouTube
Terms of Service.” Source BSD licensing remains separate from service terms.

Apple [guideline 4.8](https://developer.apple.com/app-store/review/guidelines/#login-services)
contains an exception for clients accessing a specific third-party service. This
app uses Google to access the user's YouTube channel, without a separate stream14
account. That supports retaining the current service-specific authorization rather
than adding another account system; final reviewer acceptance remains external.

---

## Task 2: Verify release configuration and audit the actual archive

**Prompt:**
Inspect `Config/AppInfo.plist`, `Config/Google.xcconfig`, ignored
`Config/Local.xcconfig`, `Stream14.xcodeproj/project.pbxproj`, shared scheme,
`Package.resolved`, `Stream14/PrivacyInfo.xcprivacy` and ThirdPartyNotices. Never
commit local config, team/signing IDs, profiles, private tester details or media.
Use the real public iOS OAuth client and matching reversed callback in the local
configuration for the exact archive. Missing config is a release blocker for an
account-enabled candidate, although local recording still works.

Preparation verified Xcode 27.2 (27B52) and iOS SDK 27.2 locally. Apple's
[current submission page](https://developer.apple.com/app-store/submitting/),
checked 2026-11-09, recommends Xcode 27 and announces iOS/iPadOS 27 SDK minimums
from April 2027. Recheck at actual upload; validation remains authoritative for
that archive. The scheme's Archive action uses Release. Keep its main teal icon
and normal signing; separate UI test installations must use the branded purple
runner. No hand-edited re-sign, ad-hoc distribution or unbranded xctestrun install.

Selected package products are HaishinKit, RTMPHaishinKit and GoogleSignIn. Pins
include GoogleSignIn 10.1.0, AppAuth 3.0.0, GTMAppAuth 6.0.0,
GTMSessionFetcher 5.3.1, AppCheckCore 12.0.0, GoogleUtilities 8.1.5 and Logboard
2.6.0. Resolved SRT/RTC/OpenSSL packages are not evidence of linkage: inspect the
actual archive/load commands and privacy resources. Preserve BSD-3-Clause and the
full linked-dependency notices. Apple's [SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
list AppAuth, GoogleSignIn, GoogleUtilities, GTMAppAuth and GTMSessionFetcher;
listed SDKs need manifests and binary dependencies also need the required signatures.
Generate Organizer's aggregate privacy report, inspect it alongside source,
and resolve archive validation findings before upload.

The app manifest declares UserDefaults CA92.1, system boot time 35F9.1 and
app-container file timestamps C617.1, no tracking, and no app-declared collected
data. This does not replace Google SDK disclosures or App Store Connect answers.
F12's diagnostics are private on-device checkpoints exported only deliberately.
Verify their timing/memory/file APIs against the final manifest. Confirm camera
and microphone purpose strings mention local recording and confirmed YouTube
broadcasting; verify no Photos, location, tracking or background-audio workaround.

Proposed App Privacy assessment: no developer backend or automatic media/report
upload; separately inspect Google SDK account/contact/identifier/coarse-location/
usage/other-data declarations, direct YouTube media/connection processing and
chosen overlay website requests. Do not automatically answer “Data Not Collected”
from the app-only manifest. Use Apple's [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)
and aggregate report to determine final categories, purposes, linkage and tracking.
No answers have been saved to App Store Connect in this preparation.

Export-compliance assessment is pending the final linked binary. HTTPS/WebKit,
Keychain, Google authorization and RTMPS use encryption. If actual implementation
uses only operating-system encryption and no additional cryptographic library,
assess the exemption on that evidence; never reuse old local-only answers blindly.
Apple's [export-compliance guide](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
requires a determination even for OS crypto. No new exemption key or compliance
answer is applied here.

---

## Task 3: Reproduce packaging after final-source review

**Prompt:**
Run appropriate native tests for final code changes using the shared scheme and
record exact result bundles. Documentation-only preparation needs link/content
checks and `git diff --check`, not an invented app pass. First build an unsigned
Release archive for the bundle audit after inheriting all final prerequisites:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -configuration Release -destination 'generic/platform=iOS' \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages \
  -disableAutomaticPackageResolution \
  -archivePath /private/tmp/stream14-full-app-unsigned.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
```

For the real candidate, choose the existing paid team privately in Xcode; use
Product → Archive with Stream14 / Any iOS Device (arm64). Equivalent normal signed
command once local team configuration and unique version/build are confirmed:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -configuration Release -destination 'generic/platform=iOS' \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  -archivePath /private/tmp/stream14-full-app-candidate.xcarchive archive
codesign --verify --deep --strict /private/tmp/stream14-full-app-candidate.xcarchive/Products/Applications/Stream14.app
```

A missing local team is a setup blocker; do not embed a private team selection in
this document or commit a guessed value. Audit built identity/version/client
callback, icon, permission strings, dependency resources, licenses, no test
bundles/HTML fixtures and Release exclusion of Debug fixture launch seams.
An unsigned archive is not upload-ready. A signed development build is not
App Store distribution validation.

In Organizer select that archive → Validate App, then Distribute App → App Store
Connect. Until upload is explicitly authorized, stop at the concrete reviewed
archive/validation result. The later upload can use Xcode's normal automatic
signing export path with `method=app-store-connect`, `destination=upload`,
`manageAppVersionAndBuildNumber=false`, symbols and existing internal-only testing
settings. Keep any export plist and signing logs private outside Git; do not
re-sign a payload manually. Upload is not part of this preparation.

---

## Task 4: Prepare accurate beta text and owner dependencies

**Prompt:**
Use the following proposed metadata only after it matches the final candidate.
Keep old MVP beta text identifiable as historical. Verify signed-out HTTP access
to the exact main policy/support/terms links after their PR merges, then inspect
the installed build's links later. A source URL or authenticated browser load does
not establish public availability.

**Proposed beta description:** stream14 combines rear-camera video, microphone
audio and an optional transparent HTTPS web overlay. Rehearse and save a local
H.264/AAC MP4 without Google, or explicitly confirm broadcasting to an existing
scheduled YouTube event. Local recording, upload and YouTube status are separate.
Keep the app foreground. Long-run broadcast qualification remains pending.

**Proposed What to Test:** Check Preparation, Session and Recordings. Start with a
short local clip, manual overlay hide, Stop, Play and Export to Files. Retain
valuable originals before updating. For an owner-agreed Unlisted test, verify the
real channel/event/visibility and confirm Go Live deliberately; inspect the receiver
and saved original, then confirm End and verify YouTube ended. Report exact
build/model/OS and visible failure states. Private diagnostics export separately
from media. Do not attach private media, credentials or secret-bearing URLs.

**Proposed review notes:** Local rehearsal needs no account. YouTube requires the
reviewer's explicitly authorized eligible Google test account while OAuth is
Testing, live-enabled channel, and an existing encoder event with auto-stop off.
Selecting/refreshing/preparing never publishes. Go Live confirmation starts media
upload; auto-start events can go Live from first upload. No purchases or separate
stream14 account. No background camera broadcasting. Arrange private reviewer
access outside Git only if external review is actually requested; do not publish
account credentials or private event identifiers.

Owner-only prerequisites are membership/account agreement issues, existing eligible
internal Apple access, any OAuth audience/branding/verification changes, actual
channel permissions/live eligibility and intended event/publishing choice. Do not
accept agreements, broaden account permissions, create paid resources or invite
new testers during preparation. Existing account checks #15/#16 were owner-confirmed
outside this stage; reauthorization may still be needed because access was revoked.
Google Testing users and Apple internal/external testers are separate lists.
Google's [OAuth token documentation](https://developers.google.com/identity/protocols/oauth2#expiration)
states External/Testing grants expire after seven days for these YouTube scopes.
Do not assume Apple distribution expands Google's allowed audience or API quota.

---

## Task 5: Review and record delivery checkpoints separately

**Prompt:**
An independent agent must inspect the actual final diff against main, relevant
requirements and validation artifacts. Resolve material correctness/privacy/build/
media findings, rerun affected checks and record the outcome in the PR. Root will
arrange independent review of this preparation. Commit useful changes, prepare a
focused PR into current main, and never merge automatically.

When separately authorized, record signed validation, upload success, processing,
export compliance, saved beta text, group assignment, actual installation identity,
public/in-app links, short A3 smoke and owner review as separate rows in a new
full-app delivery record. Apple's [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
distinguishes eligible internal testers from external review/access. Retain the
existing internal group and recipients unless explicitly directed otherwise.
No invitation or public testing link is authorized here. Builds are testable for
up to 90 days; record actual upload/expiry and replace with a higher build before
expiry without deleting originals.

Phone operations remain outside this preparation. A later routine attended run
has a five-minute TOTAL budget including install/prompts/wrap-up; do not silently
extend it. Stop if setup consumes the budget. Long A2/A7 recording/broadcast runs
require separate explicit agreement and belong to F14. Native fixtures, archive
success and old MVP owner approval cannot qualify the new TestFlight binary.

Current pending evidence: final parent integration; legal/consent/API-data deletion
resolution; live version/build inventory; final archive/privacy/linkage audit;
normal signed validation; upload/processing/compliance/group state; exact-build
TestFlight installation; installed policy links; private short Unlisted A3 smoke;
actual F12 report export/overhead; F14 acceptance. Issue #26 remains open.
