# TestFlight update — 0.2 (3)

Updated: 2026-11-07. **Version 0.2 (3) is Testing in the existing Owner MVP group.**

The owner merged [PR #36](https://github.com/smith3v/stream14/pull/36), reviewed
the development app on the testing iPhone, and requested the next TestFlight update
with minor-version increments for merged changes. The source baseline is main
`b6266c9`, including the reviewed rear-lens selection (#33) and removal of the
separate overlay-preview strip (#34). The release branch changes only version/build
metadata and delivery documentation; it adds no media behavior or dependency.

Both Debug and Release now use marketing version **0.2**, build **3**. Starting
with this release, a TestFlight update containing newly merged changes from main
increments the minor version (0.1 → 0.2 → 0.3). Replacement uploads for the same
release keep that minor version and increment the build number. Build numbers
continue increasing across releases; do not reset them when the minor changes.
Check App Store Connect for collisions before each upload. This is a release-time
step; ordinary development branches do not each consume a release version.

The release preserves bundle ID, signing team, original recording files, Keychain
ownership, icons, package pins and the local-only media pipeline. Use the existing
Owner MVP internal group; do not add testers or public links.

Validation inherited from the exact merged app source: #33 has physical 13 mini
lens/recording/rollback evidence and owner acceptance; #34 has covered-WebKit alpha
and changing-pixel regression, composed NV12/recorder tests, three passing ordinary
UI/accessibility tests, Release build and independent review. After installation of
the #34 development build, the owner reported “All good.” That is development
review, not confirmation of installation or formal qualification of this TestFlight
update. Formal long-run sync/memory/queue limits remain as recorded in feasibility.

Signed archive `/tmp/stream14-testflight-0.2-build3.xcarchive` passed with Xcode
27.2 (27B52), iOS SDK 27.2 and the shared Stream14 scheme. Strict signature check,
privacy-manifest lint, bundle identity/version/build, icon/notices/permission strings
and exclusion of test bundles/HTML fixtures passed. Linked frameworks remain the
Apple/Swift system libraries; the project still selects only pinned HaishinKit core
and its existing Logboard dependency. No crypto/transport product is added.
Apple's [submission requirements](https://developer.apple.com/app-store/submitting/),
[upload guide](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
and [privacy-manifest documentation](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
were rechecked. Private signing/export options and distribution logs stay outside Git.

The app identity test now expects 0.2 (3), matching both project configurations.
A fresh hosted-suite run verifies this metadata change; the app's media source and
UI remain byte-identical to merged main. Independent review of the actual staged
diff/archive and the focused identity-test correction found no material issues.
The fresh hosted run passed 26 cases (including opt-in skips) in ten suites:
`/tmp/stream14-testflight-0.2-hosted.xcresult` and `.log`. Upload completed at **09:54 Amsterdam on 2026-11-07**: Xcode reports “Upload
succeeded” and “EXPORT SUCCEEDED” in `/tmp/stream14-testflight-0.2-upload.log`.
The existing Xcode account and automatic signing used `method=app-store-connect`,
`destination=upload`, `manageAppVersionAndBuildNumber=false`, symbols upload and
internal-only testing. App Store Connect completed processing and shows Binary State **Validated**, version
0.2/build 3, and App Uses Non-Exempt Encryption **No**. Compliance was saved as
“None of the algorithms mentioned above” on the question distinguishing app-defined
algorithms from Apple operating-system encryption, matching the unchanged inspected
boundary. By **10:10 Amsterdam**, Owner MVP showed **0.2 (3) Internal — Testing**,
**Expires in 90 days**, with the existing one tester. The old 0.1 (2) remains Testing;
no testers/public links were added and no build was expired. Release-specific
What to Test notes were saved and the page showed **Saved**.

This establishes upload, processing, compliance and availability through existing
internal TestFlight access. Installation/update from TestFlight and playback/export
on this exact delivered build have not been observed. On the phone, open
**TestFlight → stream14 → Update** to install 0.2 (3) in place. Do not uninstall or
remove originals. No new camera experiment or formal long-run qualification was
performed for packaging; earlier qualification limits remain explicit.

## What to Test

Compare **1×** and **0.5×** using the camera button while preview is open, before
recording. Choices reflect the phone's supported rear lenses; selection locks while
recording. The separate overlay strip is gone: inspect the overlay in the composed
camera preview and retain the status/manual-hide controls. Record a short clip,
stop, play it and export the original to Files. Confirm the wider view and overlay
are present in the saved file. Check portrait and both landscape layouts, including
larger text. Keep important recordings exported before replacing a beta; do not
uninstall the app or attach private media/secret-bearing URLs to feedback.
