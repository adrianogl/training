export interface FitSample {
  t: number
  heartRate: number | null
  speed: number | null
  altitude: number | null
  distance: number | null
}

export interface Coordinate {
  lat: number
  lon: number
}

export interface PhysioMetrics {
  vo2max: number | null
  recoveryMinutes: number | null
  performanceCondition: number | null
}

export interface HeartRateZoneInfo {
  thresholdHeartRate: number | null
  maxHeartRate: number | null
  restingHeartRate: number | null
  calcType: number | null
  floors: number[]
}

export type StepIntensity = 'warmup' | 'active' | 'recovery' | 'cooldown' | 'rest' | 'other'

export type StepDuration = { kind: 'distance'; meters: number } | { kind: 'time'; seconds: number } | { kind: 'open' } | { kind: 'repeatSteps'; fromIndex: number; count: number }

export type StepTarget =
  | { kind: 'open' }
  | { kind: 'speed'; low: number; high: number }
  | { kind: 'heartRateBpm'; low: number; high: number }
  | { kind: 'heartRatePercentMax'; low: number; high: number }
  | { kind: 'heartRateZone'; zone: number }

export interface PrescribedStep {
  index: number
  intensity: StepIntensity
  duration: StepDuration
  target: StepTarget
}

export interface WorkoutPrescription {
  name: string | null
  description: string | null
  steps: PrescribedStep[]
}

export interface LapSummary {
  stepIndex: number | null
  intensity: StepIntensity | null
  trigger: string | null
  startOffset: number
  timerSeconds: number
  distance: number
  avgSpeed: number | null
  avgHeartRate: number | null
  maxHeartRate: number | null
}

export interface WorkoutStructure {
  prescription: WorkoutPrescription | null
  laps: LapSummary[]
}

export interface FitSummary {
  version: number
  samples: FitSample[]
  route: Coordinate[]
  physio: PhysioMetrics | null
  structure: WorkoutStructure
  zoneInfo: HeartRateZoneInfo | null
}

export type FitMessage = Record<string, unknown>

export interface WorkPace {
  seconds: number
  meters: number
}

export interface RunShape {
  name: string | null
  hasRepeats: boolean
  hasHardActiveStep: boolean
  hasRepeatedActiveLaps: boolean
}

export interface RunMetrics {
  zone2Pace: number | null
  thresholdPace: number | null
  decoupling: number | null
  hillIndex: number | null
  workPace?: WorkPace | null
  shape?: RunShape
}
