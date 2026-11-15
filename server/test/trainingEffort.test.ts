import { describe, expect, it } from 'vitest'
import { workPace, workPaceOfBlocks } from '../src/analysis/workPace.js'
import type { WorkoutBlock } from '../src/analysis/analysisTypes.js'
import type { Effort } from '../src/domain/domainTypes.js'
import { bestEfforts, predict, riegel } from '../src/domain/prediction.js'
import { classifyRun } from '../src/domain/runKind.js'
import { trainingEfforts } from '../src/domain/trainingEffort.js'
import type { LapSummary, RunMetrics, RunShape } from '../src/fit/fitTypes.js'
import { addDays } from '../src/garminSync.js'
import type { ActivitySummary } from '../src/types.js'

const today = '2026-11-14'
const at = (offset: number) => addDays(today, offset)

const lap = (intensity: LapSummary['intensity'], timerSeconds: number, distance: number): LapSummary => ({
  stepIndex: null, intensity, trigger: null, startOffset: 0, timerSeconds, distance, avgSpeed: null, avgHeartRate: null,
} as LapSummary)

const block = (laps: LapSummary[], kind: WorkoutBlock['kind'] = 'active'): WorkoutBlock => ({
  kind, ordinal: 1, label: 'Ativo', prescribed: null, laps, seconds: 0, distance: 0, avgSpeed: null, avgHeartRate: null, maxHeartRate: null, dominantZone: null, status: 'noTarget',
})

const shape = (overrides: Partial<RunShape> = {}): RunShape => ({ name: null, hasRepeats: false, hasHardActiveStep: false, hasRepeatedActiveLaps: false, ...overrides })

function run(id: number, offset: number, name: string): ActivitySummary {
  return { id, name, type: 'running', day: at(offset), distanceMeters: 10_000, durationSeconds: 3000 } as ActivitySummary
}

const metricsOf = (pace: number, km: number, runShape: RunShape): RunMetrics => ({
  zone2Pace: null, thresholdPace: null, decoupling: null, hillIndex: null, workPace: { seconds: pace * km, meters: km * 1000 }, shape: runShape,
})

describe('pace de trabalho', () => {
  it('usa só os blocos ativos e descarta voltas curtas ou lentas', () => {
    const blocks = [block([lap('active', 227, 1000), lap('active', 13, 50), lap('active', 600, 1000), lap('warmup', 360, 1000)]), block([lap('warmup', 360, 1000)], 'warmup')]
    const work = workPaceOfBlocks(blocks)
    expect(work).toEqual({ seconds: 227, meters: 1000 })
  })

  it('não existe sem prescrição', () => {
    expect(workPace({ prescription: null, laps: [lap('active', 300, 1000)] })).toBeNull()
  })
})

describe('esforços de treino', () => {
  const thresholdRuns = [[2, 248], [9, 245], [16, 250], [23, 240]] as const
  const thresholdMetrics = (km = 6) => new Map(thresholdRuns.map(([offset, pace], index) => [index + 1, metricsOf(pace, km, shape({ name: 'Limiar' }))]))
  const thresholdActivities = thresholdRuns.map(([offset], index) => run(index + 1, -offset, 'Treino de limiar'))

  it('limiar usa a mediana das últimas quatro sessões, datada na mais recente', () => {
    const [effort] = trainingEfforts(thresholdActivities, thresholdMetrics(), [], today)
    expect(effort).toEqual({ distance: 10_000, seconds: (246.5 - 7) * 10, day: at(-2), kind: 'threshold' })
  })

  it('limiar exige 5 km de blocos ativos e VO2 exige 3 km', () => {
    expect(trainingEfforts(thresholdActivities, thresholdMetrics(4.9), [], today)).toEqual([])
    const vo2 = [run(10, -3, 'Tiros 1000')]
    expect(trainingEfforts(vo2, new Map([[10, metricsOf(230, 2.9, shape())]]), [], today)).toEqual([])
    expect(trainingEfforts(vo2, new Map([[10, metricsOf(230, 3, shape())]]), [], today)).toEqual([{ distance: 5000, seconds: (230 + 4) * 5, day: at(-3), kind: 'interval' }])
  })

  it('ignora sessões com mais de 90 dias', () => {
    const old = [run(11, -91, 'Limiar')]
    expect(trainingEfforts(old, new Map([[11, metricsOf(200, 6, shape())]]), [], today)).toEqual([])
  })

  it('ignora corridas sem pace de trabalho', () => {
    const plain = [run(12, -2, 'Limiar')]
    expect(trainingEfforts(plain, new Map([[12, { ...metricsOf(250, 6, shape()), workPace: null }]]), [], today)).toEqual([])
  })
})

describe('classificação', () => {
  it('repetições na estrutura viram intervalado e zona alta vira limiar', () => {
    expect(classifyRun(run(1, 0, 'Corrida'), shape({ hasRepeats: true }), [])).toBe('intervals')
    expect(classifyRun(run(1, 0, 'Corrida'), shape({ hasHardActiveStep: true }), [])).toBe('tempo')
    expect(classifyRun(run(1, 0, 'Rodagem leve'), shape(), [])).toBe('easy')
    expect(classifyRun(run(1, 0, 'Longão'), shape(), [])).toBe('long')
    expect(classifyRun(run(1, 0, 'Corrida'), shape({ hasRepeatedActiveLaps: true }), [])).toBe('intervals')
  })
})

describe('pesos da previsão', () => {
  const threshold: Effort = { distance: 10_000, seconds: 2400, day: at(-15), kind: 'threshold' }
  const interval: Effort = { distance: 5000, seconds: 1170, day: at(-30), kind: 'interval' }

  it('no 5 km, limiar pesa 1,0 e VO2 pesa 0,4', () => {
    const wThreshold = 1 - 15 / 150
    const wInterval = 0.4 * (1 - 30 / 150)
    const expected = (wThreshold * riegel(2400, 10_000, 5000) + wInterval * 1170) / (wThreshold + wInterval)
    expect(predict(5000, [threshold, interval], today)).toBeCloseTo(expected, 6)
  })

  it('VO2 só conta no 5 km', () => {
    for (const target of [10_000, 21_097.5]) {
      expect(predict(target, [threshold, interval], today)).toBeCloseTo(riegel(2400, 10_000, target), 6)
    }
  })

  it('limiar pesa metade na maratona', () => {
    const recent: Effort = { ...threshold, day: at(0) }
    const race: Effort = { distance: 21_097.5, seconds: 5600, day: at(0), kind: 'race' }
    const expected = (0.5 * riegel(2400, 10_000, 42_195) + riegel(5600, 21_097.5, 42_195)) / 1.5
    expect(predict(42_195, [recent, race], today)).toBeCloseTo(expected, 6)
  })

  it('mantém um esforço por tipo', () => {
    expect(bestEfforts([threshold, interval], 5000, today)).toHaveLength(2)
  })
})
