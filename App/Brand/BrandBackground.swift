import SwiftUI

struct BrandBackground: View {
    var body: some View {
        ZStack {
            BrandColors.background
            RadialGradient(
                colors: [BrandColors.accentGlow, .clear],
                center: UnitPoint(x: 0.2, y: 0.05),
                startRadius: 0,
                endRadius: BrandConstants.glowRadius
            )
            RadialGradient(
                colors: [BrandColors.raceGlow, .clear],
                center: UnitPoint(x: 0.85, y: 0.6),
                startRadius: 0,
                endRadius: BrandConstants.glowRadius
            )
        }
        .ignoresSafeArea()
    }
}
