import type { PrescribedStep, StepTarget } from '../fit/fitTypes.js'
import { ANALYSIS } from './analysisConstants.js'
import type { HeartRateZones, ScoreItem, ScorePart, ScoreReason, WorkoutBlock, WorkoutOccurrence, WorkoutScore } from './analysisTypes.js'

const absent = (part: ScorePart, reason: ScoreReason): ScoreItem => ({ part, points: 0, maximum: 0, reason })
const isExecuted = (block: WorkoutBlock) => block.status !== 'notExecuted'

function largest(losses: Map<ScoreReason, number>): ScoreReason | null {
  let best: ScoreReason | null = null
  let value = Number.NEGATIVE_INFINITY
  for (const [reason, amount] of losses) {
    if (amount > value) {
      best = reason
      value = amount
    }
  }
  return best
}

const add = (losses: Map<ScoreReason, number>, reason: ScoreReason, amount: number) => losses.set(reason, (losses.get(reason) ?? 0) + amount)

function executedFraction(block: WorkoutBlock, step: PrescribedStep): number {
  if (step.duration.kind === 'distance' && step.duration.meters > 0) return Math.min(block.distance / step.duration.meters, 1)
  if (step.duration.kind === 'time' && step.duration.seconds > 0) return Math.min(block.seconds / step.duration.seconds, 1)
  return 0
}

function notExecutedSeconds(step: PrescribedStep, targeted: WorkoutBlock[]): number {
  if (step.duration.kind === 'time') return step.duration.seconds
  const executed = targeted.filter(isExecuted)
  const sameStep = executed.filter((block) => block.prescribed?.index === step.index)
  const pool = sameStep.length === 0 ? executed : sameStep
  return pool.length === 0 ? 0 : pool.reduce((sum, block) => sum + block.seconds, 0) / pool.length
}

function executionItem(blocks: WorkoutBlock[], prescribed: boolean): ScoreItem {
  if (!prescribed) return absent('execution', 'noPrescription')
  const targeted = blocks.filter((block) => block.kind === 'active' && block.prescribed !== null && block.prescribed.target.kind !== 'open' && block.status !== 'noTarget')
  let credit = 0
  let total = 0
  const reasons = new Map<ScoreReason, number>()
  for (const block of targeted) {
    const step = block.prescribed
    if (step === null) continue
    const weight = isExecuted(block) ? block.seconds : notExecutedSeconds(step, targeted)
    total += weight
    if (block.status === 'inTarget') credit += weight
    else if (block.status === 'incomplete') {
      credit += weight * executedFraction(block, step)
      add(reasons, 'incompleteStep', weight)
    } else if (block.status === 'notExecuted') add(reasons, 'notExecuted', weight)
    else add(reasons, 'blocksOffTarget', weight)
  }
  if (total <= 0) return absent('execution', 'noPrescription')
  const points = (credit / total) * ANALYSIS.executionWeight
  return { part: 'execution', points, maximum: ANALYSIS.executionWeight, reason: points < ANALYSIS.executionWeight ? largest(reasons) : null }
}

function impliesAboveEasy(target: StepTarget, zones: HeartRateZones, ceiling: number): boolean {
  switch (target.kind) {
    case 'open':
      return false
    case 'speed':
      return true
    case 'heartRateBpm':
      return (target.high > 0 ? target.high : target.low) > ceiling
    case 'heartRatePercentMax':
      return zones.maxHeartRate === null ? false : Math.trunc(((target.high > 0 ? target.high : target.low) * zones.maxHeartRate) / 100) > ceiling
    case 'heartRateZone':
      return target.zone > ANALYSIS.easyZoneNumber
  }
}

function activeVerdict(block: WorkoutBlock, heartRate: number, light: boolean, ceiling: number, floor: number): { ok: boolean; reason: ScoreReason } | null {
  if (light) return { ok: heartRate <= ceiling, reason: 'easyTooHard' }
  const step = block.prescribed
  if (step === null) return null
  switch (step.target.kind) {
    case 'open':
      return null
    case 'speed':
      return { ok: heartRate >= floor, reason: 'hardTooEasy' }
    default:
      return block.status === 'noTarget' ? null : { ok: block.status === 'inTarget', reason: 'heartRateTargetMissed' }
  }
}

function intentItem(blocks: WorkoutBlock[], zones: HeartRateZones | null, prescribed: boolean, hasHeartRate: boolean): ScoreItem {
  if (!prescribed) return absent('intent', 'noPrescription')
  if (!hasHeartRate) return absent('intent', 'noHeartRate')
  if (zones === null || zones.floors.length <= ANALYSIS.easyZoneNumber) return absent('intent', 'noZones')
  const ceiling = (zones.floors[ANALYSIS.easyZoneNumber] ?? 0) - 1
  const floor = zones.floors[ANALYSIS.easyZoneNumber - 1] ?? 0
  const light = !blocks.some((block) => block.kind === 'active' && block.prescribed !== null && impliesAboveEasy(block.prescribed.target, zones, ceiling))
  let inRange = 0
  let total = 0
  const losses = new Map<ScoreReason, number>()
  for (const block of blocks) {
    if (block.kind === 'recovery' || !isExecuted(block) || block.seconds <= 0 || block.avgHeartRate === null) continue
    const verdict = block.kind === 'active' ? activeVerdict(block, block.avgHeartRate, light, ceiling, floor) : { ok: block.avgHeartRate <= ceiling, reason: 'easyTooHard' as const }
    if (verdict === null) continue
    total += block.seconds
    if (verdict.ok) inRange += block.seconds
    else add(losses, verdict.reason, block.seconds)
  }
  if (total <= 0) return absent('intent', 'noPrescription')
  const points = (inRange / total) * ANALYSIS.intentWeight
  return { part: 'intent', points, maximum: ANALYSIS.intentWeight, reason: points < ANALYSIS.intentWeight ? largest(losses) : null }
}

export function efficiency(blocks: WorkoutBlock[]): number | null {
  const prescribed = blocks.some((block) => block.prescribed !== null)
  const measured = blocks.filter((block) => (!prescribed || (block.kind === 'active' && block.prescribed !== null)) && isExecuted(block) && block.seconds > 0 && (block.avgHeartRate ?? 0) > 0)
  const seconds = measured.reduce((sum, block) => sum + block.seconds, 0)
  if (seconds <= 0) return null
  const distance = measured.reduce((sum, block) => sum + block.distance, 0)
  const heartRate = measured.reduce((sum, block) => sum + (block.avgHeartRate ?? 0) * block.seconds, 0) / seconds
  return distance / seconds / heartRate
}

function median(sorted: number[]): number {
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 0 ? ((sorted[middle - 1] ?? 0) + (sorted[middle] ?? 0)) / 2 : (sorted[middle] ?? 0)
}

function costItem(blocks: WorkoutBlock[], previous: WorkoutOccurrence[], hasHeartRate: boolean): ScoreItem {
  const current = hasHeartRate ? efficiency(blocks) : null
  if (current === null) return absent('cost', 'noHeartRate')
  const references = previous.flatMap((item) => {
    const value = efficiency(item.blocks)
    return value === null ? [] : [value]
  }).sort((a, b) => a - b)
  if (references.length === 0) return absent('cost', 'noHistory')
  const reference = median(references)
  if (reference <= 0 || !Number.isFinite(current)) return absent('cost', 'noHistory')
  const ratio = current / reference - 1
  const share = Math.min(Math.max(ANALYSIS.costMedianShare + ratio / (2 * ANALYSIS.costSaturation), 0), 1)
  const reason: ScoreReason | null = ratio >= ANALYSIS.costReasonThreshold ? 'moreEfficient' : ratio <= -ANALYSIS.costReasonThreshold ? 'lessEfficient' : null
  return { part: 'cost', points: share * ANALYSIS.costWeight, maximum: ANALYSIS.costWeight, reason }
}

export function scoreWorkout(blocks: WorkoutBlock[], zones: HeartRateZones | null, previous: WorkoutOccurrence[]): WorkoutScore | null {
  if (blocks.length === 0) return null
  const prescribed = blocks.some((block) => block.prescribed !== null)
  const hasHeartRate = blocks.some((block) => block.avgHeartRate !== null)
  const items = [executionItem(blocks, prescribed), intentItem(blocks, zones, prescribed, hasHeartRate), costItem(blocks, previous, hasHeartRate)]
  const maximum = items.reduce((sum, item) => sum + item.maximum, 0)
  if (maximum <= 0) return null
  const points = items.reduce((sum, item) => sum + item.points, 0)
  const value = Math.round((points / maximum) * ANALYSIS.scoreScale)
  const complete = items.every((item) => item.maximum > 0)
  return { value: complete ? value : Math.min(value, ANALYSIS.incompleteScoreCap), items }
}
