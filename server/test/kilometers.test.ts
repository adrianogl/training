import { describe, expect, it } from 'vitest'
import { assess } from '../src/analysis/assessment.js'
import { buildBlocks } from '../src/analysis/blocks.js'
import { blockKilometers, kilometerSplits } from '../src/analysis/kilometers.js'
import type { FitSample, LapSummary, StepDuration, StepIntensity, StepTarget } from '../src/fit/fitTypes.js'
import { distance, hrZone, open, openDuration, repeat, speed, step, structure, time, zones } from './analysisHelpers.js'

interface Segment { seconds: number; meters: number; heartRate: number }
const seg = (seconds: number, meters: number, heartRate = 150): Segment => ({ seconds, meters, heartRate })
const kms = (paces: number[], heartRates?: number[]) => paces.map((pace, i) => seg(pace, 1000, heartRates?.[i] ?? 150))
const context = (kilometers = new Map()) => ({ readinessScore: null, acuteChronic: null, previous: [], kilometers, continuity: null })

function track(segments: Segment[], stepSeconds = 5): FitSample[] {
  const samples: FitSample[] = []
  let startTime = 0
  let startDistance = 0
  segments.forEach((segment, index) => {
    const times: number[] = []
    for (let offset = 0; offset < segment.seconds; offset += stepSeconds) times.push(offset)
    if (index === segments.length - 1) times.push(segment.seconds)
    for (const offset of times) samples.push({ t: startTime + offset, heartRate: segment.heartRate, speed: segment.meters / segment.seconds, altitude: null, distance: startDistance + (segment.meters * offset) / segment.seconds })
    startTime += segment.seconds
    startDistance += segment.meters
  })
  return samples
}

function lapOf(stepIndex: number, intensity: StepIntensity, start: number, segments: Segment[]): LapSummary {
  const seconds = segments.reduce((sum, s) => sum + s.seconds, 0)
  const meters = segments.reduce((sum, s) => sum + s.meters, 0)
  return { stepIndex, intensity, trigger: 'distance', startOffset: start, timerSeconds: seconds, distance: meters, avgSpeed: meters / seconds, avgHeartRate: segments[0]?.heartRate ?? null, maxHeartRate: null }
}

const continuous = (segments: Segment[], target: StepTarget, duration: StepDuration = openDuration) => ({
  s: structure([step(0, 'active', duration, target)], [lapOf(0, 'active', 0, segments)]),
  samples: track(segments),
})

const pace = speed(1000 / 305, 1000 / 295)

describe('km a km (paridade com KilometersTests)', () => {
  it('bloco grande vira km', () => {
    const { s, samples } = continuous(kms([300, 300, 300, 300, 300]), pace, distance(5000))
    const blocks = buildBlocks(s, zones)
    const rows = blockKilometers(blocks, samples, zones).get(0) ?? []
    expect(rows.map((r) => r.label)).toEqual(['Km 1', 'Km 2', 'Km 3', 'Km 4', 'Km 5'])
    expect(rows.every((r) => Math.abs(r.distance - 1000) < 1 && Math.abs(r.seconds - 300) < 1 && r.status === 'inTarget' && r.kind === 'active' && r.laps.length === 1 && r.prescribed === blocks[0]?.prescribed)).toBe(true)
    expect([rows[0]?.dominantZone, blocks[0]?.status]).toEqual([3, 'inTarget'])
  })

  it('bloco longo em tempo abre mesmo abaixo de 3 km', () => {
    const { s, samples } = continuous([seg(960, 2800)], open, time(960))
    const rows = blockKilometers(buildBlocks(s, null), samples, null).get(0) ?? []
    expect(rows.map((r) => r.label)).toEqual(['Km 1', 'Km 2', 'Km 3'])
    expect(rows[0]!.distance >= 1000 && rows[0]!.distance < 1020).toBe(true)
    expect(Math.abs((rows[2]?.distance ?? 0) - 800)).toBeLessThan(30)
    expect(rows.every((r) => r.status === 'noTarget')).toBe(true)
  })

  it('blocos curtos ficam inteiros', () => {
    const steps = [step(0, 'active', distance(1000), speed(4, 4.4)), step(1, 'recovery', time(120)), step(2, 'active', repeat(0, 5))]
    const segments: Segment[] = []
    const laps: LapSummary[] = []
    let offset = 0
    for (let i = 0; i < 5; i += 1) {
      const fast = seg(240, 1000, 165)
      const easy = seg(120, 300, 130)
      laps.push(lapOf(0, 'active', offset, [fast]), lapOf(1, 'recovery', offset + 240, [easy]))
      segments.push(fast, easy)
      offset += 360
    }
    const blocks = buildBlocks(structure(steps, laps), zones)
    expect(blocks).toHaveLength(10)
    expect(blockKilometers(blocks, track(segments), zones).size).toBe(0)
  })

  it('status do km usa o alvo do bloco', () => {
    const p = continuous(kms([300, 300, 320, 280]), pace)
    expect((blockKilometers(buildBlocks(p.s, zones), p.samples, zones).get(0) ?? []).map((r) => r.status)).toEqual(['inTarget', 'inTarget', 'slower', 'faster'])
    const z = continuous(kms([300, 300, 300, 300], [150, 165, 130, 150]), hrZone(3))
    expect((blockKilometers(buildBlocks(z.s, zones), z.samples, zones).get(0) ?? []).map((r) => r.status)).toEqual(['inTarget', 'aboveTarget', 'belowTarget', 'inTarget'])
  })

  it('bloco de uma volta ganha queda de pace pelos km', () => {
    const { s, samples } = continuous(kms([300, 300, 300, 300, 300, 300, 315, 315]), open)
    const blocks = buildBlocks(s, null)
    const fade = assess(blocks, context(blockKilometers(blocks, samples, null))).negatives.find((f) => f.kind === 'paceFade')
    expect(fade?.blockOrdinal).toBe(0)
    expect(Math.abs((fade?.facts.fade ?? 0) - 15)).toBeLessThan(1)
    expect(assess(blocks, context()).negatives.some((f) => f.kind === 'paceFade')).toBe(false)
  })

  it('corrida livre', () => {
    const rows = kilometerSplits(track([seg(750, 2500)]), zones)
    expect(rows.map((r) => r.label)).toEqual(['Km 1', 'Km 2', 'Km 3'])
    expect(Math.abs((rows[0]?.seconds ?? 0) - 300)).toBeLessThan(1)
    expect(Math.abs((rows[0]?.distance ?? 0) - 1000)).toBeLessThan(1)
    expect(Math.abs((rows[2]?.distance ?? 0) - 500)).toBeLessThan(20)
    expect(rows.every((r) => r.status === 'noTarget' && r.kind === 'active' && r.laps.length === 1 && r.prescribed === null)).toBe(true)
    expect(rows[0]?.dominantZone).toBe(3)
    expect(kilometerSplits([], null)).toEqual([])
    expect(kilometerSplits(track([seg(606, 2020)]), null)).toHaveLength(2)
  })

  it('tempo do km pula pausas e mantém tempo quando a distância avança', () => {
    const { s, samples: running } = continuous(kms([300, 300, 300]), pace)
    const samples = running.map((sample) => (sample.t > 450 ? { ...sample, t: sample.t + 120 } : sample))
    const laps = s.laps.map((item) => ({ ...item, timerSeconds: 900 }))
    const rows = blockKilometers(buildBlocks({ ...s, laps }, zones), samples, zones).get(0) ?? []
    expect(rows).toHaveLength(3)
    expect(rows.every((r) => Math.abs(r.seconds - 300) < 6 && r.status === 'inTarget')).toBe(true)
    expect(kilometerSplits(samples, null).every((r) => Math.abs(r.seconds - 300) < 6)).toBe(true)
    const gapped = running.filter((sample) => sample.t <= 400 || sample.t >= 420)
    const blocks = buildBlocks(s, zones)
    expect((blockKilometers(blocks, gapped, zones).get(0) ?? []).map((r) => r.seconds)).toEqual((blockKilometers(blocks, running, zones).get(0) ?? []).map((r) => r.seconds))
    expect(kilometerSplits(gapped, null).map((r) => r.seconds)).toEqual(kilometerSplits(running, null).map((r) => r.seconds))
  })

  it('blocos ficam em ordem cronológica', () => {
    const steps = [step(0, 'warmup', time(900)), step(1, 'active', distance(1000), speed(4, 4.4)), step(2, 'recovery', time(120)), step(3, 'active', repeat(1, 3)), step(4, 'active', distance(5000)), step(5, 'cooldown', time(600))]
    const laps: LapSummary[] = []
    let offset = 0
    const add = (index: number, intensity: StepIntensity, segments: Segment[]) => {
      laps.push(lapOf(index, intensity, offset, segments))
      offset += segments.reduce((sum, s) => sum + s.seconds, 0) + 30
    }
    add(0, 'warmup', [seg(900, 2700)])
    add(1, 'active', [seg(240, 1000)])
    add(2, 'recovery', [seg(120, 300)])
    add(1, 'active', [seg(240, 1000)])
    for (let i = 0; i < 5; i += 1) add(4, 'active', kms([300]))
    add(5, 'cooldown', [seg(600, 1800)])
    const blocks = buildBlocks(structure(steps, laps), null)
    const executed = blocks.filter((b) => b.laps.length > 0)
    expect(executed.flatMap((b) => b.laps)).toEqual(laps)
    for (let i = 0; i + 1 < executed.length; i += 1) {
      const last = executed[i]!.laps.at(-1)!
      expect(last.startOffset + last.timerSeconds <= executed[i + 1]!.laps[0]!.startOffset).toBe(true)
    }
    expect(blocks.some((b) => b.laps.length === 0 && b.status === 'notExecuted')).toBe(true)
  })
})
