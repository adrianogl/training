public enum RouteSimplifier {
    public static func simplify(_ points: [Coordinate], maxPoints: Int) -> [Coordinate] {
        guard points.count > maxPoints else { return points }
        var tolerance = FITReaderConstants.initialSimplificationTolerance
        var result = douglasPeucker(points, tolerance: tolerance)
        while result.count > maxPoints {
            tolerance *= 2
            result = douglasPeucker(points, tolerance: tolerance)
        }
        return result
    }

    static func douglasPeucker(_ points: [Coordinate], tolerance: Double) -> [Coordinate] {
        guard points.count > 2 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack = [(0, points.count - 1)]
        while let (first, last) = stack.popLast() {
            guard last - first > 1 else { continue }
            var maxDistance = 0.0
            var index = first
            for i in (first + 1)..<last {
                let d = distance(points[i], from: points[first], to: points[last])
                if d > maxDistance {
                    maxDistance = d
                    index = i
                }
            }
            if maxDistance > tolerance {
                keep[index] = true
                stack.append((first, index))
                stack.append((index, last))
            }
        }
        return zip(points, keep).filter { $0.1 }.map { $0.0 }
    }

    private static func distance(_ p: Coordinate, from a: Coordinate, to b: Coordinate) -> Double {
        let dx = b.lon - a.lon
        let dy = b.lat - a.lat
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared == 0 {
            let ex = p.lon - a.lon
            let ey = p.lat - a.lat
            return (ex * ex + ey * ey).squareRoot()
        }
        let cross = (p.lon - a.lon) * dy - (p.lat - a.lat) * dx
        return abs(cross) / lengthSquared.squareRoot()
    }
}
