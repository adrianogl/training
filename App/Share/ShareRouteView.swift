import FITReader
import SwiftUI

struct ShareRouteView: View {
    let route: [Coordinate]
    let color: Color
    let lineWidth: CGFloat
    let markerColor: Color?

    var body: some View {
        Canvas { context, size in
            let inset = lineWidth / 2 + (markerColor == nil ? 0 : ShareConstants.routeMarkerSize / 2)
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let points = ShareRouteProjection.points(route, in: rect)
            guard let first = points.first else { return }
            var path = Path()
            path.addLines(points)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            if let markerColor {
                let side = ShareConstants.routeMarkerSize
                let marker = Path(ellipseIn: CGRect(x: first.x - side / 2, y: first.y - side / 2, width: side, height: side))
                context.fill(marker, with: .color(markerColor))
            }
        }
        .accessibilityHidden(true)
    }
}
