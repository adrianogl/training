import { open, seal } from './cipher.js'
import { RACES } from './constants.js'
import type { Sql } from './db.js'
import type { Lap } from './domain/domainTypes.js'
import { freshSession } from './garmin.js'
import { garminGet } from './garminSync.js'
import type { GarminEnv } from './types.js'

export function parseLaps(body: unknown): Lap[] {
  const laps = (body as { lapDTOs?: { distance?: unknown; duration?: unknown }[] } | null)?.lapDTOs ?? []
  return laps.flatMap((lap) => (typeof lap.distance === 'number' && typeof lap.duration === 'number' && lap.distance > 0 && lap.duration > 0 ? [{ distance: lap.distance, seconds: lap.duration }] : []))
}

const context = (accountId: string, activityId: number) => `activity-laps:${accountId}:${activityId}`

export async function readLaps(sql: Sql, key: Buffer, accountId: string, ids: number[]): Promise<Map<number, Lap[]>> {
  if (ids.length === 0) return new Map()
  const rows = await sql<{ activity_id: string | number; data_enc: string }>(
    'select activity_id, data_enc from activity_laps where account_id = $1 and activity_id = any($2::bigint[])',
    [accountId, ids],
  )
  return new Map(
    rows.flatMap((row) => {
      const text = open(key, row.data_enc, context(accountId, Number(row.activity_id)))
      return text === undefined ? [] : [[Number(row.activity_id), JSON.parse(text) as Lap[]] as [number, Lap[]]]
    }),
  )
}

export async function fetchMissingLaps(sql: Sql, env: GarminEnv & { dataKey: Buffer }, accountId: string, ids: number[]): Promise<Map<number, Lap[]>> {
  const known = await readLaps(sql, env.dataKey, accountId, ids)
  const missing = ids.filter((id) => !known.has(id)).slice(0, RACES.lapsPerRequest)
  if (missing.length === 0) return known
  const session = await freshSession(sql, env, accountId)
  if (session === undefined) return known
  for (const id of missing) {
    const laps = parseLaps(await garminGet(env, session, `/activity-service/activity/${id}/splits`))
    await sql(
      `insert into activity_laps (account_id, activity_id, data_enc) values ($1, $2, $3)
       on conflict (account_id, activity_id) do update set data_enc = excluded.data_enc, fetched_at = now()`,
      [accountId, id, seal(env.dataKey, JSON.stringify(laps), context(accountId, id))],
    )
    known.set(id, laps)
  }
  return known
}
