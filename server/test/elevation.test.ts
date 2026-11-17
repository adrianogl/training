import { describe, expect, it } from 'vitest'
import type { WorkoutBlock } from '../src/analysis/analysisTypes.js'
import { assess } from '../src/analysis/assessment.js'
import { ElevationCounter, flatPaceOf } from '../src/analysis/elevation.js'
import { kilometerSplits } from '../src/analysis/kilometers.js'
import { findingEvidence, findingText } from '../src/analysis/narrative.js'

function row(index: number, pace: number, climb = 0, descent = 0): WorkoutBlock {
  return {
    kind: 'active', ordinal: index + 1, label: `Km ${index + 1}`, prescribed: null,
    laps: [{ stepIndex: null, intensity: null, trigger: null, startOffset: index * pace, timerSeconds: pace, distance: 1000, avgSpeed: 1000 / pace, avgHeartRate: null, maxHeartRate: null, climb, descent }],
    seconds: pace, distance: 1000, avgSpeed: 1000 / pace, avgHeartRate: null, maxHeartRate: null, dominantZone: null, status: 'noTarget',
  }
}

function run(rows: WorkoutBlock[]) {
  const block: WorkoutBlock = {
    kind: 'active', ordinal: 1, label: 'Bloco 1', prescribed: null, laps: [], seconds: rows.reduce((sum, item) => sum + item.seconds, 0),
    distance: rows.length * 1000, avgSpeed: null, avgHeartRate: null, maxHeartRate: null, dominantZone: null, status: 'noTarget',
  }
  return { blocks: [block], assessment: assess([block], { readinessScore: null, acuteChronic: null, previous: [], kilometers: new Map([[0, rows]]), continuity: null }) }
}

describe('subida e descida na análise', () => {
  it('converte o km com subida e descida no equivalente no plano', () => {
    expect(flatPaceOf(316, 1000, 30, 6)).toBeCloseTo(290.4, 0)
    expect(flatPaceOf(316, 1000, 4, 3)).toBe(316)
  })

  it('ignora o ruído do altímetro', () => {
    const noisy = new ElevationCounter()
    for (const altitude of [800, 801, 800, 801.5, 800.5, 801]) noisy.add(altitude)
    const hill = new ElevationCounter()
    for (const altitude of [800, 803, 806, 810, 808, 805]) hill.add(altitude)
    expect([noisy.climb, noisy.descent]).toEqual([0, 0])
    expect([hill.climb, hill.descent]).toEqual([10, 5])
  })

  it('último km lento numa subida não é perda de ritmo e aparece citado', () => {
    const rows = [...Array.from({ length: 10 }, (_, index) => row(index, 285)), row(10, 300, 25)]
    const { blocks, assessment } = run(rows)
    const climb = assessment.positives.find((finding) => finding.kind === 'climbSlower')
    expect(assessment.negatives.some((finding) => finding.kind === 'paceFade')).toBe(false)
    expect(climb?.facts).toMatchObject({ fromKilometer: 11, toKilometer: 11, climb: 25, pace: 300 })
    expect(climb === undefined ? null : findingEvidence(climb, blocks)).toBe('km 11: +25 m a 5:00/km')
    expect(climb === undefined ? null : findingText(climb, blocks)).toBe('O km 11, com +25 m, saiu a 5:00/km, o equivalente a 4:37/km no plano.')
  })

  it('queda que continua mesmo descontando a subida cita o desnível', () => {
    const rows = [...Array.from({ length: 10 }, (_, index) => row(index, 285)), row(10, 320, 7)]
    const fade = run(rows).assessment.negatives.find((finding) => finding.kind === 'paceFade')
    expect(fade?.facts).toMatchObject({ flatAdjusted: 1, lastClimb: 7, pace: 320 })
  })

  it('junta km seguidos de subida e separa a descida', () => {
    const rows = [row(0, 305, 4, 6), row(1, 316, 30, 6), row(2, 282, 0, 20), row(3, 286), row(4, 285), row(5, 300, 8, 1), row(6, 298, 9)]
    const positives = run(rows).assessment.positives
    const climbs = positives.filter((finding) => finding.kind === 'climbSlower')
    expect(climbs.map((finding) => [finding.facts.fromKilometer, finding.facts.toKilometer])).toEqual([[2, 2], [6, 7]])
    expect(positives.find((finding) => finding.kind === 'descentFaster')?.facts).toMatchObject({ fromKilometer: 3, descent: 20 })
  })

  it('os km do treino trazem a subida da altitude gravada', () => {
    const samples = Array.from({ length: 401 }, (_, second) => ({ t: second, heartRate: null, speed: 5, altitude: 800 + (second < 200 ? second * 0.1 : 20), distance: second * 5 }))
    const rows = kilometerSplits(samples, null)
    expect(rows[0]?.laps[0]?.climb).toBeCloseTo(20, 5)
    expect(rows.at(-1)?.laps[0]?.climb).toBe(0)
  })
})
