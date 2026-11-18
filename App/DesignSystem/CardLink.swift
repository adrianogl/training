import SwiftUI

struct CardLinkFooter: View {
    let title: String

    var body: some View {
        VStack(spacing: CardLinkConstants.footerSpacing) {
            Rectangle().fill(BrandColors.line).frame(height: 1)
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold))
            }
            .foregroundStyle(BrandColors.accent)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isLink)
    }
}

struct CardLinkBadge: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.heavy))
            .foregroundStyle(BrandColors.accent)
            .frame(width: CardLinkConstants.badgeSize, height: CardLinkConstants.badgeSize)
            .background(BrandColors.accentFill.opacity(CardLinkConstants.badgeOpacity), in: Circle())
            .accessibilityHidden(true)
    }
}

struct CardDisclosure: View {
    let expanded: Bool

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.caption.weight(.bold))
            .foregroundStyle(BrandColors.dim)
            .rotationEffect(.degrees(expanded ? 180 : 0))
            .animation(.snappy, value: expanded)
            .accessibilityHidden(true)
    }
}

struct CardLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? CardLinkConstants.pressedScale : 1)
            .opacity(configuration.isPressed ? CardLinkConstants.pressedOpacity : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CardLinkStyle {
    static var cardLink: CardLinkStyle { CardLinkStyle() }
}
