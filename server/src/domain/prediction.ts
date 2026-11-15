import { addDays } from '../garminSync.js'
import { PREDICTION } from './domainConstants.js'
import type { Effort, EffortKind } from './domainTypes.js'

const KIND_ORDER: EffortKind[] = ['race', 'split1k', 'split5k', 'threshold', 'interval']

export function daysBetween(from: string, to: string): number {
  return Math.round((new Date(`${to}T12:00:00Z`).getTime() - new Date(`${from}T12:00:00Z`).getTime()) / 86_400_000)
}

export function riegel(seconds: number, from: number, to: number, exponent: number = PREDICTION.riegelExponent): number {
  return seconds * (to / from) ** exponent
}

function weight(effort: Effort, on: string, target: number): number | null {
  if (effort.distance <= 0 || effort.seconds <= 0) {
    return null
  }
  const age = daysBetween(effort.day, on)
  const window = effort.kind === 'race' ? PREDICTION.raceEffortWindowDays : PREDICTION.effortWindowDays
  if (age < 0 || age >= window) {
    return null
  }
  const endurance = PREDICTION.distanceWeightFactors.find((entry) => target >= entry.minimumMeters)?.factors[effort.kind] ?? 1
  const value = PREDICTION.kindWeight[effort.kind] * endurance * (1 - age / window)
  return value > 0 ? value : null
}

function gap(distance: number, target: number): number {
  return Math.abs(Math.log(distance / target))
}

function replaces(effort: Effort, predicted: number, current: Effort, currentPredicted: number, target: number): boolean {
  if (effort.kind === 'race') {
    const effortGap = gap(effort.distance, target)
    const currentGap = gap(current.distance, target)
    if (effortGap < currentGap - PREDICTION.sameRaceDistanceLogTolerance) {
      return true
    }
    if (effortGap > currentGap + PREDICTION.sameRaceDistanceLogTolerance) {
      return false
    }
  }
  if (predicted !== currentPredicted) {
    return predicted < currentPredicted
  }
  return current.day < effort.day
}

export function bestEfforts(efforts: Effort[], distance: number, on: string): Effort[] {
  const best = new Map<EffortKind, { effort: Effort; predicted: number }>()
  for (const effort of efforts) {
    if (weight(effort, on, distance) === null) {
      continue
    }
    const predicted = riegel(effort.seconds, effort.distance, distance)
    const current = best.get(effort.kind)
    if (current !== undefined && !replaces(effort, predicted, current.effort, current.predicted, distance)) {
      continue
    }
    best.set(effort.kind, { effort, predicted })
  }
  return [...best.values()]
    .map(({ effort }) => effort)
    .sort((left, right) => (left.day !== right.day ? (left.day < right.day ? 1 : -1) : KIND_ORDER.indexOf(left.kind) - KIND_ORDER.indexOf(right.kind)))
}

export function predict(distance: number, efforts: Effort[], on: string): number | null {
  let weighted = 0
  let total = 0
  for (const effort of bestEfforts(efforts, distance, on)) {
    const value = weight(effort, on, distance)
    if (value === null) {
      continue
    }
    weighted += value * riegel(effort.seconds, effort.distance, distance)
    total += value
  }
  return total > 0 ? weighted / total : null
}

export function predictionSeries(distance: number, efforts: Effort[], from: string, to: string): [string, number][] {
  const series: [string, number][] = []
  for (let day = from; day <= to; day = addDays(day, 1)) {
    const value = predict(distance, efforts, day)
    if (value !== null) {
      series.push([day, value])
    }
  }
  return series
}

export function smoothedVo2max(values: [string, number][], smoothingDays: number): [string, number][] {
  let smoothed: number | null = null
  return [...values]
    .sort((left, right) => (left[0] < right[0] ? -1 : left[0] > right[0] ? 1 : 0))
    .map(([day, value]) => {
      smoothed = smoothed === null ? value : smoothed + (value - smoothed) / smoothingDays
      return [day, smoothed] as [string, number]
    })
}
