import { createHash, createHmac, timingSafeEqual } from 'node:crypto'
import { renderAdminPage, renderDisabledPage, renderLoginPage, renderUnavailablePage } from './adminHtml.js'
import {
  ADMIN_HEADERS,
  ADMIN_HOURS,
  ADMIN_MAX_FORM_BYTES,
  ADMIN_MIN_TOKEN_LENGTH,
  ADMIN_PATH,
  ADMIN_RECENT_LIMIT,
  ADMIN_SESSION_CONTEXT,
  ADMIN_SESSION_COOKIE,
  ADMIN_SESSION_MAX_AGE_SECONDS,
  RECORD_KINDS,
} from './constants.js'
import type { Sql } from './db.js'
import type { AdminMetrics, HourlyBucket, KindCounts, RecentRequest, RecordKind } from './types.js'

const HOUR_MS = 60 * 60 * 1000
const isoUtc = (column: string) => `to_char(${column} at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')`

function safeEqual(candidate: string, expected: string): boolean {
  const digest = (value: string) => createHash('sha256').update(value).digest()
  return timingSafeEqual(digest(candidate), digest(expected))
}

function sessionMac(adminToken: string, issuedAt: string): string {
  return createHmac('sha256', adminToken).update(`${ADMIN_SESSION_CONTEXT}.${issuedAt}`).digest('base64url')
}

function sessionValue(adminToken: string, now: Date): string {
  const issuedAt = String(Math.floor(now.getTime() / 1000))
  return `${issuedAt}.${sessionMac(adminToken, issuedAt)}`
}

function isValidSession(cookie: string, adminToken: string, now: Date): boolean {
  const match = /^(\d{1,12})\.([A-Za-z0-9_-]+)$/.exec(cookie)
  if (match === null || match[1] === undefined || match[2] === undefined) {
    return false
  }
  const age = Math.floor(now.getTime() / 1000) - Number(match[1])
  const macMatches = safeEqual(match[2], sessionMac(adminToken, match[1]))
  return macMatches && age >= 0 && age <= ADMIN_SESSION_MAX_AGE_SECONDS
}

function sessionCookie(headers: Headers): string | undefined {
  return (headers.get('cookie') ?? '')
    .split(';')
    .map((part) => part.trim().split('='))
    .find(([name]) => name === ADMIN_SESSION_COOKIE)?.[1]
}

function isAuthorized(headers: Headers, adminToken: string, now: Date): boolean {
  const bearer = /^Bearer (.+)$/.exec(headers.get('authorization') ?? '')?.[1]
  if (bearer !== undefined && safeEqual(bearer, adminToken)) {
    return true
  }
  const cookie = sessionCookie(headers)
  return cookie !== undefined && isValidSession(cookie, adminToken, now)
}

function page(status: number, body: string, extra: Record<string, string> = {}): Response {
  return new Response(body, { status, headers: { ...ADMIN_HEADERS, ...extra } })
}

async function login(request: Request, adminToken: string, now: Date): Promise<Response> {
  const text = await request.text()
  const token = Buffer.byteLength(text) > ADMIN_MAX_FORM_BYTES ? null : new URLSearchParams(text).get('token')
  if (token === null || !safeEqual(token, adminToken)) {
    return page(401, renderLoginPage(true))
  }
  return page(303, '', {
    location: ADMIN_PATH,
    'set-cookie': `${ADMIN_SESSION_COOKIE}=${sessionValue(adminToken, now)}; Path=/; Max-Age=${ADMIN_SESSION_MAX_AGE_SECONDS}; HttpOnly; Secure; SameSite=Lax`,
  })
}

async function databaseLatency(sql: Sql): Promise<number> {
  const started = performance.now()
  await sql('select 1')
  return Math.round(performance.now() - started)
}

function hourlyBuckets(rows: { hour: string; total: number; errors: number }[], now: Date): HourlyBucket[] {
  const lastHour = Math.floor(now.getTime() / HOUR_MS)
  const byHour = new Map(rows.map((row) => [Number(row.hour), row]))
  return Array.from({ length: ADMIN_HOURS }, (_, index) => {
    const hour = lastHour - ADMIN_HOURS + 1 + index
    const row = byHour.get(hour)
    return { hourStart: new Date(hour * HOUR_MS).toISOString(), total: row?.total ?? 0, errors: row?.errors ?? 0 }
  })
}

export async function collectMetrics(sql: Sql, now: Date): Promise<AdminMetrics> {
  const latencyMs = await databaseLatency(sql)
  const windowStart = new Date((Math.floor(now.getTime() / HOUR_MS) - ADMIN_HOURS + 1) * HOUR_MS).toISOString()
  const [accounts, kinds, lastWrite, errors, hourly, recent] = await Promise.all([
    sql<{ total: number }>('select count(*)::int as total from accounts'),
    sql<{ kind: RecordKind; live: number; deleted: number }>(
      'select kind, count(*) filter (where not deleted)::int as live, count(*) filter (where deleted)::int as deleted from records group by kind',
    ),
    sql<{ at: string | null; seq: string }>(
      `select ${isoUtc('max(written_at)')} as at, coalesce(max(seq), 0)::text as seq from records`,
    ),
    sql<{ total: number }>(
      'select count(*)::int as total from request_log where status >= 400 and created_at > $1::timestamptz',
      [new Date(now.getTime() - ADMIN_HOURS * HOUR_MS).toISOString()],
    ),
    sql<{ hour: string; total: number; errors: number }>(
      `select floor(extract(epoch from created_at) / 3600)::int8::text as hour,
              count(*)::int as total,
              count(*) filter (where status >= 400)::int as errors
       from request_log where created_at >= $1::timestamptz group by 1`,
      [windowStart],
    ),
    sql<{ at: string; method: string; route: string; status: number; record_count: number | null }>(
      `select ${isoUtc('created_at')} as at, method, route, status, record_count
       from request_log order by id desc limit $1`,
      [ADMIN_RECENT_LIMIT],
    ),
  ])
  const records = Object.fromEntries(
    RECORD_KINDS.map((kind) => {
      const row = kinds.find((candidate) => candidate.kind === kind)
      return [kind, { live: row?.live ?? 0, deleted: row?.deleted ?? 0 }]
    }),
  ) as Record<RecordKind, KindCounts>
  return {
    database: { latencyMs },
    accounts: accounts[0]?.total ?? 0,
    records,
    lastWrite: { at: lastWrite[0]?.at ?? null, seq: Number(lastWrite[0]?.seq ?? 0) },
    errors24h: errors[0]?.total ?? 0,
    hourly: hourlyBuckets(hourly, now),
    recent: recent.map(
      (row): RecentRequest => ({
        at: row.at,
        method: row.method,
        route: row.route,
        status: row.status,
        recordCount: row.record_count,
      }),
    ),
  }
}

export async function adminRoute(
  request: Request,
  sql: Sql,
  adminToken: string | undefined,
  now: Date = new Date(),
): Promise<Response> {
  if (adminToken === undefined || adminToken.length < ADMIN_MIN_TOKEN_LENGTH) {
    return page(503, renderDisabledPage())
  }
  if (request.method === 'POST') {
    return login(request, adminToken, now)
  }
  if (!isAuthorized(request.headers, adminToken, now)) {
    return page(401, renderLoginPage(false))
  }
  try {
    return page(200, renderAdminPage(await collectMetrics(sql, now), new URL(request.url).host))
  } catch (error) {
    console.error(JSON.stringify({ route: 'admin', error: error instanceof Error ? error.name : 'unknown' }))
    return page(503, renderUnavailablePage())
  }
}
