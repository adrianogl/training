import SwiftUI

struct TrackGlyph: View {
    var size: CGFloat
    var trackOpacity = 1.0
    var showsRunner = true

    private typealias C = TrackGlyphConstants

    var body: some View {
        Canvas { context, canvas in
            let unit = canvas.width / C.canvas
            context.stroke(
                Self.lane(C.outer, unit: unit),
                with: .color(BrandColors.iconAccent.opacity(trackOpacity)),
                lineWidth: C.outerLineWidth * unit
            )
            context.stroke(
                Self.lane(C.inner, unit: unit),
                with: .color(BrandColors.iconAccent.opacity(C.innerOpacity * trackOpacity)),
                lineWidth: C.innerLineWidth * unit
            )
            if showsRunner {
                context.fill(Path(ellipseIn: C.runner.scaled(by: unit)), with: .color(BrandColors.iconRunner))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    static func lane(_ rect: CGRect, unit: CGFloat) -> Path {
        let scaled = rect.scaled(by: unit)
        return Path(roundedRect: scaled, cornerRadius: scaled.height / 2)
    }
}
