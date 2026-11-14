import { HEAT } from './domainConstants.js'
import type { HeatAdjustment, Weather } from './domainTypes.js'

function fahrenheit(celsius: number): number {
  return (celsius * 9) / 5 + 32
}

export function heatFraction(sumFahrenheit: number): number {
  const bands = HEAT.bands
  const first = bands[0]
  if (first === undefined || sumFahrenheit <= first[0]) return 0
  for (let index = 1; index < bands.length; index += 1) {
    const [upper, value] = bands[index] ?? [0, 0]
    const [lower, base] = bands[index - 1] ?? [0, 0]
    if (sumFahrenheit <= upper) return base + ((value - base) * (sumFahrenheit - lower)) / (upper - lower)
  }
  return bands.at(-1)?.[1] ?? 0
}

export function heatAdjustment(weather: Weather, targetSeconds: number): HeatAdjustment {
  const sumFahrenheit = fahrenheit(weather.temperature) + fahrenheit(weather.dewPoint)
  const fraction = heatFraction(sumFahrenheit)
  return { weather, sumFahrenheit, fraction, tooHot: sumFahrenheit > HEAT.maxSum, adjustedSeconds: targetSeconds * (1 + fraction) }
}
