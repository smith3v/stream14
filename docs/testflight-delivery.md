# TestFlight delivery record — issue #6

Updated: 2026-11-05. **Release resources prepared; nothing uploaded or installed from
TestFlight yet.** Prerequisite PRs #10 and #11 merged; issue #5 closed with explicit
start/end sync and TestFlight qualification carryover.

## Current state and attention boundaries

| Item | Status |
| --- | --- |
| Source baseline | main 122c69c; focused branch codex/issue-6-testflight |
| App identity | com.smith3v.stream14; planned first candidate 0.1 (1), subject to unused-build check |
| Apple membership | Enrollment submitted; owner is waiting for Apple confirmation |
| App record / distribution team | Pending active membership and App Store Connect access |
| Release packaging | Unsigned Release archive and bundle inspection passed; not upload validation |
| Upload / processing / review / invitations | Pending; private contacts not collected in Git |
| TestFlight installation / expiry date | Pending; record actual upload date and Apple expiry after upload |
| Delivered-build M1–M5 / owner review | Pending; historical development evidence is not delivered-build acceptance |

The owner does not monitor this chat continuously. Requests remain pending until
answered; silence never authorizes a run. Archive and upload require no connected
phone. For any USB operation, check connection immediately before the operation;
a disconnection is a resumable setup/transfer interruption, not proof of an app
failure. Do not automatically reinstall, erase data or start another recording.
Copy only stopped/finalized files and verify copies before drawing conclusions.
No recordings are deleted as cleanup.

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
to the main-branch privacy page in setup's footer beside Third-party notices,
available before permissions or recording (issue #30 on integration).
**Pre-upload blocker:** merge the reviewed privacy-page
change with owner authorization and verify that exact in-app main URL and support
page open signed out before uploading. Branch publication alone does not make
the main URL live. Verify the link on the delivered build as well. Do not use
a local path
or claim unpublished documents are already hosted. No custom legal terms have been
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
manually to check it disappears from preview and file. Stop, Play sample, then
Export original sample → Save to Files and open that copy. Report build/model/OS
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
