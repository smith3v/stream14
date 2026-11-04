import CoreImage
import HaishinKit
import UIKit

/// Only the generated bitmap is app-owned; HaishinKit composites it with camera video.
@ScreenActor
final class SyntheticOverlay {
    private let layer = ImageScreenObject()
    private var installed = false

    func install(on mixer: MediaMixer) throws {
        mixer.screen.size = CGSize(width: 1920, height: 1080)
        layer.size = CGSize(width: 1920, height: 1080)
        if !installed {
            try mixer.screen.addChild(layer)
            installed = true
        }
        update(counter: 0)
    }

    func update(counter: Int) {
        layer.ciImage = CIImage(cgImage: Self.makeImage(counter: counter))
    }

    static func makeImage(counter: Int) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1920, height: 1080), format: format)
        return renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(CGColor(gray: 0, alpha: 0.5))
            cg.fill(CGRect(x: 60, y: 60, width: 900, height: 180))
            cg.setFillColor(counter.isMultiple(of: 2) ? UIColor.systemYellow.cgColor : UIColor.systemCyan.cgColor)
            cg.fillEllipse(in: CGRect(x: 90, y: 90, width: 120, height: 120))
            let text = "ALPHA TEST · \(counter)"
            (text as NSString).draw(at: CGPoint(x: 240, y: 110), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 64),
                .foregroundColor: UIColor.white
            ])
        }.cgImage!
    }
}
