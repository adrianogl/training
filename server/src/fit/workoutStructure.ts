import { FIT } from './fitConstants.js'
import type { FitMessage, LapSummary, PrescribedStep, StepDuration, StepIntensity, StepTarget, WorkoutPrescription, WorkoutStructure } from './fitTypes.js'

const num = (value: unknown): number | null => (typeof value === 'number' && Number.isFinite(value) ? value : null)
const text = (value: unknown): string | null => (typeof value === 'string' ? value : null)
const seconds = (value: unknown): number | null => (value instanceof Date ? value.getTime() / 1000 : null)

export function intensity(value: unknown): StepIntensity | null {
  return typeof value === 'string' ? ((FIT.intensities[value] as StepIntensity | undefined) ?? null) : null
}

function duration(step: FitMessage): StepDuration {
  switch (step.durationType) {
    case 'distance': {
      const meters = num(step.durationDistance)
      return meters === null ? { kind: 'open' } : { kind: 'distance', meters }
    }
    case 'time': {
      const value = num(step.durationTime)
      return value === null ? { kind: 'open' } : { kind: 'time', seconds: value }
    }
    case 'repeatUntilStepsCmplt': {
      const from = num(step.durationStep ?? step.durationValue)
      const count = num(step.repeatSteps ?? step.targetValue)
      return from === null || count === null ? { kind: 'open' } : { kind: 'repeatSteps', fromIndex: Math.trunc(from), count: Math.trunc(count) }
    }
    default:
      return { kind: 'open' }
  }
}

function target(step: FitMessage): StepTarget {
  if (step.targetType === 'speed') {
    const low = num(step.customTargetSpeedLow) ?? 0
    const high = num(step.customTargetSpeedHigh) ?? 0
    return low > 0 || high > 0 ? { kind: 'speed', low, high } : { kind: 'open' }
  }
  if (step.targetType === 'heartRate') {
    const low = Math.trunc(num(step.customTargetHeartRateLow) ?? 0)
    const high = Math.trunc(num(step.customTargetHeartRateHigh) ?? 0)
    if (low === 0 && high === 0) {
      const zone = num(step.targetHrZone)
      const [min, max] = FIT.heartRateZones
      return zone !== null && zone >= min && zone <= max ? { kind: 'heartRateZone', zone: Math.trunc(zone) } : { kind: 'open' }
    }
    const offset = FIT.heartRateBpmOffset
    if (low > offset || high > offset) return { kind: 'heartRateBpm', low: Math.max(low - offset, 0), high: Math.max(high - offset, 0) }
    return { kind: 'heartRatePercentMax', low, high }
  }
  return { kind: 'open' }
}

function prescription(workout: FitMessage | undefined, steps: FitMessage[]): WorkoutPrescription | null {
  if (workout === undefined && steps.length === 0) return null
  const prescribed: PrescribedStep[] = steps.map((step, position) => ({
    index: num(step.messageIndex) ?? position,
    intensity: intensity(step.intensity) ?? 'active',
    duration: duration(step),
    target: target(step),
  }))
  return {
    name: text(workout?.wktName),
    description: text(workout?.wktDescription),
    steps: prescribed.sort((a, b) => a.index - b.index),
  }
}

function lapSummaries(laps: FitMessage[], origin: number | null): LapSummary[] {
  const starts = laps.map((lap) => seconds(lap.startTime))
  const known = starts.filter((value): value is number => value !== null)
  const base = origin ?? (known.length > 0 ? Math.min(...known) : 0)
  return laps.map((lap, index) => {
    const start = starts[index] ?? null
    const average = num(lap.avgHeartRate)
    const maximum = num(lap.maxHeartRate)
    return {
      stepIndex: num(lap.wktStepIndex),
      intensity: intensity(lap.intensity),
      trigger: typeof lap.lapTrigger === 'string' ? (FIT.lapTriggers[lap.lapTrigger] ?? null) : null,
      startOffset: start === null ? 0 : start - base,
      timerSeconds: num(lap.totalTimerTime) ?? 0,
      distance: num(lap.totalDistance) ?? 0,
      avgSpeed: num(lap.enhancedAvgSpeed) ?? num(lap.avgSpeed),
      avgHeartRate: average === null ? null : Math.trunc(average),
      maxHeartRate: maximum === null ? null : Math.trunc(maximum),
    }
  })
}

export function workoutStructure(workouts: FitMessage[], steps: FitMessage[], laps: FitMessage[], origin: number | null): WorkoutStructure {
  return { prescription: prescription(workouts[0], steps), laps: lapSummaries(laps, origin) }
}
