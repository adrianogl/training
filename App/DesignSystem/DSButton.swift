import SwiftUI

enum DSButtonRole {
    case primary, secondary, text, destructive
}

struct DSButtonStyle: ButtonStyle {
    let role: DSButtonRole
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous)
        configuration.label
            .font(role == .primary ? .subheadline.weight(.bold) : .subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: isFullWidth ? DSButtonConstants.height : DSButtonConstants.textHeight)
            .padding(.horizontal, isFullWidth ? DSSpacing.s5 : 0)
            .background {
                switch role {
                case .primary: shape.fill(BrandColors.accentFill)
                case .secondary: shape.fill(BrandColors.card).overlay(shape.strokeBorder(BrandColors.cardBorder, lineWidth: 1))
                case .text, .destructive: Color.clear
                }
            }
            .contentShape(shape)
            .opacity(isEnabled ? (configuration.isPressed ? DSButtonConstants.pressedOpacity : 1) : DSButtonConstants.disabledOpacity)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }

    private var isFullWidth: Bool { role == .primary || role == .secondary }

    private var foreground: Color {
        switch role {
        case .primary: BrandColors.onAccent
        case .secondary: BrandColors.text
        case .text: BrandColors.accent
        case .destructive: BrandColors.danger
        }
    }
}

extension ButtonStyle where Self == DSButtonStyle {
    static func ds(_ role: DSButtonRole) -> DSButtonStyle { DSButtonStyle(role: role) }
}
