import { addDays } from '../garminSync.js'
import { paceOfWork } from '../analysis/workPace.js'
import type { RunMetrics } from '../fit/fitTypes.js'
import type { ActivitySummary } from '../types.js'
import { TRAINING_EFFORT } from './domainConstants.js'
import type { Effort } from './domainTypes.js'
import { classifyRun } from './runKind.js'
import { isRun } from './today.js'

type Rule = typeof TRAINING_EFFORT.threshold | typeof TRAINING_EFFORT.interval

function median(values: number[]): number | null {
  if (values.length === 0) return null
  const sorted = [...values].sort((a, b) => a - b)
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 1 ? (sorted[middle] ?? null) : ((sorted[middle - 1] ?? 0) + (sorted[middle] ?? 0)) / 2
}

function effortFor(rule: Rule, sessions: { day: string; pace: number; meters: number }[], today: string): Effort | null {
  const recent = sessions
    .filter((session) => session.day <= today && session.day >= addDays(today, -TRAINING_EFFORT.windowDays) && session.meters >= rule.minimumMeters)
    .sort((a, b) => (a.day < b.day ? 1 : a.day > b.day ? -1 : 0))
    .slice(0, TRAINING_EFFORT.sessions)
  const latest = recent[0]
  const pace = median(recent.map((session) => session.pace))
  if (latest === undefined || pace === null) return null
  return { distance: rule.distance, seconds: ((pace + rule.paceOffset) * rule.distance) / TRAINING_EFFORT.metersPerKilometer, day: latest.day, kind: rule.effortKind }
}

export function structuredRunIds(activities: ActivitySummary[], metrics: Map<number, RunMetrics>, raceGoalKms: number[]): Set<number> {
  return new Set(
    activities.filter(isRun).flatMap((run) => {
      const item = metrics.get(run.id)
      if (item === undefined) return []
      const kind = classifyRun(run, item.shape, raceGoalKms)
      return item.workPace || kind === 'tempo' || kind === 'intervals' ? [run.id] : []
    }),
  )
}

export function trainingEfforts(activities: ActivitySummary[], metrics: Map<number, RunMetrics>, raceGoalKms: number[], today: string): Effort[] {
  const sessions = { tempo: [] as { day: string; pace: number; meters: number }[], intervals: [] as { day: string; pace: number; meters: number }[] }
  for (const run of activities.filter(isRun)) {
    const item = metrics.get(run.id)
    const work = item?.workPace
    if (item === undefined || work === null || work === undefined) continue
    const kind = classifyRun(run, item.shape, raceGoalKms)
    if (kind === 'tempo' || kind === 'intervals') sessions[kind].push({ day: run.day, pace: paceOfWork(work), meters: work.meters })
  }
  return [effortFor(TRAINING_EFFORT.threshold, sessions[TRAINING_EFFORT.threshold.runKind], today), effortFor(TRAINING_EFFORT.interval, sessions[TRAINING_EFFORT.interval.runKind], today)].flatMap((effort) => (effort === null ? [] : [effort]))
}
