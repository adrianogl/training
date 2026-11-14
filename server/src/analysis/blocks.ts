import type { LapSummary, PrescribedStep, StepIntensity, StepTarget, WorkoutStructure } from '../fit/fitTypes.js'
import { ANALYSIS } from './analysisConstants.js'
import type { BlockKind, BlockStatus, ExpectedStep, HeartRateZones, LapGroup, WorkoutBlock } from './analysisTypes.js'

const isRepeat = (step: PrescribedStep) => step.duration.kind === 'repeatSteps'

export function hasPrescription(structure: WorkoutStructure): boolean {
  return (structure.prescription?.steps ?? []).some((step) => !isRepeat(step))
}

class BlockLabeler {
  private counters = new Map<string, number>()

  next(kind: BlockKind, insideRepeat: boolean): { ordinal: number; label: string } {
    const prefix =
      kind === 'warmup' ? ANALYSIS.labels.warmup
      : kind === 'cooldown' ? ANALYSIS.labels.cooldown
      : kind === 'recovery' ? ANALYSIS.labels.recovery
      : insideRepeat ? ANALYSIS.labels.repeatActive
      : ANALYSIS.labels.active
    const ordinal = (this.counters.get(prefix) ?? 0) + 1
    this.counters.set(prefix, ordinal)
    return { ordinal, label: kind === 'warmup' || kind === 'cooldown' ? prefix : `${prefix} ${ordinal}` }
  }
}

export function unroll(steps: PrescribedStep[]): ExpectedStep[] {
  const expanded: ExpectedStep[] = []
  const firstPosition = new Map<number, number>()
  for (const step of steps) {
    if (step.duration.kind !== 'repeatSteps') {
      if (!firstPosition.has(step.index)) firstPosition.set(step.index, expanded.length)
      expanded.push({ step, insideRepeat: false })
      continue
    }
    const start = firstPosition.get(step.duration.fromIndex)
    if (start === undefined || start >= expanded.length) continue
    for (let position = start; position < expanded.length; position += 1) {
      const item = expanded[position]
      if (item) item.insideRepeat = true
    }
    const body = expanded.slice(start).map((item) => ({ ...item }))
    for (let round = 1; round < Math.max(step.duration.count, 1); round += 1) {
      expanded.push(...body.map((item) => ({ ...item })))
    }
  }
  return expanded
}

function consecutiveRepetitions(expected: ExpectedStep[], start: number): number {
  const index = expected[start]?.step.index
  let count = 0
  for (let position = start; position < expected.length && expected[position]?.step.index === index; position += 1) count += 1
  return count
}

function reachesDuration(laps: LapSummary[], step: PrescribedStep): boolean {
  switch (step.duration.kind) {
    case 'distance':
      return laps.reduce((sum, lap) => sum + lap.distance, 0) >= step.duration.meters * ANALYSIS.completionRatio
    case 'time':
      return laps.reduce((sum, lap) => sum + lap.timerSeconds, 0) >= step.duration.seconds * ANALYSIS.completionRatio
    default:
      return true
  }
}

function splitAcrossRepetitions(laps: LapSummary[], step: PrescribedStep, available: number): LapSummary[][] {
  if (available <= 1) return [laps]
  const repetitions: LapSummary[][] = []
  let current: LapSummary[] = []
  for (const lap of laps) {
    current.push(lap)
    if (repetitions.length < available - 1 && reachesDuration(current, step)) {
      repetitions.push(current)
      current = []
    }
  }
  if (current.length > 0) repetitions.push(current)
  return repetitions
}

const isStray = (lap: LapSummary) => lap.stepIndex === null && (lap.trigger === ANALYSIS.sessionEndTrigger || lap.timerSeconds < ANALYSIS.minimumStraySeconds)

function groupByStep(laps: LapSummary[]): LapGroup[] {
  const groups: LapGroup[] = []
  for (const lap of laps) {
    const last = groups.at(-1)
    const orphan = lap.stepIndex === null
    if (last !== undefined && last.extra === orphan && (orphan || last.stepIndex === lap.stepIndex)) last.laps.push(lap)
    else groups.push({ stepIndex: lap.stepIndex, laps: [lap], extra: orphan && last !== undefined })
  }
  return groups
}

function blockKind(intensity: StepIntensity): BlockKind {
  switch (intensity) {
    case 'warmup':
      return 'warmup'
    case 'cooldown':
      return 'cooldown'
    case 'recovery':
    case 'rest':
      return 'recovery'
    default:
      return 'active'
  }
}

function weightedHeartRate(laps: LapSummary[]): number | null {
  const measured = laps.filter((lap) => lap.avgHeartRate !== null)
  if (measured.length === 0) return null
  const totalSeconds = measured.reduce((sum, lap) => sum + lap.timerSeconds, 0)
  if (totalSeconds <= 0) return Math.round(measured.reduce((sum, lap) => sum + (lap.avgHeartRate ?? 0), 0) / measured.length)
  return Math.round(measured.reduce((sum, lap) => sum + (lap.avgHeartRate ?? 0) * lap.timerSeconds, 0) / totalSeconds)
}

export function zoneOf(heartRate: number, zones: HeartRateZones | null): number | null {
  if (zones === null) return null
  const zone = zones.floors.filter((floor) => floor <= heartRate).length
  return zone > 0 ? zone : null
}

function heartRateStatus(heartRate: number | null, low: number, high: number | null): BlockStatus {
  if (heartRate === null) return 'noTarget'
  if (high !== null && heartRate > high) return 'aboveTarget'
  if (heartRate < low) return 'belowTarget'
  return 'inTarget'
}

export function targetStatus(target: StepTarget, avgSpeed: number | null, avgHeartRate: number | null, zones: HeartRateZones | null): BlockStatus {
  switch (target.kind) {
    case 'open':
      return 'noTarget'
    case 'speed':
      if (avgSpeed === null) return 'noTarget'
      if (target.high > 0 && avgSpeed > target.high) return 'faster'
      if (avgSpeed < target.low) return 'slower'
      return 'inTarget'
    case 'heartRateBpm':
      return heartRateStatus(avgHeartRate, target.low, target.high > 0 ? target.high : null)
    case 'heartRatePercentMax': {
      const max = zones?.maxHeartRate ?? null
      if (max === null) return 'noTarget'
      return heartRateStatus(avgHeartRate, (target.low * max) / 100, target.high > 0 ? (target.high * max) / 100 : null)
    }
    case 'heartRateZone': {
      const floors = zones?.floors ?? null
      if (floors === null || target.zone < 1 || target.zone > floors.length) return 'noTarget'
      const high = target.zone < floors.length ? (floors[target.zone] ?? 0) - 1 : null
      return heartRateStatus(avgHeartRate, floors[target.zone - 1] ?? 0, high)
    }
  }
}

function status(prescribed: PrescribedStep | null, hasLaps: boolean, seconds: number, distance: number, avgSpeed: number | null, avgHeartRate: number | null, zones: HeartRateZones | null): BlockStatus {
  if (prescribed === null) return hasLaps ? 'noTarget' : 'notExecuted'
  if (!hasLaps) return 'notExecuted'
  if (prescribed.duration.kind === 'distance' && distance < prescribed.duration.meters * ANALYSIS.completionRatio) return 'incomplete'
  if (prescribed.duration.kind === 'time' && seconds < prescribed.duration.seconds * ANALYSIS.completionRatio) return 'incomplete'
  return targetStatus(prescribed.target, avgSpeed, avgHeartRate, zones)
}

function makeBlock(kind: BlockKind, ordinal: number, label: string, prescribed: PrescribedStep | null, laps: LapSummary[], zones: HeartRateZones | null): WorkoutBlock {
  const seconds = laps.reduce((sum, lap) => sum + lap.timerSeconds, 0)
  const distance = laps.reduce((sum, lap) => sum + lap.distance, 0)
  const avgSpeed = seconds > 0 ? distance / seconds : null
  const avgHeartRate = weightedHeartRate(laps)
  const maxima = laps.flatMap((lap) => (lap.maxHeartRate === null ? [] : [lap.maxHeartRate]))
  return {
    kind, ordinal, label, prescribed, laps, seconds, distance, avgSpeed, avgHeartRate,
    maxHeartRate: maxima.length === 0 ? null : Math.max(...maxima),
    dominantZone: avgHeartRate === null ? null : zoneOf(avgHeartRate, zones),
    status: status(prescribed, laps.length > 0, seconds, distance, avgSpeed, avgHeartRate, zones),
  }
}

function blockFor(expected: ExpectedStep, laps: LapSummary[], labeler: BlockLabeler, zones: HeartRateZones | null): WorkoutBlock {
  const kind = blockKind(expected.step.intensity)
  const { ordinal, label } = labeler.next(kind, expected.insideRepeat)
  return makeBlock(kind, ordinal, label, expected.step, laps, zones)
}

function freeRunBlocks(laps: LapSummary[], zones: HeartRateZones | null): WorkoutBlock[] {
  return laps.map((lap, offset) => makeBlock('active', offset + 1, `${ANALYSIS.labels.freeRun} ${offset + 1}`, null, [lap], zones))
}

export function buildBlocks(structure: WorkoutStructure, zones: HeartRateZones | null): WorkoutBlock[] {
  const prescription = structure.prescription
  if (!hasPrescription(structure) || prescription === null) return freeRunBlocks(structure.laps, zones)
  const expected = unroll(prescription.steps)
  const groups = groupByStep(structure.laps.filter((lap) => !isStray(lap)))
  const labeler = new BlockLabeler()
  const blocks: WorkoutBlock[] = []
  let cursor = 0
  let extras = 0
  for (const group of groups) {
    if (group.extra) {
      const previous = blocks.at(-1)
      if (cursor >= expected.length || previous === undefined) {
        for (const extraLap of group.laps) {
          extras += 1
          blocks.push(makeBlock('cooldown', extras, `${ANALYSIS.labels.extra} ${extras}`, null, [extraLap], zones))
        }
      } else {
        blocks[blocks.length - 1] = makeBlock(previous.kind, previous.ordinal, previous.label, previous.prescribed, [...previous.laps, ...group.laps], zones)
      }
      continue
    }
    let match = -1
    for (let position = cursor; position < expected.length; position += 1) {
      if (expected[position]?.step.index === group.stepIndex) {
        match = position
        break
      }
    }
    if (match < 0) {
      const kind = blockKind(group.laps[0]?.intensity ?? 'active')
      const { ordinal, label } = labeler.next(kind, false)
      blocks.push(makeBlock(kind, ordinal, label, null, group.laps, zones))
      continue
    }
    for (let position = cursor; position < match; position += 1) {
      const skipped = expected[position]
      if (skipped) blocks.push(blockFor(skipped, [], labeler, zones))
    }
    const step = expected[match]?.step
    if (step === undefined) continue
    const repetitions = splitAcrossRepetitions(group.laps, step, consecutiveRepetitions(expected, match))
    repetitions.forEach((laps, offset) => {
      const item = expected[match + offset]
      if (item) blocks.push(blockFor(item, laps, labeler, zones))
    })
    cursor = match + repetitions.length
  }
  for (let position = cursor; position < expected.length; position += 1) {
    const remaining = expected[position]
    if (remaining) blocks.push(blockFor(remaining, [], labeler, zones))
  }
  return blocks
}
