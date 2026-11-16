import SwiftUI

struct TrackRunner: Shape {
    var cornerRadius: CGFloat
    var fraction: Double
    var diameter: CGFloat

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let wrapped = fraction.truncatingRemainder(dividingBy: 1)
        let outline = BrandLoaderRing.outline(in: rect, cornerRadius: cornerRadius)
        let head = outline.trimmedPath(from: 0, to: wrapped).currentPoint ?? CGPoint(x: rect.midX, y: rect.minY)
        return Path(ellipseIn: CGRect(x: head.x - diameter / 2, y: head.y - diameter / 2, width: diameter, height: diameter))
    }
}
