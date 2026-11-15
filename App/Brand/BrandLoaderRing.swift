import SwiftUI

struct BrandLoaderRing: Shape {
    var cornerRadius: CGFloat
    var start: Double
    var length: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(start, length) }
        set {
            start = newValue.first
            length = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let outline = Self.outline(in: rect, cornerRadius: cornerRadius)
        let end = start + length
        var path = Path()
        path.addPath(outline.trimmedPath(from: start, to: min(end, 1)))
        if end > 1 {
            path.addPath(outline.trimmedPath(from: 0, to: end - 1))
        }
        return path
    }

    static func outline(in rect: CGRect, cornerRadius: CGFloat) -> Path {
        let radius = min(cornerRadius, rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addRelativeArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius, startAngle: .degrees(-90), delta: .degrees(90))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addRelativeArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius, startAngle: .degrees(0), delta: .degrees(90))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addRelativeArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius, startAngle: .degrees(90), delta: .degrees(90))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addRelativeArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius, startAngle: .degrees(180), delta: .degrees(90))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}
