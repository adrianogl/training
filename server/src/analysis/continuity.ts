import type { FitSample } from '../fit/fitTypes.js'
import { ANALYSIS } from './analysisConstants.js'
import type { RunContinuity } from './analysisTypes.js'

export function runContinuity(samples: FitSample[]): RunContinuity | null {
  const points = samples
    .flatMap((sample) => (sample.distance === null ? [] : [{ t: sample.t, distance: sample.distance }]))
    .sort((a, b) => a.t - b.t)
  const first = points[0]
  const last = points[points.length - 1]
  if (first === undefined || last === undefined || last.distance <= first.distance) return null
  const pauses: { startMeters: number; seconds: number }[] = []
  let movingSeconds = 0
  let segmentStart = first.distance
  let longest = 0
  let slowStart: { t: number; distance: number } | null = null
  let slowSeconds = 0
  let previous = first

  const closeSlow = () => {
    if (slowStart === null) return
    if (slowSeconds >= ANALYSIS.pauseGapSeconds) {
      pauses.push({ startMeters: slowStart.distance - first.distance, seconds: slowSeconds })
      longest = Math.max(longest, slowStart.distance - segmentStart)
      segmentStart = previous.distance
    } else {
      movingSeconds += slowSeconds
    }
    slowStart = null
    slowSeconds = 0
  }

  for (const point of points.slice(1)) {
    const interval = point.t - previous.t
    if (interval <= 0) continue
    if (point.distance - previous.distance < interval * ANALYSIS.pauseMaximumSpeed) {
      if (slowStart === null) slowStart = previous
      slowSeconds += interval
    } else {
      closeSlow()
      movingSeconds += interval
    }
    previous = point
  }
  closeSlow()
  longest = Math.max(longest, last.distance - segmentStart)
  return { totalMeters: last.distance - first.distance, movingSeconds, pauses, longestContinuousMeters: longest }
}

export function continuityPace(continuity: RunContinuity): number | null {
  return continuity.totalMeters > 0 && continuity.movingSeconds > 0 ? continuity.movingSeconds / (continuity.totalMeters / 1000) : null
}

export function meetsContinuousGoal(continuity: RunContinuity, distanceKm: number, paceSecondsPerKm: number): boolean {
  const pace = continuityPace(continuity)
  return continuity.pauses.length === 0 && continuity.totalMeters >= distanceKm * 1000 && pace !== null && pace <= paceSecondsPerKm
}
