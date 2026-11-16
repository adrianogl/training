import SwiftUI

struct BrandIcon: View {
    var size: CGFloat
    var bordered = true
    var lap: Double?

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
            .overlay {
                if let lap {
                    TrackGlyph(size: size, trackOpacity: TrackGlyphConstants.loaderTrackOpacity, showsRunner: false)
                    TrackLap(side: size, start: TrackGlyphConstants.runnerRestFraction, length: lap)
                } else {
                    TrackGlyph(size: size)
                }
            }
            .frame(width: size, height: size)
            .shadow(color: BrandColors.iconAccent.opacity(0.18), radius: BrandConstants.iconGlowRadius)
            .accessibilityHidden(true)
    }
}
