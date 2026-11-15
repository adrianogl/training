import { describe, expect, it } from 'vitest'
import { heatAdjustment, heatFraction } from '../src/domain/heat.js'
import { raceChecklist, racePaceKm, racePaceTarget, recentAverage, tuneUpDistance, weeklyVolumeTarget } from '../src/domain/raceChecklist.js'
import { weekStartOf } from '../src/domain/today.js'
import { addDays } from '../src/garminSync.js'
import { forecastAvailable, geocode, pickHour, raceWeather, startHour } from '../src/weather.js'

const today = '2026-11-14'

describe('ajuste por calor', () => {
  it('faixas da soma temperatura + orvalho em °F', () => {
    expect(heatFraction(95)).toBe(0)
    expect(heatFraction(105)).toBeCloseTo(0.0025, 9)
    expect(heatFraction(135)).toBeCloseTo(0.025, 9)
    expect(heatFraction(200)).toBe(0.1)
  })

  it('ajusta o tempo alvo e marca calor demais', () => {
    const mild = heatAdjustment({ hour: 7, temperature: 10, dewPoint: 5 }, 6000)
    expect(mild.fraction).toBe(0)
    expect(mild.adjustedSeconds).toBe(6000)
    const humid = heatAdjustment({ hour: 7, temperature: 25, dewPoint: 20 }, 6000)
    expect(humid.sumFahrenheit).toBeCloseTo(145, 6)
    expect(humid.adjustedSeconds).toBeCloseTo(6000 * (1 + 0.0375), 6)
    expect(heatAdjustment({ hour: 14, temperature: 35, dewPoint: 30 }, 6000).tooHot).toBe(true)
  })
})

describe('checklist da prova (paridade com o app)', () => {
  it('metas por distância', () => {
    expect([weeklyVolumeTarget(5000), weeklyVolumeTarget(10000), weeklyVolumeTarget(21097.5), weeklyVolumeTarget(42195)]).toEqual([25, 30, 40, 55])
    expect([racePaceTarget(21097.5), tuneUpDistance(21097.5), tuneUpDistance(42195)]).toEqual([15, 10, 21])
  })

  it('média das últimas 4 semanas divide por 4 mesmo com semana faltando', () => {
    const week = weekStartOf(today)
    expect(recentAverage(new Map([[addDays(week, -7), 40], [addDays(week, -14), 20]]), today)).toBe(15)
    expect(recentAverage(new Map([[week, 40]]), today)).toBeNull()
  })

  it('km no pace de prova contam só voltas inteiras na faixa', () => {
    const laps = [
      { distance: 1000, seconds: 280 },
      { distance: 1000, seconds: 270 },
      { distance: 1000, seconds: 286 },
      { distance: 500, seconds: 140 },
      { distance: 1000, seconds: 300 },
    ]
    expect(racePaceKm(laps, 281)).toBe(2)
  })

  it('simulado ignora corrida com blocos de trabalho', () => {
    const base = { today, blockStart: addDays(today, -60), distance: 10000, goalSeconds: 2400, priority: 'A', profile: null, targetPace: 240, weeklyKm: new Map<string, number>() }
    const blocks = { day: addDays(today, -3), distance: 14100, seconds: 3510, laps: [], structured: true }
    expect(raceChecklist({ ...base, runs: [blocks] }).find((item) => item.kind === 'tuneUp')?.status).toBe('missing')
    expect(raceChecklist({ ...base, runs: [blocks, { ...blocks, structured: false, distance: 5400, seconds: 1300 }] }).find((item) => item.kind === 'tuneUp')?.status).toBe('ok')
  })

  it('monta os cinco itens', () => {
    const blockStart = addDays(today, -60)
    const items = raceChecklist({
      today,
      blockStart,
      distance: 21097.5,
      goalSeconds: 5940,
      priority: 'A',
      profile: [{ distance: 0, altitude: 800 }, { distance: 5000, altitude: 830 }, { distance: 10000, altitude: 810 }],
      targetPace: 281,
      weeklyKm: new Map([[addDays(weekStartOf(today), -7), 44]]),
      runs: [
        { day: addDays(today, -10), distance: 10000, seconds: 2850, laps: Array.from({ length: 16 }, () => ({ distance: 1000, seconds: 281 })), structured: false },
        { day: addDays(today, -90), distance: 12000, seconds: 3300, laps: [], structured: false },
      ],
    })
    expect(items.map((item) => [item.kind, item.status])).toEqual([
      ['weeklyVolume', 'attention'],
      ['racePace', 'ok'],
      ['tuneUp', 'ok'],
      ['course', 'ok'],
      ['goal', 'ok'],
    ])
    expect(items[3]).toMatchObject({ km: 10, gain: 30 })
  })
})

describe('previsão do tempo', () => {
  const body = { hourly: { time: ['2026-11-29T06:00', '2026-11-29T07:00'], temperature_2m: [18, 19.5], dew_point_2m: [15, 16] } }

  it('pega a hora da largada e a janela de 16 dias', () => {
    expect(pickHour(body, 7)).toEqual({ hour: 7, temperature: 19.5, dewPoint: 16 })
    expect(pickHour(body, 9)).toBeNull()
    expect([startHour('06:30'), startHour(null), startHour('xx')]).toEqual([6, 7, 7])
    expect([forecastAvailable('2026-11-29', today), forecastAvailable('2026-12-31', today), forecastAvailable('2026-11-01', today)]).toEqual([true, false, false])
  })

  it('consulta o Open-Meteo e tolera falha', async () => {
    const urls: string[] = []
    const ok = async (url: string) => {
      urls.push(url)
      return new Response(JSON.stringify(url.includes('geocoding') ? { results: [{ latitude: -19.92, longitude: -43.94 }] } : body))
    }
    const place = await geocode(ok, 'Belo Horizonte')
    expect(place).toEqual({ latitude: -19.92, longitude: -43.94 })
    expect(await raceWeather(ok, place!, '2026-11-29', 6)).toEqual({ hour: 6, temperature: 18, dewPoint: 15 })
    expect(urls[1]).toContain('latitude=-19.9')
    expect(await raceWeather(async () => new Response('', { status: 500 }), place!, '2026-11-29', 6)).toBeNull()
    expect(await geocode(async () => { throw new Error('offline') }, 'x')).toBeNull()
  })
})
