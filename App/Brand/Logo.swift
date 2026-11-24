import SwiftUI

struct Logo: View {
    var showsTagline: Bool
    var showsIcon = true
    var showsIconPlaceholder = false
    var fontSize = BrandConstants.logoFontSize

    var body: some View {
        HStack(spacing: showsIcon && !showsIconPlaceholder ? 12 : 0) {
            if showsIcon {
                BrandIcon(size: BrandConstants.logoIconSize)
                    .frame(width: showsIconPlaceholder ? 0 : BrandConstants.logoIconSize, alignment: .leading)
                    .opacity(showsIconPlaceholder ? 0 : 1)
                    .clipShape(Rectangle().inset(by: showsIconPlaceholder ? 0 : -BrandConstants.iconGlowRadius * 2))
            }
            VStack(alignment: .leading, spacing: 2) {
                wordmark
                if showsTagline {
                    Text(BrandConstants.tagline)
                        .font(.system(size: BrandConstants.taglineFontSize))
                        .foregroundStyle(BrandColors.dim)
                }
            }
        }
        .animation(.smooth(duration: BrandRefreshConstants.slideSeconds), value: showsIconPlaceholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("trAIning")
    }

    private var wordmark: some View {
        let highlight = Text(BrandConstants.logoHighlight).foregroundStyle(BrandColors.accent)
        return Text("\(BrandConstants.logoPrefix)\(highlight)\(BrandConstants.logoSuffix)")
            .font(BrandFonts.display(fontSize))
            .tracking(fontSize * BrandConstants.logoTracking / BrandConstants.logoFontSize)
            .foregroundStyle(BrandColors.text)
    }
}
