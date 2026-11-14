import { DAY_PATTERN, PLAIN_LIMITS, RACES } from './constants.js'
import { encodeManualPaces } from './domain/raceStrategy.js'
import type { RaceItem } from './types.js'

export interface RaceEdit {
  name: string
  day: string
  distance: number
  goalSeconds: number | null
  priority: string
  startTime: string | null
  city: string | null
  manualPaces: [number, number][] | undefined
}

const optionalText = (value: unknown, max: number): string | null | undefined =>
  value === null || value === undefined || value === '' ? null : typeof value === 'string' && value.trim().length <= max ? value.trim() : undefined

export function parseRaceEdit(value: Record<string, unknown> | undefined): RaceEdit | string {
  if (value === undefined) return 'invalid_body'
  const name = typeof value.name === 'string' ? value.name.trim() : ''
  if (name === '' || name.length > PLAIN_LIMITS.name) return 'invalid_race_name'
  if (typeof value.day !== 'string' || !DAY_PATTERN.test(value.day) || Number.isNaN(new Date(`${value.day}T12:00:00Z`).getTime())) return 'invalid_day'
  if (typeof value.distance !== 'number' || !(value.distance > 0) || value.distance > PLAIN_LIMITS.maxDistance) return 'invalid_distance'
  const goal = value.goalSeconds ?? null
  if (goal !== null && (typeof goal !== 'number' || !(goal > 0) || goal > PLAIN_LIMITS.maxSeconds)) return 'invalid_goal'
  if (!RACES.priorities.some((item) => item === value.priority)) return 'invalid_priority'
  const startTime = optionalText(value.startTime, 5)
  if (startTime === undefined || (startTime !== null && !RACES.startTimePattern.test(startTime))) return 'invalid_start_time'
  const city = optionalText(value.city, PLAIN_LIMITS.city)
  if (city === undefined) return 'invalid_city'
  let manualPaces: [number, number][] | undefined
  if (value.manualPaces !== undefined) {
    const list = value.manualPaces
    const valid = Array.isArray(list) && list.every((pair) => Array.isArray(pair) && pair.length === 2 && Number.isInteger(pair[0]) && pair[0] >= 0 && typeof pair[1] === 'number' && pair[1] > 0)
    if (!valid) return 'invalid_manual_paces'
    manualPaces = list as [number, number][]
  }
  return { name, day: value.day, distance: value.distance, goalSeconds: goal, priority: value.priority as string, startTime, city, manualPaces }
}

export function applyRaceEdit(current: RaceItem | null, id: string, edit: RaceEdit, updatedAt: string): RaceItem {
  const changedDay = current !== null && current.day !== edit.day
  return {
    ...(current ?? {}),
    id,
    name: edit.name,
    day: edit.day,
    distance: edit.distance,
    goalSeconds: edit.goalSeconds,
    priority: edit.priority,
    startTime: edit.startTime,
    city: edit.city,
    manualPacesData: edit.manualPaces === undefined ? (current?.manualPacesData ?? null) : encodeManualPaces(new Map(edit.manualPaces)),
    frozenTargetSeconds: changedDay ? null : (current?.frozenTargetSeconds ?? null),
    frozenTargetDay: changedDay ? null : (current?.frozenTargetDay ?? null),
    updatedAt,
  }
}
