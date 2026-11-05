# Recording UI update — TestFlight 0.1 (2)

Updated: 2026-11-05. **Version 0.1 (2) is Testing in the existing Owner MVP group.**

The owner explicitly authorized merging reviewed issue #30 and autonomously
delivering it through TestFlight. [PR #31](https://github.com/smith3v/stream14/pull/31)
merged into `codex/full-app` at `25c3d26`. Issue #6 is now closed; the focused main
backport preserves main's newer MVP owner-verification records. App/test source is
identical to reviewed `efeb462`; this does not promote broadcasting work.

The update moves policy/notices to the footer and adds accessible horizontal
recording icons with actual original MP4 sizes. Bundle ID, icons, file layout,
Keychain ownership, packages and media behavior stay unchanged. No phone Xcode
installation, uninstall, camera experiment or user-recording cleanup occurred.

The shared Stream14 scheme was archived with Xcode/SDK 27.2, Release, generic iOS
destination, pinned package cache, the existing paid team/account and automatic
signing. `CURRENT_PROJECT_VERSION=2` overrides the development project build number;
marketing version stays 0.1. Strict signature verification and privacy-manifest
lint pass. Linked binary inspection retains the operating-system encryption
boundary with no new crypto/transport package. Apple's current
[submission requirements](https://developer.apple.com/app-store/submitting/) and
[upload guidance](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
were rechecked before upload.

Native `xcodebuild -exportArchive -allowProvisioningUpdates` reused the existing
Xcode account with `method=app-store-connect`, `destination=upload`, automatic
signing, `manageAppVersionAndBuildNumber=false`, symbols upload and
`testFlightInternalTestingOnly=true`. Apple accepted the upload at 22:55 Amsterdam,
2026-11-05; Xcode reports “Upload succeeded” and “EXPORT SUCCEEDED”. The existing
internal Owner MVP group/tester is the destination; no new testers or public link.

Private local evidence: `/tmp/stream14-issue30-build2.xcarchive`,
`/tmp/stream14-issue30-signed-archive.log`, `/tmp/stream14-issue30-upload.log`.
Account/signing values and export-options plist stay outside Git.

Validation: 23 hosted tests, final unsigned Release and signed archive pass. All
six seeded 13 mini Simulator orientation/text-size combinations pass with retained
screenshots visually inspected. Playback-sheet/Files-action availability and
Cancel/confirmed selected-only deletion checks pass. The
[UI handoff](2026-11-05-recording-ui-implementation.md) records exact bundles and
the narrow scroll-text contrast audit exception. Separate-agent source/diff review
found no material issues; the exact-source backport needs only identity/diff and
documentation checks, not another camera run.

At 23:10 Amsterdam on 2026-11-05, App Store Connect shows build 2 **Testing**,
assigned to Owner MVP, with **Expires in 90 days**. The build's group table has
the existing group and one existing tester; no recipient was added. What to Test
notes describing the new icons/sizes/footer were saved. Export compliance was
completed as “None of the algorithms mentioned above” on the question distinguishing
app-defined encryption from Apple's operating-system encryption, matching the
inspected binary/dependency boundary. The old build remains available.

This confirms processing, compliance and availability through the owner's existing
TestFlight access. Actual build 2 phone installation has not been observed. Phone
automatic-update settings and installation timing are managed by TestFlight; the
owner can use its Update action without the laptop. Physical spoken VoiceOver, actual
playback and completed original-file export on this delivered update remain
pending; no formal media gate is waived by this UI release.
