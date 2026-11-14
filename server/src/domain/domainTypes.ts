import type { COMPONENTS } from './domainConstants.js'

export type ReadinessComponent = (typeof COMPONENTS)[number]

export type ReadinessVerdict = 'rest' | 'moderate' | 'hard'

export interface HRVBaseline {
  lowUpper: number
  balancedLow: number
  balancedUpper: number
}

export interface ReadinessInput {
  hrvLastNight: number | null
  hrvBaseline: HRVBaseline | null
  sleepScore: number | null
  bodyBatteryMorningMax: number | null
  acuteChronic: number | null
}

export interface Readiness {
  score: number
  partial: boolean
  verdict: ReadinessVerdict
}

export interface ReadinessFactor {
  component: ReadinessComponent
  todayScore: number | null
  normalScore: number | null
  points: number | null
  weight: number
}

export interface ReadinessBreakdown {
  score: number
  normal: number | null
  verdict: ReadinessVerdict
  factors: ReadinessFactor[]
}

export interface FFFPoint {
  day: string
  fitness: number
  fatigue: number
  form: number
}

export interface LoadFocus {
  lowAerobic: number
  highAerobic: number
  anaerobic: number
}

export interface WeekVolume {
  perDay: Record<string, number>
  total: number
  lastWeek: number
  average4Weeks: number
  recentWeeks: { start: string; kilometers: number }[]
}

export interface TodaySummary {
  day: string
  readiness: ReadinessBreakdown | null
  raw: {
    hrvLastNight: number | null
    hrvBalancedLow: number | null
    hrvBalancedUpper: number | null
    sleepScore: number | null
    sleepSeconds: number | null
    bodyBatteryMorningMax: number | null
    acuteChronic: number | null
    restingHeartRate: number | null
    stress: number | null
  }
  recoveryMinutes: number | null
  garminReadiness: number | null
  fitness: FFFPoint | null
  week: WeekVolume
  focus: LoadFocus | null
}

export type EffortKind = 'race' | 'split5k' | 'split1k'

export interface Effort {
  distance: number
  seconds: number
  day: string
  kind: EffortKind
}

export type SeriesPoint = [string, number]

export interface MetricStats {
  current: number | null
  average: number | null
  minimum: number | null
  maximum: number | null
  change: number | null
}

export interface MetricSeries {
  key: string
  points: SeriesPoint[]
  movingAverage: SeriesPoint[]
  stats: MetricStats
  band: [number, number] | null
}

export interface Records {
  fastestKm: { seconds: number; day: string; name: string } | null
  fastest5k: { seconds: number; day: string; name: string } | null
  longestRun: { meters: number; day: string; name: string } | null
  biggestWeek: { kilometers: number; start: string } | null
}

export interface WeekTotals {
  start: string
  kilometers: number
  zoneSeconds: number[]
}

export interface Evolution {
  day: string
  periodDays: number
  series: MetricSeries[]
  weeks: WeekTotals[]
  predictions: { key: string; label: string; seconds: number | null; change: number | null }[]
  records: Records
}
