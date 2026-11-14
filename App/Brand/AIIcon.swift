import SwiftUI

struct AIIcon: View {
    var size: CGFloat
    var bordered = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * BrandConstants.iconCornerRatio, style: .continuous)
        shape
            .fill(
                RadialGradient(
                    colors: [BrandColors.iconAccent.opacity(BrandConstants.iconGlowOpacity), BrandColors.iconBase],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadius: 0,
                    endRadius: size * 0.7
                )
            )
            .overlay {
                if bordered {
                    shape.strokeBorder(BrandColors.iconAccent.opacity(BrandConstants.iconGlowOpacity), lineWidth: 1)
                }
            }
            .overlay(
                Text(BrandConstants.logoHighlight)
                    .font(.system(size: size * BrandConstants.iconFontRatio, weight: .black))
                    .foregroundStyle(BrandColors.iconAccent)
            )
            .frame(width: size, height: size)
            .shadow(color: BrandColors.iconAccent.opacity(0.18), radius: BrandConstants.iconGlowRadius)
            .accessibilityHidden(true)
    }
}
