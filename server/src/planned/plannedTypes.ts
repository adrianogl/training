export type PlannedStepKind = 'warmup' | 'active' | 'recovery' | 'cooldown' | 'rest' | 'other'

export type PlannedTarget = { kind: 'pace'; fastest: number; slowest: number } | { kind: 'heartRate'; low: number; high: number } | { kind: 'zone'; zone: number }

export interface PlannedStep {
  kind: PlannedStepKind
  seconds: number | null
  meters: number | null
  target: PlannedTarget | null
  repeats: number
  children: PlannedStep[]
}

export interface PlannedWorkout {
  id: number
  day: string
  title: string
  estimatedSeconds: number | null
  estimatedMeters: number | null
  steps: PlannedStep[]
}

export interface CalendarItem {
  itemType?: string
  date?: string
  title?: string
  workoutId?: number
  sportTypeKey?: string
}

export interface StepDto {
  type?: string
  stepType?: { stepTypeKey?: string }
  endCondition?: { conditionTypeKey?: string }
  endConditionValue?: number
  targetType?: { workoutTargetTypeKey?: string }
  targetValueOne?: number
  targetValueTwo?: number
  zoneNumber?: number
  numberOfIterations?: number
  workoutSteps?: StepDto[]
}

export interface WorkoutDto {
  workoutId: number
  workoutName?: string
  estimatedDistanceInMeters?: number
  estimatedDurationInSecs?: number
  workoutSegments?: { workoutSteps?: StepDto[] }[]
}
