import { open, seal } from './cipher.js'
import { GARMIN_API_BASE, GARMIN_NATIVE_HEADERS, SYNC_ACTIVITY_PAGE, SYNC_BUDGET_MS, SYNC_HISTORY_DAYS, SYNC_RECENT_DAYS, SYNC_TIME_ZONE, SYNC_VERSION } from './constants.js'
import type { Sql } from './db.js'
import { freshSession } from './garmin.js'
import { GarminError } from './garminError.js'
import { parseActivity, parseHealthDay } from './garminParse.js'
import type { ActivitySummary, GarminEnv, GarminSession, HealthDay, SyncProgress } from './types.js'

type Env = GarminEnv & { dataKey: Buffer }

export function localDay(date: Date): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: SYNC_TIME_ZONE, year: 'numeric', month: '2-digit', day: '2-digit' }).format(date)
}

export function addDays(day: string, delta: number): string {
  const date = new Date(`${day}T12:00:00Z`)
  date.setUTCDate(date.getUTCDate() + delta)
  return date.toISOString().slice(0, 10)
}

export async function garminGet(env: Env, session: GarminSession, path: string): Promise<unknown> {
  const response = await env.fetcher(`${GARMIN_API_BASE}${path}`, {
    headers: { ...GARMIN_NATIVE_HEADERS, authorization: `Bearer ${session.accessToken}`, accept: 'application/json' },
  })
  if (response.status === 429) {
    throw new GarminError('rate_limited')
  }
  if (response.status === 401) {
    throw new GarminError('session_expired')
  }
  if (response.status === 204 || response.status === 404) {
    return null
  }
  if (!response.ok) {
    throw new GarminError('unexpected_response')
  }
  const text = await response.text()
  return text === '' ? null : (JSON.parse(text) as unknown)
}

async function displayName(sql: Sql, env: Env, session: GarminSession, accountId: string): Promise<string> {
  const rows = await sql<{ profile_enc: string | null }>('select profile_enc from garmin_sync_state where account_id = $1', [accountId])
  const stored = rows[0]?.profile_enc
  const cached = stored === null || stored === undefined ? undefined : open(env.dataKey, stored, `garmin-profile:${accountId}`)
  if (cached !== undefined) {
    return cached
  }
  const profile = (await garminGet(env, session, '/userprofile-service/socialProfile')) as { displayName?: string } | null
  if (typeof profile?.displayName !== 'string') {
    throw new GarminError('unexpected_response')
  }
  await sql(
    `insert into garmin_sync_state (account_id, profile_enc) values ($1, $2)
     on conflict (account_id) do update set profile_enc = excluded.profile_enc`,
    [accountId, seal(env.dataKey, profile.displayName, `garmin-profile:${accountId}`)],
  )
  return profile.displayName
}

async function fetchDay(env: Env, session: GarminSession, name: string, day: string): Promise<HealthDay> {
  const [summary, hrv, sleep, readiness, battery] = await Promise.all([
    garminGet(env, session, `/usersummary-service/usersummary/daily/${encodeURIComponent(name)}?calendarDate=${day}`),
    garminGet(env, session, `/hrv-service/hrv/${day}`),
    garminGet(env, session, `/wellness-service/wellness/dailySleepData/${encodeURIComponent(name)}?date=${day}&nonSleepBufferMinutes=60`),
    garminGet(env, session, `/metrics-service/metrics/trainingreadiness/${day}`),
    garminGet(env, session, `/wellness-service/wellness/dailyStress/${day}`),
  ])
  return parseHealthDay(day, summary, hrv, sleep, readiness, battery)
}

async function saveDay(sql: Sql, key: Buffer, accountId: string, day: HealthDay): Promise<void> {
  await sql(
    `insert into health_days (account_id, day, data_enc) values ($1, $2, $3)
     on conflict (account_id, day) do update set data_enc = excluded.data_enc, updated_at = now()`,
    [accountId, day.day, seal(key, JSON.stringify(day), `health-day:${accountId}:${day.day}`)],
  )
}

async function saveActivity(sql: Sql, key: Buffer, accountId: string, activity: ActivitySummary): Promise<void> {
  await sql(
    `insert into activities (account_id, activity_id, day, data_enc) values ($1, $2, $3, $4)
     on conflict (account_id, activity_id) do update set day = excluded.day, data_enc = excluded.data_enc, updated_at = now()`,
    [accountId, activity.id, activity.day, seal(key, JSON.stringify(activity), `activity:${accountId}:${activity.id}`)],
  )
}

export async function syncAccount(sql: Sql, env: Env, accountId: string, budgetMs = SYNC_BUDGET_MS): Promise<SyncProgress | undefined> {
  const started = Date.now()
  const hasTime = () => Date.now() - started < budgetMs
  const session = await freshSession(sql, env, accountId)
  if (session === undefined) {
    return undefined
  }
  const name = await displayName(sql, env, session, accountId)
  const today = localDay(env.now())
  const limit = addDays(today, -SYNC_HISTORY_DAYS)
  let days = 0
  let activities = 0

  for (let offset = 0; offset < SYNC_RECENT_DAYS && hasTime(); offset += 1) {
    await saveDay(sql, env.dataKey, accountId, await fetchDay(env, session, name, addDays(today, -offset)))
    days += 1
  }

  const [state] = await sql<{ oldest_day: string | Date | null; activities_done: boolean; version: number }>(
    'select oldest_day, activities_done, version from garmin_sync_state where account_id = $1',
    [accountId],
  )
  const outdated = state !== undefined && state.version < SYNC_VERSION
  let oldest = state?.oldest_day === null || state?.oldest_day === undefined || outdated ? addDays(today, -SYNC_RECENT_DAYS + 1) : new Date(state.oldest_day).toISOString().slice(0, 10)

  let start = 0
  let activitiesDone = false
  while (hasTime() && !activitiesDone) {
    const page = (await garminGet(env, session, `/activitylist-service/activities/search/activities?start=${start}&limit=${SYNC_ACTIVITY_PAGE}`)) as unknown[] | null
    const items = (page ?? []).map(parseActivity).filter((item): item is ActivitySummary => item !== undefined)
    let reachedKnown = false
    for (const item of items) {
      if (item.day < limit) {
        reachedKnown = true
        break
      }
      const known = await sql('select 1 from activities where account_id = $1 and activity_id = $2', [accountId, item.id])
      if (known.length > 0 && state?.activities_done === true && !outdated) {
        reachedKnown = true
        break
      }
      await saveActivity(sql, env.dataKey, accountId, item)
      activities += 1
    }
    activitiesDone = reachedKnown || items.length < SYNC_ACTIVITY_PAGE
    start += SYNC_ACTIVITY_PAGE
  }

  while (hasTime() && oldest > limit) {
    const day = addDays(oldest, -1)
    await saveDay(sql, env.dataKey, accountId, await fetchDay(env, session, name, day))
    oldest = day
    days += 1
  }

  const done = activitiesDone && oldest <= limit
  await sql(
    `insert into garmin_sync_state (account_id, oldest_day, activities_done, last_sync_at, version) values ($1, $2, $3, $4, $5)
     on conflict (account_id) do update set oldest_day = excluded.oldest_day,
       activities_done = excluded.activities_done or (garmin_sync_state.activities_done and garmin_sync_state.version = excluded.version), last_sync_at = excluded.last_sync_at,
       version = excluded.version`,
    [accountId, oldest, activitiesDone, env.now().toISOString(), SYNC_VERSION],
  )
  return { done, days, activities, oldestDay: oldest }
}

export async function readDays(sql: Sql, key: Buffer, accountId: string, from: string, to: string): Promise<HealthDay[]> {
  const rows = await sql<{ day: string | Date; data_enc: string }>(
    'select day, data_enc from health_days where account_id = $1 and day between $2 and $3 order by day',
    [accountId, from, to],
  )
  return rows.flatMap((row) => {
    const day = new Date(row.day).toISOString().slice(0, 10)
    const text = open(key, row.data_enc, `health-day:${accountId}:${day}`)
    return text === undefined ? [] : [JSON.parse(text) as HealthDay]
  })
}

export async function readActivities(sql: Sql, key: Buffer, accountId: string, before: string | undefined, limit: number): Promise<ActivitySummary[]> {
  const rows = await sql<{ activity_id: string | number; data_enc: string }>(
    `select activity_id, data_enc from activities where account_id = $1 and ($2::date is null or day < $2::date)
     order by day desc, activity_id desc limit $3`,
    [accountId, before ?? null, limit],
  )
  return rows.flatMap((row) => {
    const text = open(key, row.data_enc, `activity:${accountId}:${row.activity_id}`)
    return text === undefined ? [] : [JSON.parse(text) as ActivitySummary]
  })
}

export async function readActivitiesSince(sql: Sql, key: Buffer, accountId: string, from: string): Promise<ActivitySummary[]> {
  const rows = await sql<{ activity_id: string | number; data_enc: string }>(
    'select activity_id, data_enc from activities where account_id = $1 and day >= $2 order by day',
    [accountId, from],
  )
  return rows.flatMap((row) => {
    const text = open(key, row.data_enc, `activity:${accountId}:${row.activity_id}`)
    return text === undefined ? [] : [JSON.parse(text) as ActivitySummary]
  })
}
