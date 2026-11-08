import CoreGraphics
import FITReader
import Foundation

enum ShareRouteProjection {
    static func points(_ route: [Coordinate], in rect: CGRect) -> [CGPoint] {
        guard !route.isEmpty, rect.width > 0, rect.height > 0 else { return [] }
        let meanLatitude = route.reduce(0) { $0 + $1.lat } / Double(route.count)
        let lonScale = cos(meanLatitude * .pi / 180)
        let raw = route.map { CGPoint(x: $0.lon * lonScale, y: -$0.lat) }
        let xs = raw.map(\.x)
        let ys = raw.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return [] }
        let spanX = maxX - minX
        let spanY = maxY - minY
        let longest = max(spanX, spanY)
        guard longest > 0 else { return raw.map { _ in CGPoint(x: rect.midX, y: rect.midY) } }
        let scale = min(spanX > 0 ? rect.width / spanX : .infinity, spanY > 0 ? rect.height / spanY : .infinity)
        let offsetX = rect.minX + (rect.width - spanX * scale) / 2
        let offsetY = rect.minY + (rect.height - spanY * scale) / 2
        return raw.map { CGPoint(x: offsetX + ($0.x - minX) * scale, y: offsetY + ($0.y - minY) * scale) }
    }
}
