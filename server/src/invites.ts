import { randomUUID } from 'node:crypto'
import { INVITE_DAYS } from './constants.js'
import type { Sql } from './db.js'
import type { InviteChannel, InviteInput, InviteRow, InviteStatus } from './types.js'
import { newToken, tokenHash } from './users.js'

interface InviteRecord {
  id: string
  name: string
  email: string | null
  channel: InviteChannel
  created_at: string | Date
  expires_at: string | Date
  accepted_at: string | Date | null
  canceled_at: string | Date | null
}

const COLUMNS = 'id, name, email, channel, created_at, expires_at, accepted_at, canceled_at'

function iso(value: string | Date): string {
  return new Date(value).toISOString()
}

function status(record: InviteRecord, now: Date): InviteStatus {
  if (record.accepted_at !== null) {
    return 'accepted'
  }
  if (record.canceled_at !== null) {
    return 'canceled'
  }
  return new Date(record.expires_at).getTime() <= now.getTime() ? 'expired' : 'pending'
}

function toRow(record: InviteRecord, now: Date): InviteRow {
  return {
    id: record.id,
    name: record.name,
    email: record.email,
    channel: record.channel,
    status: status(record, now),
    createdAt: iso(record.created_at),
    expiresAt: iso(record.expires_at),
    acceptedAt: record.accepted_at === null ? null : iso(record.accepted_at),
  }
}

function expiry(now: Date): string {
  return new Date(now.getTime() + INVITE_DAYS * 24 * 60 * 60 * 1000).toISOString()
}

export async function createInvite(sql: Sql, input: InviteInput, createdBy: string, now: Date): Promise<{ token: string; invite: InviteRow }> {
  const token = newToken()
  const rows = await sql<InviteRecord>(
    `insert into invites (id, token_hash, name, email, channel, created_by, created_at, expires_at)
     values ($1, $2, $3, $4, $5, $6, $7, $8) returning ${COLUMNS}`,
    [randomUUID(), tokenHash(token), input.name, input.email ?? null, input.channel, createdBy, now.toISOString(), expiry(now)],
  )
  return { token, invite: toRow(rows[0] as InviteRecord, now) }
}

export async function pendingInvite(
  sql: Sql,
  token: string,
  now: Date,
): Promise<{ id: string; name: string; email: string | null; inviterName: string | null; expiresAt: string } | undefined> {
  const rows = await sql<{ id: string; name: string; email: string | null; inviter: string | null; expires_at: string | Date }>(
    `select i.id, i.name, i.email, u.name as inviter, i.expires_at
     from invites i left join users u on u.id = i.created_by
     where i.token_hash = $1 and i.accepted_at is null and i.canceled_at is null and i.expires_at > $2`,
    [tokenHash(token), now.toISOString()],
  )
  const row = rows[0]
  return row === undefined ? undefined : { id: row.id, name: row.name, email: row.email, inviterName: row.inviter, expiresAt: iso(row.expires_at) }
}

export async function acceptInvite(sql: Sql, inviteId: string, userId: string, now: Date): Promise<boolean> {
  const rows = await sql(
    `update invites set accepted_user_id = $2, accepted_at = $3
     where id = $1 and accepted_at is null and canceled_at is null and expires_at > $3 returning id`,
    [inviteId, userId, now.toISOString()],
  )
  return rows.length > 0
}



export async function listInvites(sql: Sql, now: Date): Promise<InviteRow[]> {
  const rows = await sql<InviteRecord>(`select ${COLUMNS} from invites order by created_at desc limit 100`)
  return rows.map((row) => toRow(row, now))
}

export async function inviteById(sql: Sql, id: string, now: Date): Promise<InviteRow | undefined> {
  const rows = await sql<InviteRecord>(`select ${COLUMNS} from invites where id = $1`, [id])
  const row = rows[0]
  return row === undefined ? undefined : toRow(row, now)
}

export async function cancelInvite(sql: Sql, id: string, now: Date): Promise<void> {
  await sql('update invites set canceled_at = $2 where id = $1 and accepted_at is null and canceled_at is null', [id, now.toISOString()])
}

export async function renewInvite(sql: Sql, id: string, now: Date): Promise<{ token: string; invite: InviteRow } | undefined> {
  const token = newToken()
  const rows = await sql<InviteRecord>(
    `update invites set token_hash = $2, expires_at = $3, canceled_at = null, created_at = $4
     where id = $1 and accepted_at is null returning ${COLUMNS}`,
    [id, tokenHash(token), expiry(now), now.toISOString()],
  )
  const row = rows[0]
  return row === undefined ? undefined : { token, invite: toRow(row, now) }
}
