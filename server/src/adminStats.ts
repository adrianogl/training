import { ACTIVE_WINDOW_DAYS } from './constants.js'
import type { Sql } from './db.js'
import type { AdminOverview, AdminUserRow, UserRole } from './types.js'

export async function adminOverview(sql: Sql, now: Date, maxAccounts: number): Promise<AdminOverview> {
  const dayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString()
  const activeSince = new Date(now.getTime() - ACTIVE_WINDOW_DAYS * 24 * 60 * 60 * 1000).toISOString()
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString()
  const [counts] = await sql<{
    accounts: number
    pending: number
    expiring: number
    active: number
    garmin: number
    requests: number
    errors: number
  }>(
    `select
       (select count(*)::int from accounts) as accounts,
       (select count(*)::int from invites where accepted_at is null and canceled_at is null and expires_at > $1) as pending,
       (select count(*)::int from invites where accepted_at is null and canceled_at is null and expires_at > $1 and expires_at <= $2) as expiring,
       (select count(distinct user_id)::int from sessions where last_seen_at > $3) as active,
       (select count(*)::int from garmin_connections) as garmin,
       (select count(*)::int from request_log where created_at > $4) as requests,
       (select count(*)::int from request_log where created_at > $4 and status >= 500) as errors`,
    [now.toISOString(), tomorrow, activeSince, dayAgo],
  )
  const byHour = await sql<{ hour: string | Date; count: number }>(
    `select date_trunc('hour', created_at) as hour, count(*)::int as count
     from request_log where created_at > $1 group by 1 order by 1`,
    [dayAgo],
  )
  const byRoute = await sql<{ route: string; count: number }>(
    `select route, count(*)::int as count from request_log where created_at > $1 group by route order by count desc`,
    [dayAgo],
  )
  let databaseBytes: number | null = null
  try {
    const [size] = await sql<{ bytes: string | number }>('select pg_database_size(current_database()) as bytes')
    databaseBytes = size === undefined ? null : Number(size.bytes)
  } catch {
    databaseBytes = null
  }
  return {
    accounts: counts?.accounts ?? 0,
    maxAccounts,
    pendingInvites: counts?.pending ?? 0,
    expiringInvites: counts?.expiring ?? 0,
    activeAccounts: counts?.active ?? 0,
    garminConnected: counts?.garmin ?? 0,
    requests24h: counts?.requests ?? 0,
    errors24h: counts?.errors ?? 0,
    requestsByHour: byHour.map((row) => ({ hour: new Date(row.hour).toISOString(), count: row.count })),
    requestsByRoute: byRoute,
    databaseBytes,
  }
}

export async function adminUsers(sql: Sql, adminEmails: string[]): Promise<AdminUserRow[]> {
  const rows = await sql<{
    id: string
    name: string
    email: string
    role: UserRole
    garmin: boolean
    last_seen: string | Date | null
    bytes: string | number | null
  }>(
    `select u.id, u.name, u.email, u.role,
       exists (select 1 from garmin_connections g where g.account_id = u.account_id) as garmin,
       (select max(last_seen_at) from sessions s where s.user_id = u.id) as last_seen,
       (select coalesce(sum(length(coalesce(payload, ''))), 0) from records r where r.account_id = u.account_id) as bytes
     from users u order by u.created_at`,
  )
  const admins = new Set(adminEmails.map((email) => email.toLowerCase()))
  return rows.map((row) => ({
    id: row.id,
    name: row.name,
    email: row.email,
    role: row.role,
    admin: admins.has(row.email.toLowerCase()),
    garminConnected: row.garmin,
    lastSeenAt: row.last_seen === null ? null : new Date(row.last_seen).toISOString(),
    dataBytes: Number(row.bytes ?? 0),
  }))
}
