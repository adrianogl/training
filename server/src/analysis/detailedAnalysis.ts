import { DETAILED } from './detailedConstants.js'
import { buildFindings } from './detailedFindings.js'
import { classify, mean, median, round, runFacts } from './detailedMetrics.js'
import type { DetailedAnalysis, DetailedInput, DetailedKpi, DetailedRun, DetailedSource, RunFacts, SimilarRun } from './detailedTypes.js'

const dayNumber = (day: string) => Math.round(Date.parse(`${day}T00:00:00Z`) / DETAILED.dayMilliseconds)
const defined = (values: (number | null)[]): number[] => values.flatMap((value) => (value === null ? [] : [value]))

function kpi(value: number | null, similar: (number | null)[]): DetailedKpi {
  const average = mean(defined(similar))
  return { value, similarAverage: average === null ? null : round(average) }
}

function percentOf(meters: number | null, reference: number | null): number | null {
  return meters === null || reference === null || reference <= 0 ? null : round((meters / reference) * 100)
}

function isBefore(run: DetailedRun, current: DetailedRun): boolean {
  return run.activity.id !== current.activity.id && run.activity.startLocal < current.activity.startLocal
}

function weekLoad(input: DetailedInput, today: number) {
  const inRange = (run: DetailedRun, from: number, to: number) => {
    const day = dayNumber(run.activity.day)
    return day >= today - from && day <= today - to
  }
  const kilometers = (runs: DetailedRun[]) => runs.reduce((sum, run) => sum + (run.activity.distanceMeters ?? 0), 0) / DETAILED.metersPerKilometer
  const last = input.runs.filter((run) => inRange(run, DETAILED.weekDays, 1))
  const previous = input.runs.filter((run) => inRange(run, DETAILED.weekDays * (DETAILED.previousWeeks + 1), DETAILED.weekDays + 1))
  return {
    kilometers: kilometers(last),
    averageKilometers: kilometers(previous) / DETAILED.previousWeeks,
    hadIntervals: last.some((run) => classify(run) === 'intervals'),
  }
}

export function detailedAnalysis(input: DetailedInput): DetailedAnalysis {
  const current = runFacts(input.current)
  const today = dayNumber(input.current.activity.day)
  const candidates = input.runs
    .filter((run) => isBefore(run, input.current) && today - dayNumber(run.activity.day) <= DETAILED.windowDays && classify(run) === current.kind)
    .sort((a, b) => b.activity.startLocal.localeCompare(a.activity.startLocal))
    .slice(0, DETAILED.maxSimilar)
  const similar: RunFacts[] = candidates.map(runFacts)

  const medianMeters = median(defined(similar.map((item) => item.run.activity.distanceMeters)))
  const planned = current.plannedMeters
  const referenceMeters = planned ?? medianMeters
  const completions = new Map<number, number | null>(
    [current, ...similar].map((item) => {
      const value = percentOf(item.run.activity.distanceMeters, item.plannedMeters ?? medianMeters)
      return [item.run.activity.id, value === null || item === current ? value : Math.min(value, DETAILED.completionCap)]
    }),
  )

  const similarRuns: SimilarRun[] = [...similar]
    .sort((a, b) => a.run.activity.startLocal.localeCompare(b.run.activity.startLocal))
    .map((item) => {
      const completion = completions.get(item.run.activity.id) ?? null
      return {
        activityId: item.run.activity.id,
        day: item.run.activity.day,
        completion,
        fadeKm: item.fadeKm,
        complete: completion === null ? null : completion >= DETAILED.completeRatio * 100,
        noPauses: item.continuity === null ? null : item.continuity.pauses.length === 0,
      }
    })

  const readinessByDay = new Map(input.days.flatMap((day) => (day.readiness === null ? [] : [[day.day, day.readiness.score] as [string, number]])))
  const { findings, recommendations } = buildFindings({
    current,
    similar,
    completions,
    referenceMeters,
    referenceSource: planned === null ? 'similar' : 'plan',
    readinessToday: readinessByDay.get(input.current.activity.day) ?? null,
    readinessByDay,
    week: weekLoad(input, today),
    goals: input.goals,
  })

  const sources: DetailedSource[] = [
    { key: 'fit', count: current.splits.length },
    ...(planned === null ? [] : [{ key: 'plan' as const, count: 1 }]),
    { key: 'similar', count: similar.length },
    { key: 'readiness', count: readinessByDay.size },
    ...(input.goals.some((goal) => !goal.archived) ? [{ key: 'goal' as const, count: input.goals.filter((goal) => !goal.archived).length }] : []),
  ]

  return {
    kind: current.kind,
    kpis: {
      completion: kpi(completions.get(input.current.activity.id) ?? null, similar.map((item) => completions.get(item.run.activity.id) ?? null)),
      fadeKm: kpi(current.fadeKm, similar.map((item) => item.fadeKm)),
      hrDrift: kpi(current.drift, similar.map((item) => item.drift)),
    },
    splits: current.splits,
    fadeKm: current.fadeKm,
    similar: similarRuns,
    findings,
    recommendations,
    sources,
  }
}
