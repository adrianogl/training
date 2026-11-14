import { FIT } from './fitConstants.js'
import type { Coordinate } from './fitTypes.js'

function distance(p: Coordinate, a: Coordinate, b: Coordinate): number {
  const dx = b.lon - a.lon
  const dy = b.lat - a.lat
  const lengthSquared = dx * dx + dy * dy
  if (lengthSquared === 0) return Math.hypot(p.lon - a.lon, p.lat - a.lat)
  return Math.abs((p.lon - a.lon) * dy - (p.lat - a.lat) * dx) / Math.sqrt(lengthSquared)
}

export function douglasPeucker(points: Coordinate[], tolerance: number): Coordinate[] {
  if (points.length <= 2) return points
  const keep = points.map(() => false)
  keep[0] = true
  keep[points.length - 1] = true
  const stack: [number, number][] = [[0, points.length - 1]]
  while (stack.length > 0) {
    const [first, last] = stack.pop() as [number, number]
    if (last - first <= 1) continue
    let maxDistance = 0
    let index = first
    for (let i = first + 1; i < last; i += 1) {
      const d = distance(points[i] as Coordinate, points[first] as Coordinate, points[last] as Coordinate)
      if (d > maxDistance) {
        maxDistance = d
        index = i
      }
    }
    if (maxDistance > tolerance) {
      keep[index] = true
      stack.push([first, index], [index, last])
    }
  }
  return points.filter((_, i) => keep[i])
}

export function simplify(points: Coordinate[], maxPoints: number): Coordinate[] {
  if (points.length <= maxPoints) return points
  let tolerance: number = FIT.initialSimplificationTolerance
  let result = douglasPeucker(points, tolerance)
  while (result.length > maxPoints) {
    tolerance *= 2
    result = douglasPeucker(points, tolerance)
  }
  return result
}
