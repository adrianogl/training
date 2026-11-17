import type { Sql } from '../db.js'
import { limitsFromEnv } from '../limits.js'
import { pushRecords } from '../merge.js'
import { openPlainPayload, sealPlainRecords } from '../recordPayload.js'
import { MCP } from './mcpConstants.js'

export async function readBlob(sql: Sql, key: Buffer, accountId: string, id: string): Promise<{ text: string; updatedAt: string } | null> {
  const rows = await sql<{ payload: string | null; format: string; updated_at: string }>(
    `select payload, format, to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as updated_at
     from records where account_id = $1 and kind = 'preference' and id = $2 and not deleted`,
    [accountId, id],
  )
  const row = rows[0]
  if (row === undefined || row.format !== 'plain' || row.payload === null) return null
  const plain = openPlainPayload(key, accountId, 'preference', id, row.payload)
  if (plain === undefined) return null
  const data = (JSON.parse(plain) as { data?: string }).data
  return data === undefined ? null : { text: Buffer.from(data, 'base64').toString('utf8'), updatedAt: row.updated_at }
}

export async function writeBlob(sql: Sql, key: Buffer, accountId: string, id: string, text: string, now: Date): Promise<boolean> {
  const payload = JSON.stringify({ data: Buffer.from(text, 'utf8').toString('base64') })
  const records = sealPlainRecords([{ kind: 'preference', id, updatedAt: now.toISOString(), deleted: false, payload, format: 'plain' }], key, accountId)
  const outcome = await pushRecords(sql, accountId, records, limitsFromEnv(process.env).maxAccountBytes)
  return outcome.status === 'ok'
}

export async function withinRateLimit(sql: Sql, accountPrefix: string): Promise<boolean> {
  const rows = await sql<{ calls: number }>(
    `select count(*)::int as calls from request_log
     where route = $1 and account_prefix = $2 and created_at > now() - interval '1 minute'`,
    [MCP.route, accountPrefix],
  )
  return (rows[0]?.calls ?? 0) < MCP.callsPerMinute
}
