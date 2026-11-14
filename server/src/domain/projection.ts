import { addDays } from '../garminSync.js'
import { PROJECTION } from './domainConstants.js'
import type { Projection, ProjectionPoint, SeriesPoint } from './domainTypes.js'
import { daysBetween } from './prediction.js'

export function project(series: SeriesPoint[], today: string, horizonDays: number, softCeiling: number | null = null, target: number | null = null): Projection | null {
  if (horizonDays < 1) {
    return null
  }
  const samples = series.flatMap(([day, value]) => {
    const offset = daysBetween(today, day)
    return offset <= 0 && offset > -PROJECTION.windowDays ? [{ x: offset, y: value }] : []
  })
  const n = samples.length
  if (n < PROJECTION.minimumPoints) {
    return null
  }
  const meanX = samples.reduce((sum, item) => sum + item.x, 0) / n
  const meanY = samples.reduce((sum, item) => sum + item.y, 0) / n
  const sxx = samples.reduce((sum, item) => sum + (item.x - meanX) ** 2, 0)
  if (sxx <= 0) {
    return null
  }
  const sxy = samples.reduce((sum, item) => sum + (item.x - meanX) * (item.y - meanY), 0)
  const slope = sxy / sxx
  const intercept = meanY - slope * meanX
  const residualSquares = samples.reduce((sum, item) => sum + (item.y - (intercept + slope * item.x)) ** 2, 0)
  const sigma = Math.sqrt(residualSquares / (n - 2))

  let cursor = intercept
  const points: ProjectionPoint[] = []
  for (let h = 1; h <= horizonDays; h += 1) {
    const next = cursor + slope
    if (softCeiling !== null && slope > 0) {
      const high = Math.max(cursor, next)
      const low = Math.min(cursor, next)
      const above = Math.max(0, high - Math.max(low, softCeiling))
      cursor += high - low - above * (1 - PROJECTION.ceilingFactor)
    } else {
      cursor = next
    }
    const halfWidth = PROJECTION.bandZ * sigma * Math.sqrt(1 + h / n)
    points.push({ day: addDays(today, h), mid: cursor, low: cursor - halfWidth, high: cursor + halfWidth })
  }

  let crossing: string | null = null
  if (target !== null && slope !== 0) {
    const ahead = slope > 0 ? target - intercept : intercept - target
    if (Math.abs(ahead) <= PROJECTION.targetTolerance * Math.max(1, Math.abs(target))) {
      crossing = today
    } else if (ahead > 0) {
      crossing = points.find((point) => (slope > 0 ? point.mid >= target : point.mid <= target))?.day ?? null
    }
  }
  return { points, targetCrossing: crossing }
}
