import type { GoalItem } from '../types.js'
import { continuityPace, meetsContinuousGoal } from './continuity.js'
import { DETAILED } from './detailedConstants.js'
import { mean, median, round, startPace } from './detailedMetrics.js'
import type { DetailedFinding, DetailedKind, DetailedRecommendation, RunFacts } from './detailedTypes.js'

export interface FindingContext {
  current: RunFacts
  similar: RunFacts[]
  completions: Map<number, number | null>
  referenceMeters: number | null
  referenceSource: 'plan' | 'similar'
  readinessToday: number | null
  readinessByDay: Map<string, number>
  week: { kilometers: number; averageKilometers: number; hadIntervals: boolean } | null
  goals: GoalItem[]
}

const average = (values: number[]) => (values.length === 0 ? null : round(mean(values) ?? 0))
const defined = (values: (number | null | undefined)[]): number[] => values.flatMap((value) => (value === null || value === undefined ? [] : [value]))
const steadyKind = (kind: DetailedKind) => kind === 'long' || kind === 'easy'
const dayNumber = (day: string) => Math.round(Date.parse(`${day}T00:00:00Z`) / DETAILED.dayMilliseconds)

function standardDeviation(values: number[]): number {
  const average = mean(values) ?? 0
  return Math.sqrt((mean(values.map((value) => (value - average) ** 2)) ?? 0))
}

function heartRateAt(samples: { t: number; heartRate: number | null }[], from: number, to: number): { start: number | null; end: number | null } {
  const inside = samples.filter((sample) => sample.heartRate !== null && sample.t >= from && sample.t <= to)
  return { start: inside[0]?.heartRate ?? null, end: inside.at(-1)?.heartRate ?? null }
}

function repetitions(current: RunFacts): DetailedFinding | null {
  const fit = current.run.fit
  if (fit === null) return null
  const reps = fit.structure.laps.filter((lap) => lap.intensity === 'active' && lap.avgSpeed !== null && lap.avgSpeed > 0)
  if (reps.length < DETAILED.minimumRepetitions) return null
  const paces = reps.map((lap) => DETAILED.metersPerKilometer / (lap.avgSpeed ?? 1))
  const drops = fit.structure.laps
    .filter((lap) => lap.intensity === 'recovery')
    .flatMap((lap) => {
      const { start, end } = heartRateAt(fit.samples, lap.startOffset, lap.startOffset + lap.timerSeconds)
      return start === null || end === null ? [] : [start - end]
    })
  const drop = mean(drops)
  return { key: 'repsConsistency', values: { reps: reps.length, spreadSeconds: round(standardDeviation(paces)), recoveryDrop: drop === null ? null : round(drop, 0) } }
}

function goalFinding(current: RunFacts, goals: GoalItem[]): DetailedFinding | null {
  const active = goals.filter((goal) => !goal.archived)
  if (current.kind === 'long') {
    const goal = active.find((item) => item.kind === 'continuousLong')
    if (goal === undefined || current.continuity === null) return null
    const pace = continuityPace(current.continuity)
    return {
      key: 'goal',
      values: {
        kind: 'continuousLong',
        targetKm: goal.distanceKm,
        targetPace: goal.paceSecondsPerKm,
        continuousKm: round(current.continuity.longestContinuousMeters / DETAILED.metersPerKilometer, 2),
        pace: pace === null ? null : round(pace),
        met: goal.paceSecondsPerKm === null ? null : meetsContinuousGoal(current.continuity, goal.distanceKm, goal.paceSecondsPerKm),
      },
    }
  }
  if (current.kind === 'tempo' || current.kind === 'race') {
    const goal = active.find((item) => item.kind === 'time' && item.targetSeconds !== null)
    const activity = current.run.activity
    const seconds = activity.movingSeconds ?? activity.durationSeconds
    if (goal === undefined || goal.targetSeconds === null || seconds === null || (activity.distanceMeters ?? 0) <= 0) return null
    const pace = (seconds * DETAILED.metersPerKilometer) / (activity.distanceMeters ?? 1)
    const targetPace = goal.targetSeconds / goal.distanceKm
    return { key: 'goal', values: { kind: 'time', targetKm: goal.distanceKm, targetPace: round(targetPace), pace: round(pace), gapSeconds: round(pace - targetPace) } }
  }
  return null
}

function hrAtPace(similar: RunFacts[]): DetailedFinding | null {
  const points = similar
    .flatMap((item) => (item.run.activity.averageHeartRate === null ? [] : [{ day: dayNumber(item.run.activity.day), heartRate: item.run.activity.averageHeartRate, label: item.run.activity.day }]))
    .sort((a, b) => a.day - b.day)
  const first = points[0]
  const last = points.at(-1)
  if (points.length < DETAILED.hrAtPaceMinimumRuns || first === undefined || last === undefined || last.day === first.day) return null
  const meanDay = mean(points.map((point) => point.day)) ?? 0
  const meanHeartRate = mean(points.map((point) => point.heartRate)) ?? 0
  const spread = points.reduce((sum, point) => sum + (point.day - meanDay) ** 2, 0)
  if (spread === 0) return null
  const slope = points.reduce((sum, point) => sum + (point.day - meanDay) * (point.heartRate - meanHeartRate), 0) / spread
  return { key: 'hrAtPace', values: { deltaBpm: round(slope * (last.day - first.day)), runs: points.length, sinceDay: first.label } }
}

function readiness(context: FindingContext): DetailedFinding | null {
  const scored = context.similar.flatMap((item) => {
    const score = context.readinessByDay.get(item.run.activity.day)
    const completion = context.completions.get(item.run.activity.id) ?? null
    return score === undefined || completion === null ? [] : [{ score, completion }]
  })
  const low = scored.filter((item) => item.score < DETAILED.lowReadiness).map((item) => item.completion)
  const high = scored.filter((item) => item.score >= DETAILED.lowReadiness).map((item) => item.completion)
  if (context.readinessToday === null || low.length + high.length === 0) return null
  return { key: 'readiness', values: { today: context.readinessToday, limit: DETAILED.lowReadiness, lowAverage: average(low), lowCount: low.length, highAverage: average(high), highCount: high.length } }
}

function startPaceFinding(context: FindingContext): { finding: DetailedFinding | null; todayStart: number | null } {
  const todayStart = startPace(context.current.splits)
  if (todayStart === null) return { finding: null, todayStart }
  const rows = context.similar.flatMap((item) => {
    const start = startPace(item.splits)
    return start === null ? [] : [{ start, early: item.fadeKm !== null && item.fadeKm < DETAILED.earlyFadeKm }]
  })
  if (rows.length === 0) return { finding: null, todayStart }
  const limit = todayStart + DETAILED.startMarginSeconds
  const fast = rows.filter((row) => row.start < limit)
  const slow = rows.filter((row) => row.start >= limit)
  return {
    finding: {
      key: 'startPace',
      values: {
        todayStart,
        limitPace: round(limit),
        fastTotal: fast.length,
        fastEarlyFade: fast.filter((row) => row.early).length,
        slowTotal: slow.length,
        slowEarlyFade: slow.filter((row) => row.early).length,
        earlyFadeKm: DETAILED.earlyFadeKm,
      },
    },
    todayStart,
  }
}

export function buildFindings(context: FindingContext): { findings: DetailedFinding[]; recommendations: DetailedRecommendation[] } {
  const { current, similar } = context
  const steady = steadyKind(current.kind)
  const found: (DetailedFinding | null)[] = []
  const doneMeters = current.run.activity.distanceMeters
  const completion = context.completions.get(current.run.activity.id) ?? null

  found.push(
    completion === null || doneMeters === null || context.referenceMeters === null
      ? null
      : {
          key: 'completion',
          values: {
            doneKm: round(doneMeters / DETAILED.metersPerKilometer, 2),
            referenceKm: round(context.referenceMeters / DETAILED.metersPerKilometer, 2),
            percent: completion,
            source: context.referenceSource,
            similarAverage: average(defined(similar.map((item) => context.completions.get(item.run.activity.id)))),
          },
        },
  )

  const similarFades = defined(similar.map((item) => item.fadeKm))
  const similarWithSplits = similar.filter((item) => item.splits.length > DETAILED.fadeMinimumKm)
  found.push(
    current.kind === 'intervals' || current.splits.length <= DETAILED.fadeMinimumKm
      ? null
      : { key: 'fadeKm', values: { fadeKm: current.fadeKm, similarMedian: median(similarFades), similarFaded: similarFades.length, similarTotal: similarWithSplits.length } },
  )

  const similarDrifts = defined(similar.map((item) => item.drift))
  found.push(steady && current.drift !== null ? { key: 'hrDrift', values: { drift: current.drift, similarAverage: average(similarDrifts), similarRuns: similarDrifts.length } } : null)

  const start = current.kind === 'long' ? startPaceFinding(context) : { finding: null, todayStart: null }
  found.push(start.finding)
  found.push(readiness(context))

  const week = context.week
  const percent = week === null || week.averageKilometers <= 0 ? null : round((week.kilometers / week.averageKilometers - 1) * 100, 0)
  found.push(week === null || percent === null ? null : { key: 'weekLoad', values: { weekKm: round(week.kilometers), averageKm: round(week.averageKilometers), percent, hadIntervals: week.hadIntervals } })

  found.push(steady ? hrAtPace(similar) : null)

  found.push(
    current.kind === 'long' && current.continuity !== null
      ? {
          key: 'pauses',
          values: { pauses: current.continuity.pauses.length, longestContinuousKm: round(current.continuity.longestContinuousMeters / DETAILED.metersPerKilometer, 2), totalKm: round(current.continuity.totalMeters / DETAILED.metersPerKilometer, 2) },
        }
      : null,
  )
  found.push(current.kind === 'intervals' ? repetitions(current) : null)
  found.push(goalFinding(current, context.goals))

  const findings = found.flatMap((item) => (item === null ? [] : [item])).slice(0, DETAILED.maxFindings)

  const recommendations: DetailedRecommendation[] = []
  const calm = similar.flatMap((item) => (item.fadeKm === null || item.fadeKm >= DETAILED.earlyFadeKm ? [startPace(item.splits)] : []))
  const calmStart = median(defined(calm))
  if (current.kind === 'long' && start.todayStart !== null && current.fadeKm !== null && current.fadeKm < DETAILED.earlyFadeKm && calmStart !== null && start.todayStart < calmStart) {
    recommendations.push({ key: 'startPace', value: round(calmStart, 0) })
  }
  const plannedOrDone = Math.max(current.run.activity.distanceMeters ?? 0, current.plannedMeters ?? 0)
  if (current.fadeKm !== null && plannedOrDone >= DETAILED.gelMinimumMeters) {
    recommendations.push({ key: 'gel', value: Math.max(1, current.fadeKm - DETAILED.gelKmBeforeFade) })
  }
  const readinessFinding = findings.find((item) => item.key === 'readiness')
  const lowAverage = readinessFinding?.values.lowAverage
  const highAverage = readinessFinding?.values.highAverage
  if (
    context.readinessToday !== null &&
    context.readinessToday < DETAILED.lowReadiness &&
    typeof lowAverage === 'number' &&
    typeof highAverage === 'number' &&
    lowAverage < highAverage
  ) {
    recommendations.push({ key: 'swapDay', value: context.readinessToday })
  }
  if (percent !== null && percent >= DETAILED.heavyWeekPercent) recommendations.push({ key: 'easeWeek', value: percent })

  return { findings, recommendations: recommendations.slice(0, DETAILED.maxRecommendations) }
}
