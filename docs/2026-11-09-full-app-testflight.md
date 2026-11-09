# Full-app TestFlight candidate — preparation record

Updated: 2026-11-09. **Not uploaded or delivered. Issue #26 remains open.**
The previous [0.2 (3) local-only delivery](2026-11-07-testflight-0.2.md) and owner
MVP evidence remain historical. This record identifies the later full-app source
and its outstanding delivery/acceptance checkpoints.

## Candidate source and resulting behavior

The candidate normally inherits final F11 `72069f4` / main-ancestry update
`f20b330`, F12 `ef202456`, and the monitor/interface corrections they contain.
F13 adds YouTube-only privacy/service/YouTube terms agreement, direct policy and
Google access-settings links, accurate support/privacy/service text and the final
fork revision in dependency notices. Local preview/recording remains available
without Google or agreement to YouTube features.

Explicit local API-data deletion and SDK revocation are distinct actions. They
preserve recordings/recovery copies, private numeric diagnostics and overlay
settings. Stored API identifiers expire at 30 days, checked on launch, activation
and journal use; no background task while unused is promised. Unknown/offline
Restore or token refresh retains fresh exact-event context. Confirmed invalid
Google grants/API authorization denial triggers cleanup. A durable nonidentifying
Studio-resolution guard is written before removing prior/in-flight request IDs,
blocks late journal writes and survives relaunch. Only explicit Studio-resolution
acknowledgement after outstanding work settles removes it; deleting identifiers
cannot silently enable duplicate remote mutations. No remote media is deleted.

See the [canonical design](2026-11-01-stream14-design.md),
[reproducible release plan and proposed metadata](2026-11-09-full-app-testflight-implementation.md),
[privacy](privacy.md), [service terms](terms.md) and [support](support.md).

## Verified preparation

| Checkpoint | Evidence / limits |
| --- | --- |
| Native combined hosted suite | 181 passed, 8 opt-in skips, 0 failures; 30 suites; `/private/tmp/stream14-f13-combined-hosted.xcresult` |
| Retention/auth/control subset | 94 cases passed in five suites at `471eb1e`; final combined suite additionally covers precise Google/AppAuth loss classification and transient token refresh |
| Combined Simulator UI | Two passed: consent/local rehearsal/deletion-dialog dismissal and native destinations/scoped accessibility audit; `/private/tmp/stream14-f13-combined-ui.xcresult` |
| Environment | Xcode 27.2 (27B52), iOS SDK 27.2; iPhone 13 mini Simulator iOS 27.2 |
| Unsigned Release archive | `ARCHIVE SUCCEEDED`; `/private/tmp/stream14-f13-unsigned.xcarchive`; no distribution signing claim |
| Archive identity | `com.smith3v.stream14`, source version 0.2 (3), minimum iOS 27; no release version bump |
| Archive resources | Teal app icon, notices, nine parseable privacy manifests; only camera and microphone purpose keys; no test bundles or HTML fixtures |
| Binary boundary | Only Apple/Swift dynamic loads; no OpenSSL/SRT/RTC undefined-symbol indicators in the audit; Debug UI/private receiver/short-phone environment seams absent |
| OAuth configuration | This first unsigned archive intentionally used unconfigured local defaults. An account-enabled signed candidate still needs the existing authorized public iOS client/callback configuration outside Git |
| Policy links | Changed local Markdown links resolve. Exact published main URLs and installed-app links remain pending until the reviewed policy changes are published |
| App Store Connect inventory | After owner sign-in, root read Build Uploads / All Statuses on 2026-11-09: only 0.2 (3), 0.1 (2), 0.1 (1), all Complete; no newer/processing upload. 0.2 (3) is Testing for the existing Owner MVP internal group, 88 days remaining. No settings changed |
| Independent review | Initial review identified retention and Restore cleanup issues; corrected to preserve transient failures and expire IDs safely. Final actual-file/full-diff review at `63557fb` found no remaining material findings |

Hosted fixtures use invented credentials/IDs, synthetic media and local WebKit
checks; no real Google/YouTube calls or physical camera actions were performed.
Native media fixture QoS warnings remain observations, not evidence of physical
performance. The UI scope preserves the F10 documented clipped-static-text audit
allowance; it does not establish physical VoiceOver acceptance. Earlier failing
UI fixture/popover assumptions and the restore-wiring regression were corrected
before the final passing combined checks. Final source normally inherited the
main-ancestry-only F11 update after native/archive checks; that merge changed no
file bytes. The later combined UI passed on that inherited source.

Final independent F12 review covered `ef202456`; final F13 review covered
`63557fb`, including transient authorization handling and retention. Both found no
remaining material findings. Subsequent normal ancestry merges bring F12 to
`79418b8` and this candidate to `6da5dcd`, inheriting current main `f56d275` after
PR #57. Before this documentation-only checkpoint, `git diff --exit-code 63557fb
6da5dcd` was empty: the reviewed/tested file tree is unchanged. No native tests
were repeated for ancestry bookkeeping or these documentation corrections.

## Delivery and acceptance still pending

- The focused source now sets 0.3 (4), as recorded below. Recheck uploads before
  actual distribution; this archive does not reserve a build number.
- Publish the independently reviewed policy/support/terms and
  verify the exact signed-out public URLs used by the candidate.
- The account-enabled Release archive below passed the local bundle/signature
  audit with development provisioning. Obtain actual App Store distribution
  validation and Organizer aggregate privacy report, and resolve final
  export-compliance questions. Current
  Apple SDK/privacy/TestFlight requirements were checked against official sources
  linked in the release plan; recheck at actual upload.
- Record Organizer validation, authorized upload, processing/review, encryption
  compliance, saved beta text and existing internal-group assignment separately.
  No new testers/invitations/public links or account/legal changes are authorized
  by this preparation. Signing identities, profiles and tester information stay
  private outside Git.
- Install through TestFlight in place and verify the exact version/build on the
  13 mini. Export valuable originals before a potentially destructive change;
  never uninstall or delete recordings as routine cleanup. Verify installed policy
  links, a private short Unlisted A3 smoke, receiver/original playback and actual
  private diagnostic export. Google Testing audience/expiry is separate from
  Apple testers; prior revoked consent requires deliberate reauthorization.
- Keep routine phone work within five minutes total including setup/wrap-up.
  Longer A2/A7 and full A1–A9 qualification belong to F14 and require explicit
  agreement. No long recording or publishing action occurred in this stage.
- Record actual upload/expiry dates and replace before TestFlight's 90-day window
  ends, using a higher build without deleting originals. Upload/availability is
  separate from installation, acceptance and long-run qualification.


## Account-enabled 0.3 (4) archive checkpoint — 2026-11-09

A separate release stage changes both app configurations and the existing hosted
identity assertion to **0.3 (4)** at `1ae3f87`, inheriting reviewed candidate
`9bd5c7d`. Prerequisite PRs [#58](https://github.com/smith3v/stream14/pull/58)
and [#59](https://github.com/smith3v/stream14/pull/59) target main; merge #58 before
#59 and this release change. Source below those prerequisites is not yet a merged
main release. No automatic merge or upload was performed.

The existing authorized public OAuth client, matching callback and Apple team
were copied only into ignored `Config/Local.xcconfig`. No token, account, stream
identifier, signing identity or profile is in this source change. Actual archive:
`/private/tmp/stream14-release-0.3-signed.xcarchive`. It passed normal Release
archiving and `codesign --verify --deep --strict` using ordinary trust services.
It has an unexpired **development** provisioning profile matching the app;
this is not App Store distribution signing/validation or upload readiness.

The actual archived Info.plist reports `com.smith3v.stream14`, 0.3 (4), minimum
iOS 27, configured Google client with matching callback, teal AppIcon, camera and
microphone purpose strings mentioning confirmed YouTube use, no other usage
purpose keys and no background modes. Nine bundled privacy manifests parsed;
app reasons remain CA92.1/35F9.1/C617.1, tracking false and app collection empty.
Notices include fork `497f742`. No test bundles, HTML fixtures or Debug launch
seams were found. Dynamic load paths are Apple/Swift; the symbol audit found no
OpenSSL/SRT/RTC indicators. These checks do not replace the aggregate SDK privacy
report or App Store export-compliance determination. Safe numeric/boolean audit:
`/private/tmp/stream14-release-0.3-archive-audit.json`.

The **two existing hosted AppConfigurationTests passed**, zero skips/failures,
on iPhone 13 mini Simulator iOS 27.2, Xcode 27.2 (27B52). The native result summary
confirms two Swift Testing cases actually executed, distinct from XCTest's empty
wrapper. Result `/private/tmp/stream14-release-0.3-identity.xcresult`; private log
`/private/tmp/stream14-release-0.3-identity.log`. The inherited full 181-pass suite
was not repeated for the version-only change.

Reproducible native commands from the release clone:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -disableAutomaticPackageResolution \
  -derivedDataPath /private/tmp/stream14-release-0.3-build \
  -archivePath /private/tmp/stream14-release-0.3-signed.xcarchive archive
codesign --verify --deep --strict \
  /private/tmp/stream14-release-0.3-signed.xcarchive/Products/Applications/Stream14.app
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination 'platform=iOS Simulator,id=D6BEAF78-D273-4952-8349-B50B2824E6A9' \
  -clonedSourcePackagesDirPath /private/tmp/stream14-transport-fix-packages \
  -disableAutomaticPackageResolution \
  -derivedDataPath /private/tmp/stream14-release-0.3-test-build \
  -resultBundlePath /private/tmp/stream14-release-0.3-identity.xcresult \
  -only-testing:Stream14Tests/AppConfigurationTests -parallel-testing-enabled NO test
```

Use new archive/result paths on rerun; the commands above identify retained
artifacts and must not overwrite evidence. The stage did not install or operate
the phone, start capture, call Google/YouTube, change App Store settings or upload.
Published main policy links, App Store distribution validation, aggregate privacy
report, upload/processing/compliance/group state, exact TestFlight installation
and all remaining physical/service acceptance gates remain pending.


Independent release review inspected the actual full diff against main, the
focused delta from reviewed F13, archived Info.plist/privacy resources, safe audit
and native two-case result summary. It independently verified the archive's
strict signature and found no material findings at source `1ae3f87` plus these
documentation updates. `git diff --check` and changed-document local file links
passed. No extra native run was needed for the documentation-only handoff.


## Merged-main distribution checkpoint — 2026-11-09

The owner merged #58, #59 and #60. Distribution work starts from main
`32996c09e30f3b00ea36a7b34d437821741e021d`; the app, project, test and configuration
trees have an empty diff against archived source `1ae3f87`. No rebuild or media
regression rerun is claimed for that ancestry/documentation-only difference.
Root refreshed App Store Connect Build Uploads / All Statuses: only 0.2 (3),
0.1 (2), 0.1 (1), all Complete; no newer/processing upload. The exact in-app main
privacy, terms and support URLs returned HTTP 200 without authentication, and raw
content matched reviewed source. Private safe hash/status evidence:
`/private/tmp/stream14-03-public-policy-check.json`.

Xcode Organizer imported the exact retained archive and **Generate Privacy Report**
exported a one-page PDF at `/private/tmp/stream14-0.3-aggregate-privacy-report`
(the saved file has no extension). Native PDFKit extracted text to the matching
`.txt` path. All nine bundled manifests were decoded separately into private
`/private/tmp/stream14-03-manifest-audit.json`. The aggregate attributes these
GoogleSignIn declarations to that SDK, all linked and not tracking:

| SDK-declared type | Declared purpose |
| --- | --- |
| Name, email address, phone number, coarse location | App functionality |
| User ID, other data types | App functionality and analytics |
| Device ID, other usage data | Analytics |

The app's own manifest has no declared collection; that does **not** make the
combined app "Data Not Collected." This report is a declaration inventory, not a
packet-level observation that every listed field is sent in every authorization.
The published policy already distinguishes provider processing and these SDK
categories from a developer collection backend. No SDK declaration was removed or
rewritten to make the report appear empty. Root read App Store Connect App Privacy:
it is unconfigured (Get Started, empty policy/choices fields), not a previously
published no-collection answer. No privacy answer was saved. Public-submission
privacy labels still need a full assessment of actual third-party processing,
including confirmed YouTube video/audio and chosen overlay website requests,
rather than copying only this manifest table.

Current [Apple submission requirements](https://developer.apple.com/app-store/submitting/),
[third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/),
[App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)
and [export-compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
were rechecked on 2026-11-09. Xcode 27.2 / iOS SDK 27.2 satisfies the stated SDK
boundary; actual Apple validation remains required. Listed included SDKs retain
their manifests. The archived load/symbol audit finds only Apple/Swift dynamic
loads and no OpenSSL/SRT/RTC indicators. Source uses URLSession/WebKit, Keychain
and native TLS for RTMPS; AppAuth PKCE uses Apple's CommonCrypto SHA-256 hashing.
No app-defined encryption algorithm or additional cryptographic implementation
was found. This supports assessing operating-system-only encryption, not a claim
that the app uses no encryption; answer the actual compliance question separately.

### Current validation/account blocker

An initial `method=validation, destination=export` attempt exited 70 before service
validation: the installed Xcode requires `destination=upload` for that method.
The corrected normal validation attempt also exited 70 before validation/upload:
**Failed to Use Accounts**; App Store Connect access is required in Xcode Accounts.
Private log `/private/tmp/stream14-03-validation-supported.log`. Organizer also
showed account access unavailable. Xcode Settings → Apple Accounts was opened and
shows Sign In, with no usable configured account. The owner handles the existing
developer account sign-in/2FA privately; Firefox sign-in does not authenticate
Xcode. No password, code or credential was requested in Git or entered by the agent.
No build was uploaded and no compliance, group, tester or account setting changed.

Resume after the owner confirms Xcode sign-in: verify the account handoff outcome,
recheck upload inventory if time has passed, then retry supported normal validation
and `method=app-store-connect` upload with fixed 0.3 (4), automatic signing,
`manageAppVersionAndBuildNumber=false`, symbols and internal-only testing. Retain
private export options/logs outside Git. Never manually re-sign or use an unrelated
account. Record actual validation, upload, processing, compliance and existing-group
availability independently. Phone installation and all physical gates remain pending.

A separate agent inspected this actual full documentation diff against merged main,
the extensionless PDF/text, nine-manifest inventory, policy hash/status evidence and
private validation error. It independently verified the runtime-tree equality and
found no material findings. Changed-document local links and `git diff --check`
passed. No app tests were rerun for this documentation-only checkpoint.
