import SwiftUI

struct YouTubeBrandLogo: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        // The official 573-pixel canvas includes clear space around the 288-pixel mark.
        // Size the complete canvas so the mark renders at least 100 physical pixels high.
        let height = (100 * 573 / 288 / displayScale).rounded(.up)
        Image("YouTubeBrand")
            .resizable()
            .scaledToFit()
            .frame(width: height * 1705 / 573, height: height)
            .accessibilityHidden(true)
    }
}
