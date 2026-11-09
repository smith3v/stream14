# Attended account and event checks — 2026-11-08

The normally signed current-main build `f454e9b` (Xcode development Debug, 0.2 (3)) was installed and opened on the connected iPhone 13 mini/iOS 27.2. Its normal strict signature and public Google client/callback configuration were verified before installation. No test fixture environment was supplied.

The owner confirmed these manual outcomes:

1. Restore saved connection → Refresh → select the scheduled event showed the intended YouTube channel and “test app 1” with Unlisted visibility inside stream14.
2. Sign out on this iPhone → Restore saved connection did not restore the signed-out account.
3. Connect YouTube again → Revoke Google access → confirm succeeded. The app was left disconnected from Google.

Go Live was left untouched. These checks did not start capture or publish media, and the test event remains available for later use. Before the slot, read-only Firefox inspection showed Unlisted, auto-start Off, auto-stop Off and No data; no Studio setting, key or broadcast state was changed by Codex. Manual tap durations were not measured.

This completes the remaining component acceptance for [#15](https://github.com/smith3v/stream14/issues/15) and [#16](https://github.com/smith3v/stream14/issues/16), now closed with evidence comments; the epic checklist was updated. It does not qualify live account switching, Go Live/End, full-app A3/A6/A9, TestFlight, receiver A/V sync or endurance. The separate [shared-pipeline local smoke](2026-11-08-shared-pipeline-device-smoke.md) has its own source and scope.

A final API preflight identified the required monitor/testing phase, so publishing was held while that correction was implemented and reviewed. The installed `f454e9b` app does not contain that correction. A newly signed corrected candidate and deliberate operator-confirmed test are required before the next broadcast attempt.

Private build/install/launch and configuration checks are recorded in `/private/tmp/stream14-attended-broadcast-preflight.json` and the corresponding `stream14-attended-broadcast-*` logs/JSON. Credentials, stream keys, private identifiers, callback codes and raw API responses are excluded from this report. No recording was deleted.
