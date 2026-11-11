# stream14 beta privacy

Effective: 2026-11-09. This policy covers the full-app 0.3 (4) beta, including local
recording, optional Google authorization, and explicitly confirmed YouTube
broadcasting. It is available through the existing internal TestFlight group, and
the owner confirmed installation. Current-build regression and physical
qualification remain pending. The historical 0.2 (3) local-only beta has no
Google/YouTube features. stream14 uses YouTube API Services;
see the [service terms](terms.md) and [YouTube Terms of Service](https://www.youtube.com/t/terms).

## Camera, microphone and local files

stream14 requests camera and microphone permission when you open the camera to
prepare recording. It saves camera video, microphone audio and the visible web
overlay in MP4 files on your iPhone. Recording metadata includes creation time,
completion/failure state and writer frame/drop measurements. These files stay in
the app's container, excluded from device backup. The developer does not receive
your recordings or metadata automatically. No Photos permission is requested.

You choose whether to export an original recording through Apple's share interface.
The selected destination or recipient then handles that copy under its own policies.
Recovery is an explicit attempt to remux readable fragments to a separate local
copy. The original remains, including if recovery fails. A readable start is not
proof of complete-file integrity. New recordings also have bounded numeric
qualification checkpoints: elapsed/sample timing, codec/profile, per-output
admissions and drop/queue observations, thermal state, and supported memory
observations. A checkpoint may be incomplete after termination. Reports contain
no account/event identifiers, URLs, tokens or raw media. Reports remain local and
are excluded from backup; export is a deliberate action separate from media export.

Confirmed deletion removes the selected recording/copy and its associated local
metadata/review/qualification files. A group deletion names the affected originals
and recovery copies before confirmation. Exported copies remain where you saved them. Deleting the
app removes its local recordings; export anything you want to keep first.

## Web overlays and network requests

Applying an overlay URL contacts the HTTPS address you choose and any
resources requested by its webpage. The reference-overlay button selects a public
webpage; Apply URL saves it and starts requests while the app is active. A saved
overlay also resumes requests when the app becomes active. The website and its providers can receive ordinary
web-request information, including your IP address, requested URL and browser
information. URLs can contain private tokens: choose trusted services and do not
post such URLs in public reports. The website's own privacy policy applies to its
handling of those requests. stream14 does not upload camera/microphone recordings
to the overlay website and denies webpage camera, microphone, location and motion
permission requests.

The complete configured URL is saved in this iPhone's device-only Keychain and is
accessible to the app while unlocked. WebKit uses a nonpersistent website data
store. No native credentials or media access are exposed to webpage JavaScript.
Applying an empty URL removes the saved URL and disables the overlay.

## Optional Google and YouTube authorization

Connect YouTube opens Google's supported system-browser authorization through the
Google Sign-In SDK. Google receives authorization requests and handles account
selection, consent and token services under its [privacy policy](https://policies.google.com/privacy).
The app requests YouTube access to read and manage the selected broadcast;
connecting alone never uploads camera or microphone media. Before Connect or
Restore, you must explicitly agree to this privacy policy and the linked service/
YouTube terms. Only that nonsecret policy-version choice is saved in app-only
UserDefaults; local rehearsal does not require YouTube agreement. Without Google setup,
local recording remains available and no Google authorization request is made.

The 0.3 (4) build distributed through TestFlight on November 9, 2026 restores
saved sign-in only when you choose **Restore saved connection**. In builds with
automatic restore, after you have agreed and signed in, the app can try to restore
your saved Google sign-in once per launch when the app becomes active and YouTube
is configured. The Google Sign-In SDK may contact Google to refresh authorization
tokens. After a successful restore, the app may send read-only requests to
YouTube to check the status of a previously interrupted broadcast session. Event
selection and starting a broadcast still require your action. If automatic
restore fails, try **Restore saved connection** or sign in again with
**Connect YouTube**.

The SDK stores its credentials in the iPhone Keychain. stream14 does not copy them
to preferences, files, an app backend or overlay JavaScript. A fresh access token
is held in memory only for authorized API use. **Sign out on this iPhone** clears
the saved SDK session used for automatic restore. **Revoke Google access** also
requests revocation from Google. If revocation fails, the app says so and you can
review access in your Google Account.
Local sign-out clears in-memory account/channel/event readiness but retains pending
request journals for safe reconciliation; it is distinct from data deletion.
Revoke additionally deletes saved YouTube API data on this iPhone, even if the
remote revoke request fails. Local recordings and overlay settings remain. When you explicitly refresh scheduled events,
the app sends authorized read requests directly to YouTube and holds channel/event
metadata in memory for selection. It does not save raw API responses or ingestion
keys, and selecting an event alone does not publish or change it.

The broadcast-preparation component keeps a small local request journal
containing channel, event and any created stream identifiers, the chosen media
profile and request phase. This prevents duplicate stream creation after a network
error or app restart. The journal is excluded from backups and contains no Google
token, ingestion address or stream key. Ordinary sign-out hides account-dependent state
but retains this duplicate-prevention record; an unresolved creation requires
checking YouTube Studio before another stream can be created. Preparation is used
only from the confirmed Go Live flow, not from listing or selecting events.

## Confirmed YouTube broadcasting

After you confirm Go Live for the displayed channel, event and visibility, the app
may create a dedicated ingestion stream and bind it to that event. It sends the
composed camera video, microphone audio and visible overlay directly to YouTube
over RTMPS. Google receives and processes that media and ordinary connection
information under its privacy policy and YouTube terms. The selected event's
visibility controls the intended audience; an auto-start event may become visible
as soon as the confirmed upload begins. The developer does not operate a media
relay or receive a copy automatically. A local original is kept independently
while capture and writing are healthy. No remote media is sent merely by opening
the app, restoring authorization, selecting an event or previewing the camera.

Ingestion credentials remain in memory for upload and are not saved in the app's
request journals or exposed to the overlay website. The app reads stream and
broadcast status and sends live/complete transitions only as part of confirmed
operator actions. End stops local capture/output independently of remote API
success. If the app cannot confirm YouTube ended the event, it reports that
uncertainty and offers YouTube Studio; the local recording remains on the phone.

A separate protected, backup-excluded pending-session journal stores unresolved
channel/event IDs and any outstanding transition type/operation ID. It contains
no Google token, stream key, ingestion address, event title or overlay URL. It
prevents a relaunch or unknown transition from silently starting another upload.
Ordinary sign-out retains this reconciliation record. Reconciliation on relaunch
is read-only. An ambiguous mutation is not erased merely because an immediate
read still reports an upcoming event.

### Deleting YouTube data and revoking access

Choose **Delete saved YouTube data** and confirm while YouTube activity is stopped.
This signs out locally and removes saved channel/event/stream identifiers from both
journals, plus in-memory API readiness. It preserves local recordings, recovery
copies, their private numeric diagnostics, overlay settings and the policy choice.
It sends no remote delete/End request and does not delete YouTube videos or revoke
Google consent. Manage remote events/media in YouTube Studio.

Revoke Google access also requests SDK-managed remote revocation. You can revoke
access directly in [Google Account security settings](https://security.google.com/settings/security/permissions).
The app cannot observe external revocation while offline or unused. When the SDK explicitly reports invalid authorization, token refresh confirms an expired/invalid grant,
or the API rejects authorization, the app clears saved API data and stops upload
while healthy local recording can continue. An unknown/offline restore or token-refresh failure
retains nonexpired journals for exact-event reconciliation and permits a safe retry;
it does not establish revocation. A storage failure is reported and publishing remains blocked; retry
local deletion after resolving storage.

Before deleting identifiers for prior or in-flight requests, the app saves a nonidentifying **Studio resolution
required** marker. The marker contains no account, event, stream, operation ID or
timestamp. It survives relaunch and blocks publishing/late journal writes so an
unknown remote mutation cannot be repeated blindly. Resolve previous event/stream
requests in Studio, then explicitly confirm that resolution in the app; this
removes the marker without a remote request. An outstanding mutation must settle
before confirmation is allowed. Deletion never silently permits another Go Live.
Ordinary successful End/terminal reconciliation clears the pending-session journal;
binding history remains until explicit deletion, confirmed access-loss cleanup or
expiry. Both journals keep acquisition timestamps and are checked on app launch,
activation and journal use. Identifiers expire at 30 days; phase updates do not
renew that age. Undated legacy records or a future timestamp are treated as stale.
Before erasure the app saves the same nonidentifying guard, preserving safety.
There is no promised background task: if the app remains unused, cleanup occurs
when it next launches/activates. A failed cleanup remains blocked and is retried.
Newly obtained contexts have new timestamps; this beta does not silently renew
old API identifiers merely by re-saving them.

GoogleSignIn 10.1.0's bundled privacy manifest declares Google-side account/contact,
coarse location, user/device identifiers and usage/other data for app functionality
and some analytics purposes, with tracking declared false. The SDK's included
AppCheckCore and GoogleUtilities products are required dependencies; stream14
adds no separate analytics or crash SDK and does not configure optional App Check
attestation. Review Google's disclosures and the aggregate archive privacy report
before distributing a build with accounts enabled. Provider processing is distinct
from collection by the stream14 developer.

## Developer collection and Apple beta services

stream14 has no developer-operated collection backend, advertising, analytics or
third-party crash-reporting SDK. The app does not track you across apps or websites.
It uses HaishinKit and Logboard locally for media processing and local diagnostic
logging. The app privacy manifest declares elapsed-time calculations for overlay
freshness, app-container file metadata for safe deletion, and app-only UserDefaults
for the selected nonsecret session profile. These are not used for
fingerprinting or sent to the developer by stream14.

Apple operates TestFlight and may provide beta feedback and crash information under
Apple's terms and your settings. If you voluntarily send feedback or attach files,
the developer receives what you submit. Do not include private recordings or
secret-bearing overlay URLs in public GitHub issues.

## Questions and changes

Use the [support instructions](support.md) for privacy questions or problems. This
policy must be reviewed before changing broadcasting, accounts, telemetry or other
new data flows. The source-code license is separate from this privacy policy.
