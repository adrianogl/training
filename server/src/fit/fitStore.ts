import { open, seal } from '../cipher.js'
import { GARMIN_API_BASE, GARMIN_NATIVE_HEADERS } from '../constants.js'
import type { Sql } from '../db.js'
import { freshSession } from '../garmin.js'
import { GarminError } from '../garminError.js'
import type { GarminEnv, GarminSession } from '../types.js'
import { FIT } from './fitConstants.js'
import { readZip } from './fitReader.js'
import type { FitSummary, RunMetrics } from './fitTypes.js'
import { decoupling, hillIndex, thresholdPace, zone2Pace } from './runMetrics.js'
import { zonesFor } from '../analysis/workoutAnalysis.js'

type KeyedEnv = GarminEnv & { dataKey: Buffer }

const context = (accountId: string, activityId: number) => `activity-fit:${accountId}:${activityId}`
const metricsContext = (accountId: string, activityId: number) => `activity-fit-metrics:${accountId}:${activityId}`

export function runMetrics(summary: FitSummary): RunMetrics {
  const info = summary.zoneInfo
  const floors = zonesFor(summary)?.floors ?? []
  const low = floors[1]
  const high = floors[2]
  return {
    zone2Pace: low !== undefined && high !== undefined && high - 1 >= low ? zone2Pace(summary.samples, low, high - 1) : null,
    thresholdPace: info?.thresholdHeartRate != null ? thresholdPace([summary.samples], info.thresholdHeartRate) : null,
    decoupling: decoupling(summary.samples),
    hillIndex: hillIndex(summary.samples),
  }
}

export async function downloadFit(env: KeyedEnv, session: GarminSession, activityId: number): Promise<Uint8Array | null> {
  const response = await env.fetcher(`${GARMIN_API_BASE}/download-service/files/activity/${activityId}`, {
    headers: { ...GARMIN_NATIVE_HEADERS, authorization: `Bearer ${session.accessToken}`, accept: '*/*' },
  })
  if (response.status === 429) throw new GarminError('rate_limited')
  if (response.status === 401) throw new GarminError('session_expired')
  if (response.status === 404) return null
  if (!response.ok) {
    console.error(JSON.stringify({ route: 'fit', download: response.status }))
    return null
  }
  return new Uint8Array(await response.arrayBuffer())
}

export async function readStoredFits(sql: Sql, key: Buffer, accountId: string, ids: number[]): Promise<Map<number, FitSummary>> {
  if (ids.length === 0) return new Map()
  const rows = await sql<{ activity_id: string | number; version: number; data_enc: string }>(
    'select activity_id, version, data_enc from activity_fit where account_id = $1 and activity_id = any($2::bigint[]) and version = $3',
    [accountId, ids, FIT.processingVersion],
  )
  return new Map(
    rows.flatMap((row) => {
      const text = open(key, row.data_enc, context(accountId, Number(row.activity_id)))
      return text === undefined ? [] : [[Number(row.activity_id), JSON.parse(text) as FitSummary] as [number, FitSummary]]
    }),
  )
}

export async function storeFit(sql: Sql, key: Buffer, accountId: string, activityId: number, summary: FitSummary): Promise<void> {
  await sql(
    `insert into activity_fit (account_id, activity_id, version, data_enc, metrics_enc) values ($1, $2, $3, $4, $5)
     on conflict (account_id, activity_id) do update set version = excluded.version, data_enc = excluded.data_enc, metrics_enc = excluded.metrics_enc, fetched_at = now()`,
    [accountId, activityId, summary.version, seal(key, JSON.stringify(summary), context(accountId, activityId)), seal(key, JSON.stringify(runMetrics(summary)), metricsContext(accountId, activityId))],
  )
}

export async function missingFitIds(sql: Sql, accountId: string, ids: number[]): Promise<number[]> {
  if (ids.length === 0) return []
  const rows = await sql<{ activity_id: string | number }>(
    'select activity_id from activity_fit where account_id = $1 and activity_id = any($2::bigint[]) and version = $3',
    [accountId, ids, FIT.processingVersion],
  )
  const stored = new Set(rows.map((row) => Number(row.activity_id)))
  return ids.filter((id) => !stored.has(id))
}

export async function fetchFits(sql: Sql, env: KeyedEnv, accountId: string, ids: number[], limit: number, hasTime: () => boolean = () => true): Promise<number> {
  const missing = (await missingFitIds(sql, accountId, ids)).slice(0, limit)
  if (missing.length === 0) return 0
  const session = await freshSession(sql, env, accountId)
  if (session === undefined) return 0
  let fetched = 0
  for (const id of missing) {
    if (!hasTime()) break
    const zip = await downloadFit(env, session, id)
    if (zip === null) continue
    try {
      await storeFit(sql, env.dataKey, accountId, id, readZip(zip))
      fetched += 1
    } catch (error) {
      console.error(JSON.stringify({ route: 'fit', activity: 'read_failed', error: error instanceof Error ? error.message : 'unknown' }))
    }
  }
  return fetched
}

export async function fitFor(sql: Sql, env: KeyedEnv, accountId: string, activityId: number): Promise<FitSummary | null> {
  const stored = (await readStoredFits(sql, env.dataKey, accountId, [activityId])).get(activityId)
  if (stored !== undefined) return stored
  await fetchFits(sql, env, accountId, [activityId], 1)
  return (await readStoredFits(sql, env.dataKey, accountId, [activityId])).get(activityId) ?? null
}

export async function readRunMetrics(sql: Sql, key: Buffer, accountId: string, ids: number[]): Promise<Map<number, RunMetrics>> {
  if (ids.length === 0) return new Map()
  const rows = await sql<{ activity_id: string | number; metrics_enc: string | null }>(
    'select activity_id, metrics_enc from activity_fit where account_id = $1 and activity_id = any($2::bigint[]) and version = $3 and metrics_enc is not null',
    [accountId, ids, FIT.processingVersion],
  )
  return new Map(
    rows.flatMap((row) => {
      const id = Number(row.activity_id)
      const text = row.metrics_enc === null ? undefined : open(key, row.metrics_enc, metricsContext(accountId, id))
      return text === undefined ? [] : [[id, JSON.parse(text) as RunMetrics] as [number, RunMetrics]]
    }),
  )
}
