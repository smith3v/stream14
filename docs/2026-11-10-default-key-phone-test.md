# Default-key development phone check

Preparation date: 2026-11-10. **Installed and launched as a development build; attended media results pending.**
The owner requested connected-phone testing without a new TestFlight upload.
The in-place development installation replaces TestFlight on that phone while
retaining the same bundle container. Never uninstall, reset, or delete recordings.

## Prepared source and binary

Own clone `/private/tmp/stream14-default-phone-check` starts from reviewed
`32bb4b3903c7442068d222b3e8f88005bb9375f9`, app source `625df2a`. It contains
only the default-key change, not unmerged PR #63 interface or #64 preview recovery.
The native Debug build succeeded with the shared Stream14 scheme and its branding
action, exact pinned fork `497f742`, and automatic normal development signing.
Existing public OAuth client/callback and Apple team remain in ignored local
configuration. The actual product is 0.3 (4), `com.smith3v.stream14`, teal AppIcon.
That identity is unchanged; installation route/source distinguishes it from the
previous TestFlight binary.

Strict signature verification passed. The unexpired development provisioning
profile includes the connected iPhone 13 mini. Public OAuth client and callback,
app identifier/entitlements, icon and unchanged tested runtime tree were checked.
Read-only device inventory showed iPhone 13 mini, iOS 27.2, wired/paired/connected,
Developer Mode enabled. Owner also confirmed recording stopped and phone unlocked.
Preparation initially performed only read-only device inspection. Installation and
ordinary launch subsequently completed as recorded below; this agent did not open
camera, record, authenticate or publish.

Private evidence: `/private/tmp/stream14-default-phone-preparation.json`,
`stream14-default-phone-readiness.json`, `stream14-default-phone-build.log`, and
`stream14-default-phone-signature.log`. Product:
`/private/tmp/stream14-default-phone-build/Build/Products/Debug-iphoneos/Stream14.app`.
The prepared install/ordinary-launch script and private device identifier remain
outside Git. It does not uninstall, terminate separately, seed fixtures or inject
media-test environments. It verifies the prepared binary hash before installation.

## Attended boundary

Wait for root's explicit operator go after the five-minute TOTAL clock starts.
Installation, prompts, setup, selected event confirmation, media test and wrap-up
all count. Root owns Firefox, operator Go Live/End confirmation and observations.
No test starts automatically from this document or the prepared script.

Use only the disposable Unlisted test event selected by the owner. Default key
sharing is permitted by this reviewed change; concurrent publisher/auto-start
coordination is explicitly deferred in issue #65. Do not create keys, rebind,
change or end unrelated events. Keep foreground for this test: preview recovery
from PR #64 is not in this candidate. Record actual receiver/YouTube/file state;
connection alone is not Live. Stop at wrap-up and preserve all originals.

An installation/launch success is development evidence, not a TestFlight regression
or a broadcasting pass. Record exact actual results separately after execution.


## In-place installation and ordinary launch

Root explicitly started the five-minute TOTAL operator clock and authorized the
in-place installation after the owner confirmed recording stopped and the phone
unlocked. Native `devicectl device install app` exited 0 in 6.722 seconds. No
uninstall, data reset, recording deletion or separate termination was used.

The first launch invocation stopped locally with exit 64: installed devicectl
rejected an empty JSON environment dictionary. It did not launch the app. The
corrected invocation omitted that option and stripped all `DEVICECTL_CHILD_`
variables from the CLI environment; ordinary launch exited 0 in 0.462 seconds,
with no app arguments or harness modes. The source and normal signed binary are
unchanged. This is a development installation of 0.3 (4), not a new TestFlight
build or a broadcasting pass.

Private evidence: `/private/tmp/stream14-default-phone-install.json`,
`stream14-default-phone-install-outcome.json`, `stream14-default-phone-launch-retry.json`,
`stream14-default-phone-launch-outcome.json`, and the updated preparation JSON.
Root owns any subsequent owner-confirmed media, event and receiver observations.
