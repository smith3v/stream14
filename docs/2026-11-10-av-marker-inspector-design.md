# Offline physical A/V marker inspection

The aggregate analyzer proves readable tracks and reports their timing; it cannot
identify a physical clap. Add a separate native Mac tool for an operator to inspect
two short windows in a retained original or independent receiver movie. This is
laptop work after a separately authorized recording, outside the phone visit.

Use AVFoundation decoded presentation timestamps, not a requested seek time, track
endpoints or an assumed AAC correction. Write every decoded video frame in the
requested windows, a private contact sheet and a per-channel waveform whose bins
retain their actual sample-derived timestamp bounds. Bound each window to two
seconds and reject excessive frame/channel/rate counts. Decode one sample buffer
at a time. Inputs remain read-only and are SHA-256 checked before and after.
Outputs go only in a new private directory; never reuse or empty an existing one.

The operator identifies the last clearly separated-hand frame and first contact
frame as a visual bracket `[v0,v1]`, and brackets the associated audio transient
as `[a0,a1]`. A second command validates these selections against the inspection
manifest and reports signed audio-minus-video interval `[a0-v1,a1-v0]`.
Positive means audio later. It does not recognize a clap, select a channel, remove
acoustic propagation delay or assign an automatic pass. Missing/ambiguous markers
remain pending. A reported interval wholly within ±100 ms can support only that
specific reviewed marker check; physical beginning/end, receiver/original and
long-run evidence remain separate.

This native inspector is smaller than automatic physical-clap detection and needs
no third-party editor or dependency. It changes no app runtime, codec, capture,
transport, diagnostics schema or TestFlight delivery. Generated H.264/AAC fixtures
validate timestamp extraction and arithmetic, not physical synchronization.
