import { WORKOUT_TEXT } from './constants'
import { duration, kmNumber, paceClock } from './format'
import type { Activity, PlannedStep, PlannedWorkout } from './types'

export function matches(activity: Activity, query: string): boolean {
  const text = query.trim().toLowerCase()
  if (text === '') return true
  const km = activity.distanceMeters === null ? '' : `${kmNumber(activity.distanceMeters / 1000)} km`
  return `${activity.name} ${km}`.toLowerCase().includes(text)
}

export function plannedMatches(planned: PlannedWorkout, query: string): boolean {
  const text = query.trim().toLowerCase()
  return text === '' || planned.title.toLowerCase().includes(text)
}

export function plannedEstimate(planned: PlannedWorkout): string {
  const km = planned.estimatedMeters === null ? null : `${kmNumber(planned.estimatedMeters / 1000)} km`
  const time = planned.estimatedSeconds === null ? null : WORKOUT_TEXT.minutes(Math.round(planned.estimatedSeconds / 60))
  return [km, time].filter((part): part is string => part !== null).join(' · ')
}

function stepTarget(step: PlannedStep): string | null {
  const target = step.target
  if (target === null) return null
  if (target.kind === 'pace') return `${paceClock(target.fastest)}–${paceClock(target.slowest)}/km`
  if (target.kind === 'heartRate') return `${Math.round(target.low)}–${Math.round(target.high)} bpm`
  return WORKOUT_TEXT.zone(target.zone)
}

export function stepLine(step: PlannedStep): string {
  const amount = step.meters !== null ? (step.meters >= 1000 ? `${kmNumber(step.meters / 1000)} km` : `${Math.round(step.meters)} m`) : step.seconds !== null ? duration(step.seconds) : null
  return [WORKOUT_TEXT.stepKinds[step.kind], amount, stepTarget(step)].filter((part): part is string => part !== null).join(' · ')
}
