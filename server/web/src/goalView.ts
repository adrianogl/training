import { GOAL_DISTANCES, GOALS_TEXT } from './constants'
import { dayMonthNear, duration, kmNumber, paceClock } from './format'
import type { GoalView } from './types'

export function distanceLabel(distanceKm: number): string {
  return GOAL_DISTANCES.find((item) => Math.abs(item.value - distanceKm) < 0.01)?.label ?? `${kmNumber(distanceKm)} km`
}

export function goalTitle(goal: GoalView): string {
  return goal.kind === 'time' ? GOALS_TEXT.timeTitle(distanceLabel(goal.distanceKm), duration(goal.targetSeconds ?? 0)) : GOALS_TEXT.longTitle(`${kmNumber(goal.distanceKm)} km`)
}

export function goalLine(goal: GoalView): string {
  if (goal.kind === 'time') {
    return GOALS_TEXT.timeLine(paceClock((goal.targetSeconds ?? 0) / goal.distanceKm), goal.deadline === null ? null : dayMonthNear(goal.deadline))
  }
  return GOALS_TEXT.longLine(`${kmNumber(goal.distanceKm)} km`, paceClock(goal.paceSecondsPerKm ?? 0))
}

export function goalStatus(goal: GoalView): { text: string; tone: 'ok' | 'warn' } | null {
  const progress = goal.progress
  if (progress === null) return null
  if (progress.achievedOn !== null) return { text: GOALS_TEXT.achieved(dayMonthNear(progress.achievedOn)), tone: 'ok' }
  if (progress.kind === 'time') {
    if (progress.gapSeconds === null) return null
    return progress.gapSeconds <= 0 ? { text: GOALS_TEXT.ahead, tone: 'ok' } : { text: GOALS_TEXT.remaining(duration(progress.gapSeconds)), tone: 'warn' }
  }
  return { text: GOALS_TEXT.ofRuns(progress.metCount, progress.runs.length), tone: progress.metCount > 0 ? 'ok' : 'warn' }
}

export function predictionShare(todaySeconds: number, targetSeconds: number): { prediction: number; target: number } {
  const slowest = Math.max(todaySeconds, targetSeconds) * 1.08
  const fastest = Math.min(todaySeconds, targetSeconds) * 0.97
  const position = (seconds: number) => ((slowest - seconds) / (slowest - fastest)) * 100
  return { prediction: position(todaySeconds), target: position(targetSeconds) }
}
