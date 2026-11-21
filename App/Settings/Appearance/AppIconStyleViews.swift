import SwiftUI

struct AppIconStylePicker: View {
    @Binding var selection: String
    let theme: AccentTheme

    var body: some View {
        HStack(spacing: DSSpacing.s2) {
            ForEach(AppIconStyle.allCases) { style in
                Button { selection = style.rawValue } label: {
                    AppIconStyleCard(style: style, theme: theme, isSelected: AppIconStyle.stored(selection) == style)
                }
                .buttonStyle(.cardLink)
            }
        }
    }
}

struct AppIconStyleCard: View {
    let style: AppIconStyle
    let theme: AccentTheme
    let isSelected: Bool

    private typealias C = AppIconConstants

    var body: some View {
        let shape = ConcentricRectangle.dsInner
        VStack(spacing: DSSpacing.s2) {
            icon
                .frame(width: C.previewSize, height: C.previewSize)
                .clipShape(RoundedRectangle(cornerRadius: C.previewRadius, style: .continuous))
            VStack(spacing: 1) {
                Text(style.title).font(.subheadline.weight(.bold)).foregroundStyle(BrandColors.text)
                Text(style.subtitle).font(.caption2).foregroundStyle(BrandColors.dim)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.vertical, DSSpacing.s3)
        .padding(.horizontal, DSSpacing.s2)
        .frame(maxWidth: .infinity)
        .background(BrandColors.card, in: shape)
        .overlay(shape.stroke(isSelected ? BrandColors.accentFill : BrandColors.cardBorder, lineWidth: isSelected ? 2 : 1))
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(BrandColors.onAccent)
                    .frame(width: 20, height: 20)
                    .background(BrandColors.accentFill, in: Circle())
                    .padding(DSSpacing.s2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(style.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var icon: some View {
        let names = AppIconSwitcher.previewNames(for: theme)
        switch style {
        case .system:
            ZStack {
                Image(names.light).resizable()
                Image(names.dark).resizable().mask(DiagonalHalf())
            }
        case .light:
            Image(names.light).resizable()
        case .dark:
            Image(names.dark).resizable()
        }
    }
}

struct DiagonalHalf: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
