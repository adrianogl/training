import SwiftUI

struct TrackLap: View {
    var side: CGFloat
    var start: Double
    var length: Double
    var glowRadii: [CGFloat]?

    var body: some View {
        let unit = side / TrackGlyphConstants.canvas
        let track = TrackGlyphConstants.outer.scaled(by: unit)
        let corner = track.height / 2
        return ZStack {
            BrandLoaderRing(cornerRadius: corner, start: start, length: length)
                .stroke(BrandColors.iconAccent, style: StrokeStyle(lineWidth: TrackGlyphConstants.outerLineWidth * unit, lineCap: .round))
                .shadow(color: glowColor(0), radius: glowRadius(0))
                .shadow(color: glowColor(1), radius: glowRadius(1))
                .shadow(color: glowColor(2), radius: glowRadius(2))
            if length > 0 {
                TrackRunner(cornerRadius: corner, fraction: start + length, diameter: TrackGlyphConstants.runner.width * unit)
                    .fill(BrandColors.iconRunner)
            }
        }
        .frame(width: track.width, height: track.height)
        .offset(x: track.minX, y: track.minY)
        .frame(width: side, height: side, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glowColor(_ index: Int) -> Color {
        BrandColors.iconAccent.opacity(glowRadii == nil ? 0 : BrandLoaderConstants.shadowOpacities[index])
    }

    private func glowRadius(_ index: Int) -> CGFloat {
        glowRadii.map { $0[index] } ?? 0
    }
}
