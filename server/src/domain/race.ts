import { addDays } from '../garminSync.js'
import type { ActivitySummary } from '../types.js'
import { RACE } from './domainConstants.js'
import type { BlockWeek, Effort, GoalAssessment, GoalCrossing, Projection, RaceOutlook, StrategyTarget } from './domainTypes.js'
import { daysBetween, predict, predictionSeries } from './prediction.js'
import { project } from './projection.js'
import { weekStartOf } from './today.js'

export function assessGoal(goalSeconds: number, predictionSeconds: number): GoalAssessment | null {
  if (!Number.isFinite(goalSeconds) || !Number.isFinite(predictionSeconds) || goalSeconds <= 0 || predictionSeconds <= 0) {
    return null
  }
  const gap = (predictionSeconds - goalSeconds) / predictionSeconds
  return gap > RACE.aggressiveGap ? 'aggressive' : gap > RACE.challengingGap ? 'challenging' : 'easy'
}

export function longRunTarget(raceDistance: number): number {
  if (raceDistance <= RACE.shortRaceLimit) return raceDistance
  if (raceDistance <= RACE.halfRaceLimit) return raceDistance * RACE.halfLongRunShare
  return raceDistance * RACE.fullLongRunShare
}

export function distanceLabel(meters: number): string {
  const known = RACE.distanceLabels[meters]
  if (known !== undefined) return known
  const km = meters / 1000
  const text = Math.round(km) === km ? km.toFixed(0) : km.toFixed(1)
  return text.replace('.', ',') + RACE.kmSuffix
}

export function raceBlock(raceDay: string, today: string, weeklyKm: Map<string, number>): BlockWeek[] {
  const raceWeek = weekStartOf(raceDay)
  const currentWeek = weekStartOf(today)
  const recent = Array.from({ length: RACE.projectionWeeks }, (_, index) => weeklyKm.get(addDays(currentWeek, -7 * (index + 1))) ?? 0)
  const projection = recent.reduce((sum, value) => sum + value, 0) / recent.length
  return Array.from({ length: RACE.blockWeeks }, (_, offset) => {
    const start = addDays(raceWeek, -7 * (RACE.blockWeeks - 1 - offset))
    return start > currentWeek ? { start, km: projection, projected: true } : { start, km: weeklyKm.get(start) ?? 0, projected: false }
  })
}

export function goalCrossing(goal: number | null, projection: Projection | null, today: number | null): GoalCrossing {
  if (goal === null) return { kind: 'noGoal' }
  const points = projection?.points ?? []
  const improving = points.length >= 2 && (points[1]?.mid ?? 0) < (points[0]?.mid ?? 0)
  if (projection?.targetCrossing && improving) return { kind: 'on', day: projection.targetCrossing }
  const latest = points[0]?.mid ?? today
  if (latest === null) return { kind: 'unreachable' }
  return latest <= goal ? { kind: 'alreadyBeaten' } : { kind: 'unreachable' }
}

export function raceOutlook(raceDistance: number, upcoming: string | null, goalSeconds: number | null, efforts: Effort[], today: string): RaceOutlook {
  const raceDay = upcoming !== null && upcoming >= today ? upcoming : null
  const distance = raceDistance > 0 ? raceDistance : RACE.defaultRaceDistance
  const goal = goalSeconds !== null && goalSeconds > 0 ? goalSeconds : null
  const series = predictionSeries(distance, efforts, addDays(today, -RACE.yearDays), today)
  const current = predict(distance, efforts, today)
  const displayDays = raceDay === null ? RACE.raceProjectionFallbackDays : daysBetween(today, raceDay)
  const projected = project(series, today, Math.max(displayDays, RACE.goalHorizonDays), null, goal, current)
  const points = (projected?.points ?? []).slice(0, displayDays)
  const racePoint =
    raceDay === null
      ? null
      : raceDay === today
        ? current === null
          ? null
          : { day: raceDay, mid: current, low: current, high: current }
        : (points.find((point) => point.day === raceDay) ?? null)
  const reference = racePoint?.mid ?? current
  return {
    distance,
    label: distanceLabel(distance),
    today: current,
    raceDay: racePoint,
    yearAgo: predict(distance, efforts, addDays(today, -RACE.yearDays)),
    series,
    projection: points,
    longProjection: projected?.points ?? [],
    goalSeconds: goal,
    goalCrossing: goalCrossing(goal, projected, current),
    assessment: goal !== null && reference !== null ? assessGoal(goal, reference) : null,
  }
}

export function strategyTarget(race: { frozenTargetSeconds?: number | null; frozenTargetDay?: string | null; goalSeconds?: number | null }, outlook: RaceOutlook): StrategyTarget | null {
  if ((race.frozenTargetSeconds ?? 0) > 0) {
    return { seconds: race.frozenTargetSeconds ?? 0, source: 'frozen', frozenOn: race.frozenTargetDay ?? null }
  }
  if (outlook.raceDay !== null) return { seconds: outlook.raceDay.mid, source: 'raceDayProjection', frozenOn: null }
  if (outlook.today !== null) return { seconds: outlook.today, source: 'todayPrediction', frozenOn: null }
  if ((race.goalSeconds ?? 0) > 0) return { seconds: race.goalSeconds ?? 0, source: 'goal', frozenOn: null }
  return null
}

export function raceEfforts(activities: ActivitySummary[], results: { activityId: number }[]): Effort[] {
  const byId = new Map(activities.map((activity) => [activity.id, activity]))
  return results.flatMap(({ activityId }) => {
    const activity = byId.get(activityId)
    const seconds = activity?.durationSeconds ?? 0
    const distance = activity?.distanceMeters ?? 0
    return activity && seconds > 0 && distance > 0 ? [{ distance, seconds, day: activity.day, kind: 'race' as const }] : []
  })
}
