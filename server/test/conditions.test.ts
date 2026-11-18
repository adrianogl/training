import { describe, expect, it } from 'vitest'
import type { FitSample } from '../src/fit/fitTypes.js'
import { assess } from '../src/analysis/assessment.js'
import { applyWind } from '../src/analysis/conditions.js'
import { findingWhy } from '../src/analysis/narrative.js'
import { adjustForWeather, headwindOf, weatherEffect, windCost } from '../src/analysis/weatherEffect.js'
import { averageWeather } from '../src/weather.js'
import { block, distance, emptyContext as ctx, speed, step } from './analysisHelpers.js'

const target = step(1, 'active', distance(3000), speed(3.0, 3.2))
const lap = (start: number, seconds: number, meters: number) => ({ stepIndex: 1, intensity: 'active' as const, trigger: null, startOffset: start, timerSeconds: seconds, distance: meters, avgSpeed: meters / seconds, avgHeartRate: null, maxHeartRate: null })

function samples(north: number, south: number, options: { cadence?: [number, number]; stance?: [number, number] } = {}): FitSample[] {
  const total = north + south
  let latitude = -23.5
  const result: FitSample[] = []
  for (let t = 0; t < total; t += 5) {
    latitude += ((t < north ? 1 : -1) * 3 * 5) / 111_320
    const late = t >= (total * 2) / 3
    result.push({
      t, heartRate: 150, speed: 3, altitude: null, distance: t * 3, lat: latitude, lon: -46.6,
      cadence: options.cadence === undefined ? null : late ? options.cadence[1] : options.cadence[0],
      stanceTime: options.stance === undefined ? null : late ? options.stance[1] : options.stance[0],
    })
  }
  return result
}

describe('fatores (paridade com ConditionsAnalysisTests)', () => {
  it('vento contra custa ritmo e a favor devolve metade', () => {
    expect(windCost(4)).toBeCloseTo(0.04, 4)
    expect(windCost(-4)).toBeCloseTo(-0.02, 4)
    expect(headwindOf(4, 0, 0)).toBeCloseTo(3, 4)
    expect(headwindOf(4, 0, 180)).toBeCloseTo(-3, 4)
  })

  it('vento medido por bloco pela rota', () => {
    const wind = { temperature: 18, dewPoint: 10, windSpeed: 5, windFrom: 0 }
    const blocks = [
      block({ label: 'Ida', prescribed: target, laps: [lap(0, 1000, 2950)], seconds: 1000, distance: 2950, avgSpeed: 2.95, status: 'slower' }),
      block({ label: 'Volta', prescribed: target, laps: [lap(1000, 1000, 3100)], seconds: 1000, distance: 3100, avgSpeed: 3.1, status: 'inTarget' }),
    ]
    const windy = adjustForWeather(applyWind(blocks, samples(1000, 1000), wind), weatherEffect(wind))
    expect(windy[0]?.headwind ?? 0).toBeGreaterThan(3.5)
    expect(windy[0]?.windFactor ?? 0).toBeGreaterThan(0.03)
    expect(windy[1]?.windFactor ?? 0).toBeLessThan(0)
    expect(windy[0]).toMatchObject({ status: 'inTarget', weatherRescued: true })
  })

  it('vento contra lista os km', () => {
    const wind = { temperature: 18, dewPoint: 10, windSpeed: 5, windFrom: 0 }
    const rows = [0, 1, 2, 3].map((index) => block({ label: `Km ${index + 1}`, laps: [lap(index * 333, 333, 1000)], seconds: 333, distance: 1000, avgSpeed: 3 }))
    const finding = assess(applyWind(rows, samples(666, 666), wind), ctx({ weather: weatherEffect(wind) })).positives.find((f) => f.kind === 'windAgainst')
    expect(finding?.facts).toMatchObject({ fromKilometer: 1, toKilometer: 2 })
    expect(finding?.facts.windSpeed).toBeCloseTo(18, 2)
    expect(finding?.facts.mildPace ?? 999).toBeLessThan(finding?.facts.pace ?? 0)
  })

  it('sol soma calor e adaptação tira', () => {
    const shade = weatherEffect({ temperature: 28, dewPoint: 21 })
    const sun = weatherEffect({ temperature: 28, dewPoint: 21, radiation: 700 })
    const adapted = weatherEffect({ temperature: 28, dewPoint: 21, radiation: 700 }, 4)
    expect(sun?.sunBoost).toBeCloseTo(3.5, 3)
    expect(sun?.paceFactor).toBeCloseTo(0.0578, 3)
    expect(sun?.paceFactor ?? 0).toBeGreaterThan(shade?.paceFactor ?? 0)
    expect(adapted?.paceFactor).toBeCloseTo((sun?.paceFactor ?? 0) * 0.8, 4)
    expect(adapted?.hotSessions).toBe(4)
  })

  it('forma caindo no fim', () => {
    const blocks = [block({ label: 'Corrida', seconds: 1200, distance: 3600, avgSpeed: 3 })]
    const finding = assess(blocks, ctx({ samples: samples(600, 600, { cadence: [172, 167], stance: [238, 251] }) })).attention.find((f) => f.kind === 'runFormFade')
    expect(finding?.facts).toMatchObject({ cadenceFrom: 172, cadenceTo: 167, stanceTo: 251 })
    expect(assess(blocks, ctx({ samples: samples(600, 600, { cadence: [172, 171], stance: [238, 240] }) })).attention.some((f) => f.kind === 'runFormFade')).toBe(false)
  })

  it('largada e véspera explicam sem mudar o grupo', () => {
    const slow = [block({ prescribed: target, seconds: 1100, distance: 3000, avgSpeed: 2.7, status: 'slower' })]
    const tired = { sleepSeconds: 20_400, sleepScore: 72, hrvBelowBalanced: false, bodyBattery: 32, previousDay: 1 }
    const finding = assess(slow, ctx({ day: tired })).negatives.find((f) => f.kind === 'blockOffTarget')
    expect(finding?.facts).toMatchObject({ sleepSeconds: 20_400, bodyBattery: 32, previousDay: 1 })
    expect(finding?.facts.sleepScore).toBeUndefined()
    expect(finding === undefined ? '' : findingWhy(finding, slow)).toContain('Causa provável: noite de 5h40 e Body Battery 32 de manhã. Ontem teve limiar.')
    const rested = assess(slow, ctx({ day: { sleepSeconds: 28_800, sleepScore: 85, hrvBelowBalanced: false, bodyBattery: 80, previousDay: null } })).negatives[0]
    expect(rested?.facts.sleepSeconds).toBeUndefined()
  })

  it('média do vento pela direção', () => {
    const body = { hourly: { time: ['2026-11-17T06:00', '2026-11-17T07:00'], temperature_2m: [20, 22], dew_point_2m: [15, 15], wind_speed_10m: [4, 4], wind_direction_10m: [350, 10], shortwave_radiation: [200, 400] } }
    const weather = averageWeather(body, '2026-11-17T06:30:00', 3600)
    expect(weather?.windSpeed).toBeCloseTo(4, 5)
    expect(Math.min(weather?.windFrom ?? 180, 360 - (weather?.windFrom ?? 180))).toBeLessThan(0.001)
    expect(weather?.radiation).toBeCloseTo(300, 5)
  })
})
