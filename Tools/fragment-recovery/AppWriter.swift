import AVFoundation

// Standalone input generator for the production SharedMediaCodec + LocalRecorder.
// The build script copies those production bodies unchanged into the probe build.
nonisolated enum AppWriter {
    static func write(_ url: URL, mode: String) async throws {
        let profile = SessionProfile.fullHD
        let recorder = LocalRecorder()
        try recorder.start(url, profile: profile)
        let codec = try SharedMediaCodec(profile: profile)
        let seconds = mode == "before" ? 5 : 25
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        for frame in 0..<(seconds * 30) {
            var pixel: CVPixelBuffer?
            try Probe.check(CVPixelBufferCreate(nil, profile.width, profile.height, kCVPixelFormatType_32BGRA,
                [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pixel) == kCVReturnSuccess, "pixel")
            let image = pixel!
            CVPixelBufferLockBaseAddress(image, [])
            memset(CVPixelBufferGetBaseAddress(image), Int32(frame % 255), CVPixelBufferGetDataSize(image))
            CVPixelBufferUnlockBaseAddress(image, [])
            var description: CMVideoFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: image, formatDescriptionOut: &description)
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                presentationTimeStamp: CMTime(value: Int64(frame + 30), timescale: 30), decodeTimeStamp: .invalid)
            var sample: CMSampleBuffer?
            try Probe.check(CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: image,
                formatDescription: description!, sampleTiming: &timing, sampleBufferOut: &sample) == noErr, "video")
            for packet in try codec.append(sample!) { recorder.append(packet) }
            let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1470)!
            pcm.frameLength = 1470
            for channel in 0..<2 { for n in 0..<1470 {
                pcm.floatChannelData![channel][n] = Float(sin(Double(frame * 1470 + n) * 2 * .pi * 440 / 44_100)) * 0.1
            }}
            let audio = LocalRecorder.audioSample(pcm, when: AVAudioTime(hostTime:
                AVAudioTime.hostTime(forSeconds: Double(frame + 30) / 30)))!
            for packet in try codec.append(audio) { recorder.append(packet) }
            try await Task.sleep(for: .milliseconds(34))
            try Probe.check(recorder.hasStarted || frame < 5, "production writer stopped")
        }
        for packet in try codec.finish() { recorder.append(packet) }
        Probe.emit(["checkpoint": "appended", "seconds": seconds])
        if mode == "before" || mode == "after" {
            try await Task.sleep(for: .milliseconds(500))
            Probe.emit(["checkpoint": "kill-ready"])
            try await Task.sleep(for: .seconds(30))
            return
        }
        // For this production path this is a finish request race, not proof that
        // finishWriting has entered; report it separately from post-fragment kills.
        if mode == "finalize" { Probe.emit(["checkpoint": "finish-started"]) }
        _ = try await recorder.finish()
        Probe.emit(["checkpoint": "finish-completed"])
        Probe.emit(["checkpoint": "normal-complete"])
    }
}
