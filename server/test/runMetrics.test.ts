import { describe, expect, it } from 'vitest'
import { minettiCost } from '../src/domain/raceStrategy.js'
import type { FitSample } from '../src/fit/fitTypes.js'
import { decoupling, hillIndex, thresholdPace, zone2Pace } from '../src/fit/runMetrics.js'

const sample = (t: number, heartRate: number | null, speed: number | null, altitude: number | null = null, distance: number | null = null): FitSample => ({ t, heartRate, speed, altitude, distance })
function series(build: (t: number) => FitSample, to: number, from = 0, step = 5): FitSample[] {
  const result: FitSample[] = []
  for (let t = from; t <= to; t += step) result.push(build(t))
  return result
}

describe('métricas de corrida (paridade com RunMetricsTests)', () => {
  it('pace em Z2 ignora o aquecimento e precisa de 5 minutos', () => {
    expect(zone2Pace(series((t) => (t < 600 ? sample(t, 130, 5) : sample(t, 135, 3)), 1800), 120, 140)).toBeCloseTo(1000 / 3, 9)
    expect(zone2Pace(series((t) => sample(t, t >= 600 && t < 800 ? 135 : 160, 3), 1800), 120, 140)).toBeNull()
    const first = series((t) => sample(t, 135, 3), 745, 600)
    const second = series((t) => sample(t, 135, 3), 1345, 1200)
    expect(zone2Pace([...first, ...second], 120, 140)).not.toBeNull()
    expect(zone2Pace(first, 120, 140)).toBeNull()
  })

  it('pace de limiar usa só trechos longos e corta nas pausas', () => {
    const long = series((t) => (t >= 300 && t < 700 ? sample(t, 166, 4) : sample(t, 140, 3)), 1200)
    const short = series((t) => (t >= 300 && t < 500 ? sample(t, 165, 5) : sample(t, 140, 3)), 1200)
    expect(thresholdPace([long, short], 165)).toBe(250)
    expect(thresholdPace([series((t) => sample(t, 140, 3), 1200)], 165)).toBeNull()
    expect(thresholdPace([[...series((t) => sample(t, 165, 4), 175), ...series((t) => sample(t, 165, 4), 575, 400)]], 165)).toBeNull()
  })

  it('desacoplamento precisa de uma hora', () => {
    expect(decoupling(series((t) => sample(t, 140, 3), 3500))).toBeNull()
    expect(decoupling(series((t) => sample(t, t < 2300 ? 140 : 154, 3), 4000))).toBeCloseTo((1 - 1 / 1.1) * 100, 2)
  })

  it('força em subida compara a subida ajustada com o plano', () => {
    expect(hillIndex(series((t) => sample(t, 150, 3, 100, t * 3), 1800))).toBeNull()
    const climb = (heartRateFlat: number, heartRateClimb: number, noise: number[] = [0]) =>
      series((t) => {
        if (t <= 600) return sample(t, heartRateFlat, 3, 100, t * 3)
        const climbed = (t - 600) * 2.4
        return sample(t, heartRateClimb, 2.4, 100 + climbed * 0.05 + (noise[Math.trunc((t - 600) / 5) % noise.length] ?? 0), 1800 + climbed)
      }, 1000)
    const expected = (100 * 2.4 * minettiCost(0.05)) / minettiCost(0) / 3
    expect(hillIndex(climb(150, 152))).toBeCloseTo(expected, 6)
    expect(hillIndex(climb(130, 160))).toBeNull()
    expect(Math.abs((hillIndex(climb(150, 152, [0.3, -0.3, 0.3, 0.3, -0.3, -0.3, 0.3, -0.3])) ?? 0) - expected)).toBeLessThan(3)
  })

  it('descida antes da subida fica fora do plano', () => {
    const s = series((t) => {
      if (t <= 600) return sample(t, 150, 3, 100, t * 3)
      if (t <= 615) {
        const dropped = (t - 600) * 5
        return sample(t, 150, 5, 100 - dropped * 0.03, 1800 + dropped)
      }
      const climbed = (t - 615) * 2.4
      return sample(t, 152, 2.4, 100 - 2.25 + climbed * 0.08, 1800 + 75 + climbed)
    }, 1000)
    const index = hillIndex(s) ?? 0
    expect(Math.abs(index - (100 * 2.4 * minettiCost(0.08)) / minettiCost(0) / 3)).toBeLessThan(1)
    expect(index - 119.437).toBeGreaterThan(0.5)
  })
})
