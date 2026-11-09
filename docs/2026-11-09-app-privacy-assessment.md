# Full-app App Privacy assessment

Checked: 2026-11-09. Scope: merged main `32996c0`, app archive source
`1ae3f87`, 0.3 (4), GoogleSignIn 10.1.0. This is a proposed assessment, not
saved App Store Connect answers, a public submission or observed phone telemetry.
Root observed App Privacy still at Get Started, with no policy URL or published
answers. It did not show a prior Data Not Collected declaration.

## Distribution boundary

Apple's [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
requires an iOS privacy-policy URL and describes the data questionnaire for App
Store distribution. Its [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
and [beta-information guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/)
describe a separate beta workflow. These references do not establish a public
App Privacy questionnaire prerequisite for the existing internal group. Do not
block that beta on an invented public-submission gate; satisfy actual validation,
privacy-policy/beta fields and export requirements encountered during delivery.
Public App Store submission remains outside this internal-delivery step.

Use the verified public [privacy-policy URL](https://github.com/smith3v/stream14/blob/main/docs/privacy.md).
Its deletion/revocation section also provides a possible optional Privacy Choices
URL. Do not press Publish for the public questionnaire without resolving the
remaining assessment and its actual confirmation step.

## Evidence and proposed categories

Organizer generated an aggregate report from the exact signed archive. Private
artifacts: `/private/tmp/stream14-0.3-aggregate-privacy-report` (PDF without an
extension), its `.txt` extraction, and
`/private/tmp/stream14-03-manifest-audit.json`. Nine bundled manifests were
inspected. The following eight rows reproduce the **GoogleSignIn manifest's
claims**, not independent observations of every field being transmitted in every
sign-in. All eight declare linked-to-user true and tracking false.

| Proposed SDK baseline category | Manifest purposes |
| --- | --- |
| Name | App Functionality |
| Email Address | App Functionality |
| Phone Number | App Functionality |
| Coarse Location | App Functionality |
| User ID | App Functionality, Analytics |
| Device ID | Analytics |
| Other Usage Data | Analytics |
| Other Data Types | App Functionality, Analytics |

Google's [iOS SDK disclosure page](https://developers.google.com/identity/sign-in/ios/app-privacy)
(last updated 2025-05-19 when checked) describes possible user-ID collection for
OAuth grants and IP-based approximate location for fraud prevention. It is narrower
than the shipped manifest. Carry the exact manifest baseline into the proposed
answers; obtain version-specific provider evidence before omitting a declared
category or purpose. Do not claim stream14 itself reads phone numbers or runs an
analytics service. The app's [authorization adapter](../Stream14/YouTube/GoogleAuthorizationDriver.swift)
maps only SDK user ID and granted scopes; SDK-owned profile/token processing is a
separate boundary. The GoogleSignIn checkout was
`bfaebbc04a4d13ed7a89b0fc1fb8ad66b362cc1c`.

The aggregate is not a whole-app network inventory. Add these source-supported
flows when preparing the complete questionnaire:

| Flow | Proposed assessment and evidence |
| --- | --- |
| Confirmed YouTube camera/video and microphone upload | Photos or Videos and Audio Data; App Functionality; linked to the authenticated channel. The [publisher](../Stream14/Media/RTMPSPublisher.swift) sends composed encoded media to the selected YouTube ingest. This is an inference for the label from the actual feature and Google's retained-content processing, not a field emitted by the SDK manifest. |
| YouTube account/event control | User ID already included above. Channel, broadcast and stream IDs are used in authenticated requests by the [client](../Stream14/YouTube/YouTubeClient.swift); use App Functionality and linked-to-user. Server-side event/request metadata not otherwise represented needs assessment under Other Data Types rather than claiming a second category solely for locally stored IDs. |
| Overlay website traffic | [WebOverlayRenderer](../Stream14/Media/WebOverlayRenderer.swift) loads chosen HTTPS pages/resources in nonpersistent WebKit. Source proves requests, not a particular site's retention, analytics or tracking. Assess the actual supplied/reference provider before final public answers; no generic assertion of anonymous traffic or open-web-browser exemption. |
| Local originals, recovery copies and numeric reports | Local storage alone adds no off-device collection category. Deliberate exports must be assessed for their actual destination; there is no automatic developer report/media upload. See [privacy](privacy.md) and [qualification contract](2026-11-08-f12-qualification-handoff.md). |

Google's [privacy policy](https://policies.google.com/privacy) describes uploaded
content and service connection/activity processing, including storage and uses
that depend on product/settings. It supports including direct media uploads;
it does not prove every general Google data use applies to each stream14 request.

## Proposed answers and remaining limits

Propose **Yes, collection occurs**, including partner processing; do not copy the
app-only empty collected-data array into a No answer. The SDK baseline above is
linked and not used for tracking according to its manifest. Source has no app
advertising, advertising-ID request or developer analytics endpoint. This does
not independently establish the tracking/purpose answers for every operator-chosen
overlay provider or every Google service use. Resolve those specific provider
flows before public questionnaire publication; do not add permissions or infer
cross-app tracking from Analytics alone.

Apple's [data-label guidance](https://developer.apple.com/app-store/app-privacy-details/)
includes partner data retained beyond a real-time request, excludes on-device-only
processing, and requires web-view traffic assessment. Optional consent alone does
not exempt this app's primary broadcasting function. Thus a local-only rehearsal
choice does not remove the account-enabled/upload categories from a full-app
label. No health/contact-list/payment categories are inferred from arbitrary
spoken or filmed content.

Before publishing public answers: reconcile the SDK version-specific discrepancy,
review the actual overlay and retained YouTube service flows, finalize category/
purpose/linkage/tracking choices, and inspect the product-page preview. Preserve
all declared SDK categories unless supported evidence justifies a change. Keep
internal TestFlight availability, exact-device installation and A1–A9 acceptance
separate. No app, manifest, account setting, provider call or phone operation was
changed by this assessment.
