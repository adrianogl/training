import { open, seal } from './cipher.js'
import { GARMIN_PENDING_MINUTES, GARMIN_REFRESH_MARGIN_MS } from './constants.js'
import type { Sql } from './db.js'
import { garminRefresh } from './garminAuth.js'
import type { GarminEnv, GarminPendingLogin, GarminSession } from './types.js'

function sessionContext(accountId: string): string {
  return `garmin-session:${accountId}`
}

function pendingContext(accountId: string): string {
  return `garmin-pending:${accountId}`
}

export async function saveConnection(sql: Sql, key: Buffer, accountId: string, session: GarminSession): Promise<void> {
  await sql(
    `insert into garmin_connections (account_id, session_enc, expires_at) values ($1, $2, $3)
     on conflict (account_id) do update set session_enc = excluded.session_enc, expires_at = excluded.expires_at, updated_at = now()`,
    [accountId, seal(key, JSON.stringify(session), sessionContext(accountId)), session.expiresAt],
  )
}

export async function connectionStatus(sql: Sql, accountId: string): Promise<{ connected: boolean; connectedAt: string | null }> {
  const rows = await sql<{ connected_at: string | Date }>('select connected_at from garmin_connections where account_id = $1', [accountId])
  const row = rows[0]
  return { connected: row !== undefined, connectedAt: row === undefined ? null : new Date(row.connected_at).toISOString() }
}

export async function deleteConnection(sql: Sql, accountId: string): Promise<void> {
  await sql('delete from garmin_connections where account_id = $1', [accountId])
  await sql('delete from garmin_pending_logins where account_id = $1', [accountId])
}

export async function freshSession(sql: Sql, env: GarminEnv & { dataKey: Buffer }, accountId: string): Promise<GarminSession | undefined> {
  const rows = await sql<{ session_enc: string }>('select session_enc from garmin_connections where account_id = $1', [accountId])
  const sealed = rows[0]?.session_enc
  const text = sealed === undefined ? undefined : open(env.dataKey, sealed, sessionContext(accountId))
  if (text === undefined) {
    return undefined
  }
  const session = JSON.parse(text) as GarminSession
  if (new Date(session.expiresAt).getTime() - env.now().getTime() > GARMIN_REFRESH_MARGIN_MS) {
    return session
  }
  const refreshed = await garminRefresh(env.fetcher, session)
  await saveConnection(sql, env.dataKey, accountId, refreshed)
  return refreshed
}

export async function savePending(sql: Sql, key: Buffer, accountId: string, pending: GarminPendingLogin, now: Date): Promise<void> {
  const expires = new Date(now.getTime() + GARMIN_PENDING_MINUTES * 60 * 1000).toISOString()
  await sql(
    `insert into garmin_pending_logins (account_id, state_enc, expires_at) values ($1, $2, $3)
     on conflict (account_id) do update set state_enc = excluded.state_enc, expires_at = excluded.expires_at`,
    [accountId, seal(key, JSON.stringify(pending), pendingContext(accountId)), expires],
  )
}

export async function takePending(sql: Sql, key: Buffer, accountId: string, now: Date): Promise<GarminPendingLogin | undefined> {
  const rows = await sql<{ state_enc: string }>(
    'delete from garmin_pending_logins where account_id = $1 and expires_at > $2 returning state_enc',
    [accountId, now.toISOString()],
  )
  const sealed = rows[0]?.state_enc
  const text = sealed === undefined ? undefined : open(key, sealed, pendingContext(accountId))
  return text === undefined ? undefined : (JSON.parse(text) as GarminPendingLogin)
}
