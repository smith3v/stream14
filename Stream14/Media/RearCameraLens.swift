import AVFoundation
import HaishinKit

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
                                             frameRates: [ClosedRange<Double>]) -> Bool {
        width == 1920 && height == 1080 && subtype == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange &&
            frameRates.contains { $0.contains(30) }
    }

    nonisolated static func compatibleFormat(_ device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        device.formats.first { format in
            let description = format.formatDescription
            let size = CMVideoFormatDescriptionGetDimensions(description)
            return supportsProfile(width: size.width, height: size.height,
                subtype: CMFormatDescriptionGetMediaSubType(description),
                frameRates: format.videoSupportedFrameRateRanges.map { $0.minFrameRate...$0.maxFrameRate })
        }
    }

    nonisolated func device() -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(deviceTypes: [deviceType], mediaType: .video, position: .back)
            .devices.first { Self.compatibleFormat($0) != nil }
    }

    nonisolated static func available() -> [Self] {
        allCases.filter { $0.device() != nil }
    }

    /// Called on the mixer's actor after attach; attach's own callback suppresses errors in 2.3.0.
    nonisolated static func configure(_ unit: VideoDeviceUnit) throws {
        guard let device = unit.device, let format = compatibleFormat(device) else {
            throw ConfigurationError.unavailable
        }
        try device.lockForConfiguration()
        device.activeFormat = format
        device.videoZoomFactor = 1
        device.automaticallyAdjustsVideoHDREnabled = false
        if format.isVideoHDRSupported { device.isVideoHDREnabled = false }
        device.unlockForConfiguration()
        try unit.setFrameRate(30)
    }

    enum ConfigurationError: Error { case unavailable }
}

// Keep device discovery and configuration on the existing media actor. Only the
// Sendable lens identity crosses MainActor; AVCaptureDevice never leaves its owner.
extension MediaMixer {
    func attachRearCamera(_ lens: RearCameraLens) async throws {
        guard let device = lens.device() else { throw RearCameraLens.ConfigurationError.unavailable }
        try await attachVideo(device)
        try configuration(video: 0) { unit in try RearCameraLens.configure(unit) }
    }
}
