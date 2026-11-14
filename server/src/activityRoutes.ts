import { detailedAnalysis } from './analysis/detailedAnalysis.js'
import { DETAILED } from './analysis/detailedConstants.js'
import type { DetailedRun } from './analysis/detailedTypes.js'
import { analyzeWorkout, comparisonCandidates } from './analysis/workoutAnalysis.js'
import { ACTIVITY, GARMIN_API_BASE, GARMIN_NATIVE_HEADERS } from './constants.js'
import type { Sql } from './db.js'
import { acuteChronicRatio } from './domain/load.js'
import { dailyLoad, isRun } from './domain/today.js'
import { fetchFits, fitFor, readStoredFits } from './fit/fitStore.js'
import { freshSession } from './garmin.js'
import { GarminError } from './garminError.js'
import { readGoals } from './goals.js'
import { body, failure, garminEnvFromProcess, json, withAccount } from './garminRoutes.js'
import { addDays, garminGet, localDay, readActivitiesSince, readDays, saveActivity } from './garminSync.js'
import { monthsBetween, plannedWorkout, runItems } from './planned/planned.js'
import { PLANNED } from './planned/plannedConstants.js'
import type { CalendarItem, WorkoutDto } from './planned/plannedTypes.js'
import type { ActivitySummary, GarminEnv } from './types.js'

const MONTHS = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez']

export function shortDay(day: string): string {
  return `${Number(day.slice(8, 10))} de ${MONTHS[Number(day.slice(5, 7)) - 1] ?? ''}`
}

function requestedId(request: Request): number | null {
  const id = Number(new URL(request.url).searchParams.get('id'))
  return Number.isSafeInteger(id) && id > 0 ? id : null
}

export function activityRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'activity', async (accountId, key) => {
    const id = requestedId(request)
    if (id === null) return failure(400, 'invalid_id')
    const today = localDay(env.now())
    const activities = await readActivitiesSince(sql, key, accountId, addDays(today, -ACTIVITY.historyDays))
    const activity = activities.find((item) => item.id === id)
    if (activity === undefined) return failure(404, 'activity_not_found')
    const keyed = { ...env, dataKey: key }
    const fit = await fitFor(sql, keyed, accountId, id)
    const run = isRun(activity)
    const candidates = run ? comparisonCandidates(activity, activities, isRun) : []
    if (candidates.length > 0) await fetchFits(sql, keyed, accountId, candidates.map((item) => item.id), ACTIVITY.comparisonFetchLimit)
    const fits = await readStoredFits(sql, key, accountId, candidates.map((item) => item.id))
    const day = (await readDays(sql, key, accountId, activity.day, activity.day))[0]
    const analysis = analyzeWorkout(
      {
        activityId: id,
        day: activity.day,
        distance: activity.distanceMeters,
        movingSeconds: activity.movingSeconds ?? activity.durationSeconds,
        averageHeartRate: activity.averageHeartRate,
        isRun: run,
        fit,
        readinessScore: day?.readiness?.score ?? null,
        acuteChronic: acuteChronicRatio(dailyLoad(activities), activity.day),
        previous: candidates.flatMap((item) => {
          const stored = fits.get(item.id)
          return stored === undefined ? [] : [{ activityId: item.id, day: item.day, distance: item.distanceMeters, movingSeconds: item.movingSeconds ?? item.durationSeconds, averageHeartRate: item.averageHeartRate, fit: stored }]
        }),
      },
      shortDay,
    )
    return json(200, { activity, analysis, fitMissing: fit === null })
  })
}

export function detailedActivityRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'activity', async (accountId, key) => {
    const id = requestedId(request)
    if (id === null) return failure(400, 'invalid_id')
    const today = localDay(env.now())
    const activities = await readActivitiesSince(sql, key, accountId, addDays(today, -ACTIVITY.historyDays))
    const activity = activities.find((item) => item.id === id)
    if (activity === undefined) return failure(404, 'activity_not_found')
    if (!isRun(activity)) return failure(400, 'not_a_run')
    const keyed = { ...env, dataKey: key }
    const currentFit = await fitFor(sql, keyed, accountId, id)
    if (currentFit === null) return failure(404, 'fit_unavailable')
    const from = addDays(activity.day, -DETAILED.windowDays)
    const others = activities.filter((item) => item.id !== id && isRun(item) && item.day >= from && item.day <= activity.day)
    let fits = await readStoredFits(sql, key, accountId, others.map((item) => item.id))
    const days = await readDays(sql, key, accountId, from, activity.day)
    const goals = (await readGoals(sql, key, accountId)).flatMap((stored) => (stored.goal === null ? [] : [stored.goal]))
    const analyze = () => {
      const runs: DetailedRun[] = others.map((item) => ({ activity: item, fit: fits.get(item.id) ?? null }))
      return detailedAnalysis({ current: { activity, fit: currentFit }, runs, days, goals })
    }
    let analysis = analyze()
    const missing = analysis.similar.map((item) => item.activityId).filter((similarId) => !fits.has(similarId))
    if (missing.length > 0 && (await fetchFits(sql, keyed, accountId, missing, ACTIVITY.comparisonFetchLimit)) > 0) {
      fits = await readStoredFits(sql, key, accountId, others.map((item) => item.id))
      analysis = analyze()
    }
    return json(200, { analysis })
  })
}

export function renameActivityRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'activity', async (accountId, key) => {
    const id = requestedId(request)
    if (id === null) return failure(400, 'invalid_id')
    const value = await body(request)
    const name = typeof value?.name === 'string' ? value.name.trim() : ''
    if (name === '' || name.length > ACTIVITY.nameMaxLength) return failure(400, 'invalid_activity_name')
    const today = localDay(env.now())
    const activity: ActivitySummary | undefined = (await readActivitiesSince(sql, key, accountId, addDays(today, -ACTIVITY.historyDays))).find((item) => item.id === id)
    if (activity === undefined) return failure(404, 'activity_not_found')
    const session = await freshSession(sql, { ...env, dataKey: key }, accountId)
    if (session === undefined) return failure(404, 'garmin_not_connected')
    const response = await env.fetcher(`${GARMIN_API_BASE}/activity-service/activity/${id}`, {
      method: 'PUT',
      headers: { ...GARMIN_NATIVE_HEADERS, authorization: `Bearer ${session.accessToken}`, 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({ activityId: id, activityName: name }),
    })
    if (response.status === 429) throw new GarminError('rate_limited')
    if (response.status === 401) throw new GarminError('session_expired')
    if (!response.ok) throw new GarminError('unexpected_response')
    await saveActivity(sql, key, accountId, { ...activity, name })
    return json(200, { id, name })
  })
}

export function plannedRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'planned', async (accountId, key) => {
    const first = localDay(env.now())
    const last = addDays(first, PLANNED.daysAhead)
    const session = await freshSession(sql, { ...env, dataKey: key }, accountId)
    if (session === undefined) return failure(404, 'garmin_not_connected')
    const keyed = { ...env, dataKey: key }
    const items: CalendarItem[] = []
    for (const [year, month] of monthsBetween(first, last)) {
      const calendar = (await garminGet(keyed, session, PLANNED.calendarPath(year, month))) as { calendarItems?: CalendarItem[] } | null
      items.push(...(calendar?.calendarItems ?? []))
    }
    const workouts = await Promise.all(
      runItems(items, first, last).map(async (item) => {
        const dto = (await garminGet(keyed, session, PLANNED.workoutPath(item.workoutId ?? 0))) as WorkoutDto | null
        return dto === null ? null : plannedWorkout(dto, item.date ?? first, item.title ?? null)
      }),
    )
    return json(200, { planned: workouts.filter((item) => item !== null).sort((a, b) => a.day.localeCompare(b.day)) })
  })
}
