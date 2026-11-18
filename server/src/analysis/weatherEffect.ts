import { heatFraction } from '../domain/heat.js'
import { ANALYSIS_WEATHER } from './analysisConstants.js'
import type { RunWeather, WeatherEffect, WorkoutBlock } from './analysisTypes.js'

const fahrenheit = (celsius: number) => (celsius * 9) / 5 + 32

function coldFactor(temperature: number): number {
  const bands = ANALYSIS_WEATHER.coldBands
  const first = bands[0]
  if (first === undefined || temperature >= first[0]) return 0
  for (let index = 1; index < bands.length; index += 1) {
    const [lower, top] = bands[index] ?? [0, 0]
    const [upper, base] = bands[index - 1] ?? [0, 0]
    if (temperature >= lower) return base + ((top - base) * (upper - temperature)) / (upper - lower)
  }
  return bands.at(-1)?.[1] ?? 0
}

export function weatherEffect(weather: RunWeather | null): WeatherEffect | null {
  if (weather === null) return null
  if (weather.temperature <= ANALYSIS_WEATHER.coldStart) {
    const factor = coldFactor(weather.temperature)
    return { weather, stress: factor > 0 ? 'cold' : 'mild', paceFactor: factor }
  }
  if (weather.dewPoint === null) return { weather, stress: 'mild', paceFactor: 0 }
  const factor = heatFraction(fahrenheit(weather.temperature) + fahrenheit(weather.dewPoint))
  return { weather, stress: factor > 0 ? 'heat' : 'mild', paceFactor: factor }
}

export const isHeat = (effect: WeatherEffect | null) => effect !== null && effect.stress === 'heat' && effect.paceFactor > 0
export const isCold = (effect: WeatherEffect | null) => effect !== null && effect.stress === 'cold' && effect.paceFactor > 0

export const mildSpeed = (speed: number, factor: number | null | undefined) => speed * (1 + (factor ?? 0))
export const mildPace = (pace: number, effect: WeatherEffect | null) => pace / (1 + (effect?.paceFactor ?? 0))
export const weatherSpeed = (block: WorkoutBlock) => (block.avgSpeed === null ? null : mildSpeed(block.avgSpeed, block.weatherFactor))

export function adjustForWeather(blocks: WorkoutBlock[], effect: WeatherEffect | null): WorkoutBlock[] {
  if (effect === null || effect.paceFactor <= 0) return blocks
  return blocks.map((block) => {
    const adjusted: WorkoutBlock = { ...block, weatherFactor: effect.paceFactor }
    const target = block.prescribed?.target
    const speed = weatherSpeed(adjusted)
    if (block.status !== 'slower' || target?.kind !== 'speed' || speed === null) return adjusted
    if (speed < target.low || (target.high > 0 && speed > target.high)) return adjusted
    return { ...adjusted, status: 'inTarget', weatherRescued: true }
  })
}

export function weatherFacts(effect: WeatherEffect): Record<string, number> {
  const facts: Record<string, number> = { temperature: effect.weather.temperature, weatherFactor: effect.paceFactor }
  if (effect.weather.dewPoint !== null) facts.dewPoint = effect.weather.dewPoint
  if (isCold(effect)) facts.cold = 1
  return facts
}
