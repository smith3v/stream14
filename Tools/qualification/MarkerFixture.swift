import AVFoundation
import Foundation
import ImageIO

/// Generated pixels/PCM only. Never opens a camera, microphone or network.
@main struct MarkerFixture {
    enum Invalid: String, Error { case arguments, writer, sample, addVideo, addAudio, videoWrite, audioWrite, finish }
    static func ready(_ input: AVAssetWriterInput) async throws {
        let deadline = ContinuousClock.now + .seconds(10)
        while !input.isReadyForMoreMediaData {
            guard ContinuousClock.now < deadline else { throw Invalid.writer }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    static func main() async {
        var stage = "arguments"
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            if args.count == 2 && args[0] == "jpeg" {
                guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw Invalid.sample }
                var pixel = [UInt8](repeating: 0, count: 4)
                let mean = try pixel.withUnsafeMutableBytes { bytes -> Double in
                    guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1,
                        bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Invalid.sample }
                    context.interpolationQuality = .high
                    context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                    return Double(bytes[0]) / 255
                }
                print(mean)
                return
            }
            guard args.count == 7, let shift = Double(args[1]), let rate = Double(args[2]),
                  let channels = UInt32(args[3]), let origin = Double(args[4]),
                  abs(shift) <= 0.2, [44_100.0, 48_000.0].contains(rate),
                  [1, 2].contains(channels), origin >= 0, origin <= 3 else { throw Invalid.arguments }
            let variable = args[5] == "variable"
            let markers = args[6] == "markers"
            let url = URL(fileURLWithPath: args[0])
            guard !FileManager.default.fileExists(atPath: url.path) else { throw Invalid.arguments }
            stage = "createWriter"
            let writer = try AVAssetWriter(url: url, fileType: .mp4)
            let video = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 320, AVVideoHeightKey: 180,
                AVVideoCompressionPropertiesKey: [AVVideoAllowFrameReorderingKey: false, AVVideoAverageBitRateKey: 300_000, AVVideoMaxKeyFrameIntervalKey: 30]])
            let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: rate, AVNumberOfChannelsKey: channels, AVEncoderBitRateKey: 96_000])
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 180])
            video.expectsMediaDataInRealTime = true; audio.expectsMediaDataInRealTime = true
            stage = "addInputs"
            guard writer.canAdd(video) else { throw Invalid.addVideo }
            guard writer.canAdd(audio) else { throw Invalid.addAudio }
            writer.add(video); writer.add(audio)
            stage = "startWriting"
            guard writer.startWriting() else { throw Invalid.writer }
            writer.startSession(atSourceTime: .zero)
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate,
                channels: channels, interleaved: true)!
            for frame in 0..<180 {
                stage = "frame\(frame)"
                if !(variable && [40, 125].contains(frame)) {
                var pixel: CVPixelBuffer?
                guard CVPixelBufferCreate(nil, 320, 180, kCVPixelFormatType_32BGRA,
                    [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pixel) == kCVReturnSuccess,
                    let pixel else { throw Invalid.sample }
                CVPixelBufferLockBaseAddress(pixel, [])
                let visible = markers && ((45...46).contains(frame) || (135...136).contains(frame))
                memset(CVPixelBufferGetBaseAddress(pixel), visible ? 240 : 40, CVPixelBufferGetDataSize(pixel))
                CVPixelBufferUnlockBaseAddress(pixel, [])
                try await ready(video)
                guard adaptor.append(pixel, withPresentationTime:
                    CMTime(seconds: origin + Double(frame) / 30, preferredTimescale: 90_000)) else { throw Invalid.videoWrite }
                }
                let first = Int(Double(frame) * rate / 30)
                let count = Int(Double(frame + 1) * rate / 30) - first
                let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(count))!
                pcm.frameLength = UInt32(count)
                let values = pcm.floatChannelData![0]
                for n in 0..<count {
                    let time = Double(first + n) / rate
                    let pulse = markers && [1.5 + shift, 4.5 + shift].contains { time >= $0 && time < $0 + 0.03 }
                    for channel in 0..<Int(channels) {
                        values[n * Int(channels) + channel] = pulse ? Float(0.8 * Double(channel + 1) / Double(channels)) : 0
                    }
                }
                var sample: CMSampleBuffer?
                guard CMAudioSampleBufferCreateWithPacketDescriptions(allocator: nil, dataBuffer: nil,
                    dataReady: false, makeDataReadyCallback: nil, refcon: nil,
                    formatDescription: format.formatDescription, sampleCount: count,
                    presentationTimeStamp: CMTime(seconds: origin + Double(first) / rate, preferredTimescale: Int32(rate)),
                    packetDescriptions: nil, sampleBufferOut: &sample) == noErr,
                    let sample,
                    CMSampleBufferSetDataBufferFromAudioBufferList(sample, blockBufferAllocator: nil,
                        blockBufferMemoryAllocator: nil, flags: 0, bufferList: pcm.audioBufferList) == noErr else { throw Invalid.sample }
                try await ready(audio)
                guard audio.append(sample) else { throw Invalid.audioWrite }

            }
            video.markAsFinished()
            audio.markAsFinished()
            stage = "finish"
            await writer.finishWriting()
            guard writer.status == .completed else { throw Invalid.finish }
            print("syntheticMarkerFixtureCreated")
        } catch {
            FileHandle.standardError.write(Data(("syntheticMarkerFixtureUnavailable:" + (error as? Invalid ?? .writer).rawValue + ":" + stage + "\n").utf8)); exit(1)
        }
    }
}
