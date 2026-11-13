import SwiftUI

struct PulseLine: Shape {
    func path(in rect: CGRect) -> Path {
        let points = BrandConstants.introPulsePoints
        let scaleX = rect.width / BrandConstants.introPulseWidth
        let scaleY = rect.height / BrandConstants.introPulseHeight
        var path = Path()
        for (index, point) in points.enumerated() {
            let scaled = CGPoint(x: rect.minX + point.x * scaleX, y: rect.minY + point.y * scaleY)
            if index == 0 {
                path.move(to: scaled)
            } else {
                path.addLine(to: scaled)
            }
        }
        return path
    }
}
