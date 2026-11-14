import { describe, expect, it } from 'vitest'
import type { Finding } from '../src/analysis/analysisTypes.js'
import { assess } from '../src/analysis/assessment.js'
import { block, distance, emptyContext as ctx, paceLaps, speed, step } from './analysisHelpers.js'

const speedTarget = step(1, 'active', distance(5000), speed(3.9, 4.1))
const kinds = (findings: Finding[]) => findings.map((f) => f.kind)

describe('avaliação (paridade com AssessmentTests)', () => {
  it('blocos no alvo são positivos', () => {
    const a = assess([block({ kind: 'warmup', label: 'Aquecimento' }), block({ label: 'Bloco 1', prescribed: speedTarget, status: 'inTarget' }), block({ label: 'Bloco 2', prescribed: speedTarget, status: 'inTarget' })], ctx())
    const finding = a.positives.find((f) => f.kind === 'blockInTarget')
    expect(finding).toMatchObject({ group: 'positive', blockOrdinal: null, facts: { inTarget: 2, total: 2 } })
    expect(a.positives.filter((f) => f.kind === 'blockInTarget')).toHaveLength(1)
    expect(kinds(assess([block({ prescribed: speedTarget, status: 'slower' }), block({ label: 'Bloco 2' })], ctx()).positives)).not.toContain('blockInTarget')
  })

  it('fora do alvo é negativo', () => {
    const a = assess([block({ prescribed: speedTarget, status: 'inTarget' }), block({ label: 'Bloco 2', prescribed: speedTarget, avgSpeed: 4.3, status: 'faster' })], ctx())
    const off = a.negatives.filter((f) => f.kind === 'blockOffTarget')
    expect(off).toHaveLength(1)
    expect(off[0]).toMatchObject({ blockOrdinal: 1, facts: { speed: 4.3, targetLow: 3.9, targetHigh: 4.1 } })
    expect(a.positives.find((f) => f.kind === 'blockInTarget')?.facts.total).toBe(2)
    expect(kinds(assess([block({ prescribed: speedTarget, status: 'inTarget' })], ctx()).negatives)).not.toContain('blockOffTarget')
  })

  it('incompleto é negativo', () => {
    const a = assess([block({ prescribed: speedTarget, distance: 3000, status: 'incomplete' }), block({ label: 'Bloco 2', prescribed: speedTarget, seconds: 0, distance: 0, avgSpeed: null, avgHeartRate: null, status: 'notExecuted' })], ctx())
    const incomplete = a.negatives.filter((f) => f.kind === 'stepIncomplete')
    expect(incomplete.map((f) => f.blockOrdinal)).toEqual([0, 1])
    expect(incomplete[0]?.facts).toMatchObject({ distance: 3000, targetDistance: 5000 })
    expect(kinds(assess([block({ prescribed: speedTarget, status: 'inTarget' })], ctx()).negatives)).not.toContain('stepIncomplete')
  })

  it('pace constante', () => {
    const steady = assess([block({ laps: paceLaps([250, 248, 251, 247, 252]) })], ctx()).positives.find((f) => f.kind === 'steadyPace')
    expect(steady?.blockOrdinal).toBe(0)
    expect(steady?.facts.spread).toBeCloseTo(5, 3)
    expect(kinds(assess([block({ laps: paceLaps([250, 248, 262, 247, 252]) })], ctx()).positives)).not.toContain('steadyPace')
    expect(kinds(assess([block({ laps: [...paceLaps([250, 249, 251]), ...paceLaps([300], undefined, 200)] })], ctx()).positives)).toContain('steadyPace')
    expect(kinds(assess([block({ laps: paceLaps([250, 250]) })], ctx()).positives)).not.toContain('steadyPace')
  })

  it('queda de pace', () => {
    const fade = assess([block({ laps: paceLaps([250, 250, 251, 249, 260]) })], ctx()).negatives.find((f) => f.kind === 'paceFade')
    expect(fade?.blockOrdinal).toBe(0)
    expect(fade?.facts.fade).toBeCloseTo(10, 3)
    expect(kinds(assess([block({ laps: paceLaps([250, 250, 251, 249, 255]) })], ctx()).negatives)).not.toContain('paceFade')
  })

  it('deriva cardíaca', () => {
    const drift = assess([block({ laps: paceLaps(Array(6).fill(250), [150, 152, 155, 158, 161, 163]) })], ctx()).attention.find((f) => f.kind === 'cardiacDrift')
    expect(drift).toMatchObject({ group: 'attention', blockOrdinal: 0, facts: { fromHR: 151, toHR: 162 } })
    expect(Math.abs((drift?.facts.rise ?? 0) - 0.07)).toBeLessThan(0.005)
    expect(kinds(assess([block({ laps: paceLaps(Array(6).fill(250), [150, 151, 150, 152, 151, 152]) })], ctx()).attention)).not.toContain('cardiacDrift')
    expect(kinds(assess([block({ laps: paceLaps([260, 258, 250, 248, 240, 238], [150, 152, 155, 158, 161, 163]) })], ctx()).attention)).not.toContain('cardiacDrift')
  })

  it('boa recuperação', () => {
    const good = assess([block({ label: 'Tiro 1', maxHeartRate: 180 }), block({ kind: 'recovery', label: 'Recuperação 1', avgHeartRate: 150 })], ctx()).positives.find((f) => f.kind === 'goodRecovery')
    expect(good).toMatchObject({ blockOrdinal: 1, facts: { drop: 30 } })
    expect(kinds(assess([block({ label: 'Tiro 1', maxHeartRate: 180 }), block({ kind: 'recovery', label: 'Recuperação 1', avgHeartRate: 160 })], ctx()).positives)).not.toContain('goodRecovery')
  })

  it('FC menor que antes no mesmo ritmo', () => {
    const previous = [[block({ avgSpeed: 4, avgHeartRate: 160 })], [block({ avgSpeed: 4, avgHeartRate: 170 })]]
    const lower = assess([block({ avgSpeed: 4.05, avgHeartRate: 155 })], ctx({ previous })).positives.find((f) => f.kind === 'lowerHeartRateThanBefore')
    expect(lower).toMatchObject({ blockOrdinal: 0, facts: { delta: 5 } })
    expect(kinds(assess([block({ avgSpeed: 4, avgHeartRate: 158 })], ctx({ previous })).positives)).not.toContain('lowerHeartRateThanBefore')
    expect(kinds(assess([block({ avgSpeed: 3.8, avgHeartRate: 150 })], ctx({ previous })).positives)).not.toContain('lowerHeartRateThanBefore')
    const recent = assess([block({ avgSpeed: 4, avgHeartRate: 155 })], ctx({ previous: [[block({ label: 'Bloco 9', avgSpeed: 4, avgHeartRate: 140 })], [block({ avgSpeed: 4, avgHeartRate: 162 })]] }))
    expect(recent.positives.find((f) => f.kind === 'lowerHeartRateThanBefore')?.facts.delta).toBe(7)
  })

  it('bloco leve em zona alta, treino forte com prontidão baixa e carga alta', () => {
    const zonesFound = assess([block({ kind: 'warmup', label: 'Aquecimento', dominantZone: 3 }), block({ dominantZone: 4 }), block({ kind: 'cooldown', label: 'Desaquecimento', dominantZone: 2 })], ctx()).attention.filter((f) => f.kind === 'zoneAboveTarget')
    expect(zonesFound.map((f) => f.blockOrdinal)).toEqual([0])
    expect(zonesFound[0]?.facts.zone).toBe(3)
    const hard = [block({ prescribed: speedTarget, status: 'inTarget' })]
    expect(assess(hard, ctx({ readinessScore: 40 })).attention.find((f) => f.kind === 'hardOnLowReadiness')).toMatchObject({ blockOrdinal: null, facts: { readiness: 40 } })
    expect(kinds(assess([block({ dominantZone: 4 })], ctx({ readinessScore: 40 })).attention)).toContain('hardOnLowReadiness')
    expect(kinds(assess(hard, ctx({ readinessScore: 60 })).attention)).not.toContain('hardOnLowReadiness')
    expect(kinds(assess(hard, ctx()).attention)).not.toContain('hardOnLowReadiness')
    expect(kinds(assess([block({ dominantZone: 2 })], ctx({ readinessScore: 40 })).attention)).not.toContain('hardOnLowReadiness')
    expect(assess([block()], ctx({ acuteChronic: 1.6 })).attention.find((f) => f.kind === 'highAcuteChronic')).toMatchObject({ blockOrdinal: null, facts: { ratio: 1.6 } })
    expect(kinds(assess([block()], ctx({ acuteChronic: 1.5 })).attention)).not.toContain('highAcuteChronic')
  })

  it('sem nada a dizer', () => {
    const a = assess([block({ label: 'Volta 1', laps: paceLaps([330]), seconds: 330, distance: 1000, avgSpeed: 1000 / 330 }), block({ label: 'Volta 2', laps: paceLaps([335]), seconds: 335, distance: 1000, avgSpeed: 1000 / 335 })], ctx())
    expect(a).toEqual({ positives: [], negatives: [], attention: [] })
    expect(assess([], ctx())).toEqual({ positives: [], negatives: [], attention: [] })
  })
})
