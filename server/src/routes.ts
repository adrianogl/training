import { createAccount, deleteAccount } from './account.js'
import { accountExists, accountIdFromAuthorization } from './auth.js'
import { LOG_ACCOUNT_PREFIX_LENGTH, MAX_BODY_BYTES, UNLOGGED_STATUSES } from './constants.js'
import { limitsFromEnv } from './limits.js'
import type { Sql } from './db.js'
import { pullChanges, pushRecords } from './merge.js'
import { clientIpHash } from './rateLimit.js'
import { recordRequest } from './requestLog.js'
import type { Limits } from './types.js'
import { parsePushBody, parseSince } from './validate.js'

function json(status: number, body: unknown): Response {
  return Response.json(body, { status })
}

function failure(status: number, error: string): Response {
  return json(status, { error })
}

function logFailure(route: string, accountId: string | undefined, error: unknown): void {
  const code = typeof error === 'object' && error !== null && 'code' in error ? String(error.code) : undefined
  console.error(
    JSON.stringify({
      route,
      account: accountId?.slice(0, LOG_ACCOUNT_PREFIX_LENGTH),
      error: error instanceof Error ? error.name : 'unknown',
      code,
    }),
  )
}

interface Outcome {
  response: Response
  recordCount?: number
}

async function handled(
  route: string,
  request: Request,
  sql: Sql,
  handle: (accountId: string) => Promise<Outcome>,
): Promise<Response> {
  const accountId = accountIdFromAuthorization(request.headers.get('authorization'))
  let outcome: Outcome
  if (accountId === undefined) {
    outcome = { response: failure(401, 'unauthorized') }
  } else {
    try {
      outcome = await handle(accountId)
    } catch (error) {
      logFailure(`${request.method} ${route}`, accountId, error)
      outcome = { response: failure(500, 'internal_error') }
    }
  }
  if (accountId !== undefined && !UNLOGGED_STATUSES.includes(outcome.response.status)) {
    await recordRequest(sql, {
      method: request.method,
      route,
      status: outcome.response.status,
      recordCount: outcome.recordCount ?? null,
      accountPrefix: accountId.slice(0, LOG_ACCOUNT_PREFIX_LENGTH),
    })
  }
  return outcome.response
}

async function readBody(request: Request): Promise<string | undefined> {
  const declared = Number(request.headers.get('content-length') ?? 0)
  if (declared > MAX_BODY_BYTES) {
    return undefined
  }
  const text = await request.text()
  return Buffer.byteLength(text) > MAX_BODY_BYTES ? undefined : text
}

export function createAccountRoute(
  request: Request,
  sql: Sql,
  now: Date = new Date(),
  limits: Limits = limitsFromEnv(process.env),
): Promise<Response> {
  return handled('account', request, sql, async (accountId) => {
    const outcome = await createAccount(sql, accountId, clientIpHash(request.headers), now, limits.maxAccounts)
    if (outcome === 'rate_limited') {
      return { response: failure(429, 'rate_limited') }
    }
    return { response: outcome === 'created' ? json(201, { created: true }) : json(200, { created: false }) }
  })
}

export function deleteAccountRoute(request: Request, sql: Sql): Promise<Response> {
  return handled('account', request, sql, async (accountId) => ({
    response: (await deleteAccount(sql, accountId)) ? new Response(null, { status: 204 }) : failure(401, 'unauthorized'),
  }))
}

export function pullChangesRoute(request: Request, sql: Sql): Promise<Response> {
  return handled('changes', request, sql, async (accountId) => {
    if (!(await accountExists(sql, accountId))) {
      return { response: failure(401, 'unauthorized') }
    }
    const since = parseSince(new URL(request.url).searchParams.get('since'))
    if (since === undefined) {
      return { response: failure(400, 'invalid_since') }
    }
    const result = await pullChanges(sql, accountId, since)
    return { response: json(200, result), recordCount: result.records.length }
  })
}

export function pushChangesRoute(
  request: Request,
  sql: Sql,
  limits: Limits = limitsFromEnv(process.env),
): Promise<Response> {
  return handled('changes', request, sql, async (accountId) => {
    if (!(await accountExists(sql, accountId))) {
      return { response: failure(401, 'unauthorized') }
    }
    const text = await readBody(request)
    if (text === undefined) {
      return { response: failure(413, 'body_too_large') }
    }
    const parsed = parsePushBody(text)
    if (!parsed.ok) {
      return { response: failure(400, parsed.error) }
    }
    const outcome = await pushRecords(sql, accountId, parsed.records, limits.maxAccountBytes)
    if (outcome.status === 'quota_exceeded') {
      return { response: failure(413, 'quota_exceeded') }
    }
    return { response: json(200, outcome.result), recordCount: parsed.records.length }
  })
}
