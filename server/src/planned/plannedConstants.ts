export const PLANNED = {
  runSport: 'running',
  workoutItem: 'workout',
  repeatType: 'RepeatGroupDTO',
  timeCondition: 'time',
  distanceCondition: 'distance',
  paceTarget: 'pace.zone',
  heartRateTarget: 'heart.rate.zone',
  defaultPaces: { warmup: 360, active: 300, recovery: 390, cooldown: 375, rest: 0, other: 345 },
  kinds: { warmup: 'warmup', interval: 'active', recovery: 'recovery', cooldown: 'cooldown', rest: 'rest' } as Record<string, PlannedStepKindName>,
  calendarPath: (year: number, month: number) => `/calendar-service/year/${year}/month/${month - 1}`,
  workoutPath: (id: number) => `/workout-service/workout/${id}`,
  daysAhead: 14,
} as const

type PlannedStepKindName = 'warmup' | 'active' | 'recovery' | 'cooldown' | 'rest' | 'other'
