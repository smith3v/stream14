# Offline A/V Marker Inspector Implementation Plan

**Goal:** Provide a private native workflow to inspect physical start/end markers and calculate conservative audio-minus-video offset intervals.

**Architecture:** A standalone Swift CLI decodes two bounded windows and writes timestamped frame/waveform artifacts to a newly created private directory. A separate measurement command accepts explicit human-selected brackets and reports numeric intervals without recognizing markers or declaring a qualification pass.

**Tech Stack:** Swift 6, Foundation, AVFoundation, Core Image, CryptoKit; Python standard library for deterministic validation.

---

### Task 1: Implement bounded private inspection

**Prompt:**
Create `Tools/qualification/Markers.swift`. Parse exactly two finite, ordered,
nonoverlapping windows of at most two seconds. Stream decoded BGRA video and
interleaved Float32 PCM using actual CMSampleBuffer presentation times. Export
timestamped JPEGs, per-channel one-millisecond waveform bins and a local contact
sheet/manifest. Reject missing tracks, invalid or non-increasing timestamps,
unsupported/excessive dimensions, channels, sample rates or output counts. Hash
the input before/after, reject symlink/nonregular inputs and existing output
directories, create owner-only outputs, and emit only fixed safe failure codes.
Never change/delete the original or log source paths/SDK error descriptions.

### Task 2: Implement explicit bracket arithmetic

**Prompt:**
Add a `measure` command to the same tool. Accept only a typed selection JSON with
one selected audio channel and visual/audio brackets for each named window.
Validate finite ordered brackets against extracted frame timestamps and PCM
coverage. Calculate `[audioLower-videoUpper,audioUpper-videoLower]`, midpoint and
half-range uncertainty. Record missing markers explicitly; do not infer a clap,
correct propagation/priming or return a physical qualification verdict.

### Task 3: Validate with independent generated media

**Prompt:**
Create `Tools/qualification/MarkerFixture.swift` using AVAssetWriter to generate
small H.264/AAC files with two visible/tone markers, positive/negative shifts,
nonzero session starts, varied video cadence, mono/stereo and 44.1/48 kHz audio.
Create `Tools/qualification/verify-markers.py` to compile/run the tools in private
temporary paths and verify actual extracted PTS, waveform sample-derived bounds,
signed interval arithmetic, invalid selections/windows, missing/unreadable media,
safe failure text, private permissions and unchanged input hashes. Do not interpret
synthetic success as physical clap measurement. Retain validation artifacts privately.

### Task 4: Document and independently review

**Prompt:**
Update `docs/qualification-report-template.md`, the specification's F12 section
and `docs/ios-development-guide.md` with exact native compilation/inspection and
manual bracket workflow. Include sample-rate/frame uncertainty, ambiguous markers,
acoustic distance, separate original/receiver results and five-minute phone scope.
Run focused native fixture checks, document exact results/limits, check changed
local links and `git diff --check`, and commit a focused branch into main.
Have a new independent agent inspect the actual full diff and validation artifacts;
fix material findings and rerun affected checks before PR handoff. Never merge,
record camera media or upload TestFlight as part of this stage.

## Validation checkpoint

Native Swift 6 optimized compilation of both tools passed on the installed Xcode
27.2/macOS 27.2 SDK. Existing synchronous AVFoundation reader/writer APIs emit
SDK deprecation warnings; they remain public APIs. No package, Xcode project or
app binary changed. The generated fixture uses the repository's established
pixel-buffer adaptor and real-time writer-input pattern, interleaving synthetic
video and PCM. An earlier sandboxed AAC input check was unavailable; native codec
services were required. Initial experimental raw-video/non-real-time fixture
construction stalled at its bounded readiness deadline and was not counted as a
pass. All those processes exited and were reaped before later runs.

Final focused native result: **91 checks passed, three generated H.264/AAC
fixtures, exit 0, 3.328 seconds**. Private artifacts are retained at
`/private/tmp/stream14-marker-validation-final`; invocation outcome is
`/private/tmp/stream14-marker-validation-final-outcome.json`. The checks include:

- Positive 80 ms audio shift, stereo 44.1 kHz, fixed 30 Hz video.
- Negative 80 ms shift, mono 48 kHz, nonzero two-second track start and deliberately
  missing video frames; extracted PTS retain both the start and variable cadence.
- Missing physical-marker equivalents (quiet generated PCM and unchanged pixels)
  remain pending rather than fabricating an offset.
- Independent native JPEG reads confirm extracted dark/contact frames correspond
  to their actual labeled PTS. Decoded AAC onset falls in sample-derived waveform
  bins containing the known synthetic onset, without a guessed priming correction.
- Signed conservative arithmetic, uncertainty, frame/channel/window validation,
  zero-width/reversed/out-of-PCM selections, nonexistent/truncated/symlink inputs,
  fixed safe errors, owner-only output permissions and unchanged original hashes.
  Existing output directories and sentinels remain untouched.

For the positive fixture the beginning/end offset intervals are approximately
`[79.592,113.923]` ms; for the negative fixture they are approximately
`[-80.292,-45.979]` and `[-80.167,-45.854]` ms. Each contains its known synthetic
offset. The positive interval crosses +100 ms: the tool still emits no pass or
failure verdict. A reviewer must retain that uncertainty. These are generated
tooling checks, not physical clap, YouTube, app performance or endurance evidence.

Reproduce using normal macOS media/codec access and a fresh private destination:

```sh
xcrun swiftc -O -swift-version 6 -module-cache-path /private/tmp/stream14-marker-cache \
  -parse-as-library Tools/qualification/Markers.swift -o /private/tmp/stream14-markers
xcrun swiftc -O -swift-version 6 -module-cache-path /private/tmp/stream14-marker-cache \
  -parse-as-library Tools/qualification/MarkerFixture.swift -o /private/tmp/stream14-marker-fixture
python3 Tools/qualification/verify-markers.py /private/tmp/stream14-markers \
  /private/tmp/stream14-marker-fixture /private/tmp/a-new-private-marker-validation
```

All 60 local links in the five changed design/guide/report documents resolve,
Markdown fences and Python syntax pass, and `git diff --check` passes. No user
original, phone, camera, microphone, provider API, simulator or TestFlight operation
occurred. Physical start/end marker measurements and issue #25/#27 acceptance
remain pending. Independent actual full-diff review is required before publication.
