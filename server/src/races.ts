import type { Sql } from './db.js'
import { pushRecords } from './merge.js'
import { openPlainPayload, sealPlainRecords } from './recordPayload.js'
import type { RaceItem, StoredRace } from './types.js'

export async function readRaces(sql: Sql, key: Buffer, accountId: string): Promise<StoredRace[]> {
  const rows = await sql<{ id: string; payload: string | null; format: string }>(
    "select id, payload, format from records where account_id = $1 and kind = 'race' and not deleted order by id",
    [accountId],
  )
  return rows.map((row) => {
    if (row.format !== 'plain' || row.payload === null) return { id: row.id, race: null }
    const text = openPlainPayload(key, accountId, 'race', row.id, row.payload)
    return { id: row.id, race: text === undefined ? null : (JSON.parse(text) as RaceItem) }
  })
}

export async function nextUpdatedAt(sql: Sql, accountId: string, id: string, now: Date): Promise<string> {
  const rows = await sql<{ updated_at: Date | string }>("select updated_at from records where account_id = $1 and kind = 'race' and id = $2", [accountId, id])
  const current = rows[0] === undefined ? 0 : new Date(rows[0].updated_at).getTime()
  return new Date(Math.max(now.getTime(), current + 1)).toISOString()
}

export async function writeRace(sql: Sql, key: Buffer, accountId: string, race: RaceItem, maxAccountBytes: number): Promise<boolean> {
  const records = sealPlainRecords([{ kind: 'race', id: race.id, updatedAt: race.updatedAt, deleted: false, payload: JSON.stringify(race), format: 'plain' }], key, accountId)
  const outcome = await pushRecords(sql, accountId, records, maxAccountBytes)
  return outcome.status === 'ok'
}

export async function deleteRace(sql: Sql, accountId: string, id: string, updatedAt: string): Promise<void> {
  await pushRecords(sql, accountId, [{ kind: 'race', id, updatedAt, deleted: true, payload: null, format: 'plain' }], Number.MAX_SAFE_INTEGER)
}
