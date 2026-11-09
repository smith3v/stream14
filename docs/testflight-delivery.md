# TestFlight delivery record — MVP and updates

The later full-app candidate has a [separate preparation/delivery record](2026-11-09-full-app-testflight.md). It is not uploaded or delivered; the historical MVP/update evidence below remains separate.

Updated: 2026-11-07. **Version 0.2 (3) is Testing in Owner MVP**, with compliance
completed and release-specific What to Test notes saved. See the
[0.2 release record](2026-11-07-testflight-0.2.md). Installation of this update has
not been observed. Historical MVP evidence follows.

**Version 0.1 (1) was installed and used through TestFlight. The owner
exported and reviewed an approximately 35-minute recording; objective file
verification and qualification limits are recorded in feasibility.** Prerequisite PRs #10 and #11 merged; issue #5 closed with explicit
start/end sync and TestFlight qualification carryover.

UI update **0.1 (2)** uploaded successfully on 2026-11-05 at 22:55 Amsterdam;
processing and compliance completed, and Owner MVP shows it **Testing** at 23:10.
Actual build 2 installation has not been observed. See the
[issue #30 release record](2026-11-05-recording-ui-testflight.md). The historical
0.1 (1) owner review below remains unchanged.

## Version convention

The owner requested **0.2 (3)** after merging PR #36 and accepting the development
app on the phone. See the [0.2 release record](2026-11-07-testflight-0.2.md) for
completed packaging/distribution evidence. Each TestFlight release of newly merged
main changes increments the minor version; replacement uploads within that release
increment only the globally increasing build number. Version/build are committed
in both app configurations; preserve private signing selections outside Git.

## Original MVP delivery state and attention boundaries

| Item | Status |
| --- | --- |
| Source baseline | main 4f831e1 (merged PR #12); delivery branch codex/issue-6-testflight-delivery |
| App identity | com.smith3v.stream14; uploaded candidate 0.1 (1) |
| Apple membership | Active membership and Xcode paid team verified |
| App record / distribution team | Stream14 app record created; same bundle ID and existing team |
| Release packaging | Signed Release archive, strict signature check and Organizer validation passed |
| Upload / processing / review / invitations | Upload/processing completed; export declaration saved; internal Owner MVP group is Testing |
| TestFlight installation / expiry date | Upload 2026-11-05; owner confirms TestFlight use/export; Apple displays Expires in 90 days |
| Delivered-build M1–M5 / owner review | Owner confirms picture/sound/overlay and requests closeout; formal measurement limits remain explicit |

The owner does not monitor this chat continuously. Requests remain pending until
answered; silence never authorizes a run. Archive and upload require no connected
phone. For any USB operation, check connection immediately before the operation;
a disconnection is a resumable setup/transfer interruption, not proof of an app
failure. Do not automatically reinstall, erase data or start another recording.
Copy only stopped/finalized files and verify copies before drawing conclusions.
No recordings are deleted as cleanup.

The owner subsequently installed through the invitation, recorded 35 min 26.410 s
using the TestFlight app, exported the original MP4 to the laptop,
and confirmed picture, sound and overlay look correct. There were no start/end
sync markers. This establishes actual beta use and owner playback/export review;
it does not quantify ≤100 ms sync or prove memory/queue stability. See the
[original-file measurements and remaining limits](feasibility.md#owner-testflight-recording-and-review-2026-11-05).

Build 0.1 (1) was assigned to Owner MVP after processing and export compliance.
At assignment, the group had one existing internal owner tester, with invitation
status Invited and build status Testing; the owner subsequently reports installation. Automatic build distribution is disabled; replacements
must be assigned deliberately. No external beta review or external testers were
needed for this internal route. Apple displays Expires in 90 days as observed on
2026-11-05; check the current expiry in TestFlight before planning later use.

TestFlight installation and ordinary testing work without a laptop connection.
Ask the owner to reserve attention for installation/permission prompts, physical
A/V markers and playback/export. Agree on a distinct later 30-minute M3 slot;
current development experiments remain capped at fifteen minutes.

## Owner-only Apple setup

1. Open [Apple Developer Account](https://developer.apple.com/account/) and sign in
   personally. Check Membership details. If needed, use
   [enrollment](https://developer.apple.com/programs/enroll/). The owner completes
   identity verification, agreement acceptance and membership payment. Apple lists
   US$99/year with region-specific pricing; activation may take time. Do not send
   credentials, identity documents or codes to this chat.
2. Success is an active Apple Developer Program membership and access to
   [App Store Connect → Apps](https://appstoreconnect.apple.com/apps). Report only
   “active” or the blocker; no account screenshot is necessary.
3. In Xcode → Settings → Apple Accounts, sign in personally if requested. A free
   Personal Team can run a development build but cannot distribute through TestFlight.
4. Register the explicit identifier com.smith3v.stream14 in Certificates,
   Identifiers & Profiles if absent. In App Store Connect → Apps → + → New App,
   choose iOS, name stream14, English (UK), that Bundle ID, SKU stream14-ios and
   full access for the owner. A name conflict needs an agreed display-name choice;
   do not silently change the stable Bundle ID. SKU is a private app-record label.
5. Complete any Apple account agreements directly. Keep beta feedback/review
   contact name, email and phone in App Store Connect's designated fields, outside
   Git. Use the owner's existing eligible internal account initially. Do not give
   friends team access simply to make them testers.

## Release preparation and upload

Keep automatic signing and the paid team's selection local. Verify version 0.1,
build 1 has not already been uploaded before archiving; increase the build number
for every replacement upload. Recheck Apple’s
[submission requirements](https://developer.apple.com/app-store/submitting/).
The current machine reports Xcode 27.2 (27B52), iOS SDK 27.2.

The app bundles its existing teal icon, camera/microphone purpose strings,
ThirdPartyNotices.txt and PrivacyInfo.xcprivacy. The two reason declarations cover
overlay elapsed-time calculations (35F9.1) and metadata access within the app
container for deliberate safe deletion (C617.1). Source inspection of the selected
HaishinKit core/Logboard targets found no additional listed required-reason API
calls or privacy manifests. Resolved SRT/RTC/OpenSSL packages are not linked simply
because SPM resolved them; inspect the actual archive before making export claims.

Use [privacy policy](privacy.md) and [support](support.md) as public source pages
after their branch is published; use stable main URLs once merged. The app links
to the main-branch privacy page in the footer beside Third-party notices,
available before permissions or recording. PR #12 was owner-merged; the exact main-branch privacy
and support URLs both returned HTTP 200 without authentication before upload.
Verify the in-app link on the delivered build as well. A compiled URL alone does
not prove the remote page is readable. No custom legal terms have been
adopted. Fill current age-rating questions accurately for configurable web content,
and review App Privacy against actual overlay-service data flows before submitting.
The app-level empty collected-data manifest is not a claim that overlay websites
receive no requests.

Export-compliance assessment: the local app uses Apple's HTTPS/WebKit and Keychain,
with no app-defined cryptography or linked OpenSSL/RTMP/SRT/RTC product. Apple's
[encryption guidance](https://developer.apple.com/documentation/Security/complying-with-encryption-export-regulations)
says operating-system encryption is typically exempt from documentation upload.
Leave the Info.plist exemption key unset during preparation; confirm final
binary/dependency contents and answer Apple's build questions on that evidence.
Do not answer “no encryption” merely because there is no broadcasting.

In Xcode choose Stream14 scheme → Any iOS Device (arm64) → Product → Archive.
Organizer → Archives → select stream14 → Validate App, then Distribute App →
App Store Connect → Upload with normal automatic signing. Confirm upload results,
then wait for App Store Connect → TestFlight processing. Resolve reported privacy,
signing, icon, compliance or SDK errors before assigning the build. An unsigned
local archive proves packaging only and cannot be uploaded.

## Beta text ready for App Store Connect

**Beta description**

stream14 records rear-camera video and microphone audio with an optional
transparent HTTPS web overlay into a local 1080p H.264/AAC MP4. Preview and the
saved file use the same composition. Keep the iPhone upright in landscape and the
app in the foreground. Play, export the original file, or delete a selected
recording after confirmation. No Google account, YouTube login or broadcasting.
Long recording qualification is in progress.

**What to Test**

Open Overlay, choose Use reference URL, then Load overlay. Close settings, Open
camera, and allow camera/microphone access. Record a short clip; toggle Hide overlay
manually to check it disappears from preview and file. Stop, tap the recording’s Play icon, then its Export icon → Save to Files and
open that copy. Report build/model/OS
and visible failures using TestFlight feedback. Do not attach private media or
secret-bearing URLs. Keep important recordings exported before replacing a beta.

**Beta review notes**

No login or purchase is required inside the app. Overlay → Use reference URL →
Load overlay selects https://heren14-overlay.smith3v.com/overlay.html; internet is
needed for this webpage. Close settings and Open camera; permission prompts are
contextual. Record and Stop produce a local file with camera, microphone and
overlay. Recording itself needs no internet. If the reference is unavailable,
camera/audio can still record; no test success should be claimed for the missing
overlay. Reference score changes depend on the external source. For deterministic
changing-score acceptance, arrange the owner's controlled public HTTPS demo before
review; do not add credentials to the public notes. Backgrounding interrupts the
session and requires explicit restart. No streaming, Photos-library request or
account setup. Beta contact details are entered privately.

## Groups, install and acceptance

Use TestFlight → Internal Testing for an eligible existing App Store Connect owner.
For others use an external group with owner-specified recipients, complete Test
Information and applicable beta review, then send the agreed invitations. The
[Apple TestFlight guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
describes current access and review rules. Do not create a public invite link by default.

On the phone, install Apple's TestFlight from the App Store, accept the invitation
and install stream14. Export valuable development recordings before any uninstall;
prefer replacement in place. Record evidence of the TestFlight version/build and
device/OS without tester identity. Verify previously saved files rather than
assuming a signing-team transition preserves access to Keychain or container data.

Record each M1–M5 result for the actual delivered build in feasibility. Repeat the
short native UI, overlay update/hide/outage/recovery, interruption, failure-state,
playback and original Files-export checks. Keep actual-network outage distinct
from the prior WebKit request-rule injection. Do not fill the phone to test failure.

Before the owner-agreed 30-minute M3 run, settle how to measure charged memory and
queue stability on the TestFlight build: the hosted development test harness does
not run inside a TestFlight install. Existing per-record writer metrics and original
sample timestamps cover cadence/admission/stalls; they do not measure whole-app
memory or physical A/V sync. Do not equate a lack of crash with stable memory.
If additional in-app instrumentation is needed, scope/review it first and upload a
new build. Capture identifiable visual/audio markers at both start and end;
measure ≤100 ms A/V offset at each, with uncertainty, before accepting M3.
A missed marker or disconnect leaves that evidence pending.

Record upload/expiry dates from App Store Connect. Apple allows testing a build
for up to 90 days. Before expiry, increment build, archive/upload/process a
replacement, assign the group and update through TestFlight; retain/export originals.
Retest changed behavior and record the replacement identity. Expiry is not a reason
to delete recordings. After private sample/report owner review, propose a separate
broadcasting milestone; do not start it automatically.
