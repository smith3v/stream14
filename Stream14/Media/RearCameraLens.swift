import AVFoundation
import HaishinKit
import Synchronization

/// Physical rear lenses, not digital zoom presets or a simultaneous-camera session.
enum RearCameraLens: String, CaseIterable, Identifiable, Sendable {
    case ultraWide, wide, telephoto

    var id: String { rawValue }
    var label: String {
        switch self {
        case .ultraWide: "0.5× · Ultra Wide"
        case .wide: "1× · Wide"
        case .telephoto: "Telephoto"
        }
    }

    var buttonLabel: String {
        switch self {
        case .ultraWide: "0.5×"
        case .wide: "1×"
        case .telephoto: "Telephoto"
        }
    }

    nonisolated var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: .builtInUltraWideCamera
        case .wide: .builtInWideAngleCamera
        case .telephoto: .builtInTelephotoCamera
        }
    }

    nonisolated static func supportsProfile(width: Int32, height: Int32, subtype: FourCharCode,
                                             frameRates: [ClosedRange<Double>], profile: SessionProfile = .fullHD) -> Bool {
        width == profile.width && height == profile.height && subtype == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange &&
            frameRates.contains { $0.contains(profile.frameRate) }
    }

    nonisolated static func compatibleFormat(_ device: AVCaptureDevice, profile: SessionProfile = .fullHD) -> AVCaptureDevice.Format? {
        device.formats.first { format in
            let description = format.formatDescription
            let size = CMVideoFormatDescriptionGetDimensions(description)
            return supportsProfile(width: size.width, height: size.height,
                subtype: CMFormatDescriptionGetMediaSubType(description),
                frameRates: format.videoSupportedFrameRateRanges.map { $0.minFrameRate...$0.maxFrameRate }, profile: profile)
        }
    }

    nonisolated func device(profile: SessionProfile = .fullHD) -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(deviceTypes: [deviceType], mediaType: .video, position: .back)
            .devices.first { Self.compatibleFormat($0, profile: profile) != nil }
    }

    nonisolated static func available(profile: SessionProfile = .fullHD) -> [Self] {
        allCases.filter { $0.device(profile: profile) != nil }
    }

    /// Called on the mixer's actor after attach; attach's own callback suppresses errors in 2.3.0.
    nonisolated static func configure(_ unit: VideoDeviceUnit, profile: SessionProfile = .fullHD) throws {
        guard let device = unit.device, let format = compatibleFormat(device, profile: profile) else {
            throw ConfigurationError.unavailable
        }
        try device.lockForConfiguration()
        device.activeFormat = format
        device.videoZoomFactor = 1
        device.automaticallyAdjustsVideoHDREnabled = false
        if format.isVideoHDRSupported { device.isVideoHDREnabled = false }
        device.unlockForConfiguration()
        try unit.setFrameRate(profile.frameRate)
    }

    enum ConfigurationError: Error { case unavailable }
}

// Keep device discovery and configuration on the existing media actor. Only the
// Sendable lens identity crosses MainActor; AVCaptureDevice never leaves its owner.
extension MediaMixer {
    func attachRearCamera(_ lens: RearCameraLens, profile: SessionProfile = .fullHD) async throws {
        guard let device = lens.device(profile: profile) else { throw RearCameraLens.ConfigurationError.unavailable }
        try await attachVideo(device)
        try configuration(video: 0) { unit in try RearCameraLens.configure(unit, profile: profile) }
    }
}

nonisolated struct CameraZoom: Sendable {
    var value: Double = 1
    var minimum: Double = 1
    var maximum: Double = 1

    static func clamped(_ requested: Double, minimum: Double, deviceMaximum: Double) -> Self {
        let maximum = min(10, deviceMaximum)
        let value = requested.isFinite ? min(maximum, max(minimum, requested)) : minimum
        return Self(value: value, minimum: minimum, maximum: maximum)
    }
}

extension MediaMixer {
    func configureZoom(_ requested: Double) throws -> CameraZoom {
        let result = Mutex(CameraZoom())
        try configuration(video: 0) { unit in
            guard let device = unit.device else { throw RearCameraLens.ConfigurationError.unavailable }
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            let zoom = CameraZoom.clamped(requested,
                                          minimum: Double(device.minAvailableVideoZoomFactor),
                                          deviceMaximum: Double(device.maxAvailableVideoZoomFactor))
            device.videoZoomFactor = CGFloat(zoom.value)
            result.withLock { $0 = zoom }
        }
        return result.withLock { $0 }
    }
}
