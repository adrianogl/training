import { BETTER_WHEN_LOWER, EVOLUTION_TEXT, STABLE_FRACTION } from './constants'
import { signedDuration } from './format'
import type { MetricSeries, Prediction } from './types'

export type Trend = 'better' | 'worse' | 'steady'

export function trend(key: string, change: number | null, current: number | null): Trend | null {
  if (change === null || current === null) {
    return null
  }
  if (Math.abs(change) <= Math.abs(current) * STABLE_FRACTION) {
    return 'steady'
  }
  const lowerIsBetter = BETTER_WHEN_LOWER.includes(key)
  return change < 0 === lowerIsBetter ? 'better' : 'worse'
}

export function evolutionReading(half: Prediction | undefined, series: MetricSeries[], span: string): string {
  if (half === undefined || half.seconds === null || half.change === null) {
    return EVOLUTION_TEXT.noReading
  }
  const direction = trend(half.key, half.change, half.seconds)
  const verdict = direction === 'better' ? EVOLUTION_TEXT.improving : direction === 'worse' ? EVOLUTION_TEXT.declining : EVOLUTION_TEXT.steady
  const movement = direction === 'steady' ? EVOLUTION_TEXT.kept : `${half.change < 0 ? EVOLUTION_TEXT.fell : EVOLUTION_TEXT.rose} ${signedDuration(Math.abs(half.change)).slice(1)}`
  const names = (Object.keys(EVOLUTION_TEXT.readingNames) as (keyof typeof EVOLUTION_TEXT.readingNames)[])
    .filter((key) => {
      const item = series.find((entry) => entry.key === key)
      return item !== undefined && trend(key, item.stats.change, item.stats.current) === 'better'
    })
    .map((key) => EVOLUTION_TEXT.readingNames[key])
  const better = names.length === 0 ? '' : EVOLUTION_TEXT.better(names.length === 1 ? (names[0] ?? '') : `${names.slice(0, -1).join(', ')}${EVOLUTION_TEXT.and}${names.at(-1) ?? ''}`)
  return `${verdict}: ${EVOLUTION_TEXT.halfPrediction} ${movement} ${span}${better}.`
}
