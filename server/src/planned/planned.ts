import { PLANNED } from './plannedConstants.js'
import type { CalendarItem, PlannedStep, PlannedTarget, PlannedWorkout, StepDto, WorkoutDto } from './plannedTypes.js'

const num = (value: unknown): number | null => (typeof value === 'number' && Number.isFinite(value) ? value : null)

export function flattened(step: PlannedStep): PlannedStep[] {
  if (step.children.length === 0) return [step]
  const body = step.children.flatMap(flattened)
  return Array.from({ length: Math.max(step.repeats, 1) }, () => body).flat()
}

export function runItems(items: CalendarItem[], first: string, last: string): CalendarItem[] {
  const seen = new Set<number>()
  return items.filter((item) => {
    const id = item.workoutId
    if (item.itemType !== PLANNED.workoutItem || item.sportTypeKey !== PLANNED.runSport || item.date === undefined || item.date < first || item.date > last || id === undefined || seen.has(id)) return false
    seen.add(id)
    return true
  })
}

function target(dto: StepDto): PlannedTarget | null {
  const zone = num(dto.zoneNumber)
  const one = num(dto.targetValueOne)
  const two = num(dto.targetValueTwo)
  switch (dto.targetType?.workoutTargetTypeKey) {
    case PLANNED.paceTarget: {
      if (one === null || two === null || one <= 0 || two <= 0) return null
      const paces = [1000 / one, 1000 / two]
      return { kind: 'pace', fastest: Math.min(...paces), slowest: Math.max(...paces) }
    }
    case PLANNED.heartRateTarget:
      if (one !== null && two !== null) return { kind: 'heartRate', low: Math.min(one, two), high: Math.max(one, two) }
      return zone === null ? null : { kind: 'zone', zone }
    default:
      return zone === null ? null : { kind: 'zone', zone }
  }
}

export function plannedStep(dto: StepDto): PlannedStep {
  if (dto.type === PLANNED.repeatType) {
    return { kind: 'other', seconds: null, meters: null, target: null, repeats: num(dto.numberOfIterations) ?? 1, children: (dto.workoutSteps ?? []).map(plannedStep) }
  }
  const condition = dto.endCondition?.conditionTypeKey
  return {
    kind: PLANNED.kinds[dto.stepType?.stepTypeKey ?? ''] ?? 'other',
    seconds: condition === PLANNED.timeCondition ? num(dto.endConditionValue) : null,
    meters: condition === PLANNED.distanceCondition ? num(dto.endConditionValue) : null,
    target: target(dto),
    repeats: 1,
    children: [],
  }
}

function pace(step: PlannedStep): number {
  return step.target?.kind === 'pace' ? (step.target.fastest + step.target.slowest) / 2 : PLANNED.defaultPaces[step.kind]
}

export function estimate(steps: PlannedStep[]): { meters: number; seconds: number } | null {
  let meters = 0
  let seconds = 0
  for (const step of steps) {
    const value = pace(step)
    if (step.meters !== null) {
      meters += step.meters
      seconds += (step.meters / 1000) * value
    } else if (step.seconds !== null) {
      seconds += step.seconds
      meters += value > 0 ? (step.seconds / value) * 1000 : 0
    }
  }
  return meters > 0 ? { meters, seconds } : null
}

export function plannedWorkout(dto: WorkoutDto, day: string, fallbackTitle: string | null): PlannedWorkout {
  const steps = (dto.workoutSegments ?? []).flatMap((segment) => (segment.workoutSteps ?? []).map(plannedStep))
  const guess = estimate(steps.flatMap(flattened))
  return {
    id: dto.workoutId,
    day,
    title: dto.workoutName ?? fallbackTitle ?? '',
    estimatedSeconds: num(dto.estimatedDurationInSecs) ?? guess?.seconds ?? null,
    estimatedMeters: num(dto.estimatedDistanceInMeters) ?? guess?.meters ?? null,
    steps,
  }
}

export function monthsBetween(first: string, last: string): [number, number][] {
  const months: [number, number][] = []
  for (const day of [first, last]) {
    const pair: [number, number] = [Number(day.slice(0, 4)), Number(day.slice(5, 7))]
    if (!months.some(([y, m]) => y === pair[0] && m === pair[1])) months.push(pair)
  }
  return months
}
