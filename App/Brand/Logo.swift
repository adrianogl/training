import SwiftUI

struct Logo: View {
    var showsTagline: Bool
    var showsIcon = true
    var fontSize = BrandConstants.logoFontSize

    var body: some View {
        HStack(spacing: 12) {
            if showsIcon {
                AIIcon(size: BrandConstants.logoIconSize)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("trAIning")
    }

    private var wordmark: some View {
        let highlight = Text(BrandConstants.logoHighlight).foregroundStyle(BrandColors.accent)
        return Text("\(BrandConstants.logoPrefix)\(highlight)\(BrandConstants.logoSuffix)")
            .font(.system(size: fontSize, weight: .heavy))
            .tracking(fontSize * BrandConstants.logoTracking / BrandConstants.logoFontSize)
            .foregroundStyle(BrandColors.text)
    }
}
