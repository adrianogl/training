import type { FitSummary } from '../fit/fitTypes.js'
import type { ActivitySummary, GoalItem, HealthDay } from '../types.js'
import type { RunContinuity } from './analysisTypes.js'

export type DetailedKind = 'intervals' | 'tempo' | 'race' | 'long' | 'easy'

export interface DetailedRun {
  activity: ActivitySummary
  fit: FitSummary | null
}

export interface DetailedInput {
  current: DetailedRun
  runs: DetailedRun[]
  days: HealthDay[]
  goals: GoalItem[]
}

export interface KilometerPoint {
  km: number
  paceSeconds: number
  heartRate: number | null
}

export interface DetailedKpi {
  value: number | null
  similarAverage: number | null
}

export interface DetailedKpis {
  completion: DetailedKpi
  fadeKm: DetailedKpi
  hrDrift: DetailedKpi
}

export interface SimilarRun {
  activityId: number
  day: string
  completion: number | null
  fadeKm: number | null
  complete: boolean | null
  noPauses: boolean | null
}

export type FindingKey =
  | 'completion'
  | 'fadeKm'
  | 'hrDrift'
  | 'startPace'
  | 'readiness'
  | 'weekLoad'
  | 'hrAtPace'
  | 'pauses'
  | 'repsConsistency'
  | 'goal'

export type FindingValue = number | string | boolean | null

export interface DetailedFinding {
  key: FindingKey
  values: Record<string, FindingValue>
}

export type RecommendationKey = 'startPace' | 'gel' | 'swapDay' | 'easeWeek'

export interface DetailedRecommendation {
  key: RecommendationKey
  value: number
}

export type SourceKey = 'fit' | 'plan' | 'similar' | 'readiness' | 'goal'

export interface DetailedSource {
  key: SourceKey
  count: number
}

export interface DetailedAnalysis {
  kind: DetailedKind
  kpis: DetailedKpis
  splits: KilometerPoint[]
  fadeKm: number | null
  similar: SimilarRun[]
  findings: DetailedFinding[]
  recommendations: DetailedRecommendation[]
  sources: DetailedSource[]
}

export interface RunFacts {
  run: DetailedRun
  kind: DetailedKind
  splits: KilometerPoint[]
  fadeKm: number | null
  drift: number | null
  plannedMeters: number | null
  continuity: RunContinuity | null
}
