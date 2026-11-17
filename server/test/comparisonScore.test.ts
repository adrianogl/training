import { describe, expect, it } from 'vitest'
import type { BlockKind, BlockStatus, ScorePart, WorkoutBlock, WorkoutOccurrence, WorkoutScore } from '../src/analysis/analysisTypes.js'
import { compare } from '../src/analysis/comparison.js'
import { scoreWorkout } from '../src/analysis/workoutScore.js'
import type { PrescribedStep } from '../src/fit/fitTypes.js'
import { distance, hrZone, open, openDuration, speed, step, time, zones } from './analysisHelpers.js'

function cblock(kind: BlockKind, label: string, seconds: number, meters: number, heartRate: number | null): WorkoutBlock {
  return { kind, ordinal: 1, label, prescribed: null, laps: [], seconds, distance: meters, avgSpeed: seconds > 0 ? meters / seconds : null, avgHeartRate: heartRate, maxHeartRate: heartRate === null ? null : heartRate + 10, dominantZone: null, status: 'noTarget' }
}

const intervals = (activeSeconds: number, heartRate: number) => [
  cblock('warmup', 'Aquecimento', 600, 1800, 130),
  cblock('active', 'Tiro 1', activeSeconds, 1000, heartRate),
  cblock('recovery', 'Recuperação 1', 120, 300, 140),
  cblock('active', 'Tiro 2', activeSeconds * 2, 2000, heartRate + 4),
  cblock('cooldown', 'Desaquecimento', 600, 1700, 125),
]

const occ = (activityId: number, day: number, blocks: WorkoutBlock[]): WorkoutOccurrence => ({ activityId, day: `2026-10-${String(day).padStart(2, '0')}`, blocks })
const current = () => occ(100, 30, intervals(240, 160))

describe('comparação (paridade com ComparisonTests)', () => {
  it('mesma estrutura', () => {
    const c = compare(current(), [occ(90, 23, intervals(245, 162)), occ(70, 9, intervals(260, 168)), occ(80, 16, intervals(250, 165))])
    expect(c?.sameStructure).toBe(true)
    expect(c?.occurrences).toEqual([100, 90, 80, 70])
    expect(c?.blocks.map((b) => b.label)).toEqual(['Aquecimento', 'Tiro 1', 'Recuperação 1', 'Tiro 2', 'Desaquecimento'])
    expect(c?.blocks[1]?.values['70']?.heartRate).toBe(168)
    expect(c?.blocks[1]?.values['100']?.status).toBe('noTarget')
    expect(c?.activeSpeedDelta).toBeCloseTo(3000 / 720 - 3000 / 780, 4)
    expect(c?.activeHeartRateDelta).toBeCloseTo((160 + 2 * 164) / 3 - (168 + 2 * 172) / 3, 4)
  })

  it('estrutura diferente', () => {
    const shorter = [cblock('warmup', 'Aquecimento', 600, 1800, 130), cblock('active', 'Tiro 1', 250, 1000, 166), cblock('cooldown', 'Desaquecimento', 600, 1700, 125)]
    const c = compare(current(), [occ(90, 23, shorter)])
    expect(c?.sameStructure).toBe(false)
    expect(c?.blocks.map((b) => b.label)).toEqual(['Aquecimento', 'Tiro 1', 'Desaquecimento'])
    expect(c?.activeSpeedDelta).toBeCloseTo(1000 / 240 - 1000 / 250, 4)
    expect(c?.activeHeartRateDelta).toBe(-6)
  })

  it('limite, vazio, duplicados e desempate', () => {
    const many = compare(current(), [1, 2, 3, 4, 5, 6].map((i) => occ(i, i, intervals(250, 165))))
    expect(many?.occurrences).toEqual([100, 6, 5, 4, 3])
    expect(many?.blocks.every((b) => Object.keys(b.values).length === 5)).toBe(true)
    expect(compare(current(), [])).toBeNull()
    expect(compare(current(), [current(), occ(90, 23, intervals(250, 165))])?.occurrences).toEqual([100, 90])
    const earlier = occ(90, 23, intervals(250, 165))
    const dedup = compare(current(), [earlier, earlier])
    expect(dedup?.occurrences).toEqual([100, 90])
    expect(dedup?.blocks.every((b) => Object.keys(b.values).length === 2)).toBe(true)
    expect(compare(current(), [current(), current()])).toBeNull()
    expect(compare(current(), [occ(40, 20, intervals(250, 165)), occ(60, 20, intervals(250, 165)), occ(50, 20, intervals(250, 165))])?.occurrences).toEqual([100, 60, 50, 40])
  })
})

function sblock(kind: BlockKind, prescribed: PrescribedStep | null, status: BlockStatus, seconds = 200, meters = 800, heartRate: number | null = 170): WorkoutBlock {
  return { kind, ordinal: 1, label: 'b', prescribed, laps: [], seconds, distance: meters, avgSpeed: seconds > 0 ? meters / seconds : null, avgHeartRate: heartRate, maxHeartRate: null, dominantZone: null, status }
}

const sprint = step(1, 'active', distance(800), speed(3.8, 4.2))
const warmup = step(0, 'warmup', time(600))
const recovery = step(2, 'recovery', time(120))

function intervalBlocks(sprintHeartRate = 170, recoveryHeartRate = 150): WorkoutBlock[] {
  const result = [sblock('warmup', warmup, 'noTarget', 600, 1800, 130)]
  for (let i = 0; i < 6; i += 1) result.push(sblock('active', sprint, 'inTarget', 200, 800, sprintHeartRate), sblock('recovery', recovery, 'noTarget', 120, 250, recoveryHeartRate))
  return result
}

const occurrences = (blocks: WorkoutBlock[], count: number): WorkoutOccurrence[] => Array.from({ length: count }, (_, i) => ({ activityId: i, day: `2026-01-${String(i + 1).padStart(2, '0')}`, blocks }))
const item = (score: WorkoutScore | null, part: ScorePart) => score?.items.find((i) => i.part === part)

describe('nota do treino (paridade com WorkoutScoreTests)', () => {
  it('intervalado perfeito na média', () => {
    const score = scoreWorkout(intervalBlocks(), zones, occurrences(intervalBlocks(), 3))
    expect(score?.value).toBe(88)
    expect(item(score, 'execution')).toEqual({ part: 'execution', points: 50, maximum: 50, reason: null })
    expect(item(score, 'intent')).toEqual({ part: 'intent', points: 25, maximum: 25, reason: null })
    expect(item(score, 'cost')).toEqual({ part: 'cost', points: 12.5, maximum: 25, reason: null })
  })

  it('custo: 5% mais e menos eficiente', () => {
    expect(item(scoreWorkout(intervalBlocks(160), zones, occurrences(intervalBlocks(170), 3)), 'cost')).toEqual({ part: 'cost', points: 25, maximum: 25, reason: 'moreEfficient' })
    expect(item(scoreWorkout(intervalBlocks(179), zones, occurrences(intervalBlocks(170), 3)), 'cost')).toEqual({ part: 'cost', points: 0, maximum: 25, reason: 'lessEfficient' })
  })

  it('execução: incompleto e não executado', () => {
    const half = step(0, 'active', distance(2000), speed(3.8, 4.2))
    expect(item(scoreWorkout([sblock('active', half, 'incomplete', 250, 1000)], zones, []), 'execution')).toEqual({ part: 'execution', points: 25, maximum: 50, reason: 'incompleteStep' })
    const blocks = [...intervalBlocks(), sblock('active', sprint, 'notExecuted', 0, 0, null)]
    const score = scoreWorkout(blocks, zones, [])
    expect(item(score, 'execution')?.reason).toBe('notExecuted')
    expect(item(score, 'execution')?.points).toBe((50 * 6) / 7)
  })

  it('intenção', () => {
    const easy = scoreWorkout([sblock('active', step(0, 'active', time(1800), hrZone(2)), 'aboveTarget', 1800, 5000, 165)], zones, [])
    expect(item(easy, 'intent')!.points).toBeLessThan(25)
    expect(item(easy, 'intent')?.reason).toBe('easyTooHard')
    const tooEasy = scoreWorkout(intervalBlocks(110), zones, [])
    expect(item(tooEasy, 'intent')?.reason).toBe('hardTooEasy')
    expect(item(tooEasy, 'intent')?.points).toBeCloseTo(25 / 3, 9)
    const missed = scoreWorkout([sblock('active', step(0, 'active', time(1200), hrZone(4)), 'belowTarget', 1200, 4000, 150)], zones, [])
    expect([item(missed, 'intent')?.points, item(missed, 'intent')?.reason]).toEqual([0, 'heartRateTargetMissed'])
    expect(item(scoreWorkout(intervalBlocks(170, 120), zones, []), 'intent')).toEqual(item(scoreWorkout(intervalBlocks(170, 168), zones, []), 'intent'))
    expect(item(scoreWorkout(intervalBlocks(170, 168), zones, []), 'intent')?.points).toBe(25)
  })

  it('partes ausentes', () => {
    const free = [sblock('active', null, 'noTarget', 1800, 6000, 150)]
    const freeScore = scoreWorkout(free, zones, occurrences(free, 2))
    expect(item(freeScore, 'execution')).toEqual({ part: 'execution', points: 0, maximum: 0, reason: 'noPrescription' })
    expect(item(freeScore, 'intent')).toEqual({ part: 'intent', points: 0, maximum: 0, reason: 'noPrescription' })
    expect(freeScore?.value).toBe(50)
    const noHr = intervalBlocks().map((b) => ({ ...b, avgHeartRate: null }))
    const noHrScore = scoreWorkout(noHr, zones, occurrences(noHr, 2))
    expect(item(noHrScore, 'intent')).toEqual({ part: 'intent', points: 0, maximum: 0, reason: 'noHeartRate' })
    expect(item(noHrScore, 'cost')).toEqual({ part: 'cost', points: 0, maximum: 0, reason: 'noHeartRate' })
    expect(noHrScore?.value).toBe(95)
    const noZones = scoreWorkout(intervalBlocks(), null, occurrences(intervalBlocks(), 2))
    expect(item(noZones, 'intent')).toEqual({ part: 'intent', points: 0, maximum: 0, reason: 'noZones' })
    expect(noZones?.value).toBe(83)
    const noHistory = scoreWorkout(intervalBlocks(), zones, [])
    expect([item(noHistory, 'cost'), noHistory?.value]).toEqual([{ part: 'cost', points: 0, maximum: 0, reason: 'noHistory' }, 95])
    expect(scoreWorkout([], zones, [])).toBeNull()
    const flat = intervalBlocks().map((b) => ({ ...b, distance: 0, avgSpeed: 0 }))
    const zero = scoreWorkout(intervalBlocks(), zones, occurrences(flat, 3))
    expect([item(zero, 'cost'), zero?.value]).toEqual([{ part: 'cost', points: 0, maximum: 0, reason: 'noHistory' }, 95])
    expect(scoreWorkout([sblock('active', step(0, 'active', openDuration, open), 'noTarget', 600, 2000, 150)], null, [])).toBeNull()
  })

  it('100 só com as três partes', () => {
    const current = [sblock('active', null, 'noTarget', 1800, 6000, 140)]
    const earlier = [sblock('active', null, 'noTarget', 1800, 6000, 160)]
    const free = scoreWorkout(current, zones, occurrences(earlier, 2))
    expect([item(free, 'cost')?.points, free?.value]).toEqual([25, 95])
    const full = scoreWorkout(intervalBlocks(160), zones, occurrences(intervalBlocks(170), 3))
    expect(full?.items.every((part) => part.maximum > 0)).toBe(true)
    expect(full?.value).toBe(100)
  })
})
