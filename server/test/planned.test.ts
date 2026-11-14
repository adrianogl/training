import { describe, expect, it } from 'vitest'
import { flattened, monthsBetween, plannedWorkout, runItems } from '../src/planned/planned.js'
import type { CalendarItem, WorkoutDto } from '../src/planned/plannedTypes.js'

const calendar: CalendarItem[] = [
  { itemType: 'workout', date: '2026-11-13', title: 'Intervalado 5x1000', workoutId: 10, sportTypeKey: 'running' },
  { itemType: 'workout', date: '2026-11-13', title: 'Intervalado 5x1000', workoutId: 10, sportTypeKey: 'running' },
  { itemType: 'workout', date: '2026-11-12', title: 'Natação', workoutId: 11, sportTypeKey: 'swimming' },
  { itemType: 'workout', date: '2026-11-20', title: 'Fora da semana', workoutId: 12, sportTypeKey: 'running' },
  { itemType: 'activity', date: '2026-11-10', title: 'Corrida', sportTypeKey: 'running' },
]

const workout: WorkoutDto = {
  workoutId: 10, workoutName: 'Intervalado 5x1000', estimatedDistanceInMeters: 9800, estimatedDurationInSecs: 3300,
  workoutSegments: [{ workoutSteps: [
    { type: 'ExecutableStepDTO', stepType: { stepTypeKey: 'warmup' }, endCondition: { conditionTypeKey: 'time' }, endConditionValue: 900, targetType: { workoutTargetTypeKey: 'pace.zone' }, targetValueOne: 2.6315, targetValueTwo: 2.8571 },
    { type: 'RepeatGroupDTO', numberOfIterations: 5, workoutSteps: [
      { type: 'ExecutableStepDTO', stepType: { stepTypeKey: 'interval' }, endCondition: { conditionTypeKey: 'distance' }, endConditionValue: 1000, targetType: { workoutTargetTypeKey: 'pace.zone' }, targetValueOne: 4, targetValueTwo: 4.1666 },
      { type: 'ExecutableStepDTO', stepType: { stepTypeKey: 'recovery' }, endCondition: { conditionTypeKey: 'time' }, endConditionValue: 120, targetType: { workoutTargetTypeKey: 'no.target' } },
    ] },
    { type: 'ExecutableStepDTO', stepType: { stepTypeKey: 'cooldown' }, endCondition: { conditionTypeKey: 'time' }, endConditionValue: 600, targetType: { workoutTargetTypeKey: 'heart.rate.zone' }, zoneNumber: 2 },
  ] }],
}

describe('treinos planejados (paridade com PlannedWorkoutsTests)', () => {
  it('só corridas da janela, uma vez', () => {
    expect(runItems(calendar, '2026-11-09', '2026-11-15').map((item) => item.workoutId)).toEqual([10])
  })

  it('passos, repetições e alvos', () => {
    const planned = plannedWorkout(workout, '2026-11-13', null)
    expect([planned.title, planned.estimatedMeters, planned.steps.length]).toEqual(['Intervalado 5x1000', 9800, 3])
    const warmup = planned.steps[0]!
    expect([warmup.kind, warmup.seconds]).toEqual(['warmup', 900])
    expect(warmup.target?.kind).toBe('pace')
    if (warmup.target?.kind === 'pace') {
      expect(Math.abs(warmup.target.fastest - 350)).toBeLessThan(1)
      expect(Math.abs(warmup.target.slowest - 380)).toBeLessThan(1)
    }
    expect(planned.steps[1]?.repeats).toBe(5)
    expect(planned.steps[1]?.children.map((c) => c.kind)).toEqual(['active', 'recovery'])
    expect(planned.steps[1]?.children[0]?.meters).toBe(1000)
    expect(planned.steps[1]?.children[1]?.target).toBeNull()
    expect(planned.steps[2]?.target).toEqual({ kind: 'zone', zone: 2 })
    expect(planned.steps.flatMap(flattened)).toHaveLength(12)
  })

  it('estima distância e tempo quando a Garmin manda só os passos', () => {
    const planned = plannedWorkout({ workoutId: 30, workoutName: 'Rodagem 40 min', workoutSegments: [{ workoutSteps: [
      { type: 'ExecutableStepDTO', stepType: { stepTypeKey: 'warmup' }, endCondition: { conditionTypeKey: 'time' }, endConditionValue: 600 },
      { type: 'ExecutableStepDTO', stepType: { stepTypeKey: 'interval' }, endCondition: { conditionTypeKey: 'time' }, endConditionValue: 1800, targetType: { workoutTargetTypeKey: 'pace.zone' }, targetValueOne: 3.0303, targetValueTwo: 3.3333 },
      { type: 'ExecutableStepDTO', stepType: { stepTypeKey: 'cooldown' }, endCondition: { conditionTypeKey: 'distance' }, endConditionValue: 1000 },
    ] }] }, '2026-11-14', null)
    expect(Math.abs((planned.estimatedMeters ?? 0) - ((600 / 360) * 1000 + (1800 / 315) * 1000 + 1000))).toBeLessThan(5)
    expect(Math.abs((planned.estimatedSeconds ?? 0) - (600 + 1800 + 375))).toBeLessThan(2)
  })

  it('meses do calendário', () => {
    expect(monthsBetween('2026-11-20', '2026-12-04')).toEqual([[2026, 11], [2026, 12]])
    expect(monthsBetween('2026-11-01', '2026-11-15')).toEqual([[2026, 11]])
  })
})
