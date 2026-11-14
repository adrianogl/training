import SwiftUI

struct ShareTrackView: View {
    let track: [TrackPoint]
    let coloring: RouteColoring
    let zoneFloors: [Int]
    let progress: Double
    let lineWidth: CGFloat
    var solidColor: Color = BrandColors.iconAccent
    var shadow = false

    var body: some View {
        Canvas { context, size in
            let inset = lineWidth * 1.6
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let points = ShareRouteProjection.points(track.map(\.coordinate), in: rect)
            guard points.count >= 2 else { return }
            if shadow {
                context.addFilter(.shadow(color: BrandColors.stickerShadow, radius: 4, y: 1))
            }
            var base = Path()
            base.addLines(points)
            context.stroke(base, with: .color(.white.opacity(0.14)), style: stroke(lineWidth))
            let colors = segmentColors()
            let last = max(1, Int(Double(points.count - 1) * min(max(progress, 0), 1)))
            for index in 1...last {
                var segment = Path()
                segment.move(to: points[index - 1])
                segment.addLine(to: points[index])
                context.stroke(segment, with: .color(colors[index]), style: stroke(lineWidth))
            }
            let head = points[last]
            let side = lineWidth * 2.4
            let dot = Path(ellipseIn: CGRect(x: head.x - side / 2, y: head.y - side / 2, width: side, height: side))
            context.fill(dot, with: .color(.white))
            context.stroke(dot, with: .color(BrandColors.iconBase), lineWidth: lineWidth * 0.4)
        }
        .accessibilityHidden(true)
    }

    private func stroke(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    private func segmentColors() -> [Color] {
        switch coloring {
        case .solid:
            return track.map { _ in solidColor }
        case .pace:
            return ShareTrackBuilder.paceLevels(track).map(Self.paceColor)
        case .zone:
            return ShareTrackBuilder.zones(track, floors: zoneFloors).map { BrandColors.zone($0) }
        }
    }

    private static func paceColor(_ level: Double) -> Color {
        let slow = (r: 0.50, g: 0.70, b: 1.0)
        let fast = (r: 0.78, g: 0.94, b: 0.35)
        return Color(
            red: slow.r + (fast.r - slow.r) * level,
            green: slow.g + (fast.g - slow.g) * level,
            blue: slow.b + (fast.b - slow.b) * level
        )
    }
}

struct ShareElevationView: View {
    let track: [TrackPoint]
    let progress: Double

    var body: some View {
        Canvas { context, size in
            let values = track.compactMap(\.altitude)
            guard values.count >= 2, let low = values.min(), let high = values.max() else { return }
            let span = max(high - low, 10)
            let point = { (index: Int) -> CGPoint in
                CGPoint(x: size.width * Double(index) / Double(values.count - 1), y: size.height - (values[index] - low) / span * size.height)
            }
            var area = Path()
            area.move(to: CGPoint(x: 0, y: size.height))
            for index in values.indices { area.addLine(to: point(index)) }
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.closeSubpath()
            context.fill(area, with: .color(BrandColors.fitness.opacity(0.2)))
            let last = max(1, Int(Double(values.count - 1) * min(max(progress, 0), 1)))
            var line = Path()
            line.move(to: point(0))
            for index in 1...last { line.addLine(to: point(index)) }
            context.stroke(line, with: .color(BrandColors.fitness), lineWidth: 2)
            let head = point(last)
            context.fill(Path(ellipseIn: CGRect(x: head.x - 4, y: head.y - 4, width: 8, height: 8)), with: .color(.white))
        }
        .accessibilityHidden(true)
    }
}
