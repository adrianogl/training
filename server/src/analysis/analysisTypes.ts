import type { FitSummary, LapSummary, PrescribedStep } from '../fit/fitTypes.js'

export interface HeartRateZones {
  floors: number[]
  maxHeartRate: number | null
}

export type BlockKind = 'warmup' | 'active' | 'recovery' | 'cooldown'

export type BlockStatus = 'inTarget' | 'faster' | 'slower' | 'aboveTarget' | 'belowTarget' | 'noTarget' | 'incomplete' | 'notExecuted'

export interface WorkoutBlock {
  kind: BlockKind
  ordinal: number
  label: string
  prescribed: PrescribedStep | null
  laps: LapSummary[]
  seconds: number
  distance: number
  avgSpeed: number | null
  avgHeartRate: number | null
  maxHeartRate: number | null
  dominantZone: number | null
  status: BlockStatus
}

export type BlockKilometers = Map<number, WorkoutBlock[]>

export interface TrackPoint {
  t: number
  distance: number
  heartRate: number | null
}

export interface ExpectedStep {
  step: PrescribedStep
  insideRepeat: boolean
}

export interface LapGroup {
  stepIndex: number | null
  laps: LapSummary[]
}

export type FindingGroup = 'positive' | 'negative' | 'attention'

export type FindingKind =
  | 'blockInTarget' | 'steadyPace' | 'lowerHeartRateThanBefore' | 'goodRecovery'
  | 'blockOffTarget' | 'stepIncomplete' | 'paceFade'
  | 'cardiacDrift' | 'zoneAboveTarget' | 'hardOnLowReadiness' | 'highAcuteChronic'

export interface Finding {
  group: FindingGroup
  kind: FindingKind
  blockOrdinal: number | null
  facts: Record<string, number>
}

export interface WorkoutAssessment {
  positives: Finding[]
  negatives: Finding[]
  attention: Finding[]
}

export interface AssessmentContext {
  readinessScore: number | null
  acuteChronic: number | null
  previous: WorkoutBlock[][]
  kilometers: BlockKilometers
}

export interface WorkoutOccurrence {
  activityId: number
  day: string
  blocks: WorkoutBlock[]
}

export interface BlockValue {
  speed: number | null
  heartRate: number | null
  status: BlockStatus
}

export interface BlockComparison {
  label: string
  values: Record<string, BlockValue>
}

export interface WorkoutComparison {
  occurrences: number[]
  blocks: BlockComparison[]
  sameStructure: boolean
  activeSpeedDelta: number | null
  activeHeartRateDelta: number | null
}

export type ScorePart = 'execution' | 'intent' | 'cost'

export type ScoreReason =
  | 'blocksOffTarget' | 'incompleteStep' | 'notExecuted' | 'easyTooHard' | 'hardTooEasy' | 'heartRateTargetMissed'
  | 'lessEfficient' | 'moreEfficient' | 'noHeartRate' | 'noZones' | 'noHistory' | 'noPrescription'

export interface ScoreItem {
  part: ScorePart
  points: number
  maximum: number
  reason: ScoreReason | null
}

export interface WorkoutScore {
  value: number
  items: ScoreItem[]
}

export interface EvolutionFacts {
  paceDelta: number
  heartRateDelta: number | null
  oldestDate: string
}

export interface NarratedFinding {
  group: FindingGroup
  kind: FindingKind
  blockOrdinal: number | null
  text: string
  evidence: string | null
  why: string
}

export interface ComparisonRow {
  activityId: number
  day: string
  isCurrent: boolean
  secondsPerKilometer: number | null
  heartRate: number | null
  inTarget: { done: number; total: number } | null
}

export interface WorkoutAnalysis {
  isRun: boolean
  hasPrescription: boolean
  workoutName: string | null
  zones: HeartRateZones | null
  zoneSeconds: number[] | null
  blocks: WorkoutBlock[]
  kilometers: { block: number; rows: WorkoutBlock[] }[]
  splits: WorkoutBlock[]
  chart: { t: number; distance: number | null; heartRate: number | null; speed: number | null; altitude: number | null }[]
  route: { lat: number; lon: number }[]
  findings: NarratedFinding[]
  score: WorkoutScore | null
  comparison: { rows: ComparisonRow[]; notice: string | null; evolution: string | null } | null
}

export interface AnalysisInput {
  activityId: number
  day: string
  distance: number | null
  movingSeconds: number | null
  averageHeartRate: number | null
  isRun: boolean
  fit: FitSummary | null
  readinessScore: number | null
  acuteChronic: number | null
  previous: { activityId: number; day: string; distance: number | null; movingSeconds: number | null; averageHeartRate: number | null; fit: FitSummary }[]
}
