import { addDays } from '../garminSync.js'
import type { ActivitySummary, HealthDay } from '../types.js'
import { READINESS, WEEK } from './domainConstants.js'
import type { ReadinessInput, TodaySummary, WeekVolume } from './domainTypes.js'
import { acuteChronicRatio, fitnessFatigueForm, loadFocus } from './load.js'
import { readinessBreakdown } from './readiness.js'

export const LOAD_HISTORY_DAYS = 120

export function isRun(activity: ActivitySummary): boolean {
  return activity.type.includes('running')
}

export function weekStartOf(day: string): string {
  const weekday = new Date(`${day}T12:00:00Z`).getUTCDay()
  return addDays(day, -((weekday + 6) % 7))
}

export function dailyLoad(activities: ActivitySummary[]): Map<string, number> {
  const load = new Map<string, number>()
  for (const activity of activities) {
    if (activity.trainingLoad !== null) {
      load.set(activity.day, (load.get(activity.day) ?? 0) + activity.trainingLoad)
    }
  }
  return load
}

export function readinessInput(day: HealthDay | undefined, acuteChronic: number | null): ReadinessInput | null {
  if (day === undefined) {
    return null
  }
  const hrv = day.hrv
  const baseline =
    hrv !== null && hrv.lowUpper !== null && hrv.balancedLow !== null && hrv.balancedUpper !== null
      ? { lowUpper: hrv.lowUpper, balancedLow: hrv.balancedLow, balancedUpper: hrv.balancedUpper }
      : null
  return {
    hrvLastNight: hrv?.lastNight ?? null,
    hrvBaseline: baseline,
    sleepScore: day.sleep?.score ?? null,
    bodyBatteryMorningMax: day.bodyBattery.morningMax ?? null,
    acuteChronic,
  }
}

export function weekVolume(runs: ActivitySummary[], today: string): WeekVolume {
  const km = new Map<string, number>()
  for (const run of runs) {
    km.set(run.day, (km.get(run.day) ?? 0) + (run.distanceMeters ?? 0) / WEEK.metersPerKm)
  }
  const start = weekStartOf(today)
  const perDay: Record<string, number> = {}
  for (let day = start; day <= today; day = addDays(day, 1)) {
    perDay[day] = km.get(day) ?? 0
  }
  const total = (first: string) => Array.from({ length: WEEK.daysPerWeek }, (_, index) => km.get(addDays(first, index)) ?? 0).reduce((sum, value) => sum + value, 0)
  const previous = Array.from({ length: WEEK.previousWeeks }, (_, index) => total(addDays(start, -WEEK.daysPerWeek * (index + 1))))
  const recentWeeks = Array.from({ length: WEEK.historyWeeks }, (_, index) => {
    const first = addDays(start, -WEEK.daysPerWeek * (WEEK.historyWeeks - 1 - index))
    return { start: first, kilometers: total(first) }
  })
  return {
    perDay,
    total: Object.values(perDay).reduce((sum, value) => sum + value, 0),
    lastWeek: previous[0] ?? 0,
    average4Weeks: previous.reduce((sum, value) => sum + value, 0) / WEEK.previousWeeks,
    recentWeeks,
  }
}

export function buildToday(days: HealthDay[], activities: ActivitySummary[], today: string): TodaySummary {
  const byDay = new Map(days.map((day) => [day.day, day]))
  const load = dailyLoad(activities)
  const input = (day: string) => readinessInput(byDay.get(day), acuteChronicRatio(load, addDays(day, -1)))
  const history = Array.from({ length: READINESS.historyDays }, (_, index) => input(addDays(today, -(READINESS.historyDays - index)))).filter(
    (value): value is ReadinessInput => value !== null,
  )
  const todayInput = input(today)
  const current = byDay.get(today)
  const firstLoad = [...load.keys()].sort()[0]
  const fitness = firstLoad === undefined || firstLoad > today ? null : (fitnessFatigueForm(load, firstLoad, today).at(-1) ?? null)
  const focusFrom = addDays(today, -27)
  return {
    day: today,
    readiness: todayInput === null ? null : readinessBreakdown(todayInput, history),
    raw: {
      hrvLastNight: current?.hrv?.lastNight ?? null,
      hrvBalancedLow: current?.hrv?.balancedLow ?? null,
      hrvBalancedUpper: current?.hrv?.balancedUpper ?? null,
      sleepScore: current?.sleep?.score ?? null,
      sleepSeconds: current?.sleep?.seconds ?? null,
      bodyBatteryMorningMax: current?.bodyBattery.morningMax ?? null,
      acuteChronic: todayInput?.acuteChronic ?? null,
      restingHeartRate: current?.restingHeartRate ?? null,
      stress: current?.averageStress ?? null,
    },
    recoveryMinutes: current?.readiness?.recoveryMinutes ?? null,
    garminReadiness: current?.readiness?.score ?? null,
    fitness,
    week: weekVolume(activities.filter(isRun), today),
    focus: loadFocus(activities.filter((activity) => activity.day >= focusFrom).map((activity) => ({ load: activity.trainingLoad ?? 0, zoneSeconds: activity.zoneSeconds }))),
  }
}
