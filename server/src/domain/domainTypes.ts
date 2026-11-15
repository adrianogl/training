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

export type EffortKind = 'race' | 'split5k' | 'split1k' | 'threshold' | 'interval'

export type RunKind = 'intervals' | 'tempo' | 'race' | 'long' | 'easy'

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
  races: { key: string; seconds: number; day: string; name: string }[]
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

export interface ProjectionPoint {
  day: string
  mid: number
  low: number
  high: number
}

export interface Projection {
  points: ProjectionPoint[]
  targetCrossing: string | null
}

export type GoalAssessment = 'easy' | 'challenging' | 'aggressive'

export type GoalCrossing = { kind: 'on'; day: string } | { kind: 'alreadyBeaten' } | { kind: 'unreachable' } | { kind: 'noGoal' }

export interface RaceOutlook {
  distance: number
  label: string
  today: number | null
  raceDay: ProjectionPoint | null
  yearAgo: number | null
  series: SeriesPoint[]
  projection: ProjectionPoint[]
  longProjection: ProjectionPoint[]
  goalSeconds: number | null
  goalCrossing: GoalCrossing
  assessment: GoalAssessment | null
}

export type StrategyTargetSource = 'raceDayProjection' | 'todayPrediction' | 'goal' | 'frozen'

export interface StrategyTarget {
  seconds: number
  source: StrategyTargetSource
  frozenOn: string | null
}

export interface KmPlan {
  index: number
  pace: number
  grade: number
  label: string
  manual: boolean
}

export interface BlockWeek {
  start: string
  km: number
  projected: boolean
}

export interface ProfilePoint {
  distance: number
  altitude: number
}

export interface GpxPoint {
  latitude: number
  longitude: number
  altitude: number
}

export interface Lap {
  distance: number
  seconds: number
}

export interface Weather {
  hour: number
  temperature: number
  dewPoint: number
}

export interface HeatAdjustment {
  weather: Weather
  sumFahrenheit: number
  fraction: number
  tooHot: boolean
  adjustedSeconds: number
}

export type ChecklistStatus = 'ok' | 'attention' | 'missing'

export type ChecklistItem =
  | { kind: 'weeklyVolume'; status: ChecklistStatus; targetKm: number; averageKm: number | null }
  | { kind: 'racePace'; status: ChecklistStatus; targetKm: number; doneKm: number; pace: number | null }
  | { kind: 'tuneUp'; status: ChecklistStatus; distanceKm: number; best: { day: string; km: number; pace: number } | null }
  | { kind: 'course'; status: ChecklistStatus; km: number | null; gain: number | null }
  | { kind: 'goal'; status: ChecklistStatus; goalSeconds: number | null; priority: string }

export interface ChecklistRun {
  day: string
  distance: number | null
  seconds: number | null
  laps: Lap[]
}

export type WeatherNote = 'tooFar' | 'noLocation' | 'unavailable' | null

export interface RaceStrategy {
  target: StrategyTarget | null
  heat: HeatAdjustment | null
  weatherNote: WeatherNote
  kms: KmPlan[]
}

export interface RaceView {
  id: string
  locked: boolean
  name: string | null
  day: string | null
  startTime: string | null
  distance: number | null
  goalSeconds: number | null
  priority: string | null
  city: string | null
  hasCourse: boolean
  manualPaces: [number, number][]
  status: 'upcoming' | 'done' | 'locked'
  daysUntil: number | null
  result: { activityId: number; seconds: number; distance: number; day: string } | null
  outlook: Omit<RaceOutlook, 'longProjection'> | null
  strategy: RaceStrategy | null
  block: BlockWeek[]
  checklist: ChecklistItem[]
}

export interface TimeGoalProgress {
  kind: 'time'
  todaySeconds: number | null
  gapSeconds: number | null
  crossing: GoalCrossing
  achievedOn: string | null
}

export interface LongRunCheck {
  activityId: number
  day: string
  distanceKm: number
  longestContinuousKm: number | null
  pauses: { km: number; seconds: number }[] | null
  paceSecondsPerKm: number | null
  met: boolean | null
}

export interface LongGoalProgress {
  kind: 'continuousLong'
  runs: LongRunCheck[]
  metCount: number
  bestContinuousKm: number | null
  achievedOn: string | null
}

export type GoalProgress = TimeGoalProgress | LongGoalProgress
