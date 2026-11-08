import SwiftUI

struct ShareBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BrandColors.shareTop, BrandColors.background, BrandColors.background],
                startPoint: UnitPoint(x: 0.3, y: 0),
                endPoint: UnitPoint(x: 0.7, y: 1)
            )
            RadialGradient(
                colors: [BrandColors.accent.opacity(ShareConstants.backgroundGlowOpacity), .clear],
                center: UnitPoint(x: 0.2, y: 0),
                startRadius: 0,
                endRadius: ShareConstants.backgroundGlowRadius
            )
        }
    }
}
