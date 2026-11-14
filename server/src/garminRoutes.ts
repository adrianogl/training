import { accountExists, resolveAccountId } from './auth.js'
import { dataKeyFromEnv } from './cipher.js'
import { GARMIN_CODE_PATTERN, GARMIN_ROUTE, MAX_BODY_BYTES, SYNC_BUDGET_MS } from './constants.js'
import type { Sql } from './db.js'
import { connectionStatus, deleteConnection, freshSession, saveConnection, savePending, takePending } from './garmin.js'
import { garminSignIn, garminVerify } from './garminAuth.js'
import { buildToday, LOAD_HISTORY_DAYS } from './domain/today.js'
import { addDays, localDay, readActivities, readActivitiesSince, readDays, syncAccount } from './garminSync.js'
import { GarminError } from './garminError.js'
import type { GarminEnv } from './types.js'
import { parseObject } from './validate.js'

function json(status: number, body: unknown): Response {
  return Response.json(body, { status, headers: { 'cache-control': 'no-store' } })
}

function failure(status: number, error: string): Response {
  return json(status, { error })
}

export function garminEnvFromProcess(): GarminEnv {
  return { dataKey: dataKeyFromEnv(process.env), fetcher: fetch, now: () => new Date() }
}

function garminFailure(error: GarminError): Response {
  switch (error.code) {
    case 'invalid_credentials':
      return failure(400, 'garmin_invalid_credentials')
    case 'invalid_code':
      return failure(400, 'garmin_invalid_code')
    case 'rate_limited':
      return failure(429, 'garmin_rate_limited')
    case 'session_expired':
      return failure(409, 'garmin_session_expired')
    default:
      return failure(502, 'garmin_unavailable')
  }
}

async function withAccount(
  request: Request,
  sql: Sql,
  env: GarminEnv,
  route: string,
  handle: (accountId: string, key: Buffer) => Promise<Response>,
): Promise<Response> {
  try {
    const accountId = await resolveAccountId(sql, request.headers.get('authorization'), env.now())
    if (accountId === undefined || !(await accountExists(sql, accountId))) {
      return failure(401, 'unauthorized')
    }
    if (env.dataKey === undefined) {
      return failure(503, 'storage_unavailable')
    }
    return await handle(accountId, env.dataKey)
  } catch (error) {
    if (error instanceof GarminError) {
      console.error(JSON.stringify({ route: `${GARMIN_ROUTE}/${route}`, garmin: error.code }))
      return garminFailure(error)
    }
    console.error(JSON.stringify({ route: `${GARMIN_ROUTE}/${route}`, error: error instanceof Error ? error.name : 'unknown' }))
    return failure(500, 'internal_error')
  }
}

async function body(request: Request): Promise<Record<string, unknown> | undefined> {
  const text = await request.text()
  if (Buffer.byteLength(text) > MAX_BODY_BYTES) {
    return undefined
  }
  const parsed = parseObject(text)
  return parsed.ok ? parsed.value : undefined
}

export function garminConnectRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'connect', async (accountId, key) => {
    const value = await body(request)
    if (typeof value?.email !== 'string' || typeof value.password !== 'string' || value.email === '' || value.password === '') {
      return failure(400, 'garmin_invalid_credentials')
    }
    const outcome = await garminSignIn(env.fetcher, value.email, value.password)
    if (outcome.status === 'needs_code') {
      await savePending(sql, key, accountId, outcome.pending, env.now())
      return json(200, { status: 'needs_code', method: outcome.pending.method })
    }
    await saveConnection(sql, key, accountId, outcome.session)
    return json(200, { status: 'connected' })
  })
}

export function garminVerifyRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'verify', async (accountId, key) => {
    const value = await body(request)
    const code = typeof value?.code === 'string' ? value.code.trim() : ''
    if (!GARMIN_CODE_PATTERN.test(code)) {
      return failure(400, 'garmin_invalid_code')
    }
    const pending = await takePending(sql, key, accountId, env.now())
    if (pending === undefined) {
      return failure(409, 'garmin_login_expired')
    }
    await saveConnection(sql, key, accountId, await garminVerify(env.fetcher, code, pending))
    return json(200, { status: 'connected' })
  })
}

export function garminStatusRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'status', async (accountId) => {
    if (request.method === 'DELETE') {
      await deleteConnection(sql, accountId)
      return new Response(null, { status: 204, headers: { 'cache-control': 'no-store' } })
    }
    return json(200, await connectionStatus(sql, accountId))
  })
}

export function garminSessionRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'session', async (accountId, key) => {
    const session = await freshSession(sql, { ...env, dataKey: key }, accountId)
    return session === undefined ? failure(404, 'garmin_not_connected') : json(200, session)
  })
}

const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/
const MAX_DAYS_RANGE = 200
const MAX_ACTIVITIES_PAGE = 100

export function garminSyncRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'sync', async (accountId, key) => {
    const progress = await syncAccount(sql, { ...env, dataKey: key }, accountId)
    return progress === undefined ? failure(404, 'garmin_not_connected') : json(200, progress)
  })
}

export function garminDaysRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'days', async (accountId, key) => {
    const params = new URL(request.url).searchParams
    const to = params.get('to') ?? localDay(env.now())
    const from = params.get('from') ?? addDays(to, -27)
    if (!DAY_PATTERN.test(from) || !DAY_PATTERN.test(to) || from > to || from < addDays(to, -MAX_DAYS_RANGE)) {
      return failure(400, 'invalid_range')
    }
    return json(200, { days: await readDays(sql, key, accountId, from, to) })
  })
}

export function garminActivitiesRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'activities', async (accountId, key) => {
    const params = new URL(request.url).searchParams
    const before = params.get('before') ?? undefined
    const limit = Math.min(MAX_ACTIVITIES_PAGE, Math.max(1, Number(params.get('limit') ?? 30) || 30))
    if (before !== undefined && !DAY_PATTERN.test(before)) {
      return failure(400, 'invalid_range')
    }
    return json(200, { activities: await readActivities(sql, key, accountId, before, limit) })
  })
}

export async function garminCronRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess(), secret = process.env.CRON_SECRET): Promise<Response> {
  if (secret === undefined || secret === '' || request.headers.get('authorization') !== `Bearer ${secret}`) {
    return failure(401, 'unauthorized')
  }
  if (env.dataKey === undefined) {
    return failure(503, 'storage_unavailable')
  }
  const accounts = await sql<{ account_id: string }>('select account_id from garmin_connections order by updated_at')
  const budget = Math.max(5_000, Math.floor(SYNC_BUDGET_MS / Math.max(1, accounts.length)))
  let synced = 0
  for (const { account_id: accountId } of accounts) {
    try {
      await syncAccount(sql, { ...env, dataKey: env.dataKey }, accountId, budget)
      synced += 1
    } catch (error) {
      console.error(JSON.stringify({ route: 'cron/garmin-sync', error: error instanceof GarminError ? error.code : 'unknown' }))
    }
  }
  return json(200, { accounts: accounts.length, synced })
}

export function garminTodayRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'today', async (accountId, key) => {
    const today = localDay(env.now())
    const days = await readDays(sql, key, accountId, addDays(today, -35), today)
    const activities = await readActivitiesSince(sql, key, accountId, addDays(today, -LOAD_HISTORY_DAYS))
    return json(200, buildToday(days, activities, today))
  })
}
