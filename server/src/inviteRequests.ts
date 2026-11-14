import { randomUUID } from 'node:crypto'
import { open, seal } from './cipher.js'
import type { Sql } from './db.js'
import type { InviteRequestInput, InviteRequestRow } from './types.js'

const context = (id: string) => `invite-request:${id}`

export async function recentRequestsFrom(sql: Sql, ipHash: string, since: Date): Promise<number> {
  const rows = await sql<{ total: string | number }>('select count(*) as total from invite_requests where ip_hash = $1 and created_at > $2', [ipHash, since.toISOString()])
  return Number(rows[0]?.total ?? 0)
}

export async function pendingCount(sql: Sql): Promise<number> {
  const rows = await sql<{ total: string | number }>("select count(*) as total from invite_requests where status = 'pending'")
  return Number(rows[0]?.total ?? 0)
}

export async function saveRequest(sql: Sql, key: Buffer, input: InviteRequestInput, ipHash: string, now: Date): Promise<string> {
  const id = randomUUID()
  await sql('insert into invite_requests (id, data_enc, ip_hash, created_at) values ($1, $2, $3, $4)', [id, seal(key, JSON.stringify(input), context(id)), ipHash, now.toISOString()])
  return id
}

export async function pendingRequests(sql: Sql, key: Buffer): Promise<InviteRequestRow[]> {
  const rows = await sql<{ id: string; data_enc: string; created_at: Date | string }>("select id, data_enc, created_at from invite_requests where status = 'pending' order by created_at desc")
  return rows.flatMap((row) => {
    const text = open(key, row.data_enc, context(row.id))
    return text === undefined ? [] : [{ id: row.id, createdAt: new Date(row.created_at).toISOString(), ...(JSON.parse(text) as InviteRequestInput) }]
  })
}

export async function handleRequest(sql: Sql, id: string, status: 'invited' | 'declined', now: Date): Promise<void> {
  await sql("update invite_requests set status = $2, handled_at = $3 where id = $1 and status = 'pending'", [id, status, now.toISOString()])
}
