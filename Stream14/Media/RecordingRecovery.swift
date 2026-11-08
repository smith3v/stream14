import AVFoundation

/// Native inspection/remux only. Actor ownership keeps file/reader work off the UI.
actor RecordingRecovery {
    struct Inspection: Sendable { let duration: Double }
    enum Failure: Error { case unreadable, exportUnavailable }

    /// Decode one sample from each track to establish a readable start. This is
    /// deliberately not a full-duration integrity or A/V synchronization claim.
    func inspect(_ url: URL) async throws -> Inspection {
        try Task.checkCancellation()
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw Failure.unreadable }
        for mediaType in [AVMediaType.video, .audio] {
            let tracks = try await asset.loadTracks(withMediaType: mediaType)
            guard let track = tracks.first else { throw Failure.unreadable }
            let reader = try AVAssetReader(asset: asset)
            let settings: [String: Any] = mediaType == .video
                ? [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                : [AVFormatIDKey: kAudioFormatLinearPCM]
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
            guard reader.canAdd(output) else { throw Failure.unreadable }
            reader.add(output)
            guard reader.startReading(), let sample = output.copyNextSampleBuffer(),
                  sample.numSamples > 0, reader.status != .failed else { throw Failure.unreadable }
            reader.cancelReading()
            try Task.checkCancellation()
        }
        return Inspection(duration: duration)
    }

    func recover(original: URL, destination: URL) async throws -> Inspection {
        _ = try await inspect(original)
        guard !FileManager.default.fileExists(atPath: destination.path),
              let exporter = AVAssetExportSession(asset: AVURLAsset(url: original),
                                                  presetName: AVAssetExportPresetPassthrough) else {
            throw Failure.exportUnavailable
        }
        // Export into a distinct UUID. Failure/cancellation never deletes either file.
        try await exporter.export(to: destination, as: .mp4)
        return try await inspect(destination)
    }
}
