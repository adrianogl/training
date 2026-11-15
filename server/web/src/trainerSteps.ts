import { TRAINER_TEXT } from './constants'
import { kmNumber, paceClock } from './format'
import type { TrainerStep, TrainerStepRow, TrainerWorkout } from './types'

export function distanceText(meters: number): string {
  return meters < 1000 ? `${Math.round(meters)} m` : `${kmNumber(meters / 1000)} km`
}

export function paceRange(low: number | null, high: number | null): string | null {
  if (low === null && high === null) return null
  if (low === null || high === null) return `${paceClock(low ?? high ?? 0)}/km`
  const fast = Math.min(low, high)
  const slow = Math.max(low, high)
  return Math.round(fast) === Math.round(slow) ? `${paceClock(fast)}/km` : `${paceClock(fast)}–${paceClock(slow)}/km`
}

export function restClock(seconds: number): string {
  return paceClock(seconds)
}

function workName(step: TrainerStep, workout: TrainerWorkout): string {
  return (step.method === null ? undefined : TRAINER_TEXT.workMethods[step.method])
    ?? (workout.variant === null ? undefined : TRAINER_TEXT.workVariants[workout.variant])
    ?? TRAINER_TEXT.workKinds[workout.kind] ?? TRAINER_TEXT.stepKinds.work
}

function stepTitle(step: TrainerStep, workout: TrainerWorkout): string {
  return step.kind === 'work' ? TRAINER_TEXT.repeated(step.repeats, workName(step, workout)) : TRAINER_TEXT.stepKinds[step.kind]
}

function singleRow(step: TrainerStep, index: number, workout: TrainerWorkout, single: boolean, id: number, nested = false): TrainerStepRow {
  const steps = workout.steps
  const repeats = single ? 1 : step.repeats
  if (step.restSeconds !== null) {
    const transition = !nested && step.repeats <= 1 && steps[index + 1]?.kind === 'work'
    const title = transition ? TRAINER_TEXT.restBeforeNext : TRAINER_TEXT.repeated(repeats, TRAINER_TEXT.restStep)
    return { id, kind: step.kind, title, detail: restClock(step.restSeconds), header: false, nested }
  }
  if (step.kind === 'recovery' && step.meters > 0 && step.paceLow === null) {
    return { id, kind: step.kind, title: TRAINER_TEXT.repeated(repeats, TRAINER_TEXT.trotTitle), detail: distanceText(step.meters), header: false, nested }
  }
  const range = paceRange(step.paceLow, step.paceHigh)
  const detail = `${distanceText(step.meters)}${range !== null ? ` · ${range}` : step.kind === 'recovery' ? ` · ${TRAINER_TEXT.trot}` : ''}`
  return { id, kind: step.kind, title: stepTitle({ ...step, repeats }, workout), detail, header: false, nested }
}

interface LongBlock {
  steps: TrainerStep[]
  rest: number | null
}

function sameSteps(a: TrainerStep[], b: TrainerStep[]): boolean {
  return JSON.stringify(a) === JSON.stringify(b)
}

function longBlockRows(workout: TrainerWorkout): TrainerStepRow[] | null {
  if (workout.kind !== 'long' || !workout.steps.some((step) => step.kind === 'recovery' && step.restSeconds !== null)) return null
  const blocks: LongBlock[] = []
  let current: TrainerStep[] = []
  for (const step of workout.steps) {
    if (step.kind === 'recovery' && step.restSeconds !== null) {
      blocks.push({ steps: current, rest: step.restSeconds })
      current = []
    } else {
      current.push(step)
    }
  }
  blocks.push({ steps: current, rest: null })
  const rows: TrainerStepRow[] = []
  const append = (kind: TrainerStepRow['kind'], title: string, detail: string, header = false, nested = false) => {
    rows.push({ id: rows.length, kind, title, detail, header, nested })
  }
  const appendBlock = (steps: TrainerStep[], nested: boolean) => {
    const meters = steps.reduce((total, step) => total + step.meters * step.repeats, 0)
    const lows = steps.flatMap((step) => (step.paceLow === null ? [] : [step.paceLow]))
    const highs = steps.flatMap((step) => (step.paceHigh === null ? [] : [step.paceHigh]))
    const range = paceRange(lows.length === 0 ? null : Math.min(...lows), highs.length === 0 ? null : Math.max(...highs))
    append('steady', TRAINER_TEXT.workKinds.long ?? '', `${distanceText(meters)}${range === null ? '' : ` · ${range}`}`, false, nested)
  }
  const appendPause = (rest: number, nested: boolean) => append('recovery', TRAINER_TEXT.longBlockPause, restClock(rest), false, nested)
  let index = 0
  while (index < blocks.length) {
    const first = blocks[index]
    if (first === undefined) break
    let end = index
    while (end + 1 < blocks.length && sameSteps(blocks[end + 1]?.steps ?? [], first.steps)) end += 1
    const count = end - index + 1
    if (count > 1 && first.rest !== null) {
      append('work', TRAINER_TEXT.seriesTitle(count), '', true)
      appendBlock(first.steps, true)
      appendPause(first.rest, true)
    } else {
      appendBlock(first.steps, false)
      const rest = blocks[end]?.rest ?? null
      if (rest !== null) appendPause(rest, false)
    }
    index = end + 1
  }
  return rows
}

export function stepRows(workout: TrainerWorkout): TrainerStepRow[] {
  const blocks = longBlockRows(workout)
  if (blocks !== null) return blocks
  const steps = workout.steps
  const rows: TrainerStepRow[] = []
  let index = 0
  while (index < steps.length) {
    const step = steps[index]
    if (step === undefined) break
    const next = steps[index + 1]
    if (step.kind === 'work' && step.repeats > 1 && next !== undefined && next.kind === 'recovery' && next.repeats === step.repeats - 1) {
      rows.push({ id: rows.length, kind: step.kind, title: TRAINER_TEXT.seriesTitle(step.repeats), detail: '', header: true, nested: false })
      rows.push(singleRow(step, index, workout, true, rows.length, true))
      rows.push(singleRow(next, index + 1, workout, true, rows.length, true))
      index += 2
      const after = steps[index]
      if (after !== undefined && after.repeats <= 1 && after.restSeconds !== null && after.restSeconds === next.restSeconds) index += 1
    } else {
      rows.push(singleRow(step, index, workout, false, rows.length))
      index += 1
    }
  }
  return rows
}
