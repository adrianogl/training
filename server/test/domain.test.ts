import { describe, expect, it } from 'vitest'
import type { ReadinessInput } from '../src/domain/domainTypes.js'
import { acuteChronicRatio, fitnessFatigueForm, loadFocus } from '../src/domain/load.js'
import { bodyBatteryMorningMax, hrvComponent, loadComponent, readiness, readinessBreakdown, readinessComponents, readinessVerdict } from '../src/domain/readiness.js'
import { addDays } from '../src/garminSync.js'

const b = { lowUpper: 38, balancedLow: 41, balancedUpper: 53 }

function input(overrides: Partial<{ hrv: number | null; baseline: typeof b | null; sleep: number | null; bb: number | null; load: number | null }> = {}): ReadinessInput {
  const value = { hrv: 47, baseline: b, sleep: 80, bb: 70, load: 1.0, ...overrides }
  return { hrvLastNight: value.hrv, hrvBaseline: value.baseline, sleepScore: value.sleep, bodyBatteryMorningMax: value.bb, acuteChronic: value.load }
}

const normalDay = () => input({ hrv: 45.5, sleep: 64, bb: 75, load: 1.5375 })

describe('prontidão (paridade com o Swift)', () => {
  it('rampas do HRV', () => {
    expect(hrvComponent(30, b)).toBe(0)
    expect(hrvComponent(39.5, b)).toBeCloseTo(30, 9)
    expect(hrvComponent(41, b)).toBe(60)
    expect(hrvComponent(47, b)).toBeCloseTo(80, 9)
    expect(hrvComponent(60, b)).toBe(100)
    const flat = { lowUpper: 40, balancedLow: 40, balancedUpper: 40 }
    expect([hrvComponent(39, flat), hrvComponent(40, flat), hrvComponent(41, flat)]).toEqual([0, 60, 100])
  })

  it('rampas da carga', () => {
    expect([loadComponent(1.0), loadComponent(0.5), loadComponent(1.8)]).toEqual([100, 0, 0])
    expect(loadComponent(1.55)).toBeCloseTo(50, 9)
    expect(loadComponent(0.65)).toBeCloseTo(50, 9)
    expect([loadComponent(0.8), loadComponent(1.3), loadComponent(0.2), loadComponent(2.5)]).toEqual([100, 100, 0, 0])
  })

  it('nota, parcial e redistribuição', () => {
    expect(readiness(input())).toEqual({ score: 82, partial: false, verdict: 'hard' })
    expect(readiness(input({ bb: null }))).toMatchObject({ score: 85, partial: true })
    expect(readiness(input({ baseline: null }))).toMatchObject({ score: 83, partial: true })
    expect(readiness(input({ hrv: null, sleep: null, bb: 90 }))).toBeNull()
    expect(readiness(input({ baseline: null, sleep: null, bb: 90 }))).toBeNull()
    expect(readiness(input({ hrv: null, bb: null, load: null }))).toMatchObject({ score: 80, partial: true })
    expect(readiness(input({ hrv: null, sleep: 150, bb: -20, load: null }))?.score).toBe(56)
  })

  it('faixas do veredito', () => {
    expect([39, 40, 69, 70].map(readinessVerdict)).toEqual(['rest', 'moderate', 'moderate', 'hard'])
  })

  it('Body Battery da manhã usa a janela de 3 horas', () => {
    const end = 1_800_000_000_000
    const samples: [number, number][] = [[end - 60_000, 99], [end, 40], [end + 3_600_000, 65], [end + 3 * 3_600_000, 58], [end + 3 * 3_600_000 + 1_000, 95]]
    expect(bodyBatteryMorningMax(samples, end)).toBe(65)
    expect(bodyBatteryMorningMax([[end - 1_000, 80]], end)).toBeNull()
  })

  it('o detalhamento soma a diferença para o normal e bate com o mockup', () => {
    const history = Array.from({ length: 20 }, normalDay)
    const result = readinessBreakdown(input({ hrv: 51.5, sleep: 54, bb: 85, load: 1.55 }), history)
    const points = (component: string) => result?.factors.find((factor) => factor.component === component)?.points
    expect(points('hrv')).toBeCloseTo(7, 6)
    expect(points('sleep')).toBeCloseTo(-2.5, 6)
    expect(points('bodyBattery')).toBeCloseTo(2, 6)
    expect(points('load')).toBeCloseTo(-0.5, 6)
    expect(result?.factors[0]?.component).toBe('hrv')
    const sum = result?.factors.reduce((total, factor) => total + (factor.points ?? 0), 0) ?? 0
    expect(sum).toBeCloseTo((result?.score ?? 0) - (result?.normal ?? 0), 9)
  })

  it('precisa de 14 dias de histórico e renormaliza os pesos', () => {
    const short = readinessBreakdown(input(), Array.from({ length: 13 }, normalDay))
    expect(short?.normal).toBeNull()
    expect(short?.factors.every((factor) => factor.points === null && factor.normalScore === null)).toBe(true)
    const missing = readinessBreakdown(input({ bb: null }), Array.from({ length: 20 }, normalDay))
    const present = missing?.factors.filter((factor) => factor.todayScore !== null) ?? []
    expect(present).toHaveLength(3)
    expect(present.reduce((sum, factor) => sum + factor.weight, 0)).toBeCloseTo(1, 9)
    expect(missing?.factors.at(-1)?.component).toBe('bodyBattery')
  })

  it('os componentes reproduzem a média ponderada', () => {
    const scores = readinessComponents(input())
    const weights = { hrv: 0.35, sleep: 0.25, bodyBattery: 0.2, load: 0.2 }
    const entries = Object.entries(scores) as [keyof typeof weights, number][]
    const weighted = entries.reduce((sum, [key, value]) => sum + value * weights[key], 0)
    const total = entries.reduce((sum, [key]) => sum + weights[key], 0)
    expect(Math.round(weighted / total)).toBe(readiness(input())?.score)
  })
})

describe('carga (paridade com o Swift)', () => {
  const start = '2026-01-01'

  it('média móvel com carga constante e forma do dia anterior', () => {
    const loads = new Map(Array.from({ length: 100 }, (_, index) => [addDays(start, index), 100] as [string, number]))
    const points = fitnessFatigueForm(loads, start, '2026-04-10')
    expect(points).toHaveLength(100)
    expect(points[0]?.fitness).toBeCloseTo(100 / 42, 9)
    expect(points[0]?.fatigue).toBeCloseTo(100 / 7, 9)
    expect(points[0]?.form).toBe(0)
    expect((points.at(-1)?.fatigue ?? 0) > 99).toBe(true)
    const two = fitnessFatigueForm(new Map([[start, 100]]), start, addDays(start, 1))
    expect(two[1]?.form).toBeCloseTo(100 / 42 - 100 / 7, 9)
    expect(fitnessFatigueForm(new Map(), addDays(start, 1), start)).toEqual([])
  })

  it('razão aguda/crônica', () => {
    const on = addDays(start, 27)
    const loads = new Map<string, number>()
    for (let index = 0; index < 7; index += 1) loads.set(addDays(on, -index), 100)
    for (let index = 7; index < 28; index += 1) loads.set(addDays(on, -index), 50)
    expect(acuteChronicRatio(loads, on)).toBeCloseTo(1.6, 9)
    expect(acuteChronicRatio(new Map(), start)).toBeNull()
    expect(acuteChronicRatio(new Map([[addDays(start, -28), 100]]), start)).toBeNull()
  })

  it('foco da carga por zona', () => {
    const one = loadFocus([{ load: 100, zoneSeconds: [0, 600, 300, 100, 0] }])
    expect(one?.lowAerobic).toBeCloseTo(0.6, 9)
    expect(one?.highAerobic).toBeCloseTo(0.4, 9)
    expect(loadFocus([{ load: 100, zoneSeconds: [0, 0, 0, 0, 0] }, { load: 0, zoneSeconds: [1, 1, 1, 1, 1] }])).toBeNull()
  })
})
