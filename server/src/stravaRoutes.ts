import { accountExists, resolveAccountId } from './auth.js'
import { dataKeyFromEnv } from './cipher.js'
import { STRAVA_APP_REDIRECT, STRAVA_FORMAT, STRAVA_MAX_TEXT_LENGTH, STRAVA_REQUIRED_SCOPES, STRAVA_ROUTE, STRAVA_SIGNATURE } from './constants.js'
import type { Sql } from './db.js'
import { body, failure, json } from './garminRoutes.js'
import {
  authorizeUrl,
  deauthorize,
  deleteLink,
  exchangeCode,
  findActivity,
  findBlock,
  freshLink,
  postedHash,
  readDescription,
  readLink,
  recordPost,
  saveLink,
  setEnabled,
  signState,
  textHash,
  verifyState,
  writeDescription,
} from './strava.js'
import { StravaError } from './stravaError.js'
import type { StravaDescribeStatus, StravaEnv } from './types.js'

export function stravaEnvFromProcess(): StravaEnv {
  return {
    dataKey: dataKeyFromEnv(process.env),
    fetcher: fetch,
    now: () => new Date(),
    clientId: process.env.STRAVA_CLIENT_ID,
    clientSecret: process.env.STRAVA_CLIENT_SECRET,
  }
}

function configured(env: StravaEnv): env is StravaEnv & { dataKey: Buffer; clientId: string; clientSecret: string } {
  return env.dataKey !== undefined && env.clientId !== undefined && env.clientId !== '' && env.clientSecret !== undefined && env.clientSecret !== ''
}

function stravaFailure(error: StravaError): Response {
  switch (error.code) {
    case 'rate_limited':
      return json(200, { status: 'retry_later' })
    case 'unauthorized':
      return failure(409, 'strava_session_expired')
    default:
      return failure(502, 'strava_unavailable')
  }
}

function appRedirect(query: string): Response {
  return new Response(null, { status: 302, headers: { location: `${STRAVA_APP_REDIRECT}?${query}`, 'cache-control': 'no-store' } })
}

async function withStrava(
  request: Request,
  sql: Sql,
  env: StravaEnv,
  route: string,
  handle: (accountId: string, ready: StravaEnv & { dataKey: Buffer; clientId: string; clientSecret: string }) => Promise<Response>,
): Promise<Response> {
  if (!configured(env)) {
    return failure(503, 'strava_not_configured')
  }
  try {
    const accountId = await resolveAccountId(sql, request.headers.get('authorization'), env.now())
    if (accountId === undefined || !(await accountExists(sql, accountId))) {
      return failure(401, 'unauthorized')
    }
    return await handle(accountId, env)
  } catch (error) {
    if (error instanceof StravaError) {
      console.error(JSON.stringify({ route: `${STRAVA_ROUTE}/${route}`, strava: error.code }))
      return stravaFailure(error)
    }
    console.error(JSON.stringify({ route: `${STRAVA_ROUTE}/${route}`, error: error instanceof Error ? error.name : 'unknown' }))
    return failure(500, 'internal_error')
  }
}

export function stravaConnectRoute(request: Request, sql: Sql, env: StravaEnv = stravaEnvFromProcess()): Promise<Response> {
  return withStrava(request, sql, env, 'connect', async (accountId, ready) =>
    json(200, { url: authorizeUrl(ready.clientId, signState(ready.dataKey, accountId, ready.now())) }),
  )
}

export async function stravaCallbackRoute(request: Request, sql: Sql, env: StravaEnv = stravaEnvFromProcess()): Promise<Response> {
  if (!configured(env)) {
    return failure(503, 'strava_not_configured')
  }
  const params = new URL(request.url).searchParams
  const accountId = verifyState(env.dataKey, params.get('state') ?? '', env.now())
  if (accountId === undefined) {
    return appRedirect('error=invalid_state')
  }
  const code = params.get('code')
  if (params.get('error') !== null || code === null || code === '') {
    return appRedirect('error=access_denied')
  }
  const scope = params.get('scope') ?? ''
  if (!STRAVA_REQUIRED_SCOPES.every((required) => scope.split(',').includes(required))) {
    return appRedirect('error=scope')
  }
  try {
    if (!(await accountExists(sql, accountId))) {
      return appRedirect('error=invalid_state')
    }
    await saveLink(sql, env.dataKey, accountId, await exchangeCode(env, code), scope)
    return appRedirect('connected=1')
  } catch (error) {
    console.error(JSON.stringify({ route: `${STRAVA_ROUTE}/callback`, error: error instanceof StravaError ? error.code : 'unknown' }))
    return appRedirect(error instanceof StravaError && error.code === 'rate_limited' ? 'error=rate_limited' : 'error=exchange_failed')
  }
}

export function stravaStatusRoute(request: Request, sql: Sql, env: StravaEnv = stravaEnvFromProcess()): Promise<Response> {
  return withStrava(request, sql, env, 'status', async (accountId, ready) => {
    const link = await readLink(sql, ready.dataKey, accountId)
    if (request.method === 'DELETE') {
      if (link !== undefined) {
        await deauthorize(ready.fetcher, link.accessToken)
      }
      await deleteLink(sql, accountId)
      return new Response(null, { status: 204, headers: { 'cache-control': 'no-store' } })
    }
    if (request.method === 'PATCH') {
      const value = await body(request)
      if (typeof value?.enabled !== 'boolean') {
        return failure(400, 'invalid_body')
      }
      if (!(await setEnabled(sql, accountId, value.enabled))) {
        return failure(404, 'strava_not_connected')
      }
      return json(200, { connected: true, athleteName: link?.athleteName ?? '', format: link?.format ?? STRAVA_FORMAT, enabled: value.enabled })
    }
    if (link === undefined) {
      return json(200, { connected: false, athleteName: null, format: STRAVA_FORMAT, enabled: false })
    }
    return json(200, { connected: true, athleteId: link.athleteId, athleteName: link.athleteName, format: link.format, enabled: link.enabled })
  })
}

interface DescribeInput {
  activityId: string
  startTime: Date
  distanceMeters: number
  text: string
}

function describeInput(value: Record<string, unknown> | undefined): DescribeInput | undefined {
  if (value === undefined) {
    return undefined
  }
  const { activityId, startTime, elapsedSeconds, distanceMeters, text } = value
  const start = typeof startTime === 'string' ? new Date(startTime) : undefined
  if (
    typeof activityId !== 'string' ||
    activityId === '' ||
    start === undefined ||
    Number.isNaN(start.getTime()) ||
    typeof elapsedSeconds !== 'number' ||
    !(elapsedSeconds > 0) ||
    typeof distanceMeters !== 'number' ||
    !(distanceMeters > 0) ||
    typeof text !== 'string' ||
    text.trim() === '' ||
    text.length > STRAVA_MAX_TEXT_LENGTH ||
    !text.trimEnd().endsWith(STRAVA_SIGNATURE)
  ) {
    return undefined
  }
  return { activityId, startTime: start, distanceMeters, text: text.trim() }
}

function described(status: StravaDescribeStatus, stravaActivityId?: number): Response {
  return json(200, stravaActivityId === undefined ? { status } : { status, stravaActivityId })
}

export function stravaDescribeRoute(request: Request, sql: Sql, env: StravaEnv = stravaEnvFromProcess()): Promise<Response> {
  return withStrava(request, sql, env, 'describe', async (accountId, ready) => {
    const input = describeInput(await body(request))
    if (input === undefined) {
      return failure(400, 'invalid_body')
    }
    const link = await freshLink(sql, ready, accountId)
    if (link === undefined) {
      return failure(409, 'strava_not_connected')
    }
    if (!link.enabled) {
      return described('disabled')
    }
    const stravaActivityId = await findActivity(ready.fetcher, link.accessToken, input.startTime, input.distanceMeters)
    if (stravaActivityId === undefined) {
      return described('not_found')
    }
    const description = await readDescription(ready.fetcher, link.accessToken, stravaActivityId)
    const hash = textHash(input.text)
    const block = findBlock(description)
    if (block === undefined) {
      const next = description.trim() === '' ? input.text : `${description.trimEnd()}\n\n${input.text}`
      await writeDescription(ready.fetcher, link.accessToken, stravaActivityId, next)
      await recordPost(sql, accountId, input.activityId, stravaActivityId, hash, ready.now())
      return described('posted', stravaActivityId)
    }
    const stored = await postedHash(sql, accountId, stravaActivityId)
    if (stored === undefined || textHash(description.slice(block.start, block.end)) !== stored) {
      return described('edited_by_user', stravaActivityId)
    }
    if (stored !== hash) {
      await writeDescription(ready.fetcher, link.accessToken, stravaActivityId, `${description.slice(0, block.start)}${input.text}${description.slice(block.end)}`)
      await recordPost(sql, accountId, input.activityId, stravaActivityId, hash, ready.now())
    }
    return described('updated', stravaActivityId)
  })
}
