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
