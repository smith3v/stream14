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
| App Store Connect inventory | Read-only check reached an expired Apple sign-in session; latest uploaded/processing versions and builds were unavailable. No settings or credentials were entered |
| Independent review | Initial review identified retention and Restore cleanup issues; corrected to preserve transient failures and expire IDs safely. Final combined-source review is pending |

Hosted fixtures use invented credentials/IDs, synthetic media and local WebKit
checks; no real Google/YouTube calls or physical camera actions were performed.
Native media fixture QoS warnings remain observations, not evidence of physical
performance. The UI scope preserves the F10 documented clipped-static-text audit
allowance; it does not establish physical VoiceOver acceptance. Earlier failing
UI fixture/popover assumptions and the restore-wiring regression were corrected
before the final passing combined checks. Final source normally inherited the
main-ancestry-only F11 update after native/archive checks; that merge changed no
file bytes. The later combined UI passed on that inherited source.

## Delivery and acceptance still pending

- Verify live App Store Connect inventory after owner sign-in. If the historical
  0.2 (3) remains latest, 0.3 (4) is a proposal, not a reserved or committed identity.
  Increment marketing minor for newly merged main changes and keep build numbers
  increasing; check all existing/processing uploads first.
- Resolve final independent review, publish the reviewed policy/support/terms and
  verify the exact signed-out public URLs used by the candidate.
- Configure the actual public OAuth client/callback outside Git and build the
  normally signed archive. Inspect its aggregate privacy report, purpose strings,
  linked code/SDK manifests/notices and final export-compliance questions. Current
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
