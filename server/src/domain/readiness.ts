import { COMPONENTS, READINESS } from './domainConstants.js'
import type { HRVBaseline, Readiness, ReadinessBreakdown, ReadinessComponent, ReadinessFactor, ReadinessInput, ReadinessVerdict } from './domainTypes.js'

type Scores = Partial<Record<ReadinessComponent, number>>

function interpolate(x: number, x0: number, x1: number, y0: number, y1: number): number {
  return y0 + ((x - x0) / (x1 - x0)) * (y1 - y0)
}

function clampPercent(value: number): number {
  return Math.min(Math.max(value, 0), 100)
}

function mean(values: number[]): number | null {
  return values.length === 0 ? null : values.reduce((sum, value) => sum + value, 0) / values.length
}

export function hrvComponent(value: number, baseline: HRVBaseline): number {
  if (value < baseline.lowUpper) {
    return 0
  }
  if (value < baseline.balancedLow) {
    return interpolate(value, baseline.lowUpper, baseline.balancedLow, 0, READINESS.hrvLowEdgeScore)
  }
  if (value <= baseline.balancedUpper) {
    if (baseline.balancedUpper <= baseline.balancedLow) {
      return READINESS.hrvLowEdgeScore
    }
    return interpolate(value, baseline.balancedLow, baseline.balancedUpper, READINESS.hrvLowEdgeScore, READINESS.hrvBalancedTopScore)
  }
  return READINESS.hrvBalancedTopScore
}

export function loadComponent(ratio: number): number {
  if (ratio >= READINESS.loadIdealLow && ratio <= READINESS.loadIdealHigh) {
    return 100
  }
  if (ratio > READINESS.loadZeroLow && ratio < READINESS.loadIdealLow) {
    return interpolate(ratio, READINESS.loadZeroLow, READINESS.loadIdealLow, 0, 100)
  }
  if (ratio > READINESS.loadIdealHigh && ratio < READINESS.loadZeroHigh) {
    return interpolate(ratio, READINESS.loadIdealHigh, READINESS.loadZeroHigh, 100, 0)
  }
  return 0
}

export function readinessComponents(input: ReadinessInput): Scores {
  const scores: Scores = {}
  if (input.hrvLastNight !== null && input.hrvBaseline !== null) {
    scores.hrv = hrvComponent(input.hrvLastNight, input.hrvBaseline)
  }
  if (input.sleepScore !== null) {
    scores.sleep = clampPercent(input.sleepScore)
  }
  if (input.bodyBatteryMorningMax !== null) {
    scores.bodyBattery = clampPercent(input.bodyBatteryMorningMax)
  }
  if (input.acuteChronic !== null) {
    scores.load = loadComponent(input.acuteChronic)
  }
  return scores
}

export function readinessVerdict(score: number): ReadinessVerdict {
  if (score >= READINESS.hardThreshold) {
    return 'hard'
  }
  return score >= READINESS.moderateThreshold ? 'moderate' : 'rest'
}

export function readiness(input: ReadinessInput): Readiness | null {
  const scores = readinessComponents(input)
  if (scores.hrv === undefined && scores.sleep === undefined) {
    return null
  }
  const present = COMPONENTS.filter((component) => scores[component] !== undefined)
  const totalWeight = present.reduce((sum, component) => sum + READINESS.weights[component], 0)
  const weighted = present.reduce((sum, component) => sum + (scores[component] ?? 0) * READINESS.weights[component], 0)
  const score = Math.round(weighted / totalWeight)
  return { score, partial: present.length < COMPONENTS.length, verdict: readinessVerdict(score) }
}

export function readinessBreakdown(today: ReadinessInput, history: ReadinessInput[]): ReadinessBreakdown | null {
  const current = readiness(today)
  if (current === null) {
    return null
  }
  const todayScores = readinessComponents(today)
  const recent = history.slice(-READINESS.normalWindowDays).map(readinessComponents)
  const presentWeight = COMPONENTS.filter((component) => todayScores[component] !== undefined).reduce((sum, component) => sum + READINESS.weights[component], 0)
  const factors: ReadinessFactor[] = COMPONENTS.map((component) => {
    const todayScore = todayScores[component] ?? null
    const samples = recent.flatMap((scores) => (scores[component] === undefined ? [] : [scores[component] as number]))
    const normalScore = samples.length >= READINESS.normalMinimumDays ? mean(samples) : null
    const weight = todayScore === null ? 0 : READINESS.weights[component] / presentWeight
    const points = todayScore !== null && normalScore !== null ? weight * (todayScore - normalScore) : null
    return { component, todayScore, normalScore, points, weight }
  })
  const ordered = factors
    .map((factor, index) => ({ factor, index }))
    .sort((left, right) => {
      if ((left.factor.todayScore === null) !== (right.factor.todayScore === null)) {
        return left.factor.todayScore === null ? 1 : -1
      }
      const leftSize = Math.abs(left.factor.points ?? 0)
      const rightSize = Math.abs(right.factor.points ?? 0)
      return leftSize !== rightSize ? rightSize - leftSize : left.index - right.index
    })
    .map(({ factor }) => factor)
  const present = ordered.filter((factor) => factor.todayScore !== null)
  const normal = present.every((factor) => factor.points !== null)
    ? current.score - present.reduce((sum, factor) => sum + (factor.points ?? 0), 0)
    : null
  return { score: current.score, normal, verdict: current.verdict, factors: ordered }
}

export function bodyBatteryMorningMax(samples: [number, number][], sleepEndMs: number): number | null {
  const windowEnd = sleepEndMs + READINESS.bodyBatteryWindowMs
  const values = samples.filter(([time]) => time >= sleepEndMs && time <= windowEnd).map(([, value]) => value)
  return values.length === 0 ? null : Math.max(...values)
}
