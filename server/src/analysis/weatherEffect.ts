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

const W = ANALYSIS_WEATHER

export const sunBoost = (radiation: number | null | undefined) => (radiation === null || radiation === undefined || radiation <= 0 ? 0 : Math.min(radiation / W.fullSunRadiation, 1) * W.fullSunBoost)
export const adaptation = (hotSessions: number) => Math.min(Math.max(hotSessions, 0) * W.adaptationPerSession, W.maxAdaptation)

export function weatherEffect(weather: RunWeather | null, hotSessions = 0): WeatherEffect | null {
  if (weather === null) return null
  const base = { sunBoost: 0, hotSessions: 0, adaptation: 0 }
  if (weather.temperature <= W.coldStart) {
    const factor = coldFactor(weather.temperature)
    return { weather, stress: factor > 0 ? 'cold' : 'mild', paceFactor: factor, ...base }
  }
  if (weather.dewPoint === null) return { weather, stress: 'mild', paceFactor: 0, ...base }
  const boost = sunBoost(weather.radiation)
  const raw = heatFraction(fahrenheit(weather.temperature + boost) + fahrenheit(weather.dewPoint))
  const taken = raw > 0 ? adaptation(hotSessions) : 0
  const factor = raw * (1 - taken)
  return { weather, stress: factor > 0 ? 'heat' : 'mild', paceFactor: factor, sunBoost: boost, hotSessions: raw > 0 ? hotSessions : 0, adaptation: taken }
}

export function isHotSession(weather: RunWeather | null): boolean {
  const effect = weatherEffect(weather)
  return effect !== null && effect.stress === 'heat' && effect.paceFactor >= W.hotSessionFactor
}

export const windCost = (headwind: number) => (headwind >= 0 ? W.headwindCost * headwind * headwind : -W.headwindCost * W.tailwindShare * headwind * headwind)
export const headwindOf = (windSpeed: number, windFrom: number, heading: number) => windSpeed * W.windHeightFactor * Math.cos(((windFrom - heading) * Math.PI) / 180)

export const isHeat = (effect: WeatherEffect | null) => effect !== null && effect.stress === 'heat' && effect.paceFactor > 0
export const isCold = (effect: WeatherEffect | null) => effect !== null && effect.stress === 'cold' && effect.paceFactor > 0

export const mildSpeed = (speed: number, factor: number | null | undefined) => speed * (1 + (factor ?? 0))
export const mildPace = (pace: number, effect: WeatherEffect | null) => pace / (1 + (effect?.paceFactor ?? 0))
export const conditionsFactor = (block: WorkoutBlock) => (block.weatherFactor ?? 0) + (block.windFactor ?? 0)
export const weatherSpeed = (block: WorkoutBlock) => (block.avgSpeed === null ? null : mildSpeed(block.avgSpeed, conditionsFactor(block)))

export function adjustForWeather(blocks: WorkoutBlock[], effect: WeatherEffect | null): WorkoutBlock[] {
  const factor = effect?.paceFactor ?? 0
  if (factor <= 0 && !blocks.some((block) => (block.windFactor ?? 0) !== 0)) return blocks
  return blocks.map((block) => {
    const adjusted: WorkoutBlock = factor > 0 ? { ...block, weatherFactor: factor } : { ...block }
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
  if (effect.sunBoost >= W.sunnyBoost) facts.sunny = 1
  if (effect.adaptation > 0) facts.hotSessions = effect.hotSessions
  return facts
}
