import { continuityPace, meetsContinuousGoal, runContinuity } from '../analysis/continuity.js'
import type { FitSample } from '../fit/fitTypes.js'
import type { ActivitySummary, GoalItem } from '../types.js'
import { GOAL_PROGRESS } from './domainConstants.js'
import type { Effort, LongGoalProgress, LongRunCheck, TimeGoalProgress } from './domainTypes.js'
import { raceOutlook } from './race.js'
import { isRun } from './today.js'

export function timeGoalProgress(goal: GoalItem, efforts: Effort[], activities: ActivitySummary[], today: string): TimeGoalProgress {
  const target = goal.targetSeconds ?? 0
  const meters = goal.distanceKm * 1000
  const outlook = raceOutlook(meters, goal.deadline, target, efforts, today)
  const achieved = activities
    .filter((run) => isRun(run) && run.day >= goal.createdAt.slice(0, 10))
    .filter((run) => (run.distanceMeters ?? 0) >= meters * GOAL_PROGRESS.timeMatchLow && (run.distanceMeters ?? 0) <= meters * GOAL_PROGRESS.timeMatchHigh)
    .filter((run) => (run.durationSeconds ?? Number.POSITIVE_INFINITY) * (meters / (run.distanceMeters ?? 1)) <= target)
    .sort((a, b) => a.day.localeCompare(b.day))[0]
  return {
    kind: 'time',
    todaySeconds: outlook.today,
    gapSeconds: outlook.today === null ? null : outlook.today - target,
    crossing: outlook.goalCrossing,
    achievedOn: achieved?.day ?? null,
  }
}

export function longCandidates(goal: GoalItem, activities: ActivitySummary[]): ActivitySummary[] {
  return activities
    .filter((run) => isRun(run) && (run.distanceMeters ?? 0) >= goal.distanceKm * 1000 * GOAL_PROGRESS.longShare)
    .sort((a, b) => b.day.localeCompare(a.day) || b.id - a.id)
    .slice(0, GOAL_PROGRESS.longRuns)
}

export function longGoalProgress(goal: GoalItem, runs: ActivitySummary[], samples: Map<number, FitSample[]>): LongGoalProgress {
  const pace = goal.paceSecondsPerKm ?? 0
  const checks: LongRunCheck[] = runs.map((run) => {
    const continuity = runContinuity(samples.get(run.id) ?? [])
    if (continuity === null) {
      return { activityId: run.id, day: run.day, distanceKm: (run.distanceMeters ?? 0) / 1000, longestContinuousKm: null, pauses: null, paceSecondsPerKm: null, met: null }
    }
    return {
      activityId: run.id,
      day: run.day,
      distanceKm: continuity.totalMeters / 1000,
      longestContinuousKm: continuity.longestContinuousMeters / 1000,
      pauses: continuity.pauses.map((pause) => ({ km: pause.startMeters / 1000, seconds: pause.seconds })),
      paceSecondsPerKm: continuityPace(continuity),
      met: meetsContinuousGoal(continuity, goal.distanceKm, pace),
    }
  })
  const known = checks.flatMap((check) => (check.longestContinuousKm === null ? [] : [check.longestContinuousKm]))
  const achieved = checks.filter((check) => check.met === true && check.day >= goal.createdAt.slice(0, 10)).sort((a, b) => a.day.localeCompare(b.day))[0]
  return {
    kind: 'continuousLong',
    runs: [...checks].sort((a, b) => a.day.localeCompare(b.day)),
    metCount: checks.filter((check) => check.met === true).length,
    bestContinuousKm: known.length === 0 ? null : Math.max(...known),
    achievedOn: achieved?.day ?? null,
  }
}
