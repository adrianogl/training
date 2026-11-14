import { describe, expect, it } from 'vitest'
import { evolutionReading, trend } from '../src/evolutionReading'
import type { MetricSeries } from '../src/types'

function metric(key: string, current: number, change: number): MetricSeries {
  return { key, points: [], movingAverage: [], stats: { current, average: current, minimum: current, maximum: current, change }, band: null }
}

describe('leitura da evolução', () => {
  it('tendência considera o sentido bom de cada métrica', () => {
    expect(trend('vo2max', 2, 51)).toBe('better')
    expect(trend('restingHeartRate', -3, 46)).toBe('better')
    expect(trend('predictionHalf', 200, 6070)).toBe('worse')
    expect(trend('vo2max', 0.2, 51)).toBe('steady')
    expect(trend('vo2max', null, 51)).toBeNull()
  })

  it('frase com a previsão da meia e as métricas que melhoraram', () => {
    const half = { key: 'predictionHalf', label: '21,1 km', seconds: 6070, change: -200 }
    const series = [metric('vo2max', 51, 2), metric('fitness', 50, -5), metric('hrv', 48, 3)]
    expect(evolutionReading(half, series, 'em 3 meses')).toBe('Em evolução: previsão da meia caiu 3:20 em 3 meses, com VO2 e HRV melhores.')
    expect(evolutionReading({ ...half, change: 10 }, [], 'em 6 semanas')).toBe('Estável: previsão da meia ficou estável em 6 semanas.')
    expect(evolutionReading({ ...half, seconds: null, change: null }, series, 'em 1 ano')).toMatch(/A leitura aparece/)
  })
})
