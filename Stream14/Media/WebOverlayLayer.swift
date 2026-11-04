import CoreImage
import HaishinKit

@ScreenActor
final class WebOverlayLayer {
    private let layer = ImageScreenObject()
    private var lastImage: CGImage?
    private var lastVisible = false
    private var installed = false
    func install(on mixer: MediaMixer) throws {
        mixer.screen.size = CGSize(width: 1920, height: 1080)
        layer.size = CGSize(width: 1920, height: 1080)
        if !installed { try mixer.screen.addChild(layer); installed = true }
        layer.isVisible = false
        layer.ciImage = nil
        lastImage = nil
        lastVisible = false
    }
    func update(image: CGImage?, visible: Bool) {
        guard image !== lastImage || visible != lastVisible else { return }
        lastImage = image
        lastVisible = visible
        // HaishinKit retains the last laid-out image when makeImage returns nil.
        // Visibility must gate drawing, not merely clear the source image.
        layer.isVisible = visible && image != nil
        if let image { layer.ciImage = CIImage(cgImage: image) }
    }
}
