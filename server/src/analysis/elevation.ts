import type { LapSummary } from '../fit/fitTypes.js'
import { ANALYSIS } from './analysisConstants.js'

export function flatPaceOf(pace: number, distance: number, climb: number, descent: number): number {
  if (distance <= 0 || (climb < ANALYSIS.elevationMinimum && descent < ANALYSIS.elevationMinimum)) return pace
  return pace / (1 + (ANALYSIS.climbCost * climb) / distance - (ANALYSIS.descentGain * descent) / distance)
}

export const hasElevation = (lap: LapSummary) => (lap.climb ?? 0) >= ANALYSIS.elevationMinimum || (lap.descent ?? 0) >= ANALYSIS.elevationMinimum

export function flatPace(lap: LapSummary): number | null {
  const speed = lap.avgSpeed ?? (lap.timerSeconds > 0 ? lap.distance / lap.timerSeconds : 0)
  if (speed <= 0) return null
  return flatPaceOf(1000 / speed, lap.distance, lap.climb ?? 0, lap.descent ?? 0)
}

export class ElevationCounter {
  private anchor: number | null = null
  climb = 0
  descent = 0
  hasData = false

  add(altitude: number | null): void {
    if (altitude === null) return
    this.hasData = true
    if (this.anchor === null) {
      this.anchor = altitude
      return
    }
    const change = altitude - this.anchor
    if (Math.abs(change) < ANALYSIS.elevationNoise) return
    if (change > 0) this.climb += change
    else this.descent -= change
    this.anchor = altitude
  }

  restart(): void {
    this.climb = 0
    this.descent = 0
  }
}
