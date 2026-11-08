# Private RTMPS Receiver Validation Implementation Plan

**Goal:** Measure actual shared encoder → acknowledged RTMPS socket → independent receiver → native decode, entirely on the laptop, and prepare a bounded later phone check.

**Architecture:** An opt-in hosted test generates finite synthetic BGRA/PCM through the production SharedMediaEncoder, SharedMediaDestinations, LocalRecorder, RTMPSPublisher and RTMPSConnection. A pinned standalone MediaMTX receives normal TLS and records compressed H264/AAC to fMP4. Native AVFoundation independently decodes the received and local originals. A short-lived local CA is trusted only by a disposable Simulator; production trust policy is unchanged.

**Tech Stack:** Swift 6, Swift Testing, AVFoundation, VideoToolbox, existing pinned RTMPHaishinKit fork, OpenSSL, MediaMTX v1.21.3 test executable (MIT; no app linkage).

---

### Task 1: Select and isolate the receiver

**Prompt:** Compare existing Docker receiver, native standalone receiver and custom RTMP parser. Prefer the official standalone MediaMTX: Docker daemon and ffmpeg/nginx are unavailable; implementing RTMP would weaken independent protocol evidence and increase scope. Download the Darwin arm64 release into private temporary storage and verify its published SHA256. Keep executable, private keys, certificates, logs and generated media outside Git. Disable all nonessential listeners, bind RTMPS to loopback, disable automatic recording deletion, and use only a public synthetic fixture path. Record exact version/hash and official sources.

### Task 2: Add an opt-in finite production-path fixture

**Prompt:** Add Stream14Tests/PrivateRTMPSReceiverTests.swift. Require explicit environment opt-in and a loopback-only destination; never accept YouTube destinations. Generate a short dark/bright video and silence/tone audio with a known common epoch and midpoint. Feed the real SharedMediaEncoder and independently attach the local recorder and actual RTMPSConnection through RTMPSPublisher. Drain acknowledged sends with a bounded timeout before stopping transport. Keep source/local/receiver files privately. Assert no encoder/upload failures, bounded queues, complete local file, expected sample formats, strict ordering and decoded midpoint offset. Do not use legacy DualOutputFeasibility's two encoder path or Void append acceptance.

### Task 3: Exercise real TLS and receiver decode

**Prompt:** Use a disposable Simulator only after the active F8 simulator lease is released. Create a one-day private CA/server certificate with localhost SAN; add its root only to that Simulator. First verify normal untrusted TLS fails; then trust and run the finite test. Receiver finalizes fMP4 on disconnect. Decode it with AVAssetReader to BGRA/PCM, check H264/AAC formats, dimensions, monotonic samples, marker correspondence/common origin and duration. Preserve originals. Add reconnect and transport interruption/file independence only where the same fixture remains bounded and assertions provide real receiver evidence; record incomplete cases honestly. Never change host trust or production validation.

### Task 4: Prepare later phone use and review

**Prompt:** Document an explicit opt-in five-minute TOTAL phone slot with preparation completed beforehand, owner-approved local network/TLS trust setup, recording start, short controlled transport interruption/recovery, finalization and private original-file retrieval. No phone execution now. This synthetic laptop test cannot qualify camera/compositor, hardware performance, memory/thermal stability, measured physical A/V sync, YouTube interoperability or long-run gates. Run git diff --check and appropriate native tests/build, inspect the full diff against main with an independent reviewer, resolve material findings and commit. Parent coordinates PR publication and independent review; do not merge or publish from this stage.

## Sources and scope

- [Official MediaMTX RTMP TLS configuration](https://mediamtx.org/docs/features/rtmp-specific-features)
- [Official receiver fMP4 recording documentation](https://mediamtx.org/docs/features/record)
- [Pinned release](https://github.com/bluenviron/mediamtx/releases/tag/v1.21.3)

This is a supplemental F6/issue #19 and missing F1 receiver-evidence stage. It does not pass physical acceptance gates or authorize production fork adoption.
