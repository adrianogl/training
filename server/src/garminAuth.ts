import {
  GARMIN_CLIENT_IDS,
  GARMIN_DEFAULT_MFA_METHOD,
  GARMIN_INVALID_CREDENTIALS_STATUS,
  GARMIN_LOCALE,
  GARMIN_LOGIN_URL,
  GARMIN_LOGIN_USER_AGENT,
  GARMIN_MFA_STATUS,
  GARMIN_MFA_URL,
  GARMIN_NATIVE_HEADERS,
  GARMIN_REFRESH_GRANT,
  GARMIN_SERVICE_TICKET_GRANT,
  GARMIN_SERVICE_URL,
  GARMIN_SSO_CLIENT_ID,
  GARMIN_SSO_ORIGIN,
  GARMIN_SUCCESS_STATUS,
  GARMIN_TOKEN_URL,
} from './constants.js'
import { GarminError } from './garminError.js'
import type { Fetcher, GarminLoginOutcome, GarminPendingLogin, GarminSession } from './types.js'

interface SSOResponse {
  responseStatus?: { type?: string }
  serviceTicketId?: string
  customerMfaInfo?: { mfaLastMethodUsed?: string }
}

interface TokenResponse {
  access_token?: string
  refresh_token?: string
}

function ssoUrl(base: string): string {
  const url = new URL(base)
  url.searchParams.set('clientId', GARMIN_SSO_CLIENT_ID)
  url.searchParams.set('locale', GARMIN_LOCALE)
  url.searchParams.set('service', GARMIN_SERVICE_URL)
  return url.toString()
}

function cookiePairs(response: Response): string[] {
  return response.headers.getSetCookie().map((cookie) => cookie.split(';')[0] ?? '').filter((pair) => pair.includes('='))
}

export function jwtClaims(token: string): { expiresAt: string | undefined; clientId: string | undefined } {
  const payload = token.split('.')[1]
  if (payload === undefined) {
    return { expiresAt: undefined, clientId: undefined }
  }
  try {
    const json = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as { exp?: number; client_id?: string }
    return {
      expiresAt: typeof json.exp === 'number' ? new Date(json.exp * 1000).toISOString() : undefined,
      clientId: typeof json.client_id === 'string' ? json.client_id : undefined,
    }
  } catch {
    return { expiresAt: undefined, clientId: undefined }
  }
}

async function ssoPost(fetcher: Fetcher, url: string, body: unknown, cookies: string[]): Promise<{ data: SSOResponse; cookies: string[] }> {
  const headers: Record<string, string> = {
    'user-agent': GARMIN_LOGIN_USER_AGENT,
    accept: 'application/json, text/plain, */*',
    'content-type': 'application/json',
    origin: GARMIN_SSO_ORIGIN,
  }
  if (cookies.length > 0) {
    headers.cookie = cookies.join('; ')
  }
  const response = await fetcher(ssoUrl(url), { method: 'POST', headers, body: JSON.stringify(body) })
  if (response.status === 429) {
    throw new GarminError('rate_limited')
  }
  const data = (await response.json().catch(() => undefined)) as SSOResponse | undefined
  if (data === undefined) {
    throw new GarminError('unexpected_response')
  }
  return { data, cookies: [...cookies, ...cookiePairs(response)] }
}

async function tokenRequest(fetcher: Fetcher, clientId: string, form: Record<string, string>): Promise<Response> {
  const body = new URLSearchParams(Object.entries(form).sort(([a], [b]) => a.localeCompare(b))).toString()
  return fetcher(GARMIN_TOKEN_URL, {
    method: 'POST',
    headers: {
      ...GARMIN_NATIVE_HEADERS,
      authorization: `Basic ${Buffer.from(`${clientId}:`).toString('base64')}`,
      accept: 'application/json',
      'content-type': 'application/x-www-form-urlencoded',
      'cache-control': 'no-cache',
    },
    body,
  })
}

function sessionFrom(token: TokenResponse, fallbackClientId: string, previousRefresh: string | null): GarminSession {
  if (token.access_token === undefined) {
    throw new GarminError('exchange_failed')
  }
  const claims = jwtClaims(token.access_token)
  if (claims.expiresAt === undefined) {
    throw new GarminError('exchange_failed')
  }
  return {
    accessToken: token.access_token,
    refreshToken: token.refresh_token ?? previousRefresh,
    clientId: claims.clientId ?? fallbackClientId,
    expiresAt: claims.expiresAt,
  }
}

async function exchange(fetcher: Fetcher, ticket: string): Promise<GarminSession> {
  for (const clientId of GARMIN_CLIENT_IDS) {
    const response = await tokenRequest(fetcher, clientId, {
      client_id: clientId,
      service_ticket: ticket,
      grant_type: GARMIN_SERVICE_TICKET_GRANT,
      service_url: GARMIN_SERVICE_URL,
    })
    if (response.status === 429) {
      throw new GarminError('rate_limited')
    }
    if (!response.ok) {
      continue
    }
    const token = (await response.json().catch(() => undefined)) as TokenResponse | undefined
    if (token?.access_token !== undefined) {
      return sessionFrom(token, clientId, null)
    }
  }
  throw new GarminError('exchange_failed')
}

export async function garminSignIn(fetcher: Fetcher, email: string, password: string): Promise<GarminLoginOutcome> {
  const { data, cookies } = await ssoPost(fetcher, GARMIN_LOGIN_URL, { username: email, password, rememberMe: true, captchaToken: '' }, [])
  switch (data.responseStatus?.type) {
    case GARMIN_SUCCESS_STATUS:
      if (data.serviceTicketId === undefined) {
        throw new GarminError('exchange_failed')
      }
      return { status: 'signed_in', session: await exchange(fetcher, data.serviceTicketId) }
    case GARMIN_MFA_STATUS:
      return {
        status: 'needs_code',
        pending: { method: data.customerMfaInfo?.mfaLastMethodUsed ?? GARMIN_DEFAULT_MFA_METHOD, cookies },
      }
    case GARMIN_INVALID_CREDENTIALS_STATUS:
      throw new GarminError('invalid_credentials')
    default:
      throw new GarminError('unexpected_response')
  }
}

export async function garminVerify(fetcher: Fetcher, code: string, pending: GarminPendingLogin): Promise<GarminSession> {
  const { data } = await ssoPost(
    fetcher,
    GARMIN_MFA_URL,
    { mfaMethod: pending.method, mfaVerificationCode: code, rememberMyBrowser: true, reconsentList: [], mfaSetup: false },
    pending.cookies,
  )
  if (data.responseStatus?.type !== GARMIN_SUCCESS_STATUS || data.serviceTicketId === undefined) {
    throw new GarminError('invalid_code')
  }
  return exchange(fetcher, data.serviceTicketId)
}

export async function garminRefresh(fetcher: Fetcher, session: GarminSession): Promise<GarminSession> {
  if (session.refreshToken === null) {
    throw new GarminError('session_expired')
  }
  const response = await tokenRequest(fetcher, session.clientId, {
    grant_type: GARMIN_REFRESH_GRANT,
    client_id: session.clientId,
    refresh_token: session.refreshToken,
  })
  if (response.status === 429) {
    throw new GarminError('rate_limited')
  }
  if (!response.ok) {
    throw new GarminError('session_expired')
  }
  return sessionFrom((await response.json()) as TokenResponse, session.clientId, session.refreshToken)
}
