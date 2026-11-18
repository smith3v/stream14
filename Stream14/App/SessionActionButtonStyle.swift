import SwiftUI

struct SessionActionButtonStyle: ButtonStyle {
    static let standard = Self(fill: Color.secondary.opacity(0.15), label: .primary)
    static let start = Self(fill: Color(red: 32 / 255, green: 164 / 255, blue: 81 / 255), label: .black)
    static let stop = Self(fill: Color(red: 0.70, green: 0.16, blue: 0.20), label: .white, fullWidth: true)

    private let fill: Color
    private let label: Color
    private let fullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled

    private init(fill: Color, label: Color, fullWidth: Bool = false) {
        self.fill = fill
        self.label = label
        self.fullWidth = fullWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? label : Color.primary.opacity(0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minWidth: 44, maxWidth: fullWidth ? .infinity : nil, minHeight: 56)
            .background(isEnabled ? fill : Color.secondary.opacity(0.15), in: .capsule)
            .overlay {
                if configuration.isPressed {
                    Capsule().fill(.black.opacity(0.15)).allowsHitTesting(false)
                }
            }
            .contentShape(.capsule)
    }
}
