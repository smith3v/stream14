# F9 interruption and same-event resume handoff

Issue [#22](https://github.com/smith3v/stream14/issues/22), part of epic #13.
Branch `codex/issue-22-session-interruptions`, isolated clone
`/private/tmp/stream14-epic13-f9-interruptions`. Normal merge ancestry includes
reviewed F8 `20a0035`. Runtime checkpoint `75d7b92`; additional test-only End
interruption regression `859f6b0`. No PR publication/merge or issue closure by this
stage agent. Root coordinates the reviewed stacked PR.

## Result and ownership

- `MediaSession.interrupt(_:)` synchronously reports background, camera/audio,
  capture/encoder failure, critical heat or microphone-input loss to the existing
  `BroadcastSession`. Callback cancels startup/F8 and invalidates late results;
  no remote Complete is sent during interruption.
- Media ownership immediately detaches/stops publisher even while file control is
  busy, finalizes retained writing, cleans up capture and restores prior idle
  state. Early permission cancellation also runs cleanup even after phase idle.
  Background expiry immediately saves failed metadata and restores idle ownership;
  late finalization cannot claim completion. Writer finish waits at most five
  seconds; a timeout retains the original for inspection. No cancelWriting/delete,
  post-export transcode, extra camera or encoder is introduced.
- Serious thermal state changes only overlay cadence to three seconds. Critical
  heat interrupts; no silent profile change or warning sound.
- `backgroundTimeExpired()`, `applyThermalState(_:)` and DEBUG media fixtures allow
  deterministic policy/cleanup verification without actual camera or heating.
- `BroadcastSession.foregroundReturned()` does read-only reconciliation only for
  interrupted context. Transient inactive/active changes preserve healthy F8.
  `canResume`/`requestResumeConfirmation()` require resolved mutation barriers,
  original nonsecret profile/binding, explicitly reopened healthy preview and
  overlay, then new title/visibility confirmation. Confirmed resume starts a new
  local writer/UUID/timeline before upload.
- `YouTubeBinding.prepareResumeConfirmed` reads the same event and original
  dedicated inactive bound stream. It performs no insert/bind. Live is observed
  without another Live POST. Completed, replaced, active-ingestion, wrong-profile
  or ambiguous contexts fail closed. Unknown Complete cannot authorize resume.
- Optional journal fields `interrupted`, `streamID`, `profileName` preserve admitted
  context across relaunch. Old journals decode without them but cannot authorize
  resume. Credentials, overlay URL and user metadata remain absent.
- Append/finalization/status-save failure leaves healthy admitted upload running;
  `MediaSession.backupWarning` persists independently of media/upload/remote labels.
  Initial writer-admission failure still prevents publication.
- SetupView/controls expose persistent warning and explicit Resume action; active
  foreground reads never open capture or publish. F10 owns further interface work.

## Verification

Xcode native tools, iOS Simulator 27.2, simulator
`D6BEAF78-D273-4952-8349-B50B2824E6A9`. No physical device or live service was used.

Final runtime `75d7b92` full hosted regression: **147 total, 140 passes, seven
physical-only skips, zero failures**. Includes five actual MediaSession fixtures:
permission-cancellation cleanup, serious/critical thermal policy, all seven
interruption reasons with busy/repeated stops, native append/finalization failures
preserving publisher and original file, and background expiry with both prior idle
states and conservative late-finalization metadata.

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 \
  -destination 'platform=iOS Simulator,id=D6BEAF78-D273-4952-8349-B50B2824E6A9' \
  -derivedDataPath /private/tmp/stream14-f9-tests \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages \
  -disableAutomaticPackageResolution -only-testing:Stream14Tests test
```

Private log `/private/tmp/stream14-f9-regression.log`; result
`/private/tmp/stream14-f9-tests/Logs/Test/Test-Stream14-2026.11.08_14-07-43-+0100.xcresult`.

Additional test-only `859f6b0` covers interruption during an unsettled End: retains
Complete barrier, dispatches no second mutation and clears only after terminal
read. Affected coordinator suite **37 passes, zero skips/failures** using the same
command with `-only-testing:Stream14Tests/BroadcastSessionTests`. Log
`/private/tmp/stream14-f9-end-regression.log`. That suite also covers held late
startup/reconnect results, explicit fresh-writer same-event resume, relaunch,
changed/terminal/active bindings, profile mismatch and ambiguous Live mutation.

Unsigned native generic-iOS Release build passed:

```sh
xcodebuild -project Stream14.xcodeproj -scheme Stream14 -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/stream14-f9-release \
  -clonedSourcePackagesDirPath /private/tmp/stream14-f7-packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

Log `/private/tmp/stream14-f9-release.log`. `git diff --check` passed. The first
coordinator run had one old assertion expecting upcoming journal context to clear;
it was updated to the explicit same-event resume barrier and final runs pass.

## Independent review and remaining acceptance

A separate reviewer inspected actual final files, stage delta against `20a0035`
and cumulative main diff. One material early-permission cleanup issue was fixed
with the regression above; focused re-review at `75d7b92` found no remaining
material findings. Test-only End-barrier addition is included in final review.

Physical Home/lock/audio interruption, microphone route loss, real heat/system
pressure, new resumed-file/receiver continuity, permission and idle-timer behavior
on the 13 mini remain required acceptance evidence. No simulated thermal decision
is real thermal evidence. F9 does not establish three-hour stability, exact A/V
sync, crash recovery, real event resume or TestFlight delivery. Keep issue #22 open
until its acceptance evidence is complete. No long run is authorized here; routine
phone work remains five minutes total and longer qualification needs agreement.
