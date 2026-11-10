# Merged-main development phone candidate — 2026-11-10

## Prepared candidate and evidence

Current main `1960df2eb1a90758acf27f4e341cdc483e54c27d` merges PR #66 and
contains PR #64's preview foreground recovery and the default-key correction.
This preparation changes no app source, version or provider configuration. The
separate draft interface work in PR #63 is not included.

A normal shared-scheme **Debug Development 0.3 (4)** build succeeded in 30.280
seconds with native exit 0. All twelve dependency checkouts matched the committed
lockfile, including HaishinKit `497f742`; a private copy of the warmed package
cache avoids writing to the shared checkout. The scheme's branding post-action
ran. The main app's bundled icon matches the previously installed teal icon.
No separate UI-test runner was built or installed in this app-only build.

Normal strict/deep signature verification passed. The embedded development
profile is unexpired, its provisioned-device set matches the prior successfully
installed candidate, and the app/profile application identifiers agree. The
configured public OAuth client and callback match. These are laptop checks, not
current phone connectivity, installation or capture evidence.

Private local artifacts, not Git attachments:

- Clone/branch: `/private/tmp/stream14-merged-main-phone-candidate`,
  `codex/merged-main-phone-candidate`.
- App: `/private/tmp/stream14-merged-main-phone-build/Build/Products/Debug-iphoneos/Stream14.app`.
- Build log/outcome: `/private/tmp/stream14-merged-main-phone-build.log`,
  `/private/tmp/stream14-merged-main-phone-build-outcome.json`.
- Nonsecret check results/private binary identity:
  `/private/tmp/stream14-merged-main-phone-preparation.json`.
- Isolated pinned cache: `/private/tmp/stream14-merged-main-phone-packages`.

No install, launch, camera/microphone access, provider request, recording,
broadcasting or TestFlight upload occurred during the laptop preparation stage.
Before the separately authorized visit below, the installed phone app was
Development source `625df2a`, whose
[short broadcast result](2026-11-10-default-key-phone-test.md) does not test the
newly combined preview fix. Preserve the existing container and originals during
any later in-place install; never uninstall/reset as routine preparation.

Reproduce from the recorded source with ignored `Config/Local.xcconfig` prepared
privately using the [development guide](ios-development-guide.md):

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Debug \
  -destination 'generic/platform=iOS' \
  -clonedSourcePackagesDirPath /private/tmp/stream14-merged-main-phone-packages \
  -disableAutomaticPackageResolution \
  -derivedDataPath /private/tmp/stream14-merged-main-phone-build \
  -allowProvisioningUpdates build
```

Do not publish raw signing logs, profiles, device/account identifiers or local
configuration. Before a later install, recheck the candidate's source/signature
and owner readiness; there are no fixture arguments or capture opt-ins in the
normal shared-scheme launch.

## Next attended visit: preview only, five minutes total

**Pending, not executed.** Coordinate a new visit after the owner confirms the
phone is connected/unlocked, any recording is stopped and a non-private scene is
ready. Laptop build preparation is already complete. Use the existing app's
ordinary controls; leave Record and Go Live untouched. The visit starts before
installation and ends by five minutes, including wrap-up. If installation,
permission or account setup consumes the slot, stop and leave the camera closed;
reschedule the remaining checks instead of extending the visit.

| Time from visit start | Owner/operator action | Pass observation |
| --- | --- | --- |
| 0:00–1:15 | Install the prepared development app in place, ordinary launch, open Session. Keep phone portrait throughout the first checks. | Existing recordings remain; no recording/upload begins. If installation is slow, stop this visit here. |
| 1:15–2:15 | Tap Open camera; confirm a moving picture. Switch to Codex for about five seconds and return to stream14. Repeat once. | The moving camera picture returns without another Open camera tap; the overlay returns when its source is healthy. A brief opening state is acceptable; persistent black camera is a failure. |
| 2:15–3:00 | Tap Close camera. Switch to Codex and back. | Camera stays closed and Open camera remains available; no recording timer or Live/upload state starts. |
| 3:00–4:00 | If time remains, Open camera in landscape and repeat one app switch; then Close camera. | Moving camera returns; layout remains usable. Record skipped if time runs short. |
| 4:00–5:00 | Verify camera is closed and app is neither recording nor uploading. Report portrait return, manual Close and optional landscape separately. | No new recording was requested; originals retained. Stop by 5:00. |

This visit exercises preview-only restoration and manual Close. It does **not**
prove interrupted recording/broadcast explicit-resume behavior, current phone
media performance, physical A/V sync, reconnect/outage handling or TestFlight
qualification. Those remain separate visits in the
[connected-iPhone backlog](2026-11-07-connected-iphone-test-plan.md). Do not start
recording or publishing to expand this card without new owner agreement.

The merged source previously passed 107 affected native tests, unsigned Release
and independent source review as documented in the
[progress ledger](2026-11-07-epic13-progress.md#pr66-integration-after-pr64-merge--2026-11-10).
Those results are inherited evidence, not rerun or physical passes in this
preparation. This documentation-only handoff requires link/content checks,
`git diff --check` and independent review before PR publication.

## Separately authorized in-place installation

The owner subsequently confirmed the phone was connected/unlocked with recording
stopped and agreed to the five-minute preview-only visit. Device operations began
at **21:25:21.272815 UTC**, with a strict **21:30:21.272815 UTC** cutoff. Normal
in-place installation succeeded (native exit 0, 5.993 seconds), followed by an
ordinary launch (native exit 0, 1.045 seconds). No uninstall, reset or container
read was performed. The recorded installed source is now **Development 0.3 (4),
main `1960df2`**, including the preview/default-key fixes; it is not TestFlight.

Private install/launch evidence is retained under
`/private/tmp/stream14-preview-phone-{visit,install,launch,install-outcome,launch-outcome}.json`.
The owner was asked to use ordinary Open camera controls in portrait, switch to
Codex for about five seconds and return twice, without Record or Go Live. Physical
preview-return, manual Close and optional landscape results remain pending until
explicitly reported; installation/launch success alone is not a camera pass.

Independent actual-diff preparation review found no material issues. The reviewer
also verified the native successful build and normal strict/deep signature; all
54 local links and diff checks passed. The attended-result update is reviewed
separately before PR handoff.

At 21:29 UTC root instructed the owner to close the camera and leave recording
and upload stopped before the cutoff. At this checkpoint no physical preview
result or final camera-closed confirmation has been received; both remain
unknown, rather than inferred from a successful launch. The install agent has
finished its native commands; no additional phone command is scheduled. Late
owner observations may update this report without restarting device tests.
The focused independent review of the actual install artifacts and documentation
found no material issues.
