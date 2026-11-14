import type { AssessmentContext, HeartRateZones, WorkoutBlock } from '../src/analysis/analysisTypes.js'
import type { LapSummary, PrescribedStep, StepDuration, StepIntensity, StepTarget, WorkoutStructure } from '../src/fit/fitTypes.js'

export type Plan = [step: number | null, intensity: StepIntensity | null, count: number, seconds: number, meters: number]

export const zones: HeartRateZones = { floors: [100, 120, 140, 160, 175], maxHeartRate: 190 }

export const open: StepTarget = { kind: 'open' }
export const openDuration: StepDuration = { kind: 'open' }
export const speed = (low: number, high: number): StepTarget => ({ kind: 'speed', low, high })
export const bpm = (low: number, high: number): StepTarget => ({ kind: 'heartRateBpm', low, high })
export const percentMax = (low: number, high: number): StepTarget => ({ kind: 'heartRatePercentMax', low, high })
export const hrZone = (zone: number): StepTarget => ({ kind: 'heartRateZone', zone })
export const distance = (meters: number): StepDuration => ({ kind: 'distance', meters })
export const time = (seconds: number): StepDuration => ({ kind: 'time', seconds })
export const repeat = (fromIndex: number, count: number): StepDuration => ({ kind: 'repeatSteps', fromIndex, count })

export const step = (index: number, intensity: StepIntensity, duration: StepDuration, target: StepTarget = open): PrescribedStep => ({ index, intensity, duration, target })

export function lap(values: Partial<LapSummary> & { startOffset: number; timerSeconds: number; distance: number }): LapSummary {
  return { stepIndex: null, intensity: null, trigger: null, avgSpeed: null, avgHeartRate: null, maxHeartRate: null, ...values }
}

export function laps(plan: Plan[], heartRate: number | null = 150): LapSummary[] {
  let offset = 0
  const result: LapSummary[] = []
  for (const [stepIndex, intensity, count, seconds, meters] of plan) {
    for (let index = 0; index < count; index += 1) {
      result.push({ stepIndex, intensity, trigger: 'distance', startOffset: offset, timerSeconds: seconds, distance: meters, avgSpeed: meters / seconds, avgHeartRate: heartRate, maxHeartRate: heartRate === null ? null : heartRate + 15 })
      offset += seconds
    }
  }
  return result
}

export function structure(steps: PrescribedStep[] | null, executed: LapSummary[], name: string | null = null): WorkoutStructure {
  return { prescription: steps === null ? null : { name, description: null, steps }, laps: executed }
}

export const singleStep = (target: StepTarget, seconds: number, meters: number, heartRate: number | null = null) =>
  structure([step(0, 'active', openDuration, target)], laps([[0, 'active', 1, seconds, meters]], heartRate))

export function block(values: Partial<WorkoutBlock> = {}): WorkoutBlock {
  return {
    kind: 'active', ordinal: 1, label: 'Bloco 1', prescribed: null, laps: [], seconds: 1250, distance: 5000,
    avgSpeed: 4, avgHeartRate: 150, maxHeartRate: 165, dominantZone: 2, status: 'noTarget', ...values,
  }
}

export function paceLaps(paces: number[], heartRates?: number[], meters = 1000): LapSummary[] {
  let offset = 0
  return paces.map((pace, index) => {
    const seconds = (pace * meters) / 1000
    const lapValue: LapSummary = { stepIndex: 1, intensity: 'active', trigger: null, startOffset: offset, timerSeconds: seconds, distance: meters, avgSpeed: meters / seconds, avgHeartRate: heartRates?.[index] ?? null, maxHeartRate: null }
    offset += seconds
    return lapValue
  })
}

export const emptyContext = (values: Partial<AssessmentContext> = {}): AssessmentContext => ({ readinessScore: null, acuteChronic: null, previous: [], kilometers: new Map(), ...values })
