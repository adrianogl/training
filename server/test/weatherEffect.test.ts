import { describe, expect, it } from 'vitest'
import { assess } from '../src/analysis/assessment.js'
import { adjustForWeather, mildPace, weatherEffect } from '../src/analysis/weatherEffect.js'
import { scoreWorkout } from '../src/analysis/workoutScore.js'
import { averageWeather } from '../src/weather.js'
import { block, distance, emptyContext as ctx, paceLaps, speed, step } from './analysisHelpers.js'

const target = step(1, 'active', distance(10000), speed(3.9, 4.1))
const humid = weatherEffect({ temperature: 28, dewPoint: 21 })
const warm = weatherEffect({ temperature: 22, dewPoint: 12 })
const freezing = weatherEffect({ temperature: -5, dewPoint: null })
const run = (avgSpeed: number, status: 'slower' | 'faster' | 'inTarget') => block({ prescribed: target, seconds: 10000 / avgSpeed, distance: 10000, avgSpeed, status })

describe('clima (paridade com RunWeatherTests e WeatherAnalysisTests)', () => {
  it('tabela de calor e frio', () => {
    expect(weatherEffect({ temperature: 14, dewPoint: 6 })).toMatchObject({ stress: 'mild', paceFactor: 0 })
    expect(humid?.stress).toBe('heat')
    expect(humid?.paceFactor).toBeCloseTo(0.0483, 3)
    expect(mildPace(336, humid)).toBeCloseTo(320.5, 0)
    expect(weatherEffect({ temperature: 35, dewPoint: 30 })?.paceFactor).toBeCloseTo(0.1, 4)
    expect(weatherEffect({ temperature: 5, dewPoint: 0 })?.stress).toBe('mild')
    expect(weatherEffect({ temperature: 0, dewPoint: -3 })?.paceFactor).toBeCloseTo(0.005, 4)
    expect(freezing).toMatchObject({ stress: 'cold' })
    expect(freezing?.paceFactor).toBeCloseTo(0.01, 4)
    expect(weatherEffect({ temperature: -20, dewPoint: null })?.paceFactor).toBeCloseTo(0.02, 4)
    expect(weatherEffect({ temperature: 30, dewPoint: null })?.paceFactor).toBe(0)
    expect(weatherEffect(null)).toBeNull()
  })

  it('bloco mais lento dentro do alvo em clima ameno fica no alvo', () => {
    const blocks = adjustForWeather([run(3.75, 'slower')], humid)
    expect(blocks[0]).toMatchObject({ status: 'inTarget', weatherRescued: true })
    const a = assess(blocks, ctx({ weather: humid }))
    expect(a.negatives).toHaveLength(0)
    const finding = a.positives.find((f) => f.kind === 'weatherSlower')
    expect(finding?.facts.temperature).toBe(28)
    expect(finding?.facts.mildPace).toBeCloseTo(1000 / 3.75 / (1 + (humid?.paceFactor ?? 0)), 2)
    expect(a.positives.some((f) => f.kind === 'blockInTarget')).toBe(true)
  })

  it('lento demais ou rápido demais continua fora do alvo', () => {
    expect(adjustForWeather([run(3.5, 'slower')], humid)[0]?.status).toBe('slower')
    expect(adjustForWeather([run(4.3, 'faster')], humid)[0]).toMatchObject({ status: 'faster' })
    expect(adjustForWeather([run(4.3, 'faster')], humid)[0]?.weatherRescued).toBeUndefined()
    const blocks = [run(3.75, 'slower')]
    expect(adjustForWeather(blocks, null)).toBe(blocks)
  })

  it('frio também alivia o ritmo', () => {
    const blocks = adjustForWeather([run(3.87, 'slower')], freezing)
    expect(assess(blocks, ctx({ weather: freezing })).positives.find((f) => f.kind === 'weatherSlower')?.facts.cold).toBe(1)
  })

  it('deriva no calor úmido é esperada', () => {
    const blocks = [block({ laps: paceLaps(Array(6).fill(250), [150, 152, 155, 158, 161, 163]) })]
    const hot = assess(blocks, ctx({ weather: humid }))
    expect(hot.positives.find((f) => f.kind === 'cardiacDrift')?.facts.temperature).toBe(28)
    expect(hot.attention.some((f) => f.kind === 'cardiacDrift')).toBe(false)
    expect(assess(blocks, ctx({ weather: warm })).attention.some((f) => f.kind === 'cardiacDrift')).toBe(true)
    expect(assess(blocks, ctx({ weather: freezing })).attention.some((f) => f.kind === 'cardiacDrift')).toBe(true)
  })

  it('limite da zona no aquecimento sobe no calor e recuperação não entra', () => {
    const warmup = (zone: number) => [block({ kind: 'warmup', label: 'Aquecimento', dominantZone: zone })]
    expect(assess(warmup(3), ctx({ weather: humid })).attention.some((f) => f.kind === 'zoneAboveTarget')).toBe(false)
    expect(assess(warmup(4), ctx({ weather: humid })).attention.some((f) => f.kind === 'zoneAboveTarget')).toBe(true)
    expect(assess(warmup(3), ctx({ weather: warm })).attention.some((f) => f.kind === 'zoneAboveTarget')).toBe(true)
    expect(assess([block({ kind: 'recovery', label: 'Recuperação', dominantZone: 5 })], ctx()).attention).toHaveLength(0)
  })

  it('custo compara em clima ameno', () => {
    const previous = [{ activityId: 1, day: '2026-11-10', blocks: [run(4, 'inTarget')] }]
    const cost = (blocks: ReturnType<typeof run>[]) => scoreWorkout(blocks, null, previous)?.items.find((item) => item.part === 'cost')
    expect(cost(adjustForWeather([run(3.82, 'slower')], humid))?.reason).toBeNull()
    expect(cost([run(3.82, 'slower')])?.reason).toBe('lessEfficient')
  })

  it('média das horas do treino', () => {
    const body = { hourly: { time: ['2026-11-17T06:00', '2026-11-17T07:00', '2026-11-17T08:00'], temperature_2m: [20, 24, 28], dew_point_2m: [18, 19, 20] } }
    const weather = averageWeather(body, '2026-11-17T06:30:00', 3600)
    expect(weather?.temperature).toBeCloseTo(22, 5)
    expect(weather?.dewPoint).toBeCloseTo(18.5, 5)
    expect(averageWeather(null, '2026-11-17T06:30:00', 3600)).toBeNull()
  })
})
