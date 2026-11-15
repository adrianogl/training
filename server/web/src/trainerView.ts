import { TRAINER_TEXT } from './constants'
import { dayMonth, kmNumber, paceClock, shiftDay } from './format'
import { distanceText, paceRange } from './trainerSteps'
import type {
  TrainerChange,
  TrainerDayLine,
  TrainerDayTag,
  TrainerPaces,
  TrainerPhase,
  TrainerPlan,
  TrainerStep,
  TrainerStrength,
  TrainerTarget,
  TrainerTrigger,
  TrainerTriggerKind,
  TrainerVersion,
  TrainerWeek,
  TrainerWeekCell,
  TrainerWorkout,
} from './types'

type Raw = Record<string, unknown>

const PHASES: readonly TrainerPhase[] = ['general', 'base', 'build', 'specific', 'taper']
const TRIGGERS: readonly TrainerTriggerKind[] = ['created', 'weekEnded', 'workout', 'request', 'strengthChanged', 'lightWeek', 'longModeChanged', 'edited', 'readiness']
const DAY_KINDS = ['easy', 'threshold', 'vo2max', 'optionalEasy', 'long', 'off', 'race'] as const
const STEP_KINDS = ['warmup', 'work', 'recovery', 'cooldown', 'steady'] as const
const METHODS = ['cruiseIntervals', 'tempo', 'intervals', 'repetition', 'racePace', 'goalPace'] as const
const WEEK_DAYS = 7
const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/

function isRaw(value: unknown): value is Raw {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function number(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null
}

function text(value: unknown): string | null {
  return typeof value === 'string' ? value : null
}

function day(value: unknown): string | null {
  return typeof value === 'string' && DAY_PATTERN.test(value) ? value : null
}

function oneOf<T extends string>(value: unknown, options: readonly T[]): T | null {
  return options.find((option) => option === value) ?? null
}

function list<T>(value: unknown, parse: (item: Raw) => T | null): T[] {
  return Array.isArray(value) ? value.flatMap((item) => (isRaw(item) ? (parse(item) ?? []) : [])) : []
}

function parseStep(raw: Raw): TrainerStep | null {
  const kind = oneOf(raw.kind, STEP_KINDS)
  const meters = number(raw.meters)
  if (kind === null || meters === null) return null
  return {
    kind,
    repeats: number(raw.repeats) ?? 1,
    meters,
    restSeconds: number(raw.restSeconds),
    paceLow: number(raw.paceLow),
    paceHigh: number(raw.paceHigh),
    method: oneOf(raw.method, METHODS),
  }
}

function parseWorkout(raw: Raw): TrainerWorkout | null {
  const date = day(raw.day)
  const kind = oneOf(raw.kind, DAY_KINDS)
  const title = text(raw.title)
  if (date === null || kind === null || title === null) return null
  return {
    day: date,
    kind,
    title,
    totalMeters: number(raw.totalMeters) ?? 0,
    steps: list(raw.steps, parseStep),
    paceLow: number(raw.paceLow),
    paceHigh: number(raw.paceHigh),
    note: text(raw.note),
    rationale: text(raw.rationale) ?? '',
    method: oneOf(raw.method, METHODS),
    edited: raw.edited === true,
  }
}

function parseWeek(raw: Raw): TrainerWeek | null {
  const index = number(raw.index)
  const start = day(raw.start)
  if (index === null || start === null) return null
  return {
    index,
    start,
    phase: oneOf(raw.phase, PHASES) ?? 'base',
    isRecovery: raw.isRecovery === true,
    plannedMeters: number(raw.plannedMeters) ?? 0,
    longMeters: number(raw.longMeters) ?? 0,
  }
}

function parseTrigger(raw: unknown): TrainerTrigger {
  const entry = isRaw(raw) ? Object.entries(raw)[0] : undefined
  const kind = oneOf(entry?.[0], TRIGGERS) ?? 'created'
  const payload = entry?.[1]
  const body = isRaw(payload) ? payload : {}
  const value = body._0
  if (kind === 'edited') return { kind, day: null, number: isRaw(value) && Array.isArray(value.days) ? value.days.length : 0 }
  return { kind, day: day(body.day) ?? day(value), number: number(body.score) ?? number(value) }
}

function parseChange(raw: Raw): TrainerChange | null {
  const title = text(raw.title)
  return title === null ? null : { kind: text(raw.kind) ?? 'changed', title, before: text(raw.before), after: text(raw.after), reason: text(raw.reason) ?? '' }
}

function parseVersion(raw: Raw): TrainerVersion | null {
  const version = number(raw.number)
  const createdAt = text(raw.createdAt)
  if (version === null || createdAt === null) return null
  return { number: version, createdAt, trigger: parseTrigger(raw.trigger), summary: text(raw.summary) ?? '', changes: list(raw.changes, parseChange) }
}

function parseTarget(raw: unknown): TrainerTarget | null {
  if (!isRaw(raw)) return null
  const name = text(raw.name)
  return name === null
    ? null
    : { name, date: day(raw.date), distanceMeters: number(raw.distanceMeters), goalSeconds: number(raw.goalSeconds), goalPace: number(raw.goalPace) }
}

function parsePaces(raw: unknown): TrainerPaces | null {
  if (!isRaw(raw)) return null
  const [easy, long, threshold, vo2max] = [number(raw.easy), number(raw.long), number(raw.threshold), number(raw.vo2max)]
  return easy === null || long === null || threshold === null || vo2max === null ? null : { easy, long, threshold, vo2max, race: number(raw.race) }
}

function parseStrength(raw: Raw): TrainerStrength | null {
  const weekday = number(raw.weekday)
  const name = text(raw.name)
  return weekday === null || name === null ? null : { weekday, name }
}

export function parseTrainerPlan(raw: unknown): TrainerPlan | null {
  if (!isRaw(raw)) return null
  const target = parseTarget(raw.target)
  const paces = parsePaces(raw.paces)
  if (target === null || paces === null) return null
  return {
    target,
    paces,
    weeks: list(raw.weeks, parseWeek).sort((a, b) => a.index - b.index),
    workouts: list(raw.workouts, parseWorkout).sort((a, b) => a.day.localeCompare(b.day)),
    versions: list(raw.versions, parseVersion).sort((a, b) => a.number - b.number),
    strength: list(raw.strength, parseStrength),
    lightWeeks: Array.isArray(raw.lightWeeks) ? raw.lightWeeks.flatMap((item) => day(item) ?? []) : [],
    longMode: raw.longMode === 'blocks' ? 'blocks' : 'continuous',
    longStage: number(raw.longStage) ?? 1,
  }
}

function weekday(date: string): number {
  return new Date(`${date}T12:00:00Z`).getUTCDay()
}

export function weekdayShort(date: string): string {
  return TRAINER_TEXT.weekdays[weekday(date)] ?? ''
}

export function weekRange(start: string): string {
  const end = shiftDay(start, WEEK_DAYS - 1)
  return start.slice(5, 7) === end.slice(5, 7) ? `${Number(start.slice(8))} a ${dayMonth(end)}` : `${dayMonth(start)} a ${dayMonth(end)}`
}

export function isCurrentWeek(week: TrainerWeek, today: string): boolean {
  return week.start <= today && today < shiftDay(week.start, WEEK_DAYS)
}

export function weekCells(plan: TrainerPlan, today: string): TrainerWeekCell[] {
  const cells = plan.weeks.map((week) => ({
    id: week.index,
    title: `S${week.index} · ${Number(week.start.slice(8))}/${Number(week.start.slice(5, 7))}`,
    kilometers: `${kmNumber(week.plannedMeters / 1000)} km`,
    detail: plan.lightWeeks.includes(week.start)
      ? TRAINER_TEXT.lightWeek
      : `${week.isRecovery ? TRAINER_TEXT.recoveryWeek : TRAINER_TEXT.longRun} ${kmNumber(week.longMeters / 1000)}`,
    phase: week.phase,
    current: isCurrentWeek(week, today),
    past: shiftDay(week.start, WEEK_DAYS) <= today,
  }))
  const date = plan.target.date
  if (date === null) return cells
  return [
    ...cells,
    { id: Number.MAX_SAFE_INTEGER, title: `${Number(date.slice(8))}/${Number(date.slice(5, 7))}`, kilometers: kmNumber((plan.target.distanceMeters ?? 0) / 1000), detail: TRAINER_TEXT.race, phase: null, current: false, past: false },
  ]
}

function barePace(low: number | null, high: number | null): string | null {
  return paceRange(low, high)?.replace('/km', '') ?? null
}

function dayName(workout: TrainerWorkout): string {
  if (workout.kind === 'threshold' && workout.method === 'racePace') return TRAINER_TEXT.racePace
  if (workout.kind === 'vo2max' && workout.method === 'goalPace') return TRAINER_TEXT.goalPaceName
  return TRAINER_TEXT.kinds[workout.kind === 'optionalEasy' ? 'easy' : workout.kind]
}

function pauseBlocks(workout: TrainerWorkout): { count: number; meters: number }[] {
  const sizes: number[] = []
  let current = 0
  for (const step of workout.steps) {
    if (step.kind === 'recovery' && step.restSeconds !== null) {
      sizes.push(current)
      current = 0
    } else {
      current += step.meters * step.repeats
    }
  }
  sizes.push(current)
  const groups: { count: number; meters: number }[] = []
  for (const size of sizes) {
    const last = groups.at(-1)
    if (last !== undefined && last.meters === size) last.count += 1
    else groups.push({ count: 1, meters: size })
  }
  return groups
}

function hasPauses(workout: TrainerWorkout): boolean {
  return workout.kind === 'long' && workout.steps.some((step) => step.kind === 'recovery' && step.restSeconds !== null)
}

function dayDetail(workout: TrainerWorkout, pauses: boolean): string {
  const withPace = (blocks: string, range: string | null) => (range === null ? blocks : `${blocks} a ${range}`)
  if (pauses) {
    const blocks = pauseBlocks(workout).map((group) => (group.count > 1 ? `${group.count} × ${distanceText(group.meters)}` : distanceText(group.meters))).join(TRAINER_TEXT.blockSeparator)
    const steady = workout.steps.filter((step) => step.kind === 'steady')
    const lows = steady.flatMap((step) => (step.paceLow === null ? [] : [step.paceLow]))
    const highs = steady.flatMap((step) => (step.paceHigh === null ? [] : [step.paceHigh]))
    return withPace(blocks, barePace(lows.length === 0 ? null : Math.min(...lows), highs.length === 0 ? null : Math.max(...highs)))
  }
  const main = workout.steps.filter((step) => step.kind === 'work' && step.method !== 'repetition')
  if ((workout.kind === 'threshold' || workout.kind === 'vo2max') && main.length > 0) {
    return withPace(main.map((step) => `${step.repeats} × ${distanceText(step.meters)}`).join(TRAINER_TEXT.blockSeparator), barePace(workout.paceLow, workout.paceHigh))
  }
  return paceRange(workout.paceLow, workout.paceHigh) ?? ''
}

export function dayLine(plan: TrainerPlan, workout: TrainerWorkout): TrainerDayLine {
  const pauses = hasPauses(workout)
  const closing = workout.steps.find((step) => step.method === 'repetition')
  const tags: TrainerDayTag[] = []
  if (workout.kind === 'optionalEasy') tags.push({ text: TRAINER_TEXT.optional, strength: false })
  if (closing !== undefined) tags.push({ text: TRAINER_TEXT.closingTag(closing.repeats, distanceText(closing.meters)), strength: false })
  if (pauses) tags.push({ text: TRAINER_TEXT.stageTag(plan.longStage, TRAINER_TEXT.longStageCount), strength: false })
  if (workout.edited && workout.kind !== 'off') tags.push({ text: TRAINER_TEXT.edited, strength: false })
  tags.push(...strengthTags(plan, workout.day).map((text) => ({ text, strength: true })))
  if (workout.kind === 'off') return { title: TRAINER_TEXT.restDay, detail: '', tags }
  return { title: `${dayName(workout)} · ${distanceText(workout.totalMeters)}`, detail: dayDetail(workout, pauses), tags }
}

export function strengthTags(plan: TrainerPlan, date: string): string[] {
  const weekdayNumber = ((weekday(date) + 6) % WEEK_DAYS) + 1
  return plan.strength.filter((session) => session.weekday === weekdayNumber).map((session) => TRAINER_TEXT.strengthTag(session.name))
}

export function triggerText(trigger: TrainerTrigger): string {
  const triggers = TRAINER_TEXT.triggers
  switch (trigger.kind) {
    case 'created': return triggers.created()
    case 'weekEnded': return triggers.weekEnded(trigger.number)
    case 'workout': return triggers.workout(trigger.day === null ? '' : (TRAINER_TEXT.weekdaysFull[weekday(trigger.day)] ?? ''))
    case 'request': return triggers.request()
    case 'strengthChanged': return triggers.strengthChanged()
    case 'lightWeek': return triggers.lightWeek(trigger.day === null ? '' : dayMonth(trigger.day))
    case 'longModeChanged': return triggers.longModeChanged()
    case 'edited': return triggers.edited(trigger.number)
    case 'readiness': return triggers.readiness(trigger.number)
  }
}

export function weeksToTarget(plan: TrainerPlan, today: string): number | null {
  const date = plan.target.date
  if (date === null) return null
  const days = Math.round((Date.parse(`${date}T12:00:00Z`) - Date.parse(`${today}T12:00:00Z`)) / 86_400_000)
  return days > 0 ? Math.ceil(days / WEEK_DAYS) : null
}

export function goalCaption(plan: TrainerPlan, today: string): string {
  const parts: string[] = []
  const { goalPace, goalSeconds } = plan.target
  if (goalPace !== null) parts.push(TRAINER_TEXT.goalPace(paceClock(goalPace)))
  if (goalSeconds !== null) parts.push(TRAINER_TEXT.goalClock(clock(goalSeconds)))
  const weeks = weeksToTarget(plan, today)
  if (weeks !== null) parts.push(TRAINER_TEXT.weeksToTarget(weeks))
  parts.push(TRAINER_TEXT.version(plan.versions.at(-1)?.number ?? 1))
  return parts.join(' · ')
}

function clock(seconds: number): string {
  const total = Math.round(seconds)
  const hours = Math.floor(total / 3600)
  const rest = `${String(Math.floor((total % 3600) / 60)).padStart(hours > 0 ? 2 : 1, '0')}:${String(total % 60).padStart(2, '0')}`
  return hours > 0 ? `${hours}:${rest}` : rest
}

export function defaultDay(plan: TrainerPlan, today: string): string | null {
  const upcoming = plan.workouts.find((workout) => workout.day >= today && workout.kind !== 'off')
  return (upcoming ?? plan.workouts.at(-1))?.day ?? null
}

export function weekWorkouts(plan: TrainerPlan, week: TrainerWeek): TrainerWorkout[] {
  const end = shiftDay(week.start, WEEK_DAYS)
  return plan.workouts.filter((workout) => workout.day >= week.start && workout.day < end)
}

export function visibleChanges(version: TrainerVersion): TrainerChange[] {
  return version.changes.filter((change) => change.kind !== 'unchanged' && change.kind !== 'newWeek')
}

export function workoutNumbers(workout: TrainerWorkout): { label: string; value: string }[] {
  const range = paceRange(workout.paceLow, workout.paceHigh)
  return [
    { label: TRAINER_TEXT.planned, value: distanceText(workout.totalMeters) },
    ...(range === null ? [] : [{ label: TRAINER_TEXT.pace, value: range }]),
    ...(workout.note === null || workout.note === '' ? [] : [{ label: TRAINER_TEXT.noteLabel, value: workout.note }]),
  ]
}
