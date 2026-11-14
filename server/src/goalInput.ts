import { DAY_PATTERN, GOALS } from './constants.js'
import type { GoalItem, GoalKind } from './types.js'

export interface GoalEdit {
  kind: GoalKind
  distanceKm: number
  targetSeconds: number | null
  deadline: string | null
  paceSecondsPerKm: number | null
  archived: boolean
}

const isDay = (value: unknown): value is string =>
  typeof value === 'string' && DAY_PATTERN.test(value) && !Number.isNaN(new Date(`${value}T12:00:00Z`).getTime())

export function parseGoalEdit(value: Record<string, unknown> | undefined): GoalEdit | string {
  if (value === undefined) return 'invalid_body'
  const kind = GOALS.kinds.find((item) => item === value.kind)
  if (kind === undefined) return 'invalid_goal_kind'
  if (typeof value.distanceKm !== 'number' || !(value.distanceKm > 0) || value.distanceKm > GOALS.maxDistanceKm) return 'invalid_distance'
  const archived = value.archived ?? false
  if (typeof archived !== 'boolean') return 'invalid_archived'
  if (kind === 'time') {
    const target = value.targetSeconds
    if (typeof target !== 'number' || target < GOALS.minTargetSeconds || target > GOALS.maxTargetSeconds) return 'invalid_target_time'
    const deadline = value.deadline ?? null
    if (deadline !== null && !isDay(deadline)) return 'invalid_deadline'
    return { kind, distanceKm: value.distanceKm, targetSeconds: target, deadline, paceSecondsPerKm: null, archived }
  }
  const pace = value.paceSecondsPerKm
  if (typeof pace !== 'number' || pace < GOALS.minPaceSecondsPerKm || pace > GOALS.maxPaceSecondsPerKm) return 'invalid_target_pace'
  return { kind, distanceKm: value.distanceKm, targetSeconds: null, deadline: null, paceSecondsPerKm: pace, archived }
}

export function deadlineError(edit: GoalEdit, current: GoalItem | null, today: string): string | null {
  if (edit.deadline === null) return null
  const earliest = current === null ? today : current.createdAt.slice(0, 10)
  return edit.deadline < earliest ? 'invalid_deadline' : null
}

export function applyGoalEdit(current: GoalItem | null, id: string, edit: GoalEdit, updatedAt: string): GoalItem {
  const sameTarget =
    current !== null &&
    current.kind === edit.kind &&
    current.distanceKm === edit.distanceKm &&
    current.targetSeconds === edit.targetSeconds &&
    current.paceSecondsPerKm === edit.paceSecondsPerKm
  return {
    id,
    kind: edit.kind,
    distanceKm: edit.distanceKm,
    targetSeconds: edit.targetSeconds,
    deadline: edit.deadline,
    paceSecondsPerKm: edit.paceSecondsPerKm,
    archived: edit.archived,
    achievedAt: sameTarget ? current.achievedAt : null,
    createdAt: current?.createdAt ?? updatedAt,
    updatedAt,
  }
}
