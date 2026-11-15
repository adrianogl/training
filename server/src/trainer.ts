import type { Sql } from './db.js'
import { TRAINER_RECORD_ID } from './constants.js'
import { openPlainPayload } from './recordPayload.js'

export async function readTrainerPlan(sql: Sql, key: Buffer, accountId: string): Promise<unknown | null> {
  const rows = await sql<{ payload: string | null; format: string }>(
    "select payload, format from records where account_id = $1 and kind = 'trainer' and id = $2 and not deleted",
    [accountId, TRAINER_RECORD_ID],
  )
  const row = rows[0]
  if (row === undefined || row.format !== 'plain' || row.payload === null) return null
  const text = openPlainPayload(key, accountId, 'trainer', TRAINER_RECORD_ID, row.payload)
  return text === undefined ? null : JSON.parse(text)
}
