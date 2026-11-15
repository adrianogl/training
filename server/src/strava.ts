import { createHash, createHmac, timingSafeEqual } from 'node:crypto'
import { open, seal } from './cipher.js'
import {
  STRAVA_API_BASE,
  STRAVA_AUTHORIZE_URL,
  STRAVA_DEAUTHORIZE_URL,
  STRAVA_DISTANCE_TOLERANCE,
  STRAVA_FORMAT,
  STRAVA_MATCH_WINDOW_MS,
  STRAVA_REDIRECT_URI,
  STRAVA_REFRESH_MARGIN_MS,
  STRAVA_SCOPE,
  STRAVA_SIGNATURE,
  STRAVA_STATE_CONTEXT,
  STRAVA_STATE_MINUTES,
  STRAVA_TOKEN_URL,
} from './constants.js'
import type { Sql } from './db.js'
import { StravaError } from './stravaError.js'
import type { Fetcher, StravaEnv, StravaLink, StravaTokenSet } from './types.js'

interface TokenResponse {
  access_token?: string
  refresh_token?: string
  expires_at?: number
  athlete?: { id?: number; firstname?: string; lastname?: string }
}

interface StravaSummary {
  id: number
  distance: number
  start_date: string
  type?: string
  sport_type?: string
}

interface LinkRow {
  athlete_id: string | number
  athlete_name: string
  access_token_enc: string
  refresh_token_enc: string
  expires_at: string | Date
  scope: string
  format: string
  enabled: boolean
}

function accessContext(accountId: string): string {
  return `strava-access:${accountId}`
}

function refreshContext(accountId: string): string {
  return `strava-refresh:${accountId}`
}

function stateSignature(key: Buffer, payload: string): string {
  return createHmac('sha256', key).update(`${STRAVA_STATE_CONTEXT}.${payload}`).digest('base64url')
}

export function signState(key: Buffer, accountId: string, now: Date): string {
  const expires = now.getTime() + STRAVA_STATE_MINUTES * 60 * 1000
  const payload = Buffer.from(JSON.stringify({ a: accountId, e: expires })).toString('base64url')
  return `${payload}.${stateSignature(key, payload)}`
}

export function verifyState(key: Buffer, state: string, now: Date): string | undefined {
  const [payload, signature] = state.split('.')
  if (payload === undefined || signature === undefined) {
    return undefined
  }
  const expected = Buffer.from(stateSignature(key, payload))
  const received = Buffer.from(signature)
  if (expected.length !== received.length || !timingSafeEqual(expected, received)) {
    return undefined
  }
  try {
    const parsed = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as { a?: unknown; e?: unknown }
    return typeof parsed.a === 'string' && typeof parsed.e === 'number' && parsed.e > now.getTime() ? parsed.a : undefined
  } catch {
    return undefined
  }
}

export function authorizeUrl(clientId: string, state: string): string {
  const url = new URL(STRAVA_AUTHORIZE_URL)
  url.searchParams.set('client_id', clientId)
  url.searchParams.set('redirect_uri', STRAVA_REDIRECT_URI)
  url.searchParams.set('response_type', 'code')
  url.searchParams.set('approval_prompt', 'auto')
  url.searchParams.set('scope', STRAVA_SCOPE)
  url.searchParams.set('state', state)
  return url.toString()
}

function tokenSet(data: TokenResponse): StravaTokenSet {
  if (data.access_token === undefined || data.refresh_token === undefined || typeof data.expires_at !== 'number') {
    throw new StravaError('unavailable')
  }
  const name = [data.athlete?.firstname, data.athlete?.lastname].filter((part) => part !== undefined && part !== '').join(' ')
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresAt: new Date(data.expires_at * 1000).toISOString(),
    athleteId: data.athlete?.id,
    athleteName: name === '' ? undefined : name,
  }
}

async function tokenRequest(env: StravaEnv, form: Record<string, string>): Promise<StravaTokenSet> {
  const body = new URLSearchParams({ client_id: env.clientId ?? '', client_secret: env.clientSecret ?? '', ...form })
  const response = await env.fetcher(STRAVA_TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded', accept: 'application/json' },
    body: body.toString(),
  })
  if (response.status === 429) {
    throw new StravaError('rate_limited')
  }
  if (response.status === 400 || response.status === 401) {
    throw new StravaError('unauthorized')
  }
  if (!response.ok) {
    throw new StravaError('unavailable')
  }
  return tokenSet((await response.json().catch(() => ({}))) as TokenResponse)
}

export function exchangeCode(env: StravaEnv, code: string): Promise<StravaTokenSet> {
  return tokenRequest(env, { code, grant_type: 'authorization_code' })
}

export async function saveLink(sql: Sql, key: Buffer, accountId: string, tokens: StravaTokenSet, scope: string): Promise<void> {
  await sql(
    `insert into strava_links (account_id, athlete_id, athlete_name, access_token_enc, refresh_token_enc, expires_at, scope, format)
     values ($1, $2, $3, $4, $5, $6, $7, $8)
     on conflict (account_id) do update set athlete_id = excluded.athlete_id, athlete_name = excluded.athlete_name,
       access_token_enc = excluded.access_token_enc, refresh_token_enc = excluded.refresh_token_enc,
       expires_at = excluded.expires_at, scope = excluded.scope, updated_at = now()`,
    [
      accountId,
      tokens.athleteId ?? 0,
      tokens.athleteName ?? '',
      seal(key, tokens.accessToken, accessContext(accountId)),
      seal(key, tokens.refreshToken, refreshContext(accountId)),
      tokens.expiresAt,
      scope,
      STRAVA_FORMAT,
    ],
  )
}

async function updateTokens(sql: Sql, key: Buffer, accountId: string, tokens: StravaTokenSet): Promise<void> {
  await sql(
    `update strava_links set access_token_enc = $2, refresh_token_enc = $3, expires_at = $4, updated_at = now() where account_id = $1`,
    [accountId, seal(key, tokens.accessToken, accessContext(accountId)), seal(key, tokens.refreshToken, refreshContext(accountId)), tokens.expiresAt],
  )
}

export async function readLink(sql: Sql, key: Buffer, accountId: string): Promise<StravaLink | undefined> {
  const rows = await sql<LinkRow>('select * from strava_links where account_id = $1', [accountId])
  const row = rows[0]
  if (row === undefined) {
    return undefined
  }
  const accessToken = open(key, row.access_token_enc, accessContext(accountId))
  const refreshToken = open(key, row.refresh_token_enc, refreshContext(accountId))
  if (accessToken === undefined || refreshToken === undefined) {
    return undefined
  }
  return {
    athleteId: Number(row.athlete_id),
    athleteName: row.athlete_name,
    accessToken,
    refreshToken,
    expiresAt: new Date(row.expires_at).toISOString(),
    scope: row.scope,
    format: row.format,
    enabled: row.enabled,
  }
}

export async function freshLink(sql: Sql, env: StravaEnv & { dataKey: Buffer }, accountId: string): Promise<StravaLink | undefined> {
  const link = await readLink(sql, env.dataKey, accountId)
  if (link === undefined || new Date(link.expiresAt).getTime() - env.now().getTime() > STRAVA_REFRESH_MARGIN_MS) {
    return link
  }
  const refreshed = await tokenRequest(env, { grant_type: 'refresh_token', refresh_token: link.refreshToken })
  await updateTokens(sql, env.dataKey, accountId, refreshed)
  return { ...link, accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken, expiresAt: refreshed.expiresAt }
}

export async function setEnabled(sql: Sql, accountId: string, enabled: boolean): Promise<boolean> {
  const rows = await sql('update strava_links set enabled = $2, updated_at = now() where account_id = $1 returning account_id', [accountId, enabled])
  return rows.length > 0
}

export async function deleteLink(sql: Sql, accountId: string): Promise<void> {
  await sql('delete from strava_posts where account_id = $1', [accountId])
  await sql('delete from strava_links where account_id = $1', [accountId])
}

export async function deauthorize(fetcher: Fetcher, accessToken: string): Promise<void> {
  await fetcher(STRAVA_DEAUTHORIZE_URL, { method: 'POST', headers: { authorization: `Bearer ${accessToken}` } }).catch(() => undefined)
}

async function api(fetcher: Fetcher, accessToken: string, path: string, init: RequestInit = {}): Promise<unknown> {
  const response = await fetcher(`${STRAVA_API_BASE}${path}`, {
    ...init,
    headers: { ...(init.headers as Record<string, string> | undefined), authorization: `Bearer ${accessToken}`, accept: 'application/json' },
  })
  if (response.status === 429) {
    throw new StravaError('rate_limited')
  }
  if (response.status === 401 || response.status === 403) {
    throw new StravaError('unauthorized')
  }
  if (!response.ok) {
    throw new StravaError('unavailable')
  }
  return response.json().catch(() => ({}))
}

export async function findActivity(
  fetcher: Fetcher,
  accessToken: string,
  startTime: Date,
  distanceMeters: number,
): Promise<number | undefined> {
  const after = Math.floor((startTime.getTime() - STRAVA_MATCH_WINDOW_MS) / 1000)
  const before = Math.floor((startTime.getTime() + STRAVA_MATCH_WINDOW_MS) / 1000)
  const list = (await api(fetcher, accessToken, `/athlete/activities?after=${after}&before=${before}&per_page=30`)) as StravaSummary[]
  const matches = (Array.isArray(list) ? list : [])
    .filter((item) => (item.sport_type ?? item.type ?? '').endsWith('Run') && Math.abs(item.distance - distanceMeters) <= distanceMeters * STRAVA_DISTANCE_TOLERANCE)
    .map((item) => ({ id: item.id, gap: Math.abs(new Date(item.start_date).getTime() - startTime.getTime()) }))
    .sort((a, b) => a.gap - b.gap)
  return matches[0]?.id
}

export async function readDescription(fetcher: Fetcher, accessToken: string, stravaActivityId: number): Promise<string> {
  const detail = (await api(fetcher, accessToken, `/activities/${stravaActivityId}`)) as { description?: string | null }
  return detail.description ?? ''
}

export async function writeDescription(fetcher: Fetcher, accessToken: string, stravaActivityId: number, description: string): Promise<void> {
  await api(fetcher, accessToken, `/activities/${stravaActivityId}`, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ description }),
  })
}

export function textHash(text: string): string {
  return createHash('sha256').update(text.trim()).digest('hex')
}

export function findBlock(description: string): { start: number; end: number } | undefined {
  const marker = description.lastIndexOf(STRAVA_SIGNATURE)
  if (marker < 0) {
    return undefined
  }
  const separator = description.lastIndexOf('\n\n', marker)
  return { start: separator < 0 ? 0 : separator + 2, end: marker + STRAVA_SIGNATURE.length }
}

export async function postedHash(sql: Sql, accountId: string, stravaActivityId: number): Promise<string | undefined> {
  const rows = await sql<{ text_hash: string }>('select text_hash from strava_posts where account_id = $1 and strava_activity_id = $2', [
    accountId,
    stravaActivityId,
  ])
  return rows[0]?.text_hash
}

export async function recordPost(sql: Sql, accountId: string, activityId: string, stravaActivityId: number, hash: string, now: Date): Promise<void> {
  await sql(
    `insert into strava_posts (account_id, activity_id, strava_activity_id, posted_at, text_hash) values ($1, $2, $3, $4, $5)
     on conflict (account_id, strava_activity_id) do update set activity_id = excluded.activity_id, posted_at = excluded.posted_at, text_hash = excluded.text_hash`,
    [accountId, activityId, stravaActivityId, now.toISOString(), hash],
  )
}
