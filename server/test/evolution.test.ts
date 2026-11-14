import { describe, expect, it } from 'vitest'
import { PREDICTION } from '../src/domain/domainConstants.js'
import type { Effort } from '../src/domain/domainTypes.js'
import { buildEvolution, efforts, metricStats, movingAverage } from '../src/domain/evolution.js'
import { bestEfforts, predict, riegel, smoothedVo2max } from '../src/domain/prediction.js'
import { weekStartOf } from '../src/domain/today.js'
import { addDays } from '../src/garminSync.js'
import type { ActivitySummary, HealthDay } from '../src/types.js'

const today = '2026-11-14'
const at = (offset: number) => addDays(today, offset)
const effort = (distance: number, seconds: number, offset: number, kind: Effort['kind']): Effort => ({ distance, seconds, day: at(offset), kind })

function day(date: string, hrv: number): HealthDay {
  return {
    day: date,
    restingHeartRate: 48,
    averageStress: 25,
    steps: 8000,
    bodyBattery: { highest: 80, lowest: 20, atWake: 75, charged: 50, drained: 40, morningMax: 80 },
    sleep: { seconds: 27000, score: 70, deep: 5000, light: 15000, rem: 5000, awake: 2000, start: null, end: null },
    hrv: { lastNight: hrv, weeklyAvg: hrv, status: 'BALANCED', lowUpper: 38, balancedLow: 41, balancedUpper: 53 },
    readiness: null,
  }
}

function run(date: string, km: number, overrides: Partial<ActivitySummary> = {}): ActivitySummary {
  return {
    id: Number(date.replaceAll('-', '')), name: 'Rodagem', type: 'running', startLocal: `${date}T07:00:00`, day: date,
    distanceMeters: km * 1000, durationSeconds: km * 330, movingSeconds: km * 320, elevationGain: 20, averageSpeed: 3, maxSpeed: 4,
    averageHeartRate: 140, maxHeartRate: 160, cadence: 170, trainingLoad: 60, aerobicEffect: 3, anaerobicEffect: 1, vo2max: 50,
    zoneSeconds: [100, 2000, 500, 100, 0], fastestKmSeconds: 280, fastest5kSeconds: 1500, laps: 8, workoutId: null,
    ...overrides,
  }
}

describe('previsão de prova (paridade com o Swift)', () => {
  it('riegel de 10 km para meia', () => {
    expect(Math.abs(riegel(2700, 10000, 21097.5) - 5958)).toBeLessThan(2)
  })

  it('ignora esforço antigo, no limite da janela e no futuro', () => {
    expect(predict(21097.5, [effort(10000, 2700, -PREDICTION.raceEffortWindowDays - 30, 'race')], today)).toBeNull()
    expect(predict(21097.5, [effort(10000, 2700, -PREDICTION.raceEffortWindowDays, 'race')], today)).toBeNull()
    expect(predict(21097.5, [effort(10000, 2700, 1, 'race')], today)).toBeNull()
  })

  it('pondera por tipo e idade', () => {
    const wRace = 1 - 30 / PREDICTION.raceEffortWindowDays
    const expected = (wRace * riegel(2700, 10000, 21097.5) + 0.7 * riegel(1200, 5000, 21097.5)) / (wRace + 0.7)
    expect(predict(21097.5, [effort(10000, 2700, -30, 'race'), effort(5000, 1200, 0, 'split5k')], today)).toBeCloseTo(expected, 6)
  })

  it('usa o melhor esforço de cada tipo', () => {
    const list = Array.from({ length: 20 }, (_, index) => effort(5000, 1680, -(index + 1), 'split5k'))
    list.push(effort(5000, 1320, -5, 'split5k'))
    expect(Math.abs((predict(5000, list, today) ?? 0) - 1320)).toBeLessThan(1)
  })

  it('esforço antigo e rápido vence o novo e lento', () => {
    const oldFast = effort(5000, 1320, -60, 'split5k')
    const newSlow = effort(5000, 1680, 0, 'split5k')
    expect(predict(10000, [newSlow, oldFast], today)).toBeCloseTo(riegel(1320, 5000, 10000), 6)
    expect(bestEfforts([newSlow, oldFast], 10000, today)).toEqual([oldFast])
  })

  it('um por tipo mantém o peso entre tipos', () => {
    const window = PREDICTION.effortWindowDays
    const weights = [1 - 45 / PREDICTION.raceEffortWindowDays, 0.7 * (1 - 9 / window), 0.3 * (1 - 18 / window)]
    const times = [riegel(2700, 10000, 21097.5), riegel(1250, 5000, 21097.5), riegel(225, 1000, 21097.5)]
    const expected = weights.reduce((sum, w, index) => sum + w * (times[index] ?? 0), 0) / weights.reduce((a, b) => a + b, 0)
    const list = [effort(10000, 2700, -45, 'race'), effort(5000, 1250, -9, 'split5k'), effort(1000, 225, -18, 'split1k')]
    expect(predict(21097.5, list, today)).toBeCloseTo(expected, 6)
  })

  it('suaviza o VO2', () => {
    expect(smoothedVo2max([[at(-1), 56], [at(0), 42]], 2)).toEqual([[at(-1), 56], [at(0), 49]])
  })
})

describe('evolução', () => {
  it('média móvel e estatísticas', () => {
    const points: [string, number][] = [[at(-9), 10], [at(-2), 20], [at(0), 30]]
    expect(movingAverage(points, 7)).toEqual([[at(-9), 10], [at(-2), 20], [at(0), 25]])
    expect(metricStats(points)).toEqual({ current: 30, average: 20, minimum: 10, maximum: 30, change: 20 })
    expect(metricStats([])).toEqual({ current: null, average: null, minimum: null, maximum: null, change: null })
  })

  it('tira esforços de 1 km e 5 km só das corridas', () => {
    const list = efforts([run(at(0), 8), run(at(-1), 10, { type: 'cycling' }), run(at(-2), 3, { fastest5kSeconds: null })])
    expect(list.map((item) => item.kind)).toEqual(['split5k', 'split1k', 'split1k'])
  })

  it('monta séries, previsões e recordes do período', () => {
    const days = Array.from({ length: 50 }, (_, index) => day(at(-49 + index), 40 + (index % 5)))
    const runs = Array.from({ length: 40 }, (_, index) => run(at(-39 + index), index === 20 ? 21 : 8, index === 30 ? { fastestKmSeconds: 250, fastest5kSeconds: 1400, name: 'Tiros' } : {}))

    const evolution = buildEvolution(days, runs, today, 42)
    const byKey = new Map(evolution.series.map((item) => [item.key, item]))

    expect(evolution.periodDays).toBe(42)
    expect(byKey.get('hrv')?.points).toHaveLength(42)
    expect(byKey.get('hrv')?.band).toEqual([41, 53])
    expect(byKey.get('vo2max')?.stats.current).toBe(50)
    expect(byKey.get('monthlyVolume')?.stats.current).toBeCloseTo(29 * 8 + 21, 6)
    expect(byKey.get('zoneDistribution')?.stats.current).toBeCloseTo((2100 / 2700) * 100, 6)
    expect(byKey.get('cadence')?.stats.current).toBe(170)
    expect(evolution.predictions.map((item) => item.key)).toEqual(['prediction5k', 'prediction10k', 'predictionHalf', 'predictionFull'])
    expect(evolution.predictions[0]?.seconds).toBeGreaterThan(1300)
    expect(evolution.records.fastestKm).toEqual({ seconds: 250, day: at(-9), name: 'Tiros' })
    expect(evolution.records.longestRun?.meters).toBe(21000)
    expect(evolution.records.biggestWeek?.kilometers).toBeGreaterThan(0)
    expect(byKey.get('fatigue')?.points).toHaveLength(40)
    expect(evolution.weeks[0]?.start).toBe(weekStartOf(at(-41)))
    expect(evolution.weeks.at(-1)?.start).toBe(weekStartOf(today))
    expect(evolution.weeks.reduce((sum, week) => sum + week.kilometers, 0)).toBeCloseTo(40 * 8 + 13, 6)
    const lastWeekRuns = (evolution.weeks.at(-1)?.kilometers ?? 0) / 8
    expect(evolution.weeks.at(-1)?.zoneSeconds).toEqual([100, 2000, 500, 100, 0].map((value) => value * lastWeekRuns))
  })

  it('sem dados devolve séries vazias', () => {
    const evolution = buildEvolution([], [], today, 91)
    expect(evolution.series.every((item) => item.points.length === 0 && item.band === null)).toBe(true)
    expect(evolution.predictions.every((item) => item.seconds === null)).toBe(true)
    expect(evolution.records).toEqual({ fastestKm: null, fastest5k: null, longestRun: null, biggestWeek: null })
  })
})
