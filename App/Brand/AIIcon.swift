import SwiftUI

struct AIIcon: View {
    var size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * BrandConstants.iconCornerRatio, style: .continuous)
        shape
            .fill(
                RadialGradient(
                    colors: [BrandColors.accent.opacity(BrandConstants.iconGlowOpacity), BrandColors.iconBase],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadius: 0,
                    endRadius: size * 0.7
                )
            )
            .overlay(shape.strokeBorder(BrandColors.accent.opacity(BrandConstants.iconGlowOpacity), lineWidth: 1))
            .overlay(
                Text(BrandConstants.logoHighlight)
                    .font(.system(size: size * BrandConstants.iconFontRatio, weight: .black))
                    .foregroundStyle(BrandColors.accent)
            )
            .frame(width: size, height: size)
            .shadow(color: BrandColors.accent.opacity(0.18), radius: BrandConstants.iconGlowRadius)
            .accessibilityHidden(true)
    }
}
