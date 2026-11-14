import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import { open, seal } from '../src/cipher.js'
import type { Sql } from '../src/db.js'
import { garminConnectRoute, garminSessionRoute, garminStatusRoute, garminVerifyRoute } from '../src/garminRoutes.js'
import { createAccountRoute } from '../src/routes.js'
import type { GarminEnv } from '../src/types.js'
import { makeRequest, makeToken, migratedSql } from './helpers.js'

const token = makeToken(5)
const key = randomBytes(32)

function jwt(exp: number, clientId = 'GARMIN_CONNECT_MOBILE_ANDROID_DI_2025Q2'): string {
  const part = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url')
  return `${part({ alg: 'none' })}.${part({ exp, client_id: clientId })}.assinatura`
}

interface Call {
  url: string
  init: RequestInit
}

function garminFake(script: { login: unknown; mfa?: unknown; tokenExp: number; refreshExp?: number }) {
  const calls: Call[] = []
  const fetcher = (async (input: string | URL | Request, init: RequestInit = {}) => {
    const url = String(input)
    calls.push({ url, init })
    if (url.startsWith('https://sso.garmin.com/mobile/api/login')) {
      return new Response(JSON.stringify(script.login), { headers: [['set-cookie', 'SESSION=abc; Path=/; HttpOnly'], ['set-cookie', 'GARMIN-SSO=1; Path=/']] })
    }
    if (url.startsWith('https://sso.garmin.com/mobile/api/mfa/verifyCode')) {
      return new Response(JSON.stringify(script.mfa))
    }
    const form = new URLSearchParams(String(init.body))
    const exp = form.get('grant_type') === 'refresh_token' ? (script.refreshExp ?? script.tokenExp) : script.tokenExp
    return new Response(JSON.stringify({ access_token: jwt(exp), refresh_token: 'renovar' }))
  }) as typeof fetch
  return { calls, fetcher }
}

let sql: Sql
let now: Date

function env(fetcher: typeof fetch, withKey = true): GarminEnv {
  return { dataKey: withKey ? key : undefined, fetcher, now: () => now }
}

function post(path: string, body: unknown): Request {
  return makeRequest('POST', path, { token, body: JSON.stringify(body) })
}

beforeEach(async () => {
  sql = await migratedSql()
  now = new Date('2026-11-14T12:00:00.000Z')
  await createAccountRoute(makeRequest('POST', '/api/v1/account', { token }), sql)
})

describe('cifra', () => {
  it('abre só com a mesma chave e o mesmo contexto', () => {
    const sealed = seal(key, 'segredo', 'garmin-session:a')

    expect(open(key, sealed, 'garmin-session:a')).toBe('segredo')
    expect(open(key, sealed, 'garmin-session:b')).toBeUndefined()
    expect(open(randomBytes(32), sealed, 'garmin-session:a')).toBeUndefined()
    expect(sealed).not.toContain('segredo')
  })
})

describe('conectar a Garmin', () => {
  it('login com código: guarda os cookies, manda no segundo passo e salva a sessão cifrada', async () => {
    const exp = Math.floor(now.getTime() / 1000) + 3600
    const garmin = garminFake({
      login: { responseStatus: { type: 'MFA_REQUIRED' }, customerMfaInfo: { mfaLastMethodUsed: 'email' } },
      mfa: { responseStatus: { type: 'SUCCESSFUL' }, serviceTicketId: 'ST-1' },
      tokenExp: exp,
    })

    const first = await garminConnectRoute(post('/api/v1/garmin/connect', { email: 'atleta@exemplo.com', password: 'senha' }), sql, env(garmin.fetcher))
    const second = await garminVerifyRoute(post('/api/v1/garmin/verify', { code: '123456' }), sql, env(garmin.fetcher))
    const stored = await sql<{ session_enc: string }>('select session_enc from garmin_connections')
    const mfaCall = garmin.calls.find((call) => call.url.includes('verifyCode'))

    expect(await first.json()).toEqual({ status: 'needs_code', method: 'email' })
    expect(await second.json()).toEqual({ status: 'connected' })
    expect((mfaCall?.init.headers as Record<string, string>).cookie).toBe('SESSION=abc; GARMIN-SSO=1')
    expect(stored[0]?.session_enc).not.toContain('renovar')
    expect(await sql('select * from garmin_pending_logins')).toEqual([])
  })

  it('login sem código conecta direto', async () => {
    const garmin = garminFake({ login: { responseStatus: { type: 'SUCCESSFUL' }, serviceTicketId: 'ST-2' }, tokenExp: 2_000_000_000 })

    const response = await garminConnectRoute(post('/api/v1/garmin/connect', { email: 'a@b.com', password: 'x' }), sql, env(garmin.fetcher))
    const status = await garminStatusRoute(makeRequest('GET', '/api/v1/garmin/status', { token }), sql, env(garmin.fetcher))

    expect(await response.json()).toEqual({ status: 'connected' })
    expect(((await status.json()) as { connected: boolean }).connected).toBe(true)
  })

  it('senha errada e código errado viram erros próprios', async () => {
    const wrong = garminFake({ login: { responseStatus: { type: 'INVALID_USERNAME_PASSWORD' } }, tokenExp: 0 })
    const badCode = garminFake({
      login: { responseStatus: { type: 'MFA_REQUIRED' } },
      mfa: { responseStatus: { type: 'INVALID_MFA_CODE' } },
      tokenExp: 0,
    })

    const login = await garminConnectRoute(post('/api/v1/garmin/connect', { email: 'a@b.com', password: 'x' }), sql, env(wrong.fetcher))
    await garminConnectRoute(post('/api/v1/garmin/connect', { email: 'a@b.com', password: 'x' }), sql, env(badCode.fetcher))
    const code = await garminVerifyRoute(post('/api/v1/garmin/verify', { code: '000000' }), sql, env(badCode.fetcher))

    expect(await login.json()).toEqual({ error: 'garmin_invalid_credentials' })
    expect(await code.json()).toEqual({ error: 'garmin_invalid_code' })
  })

  it('código depois de 10 minutos pede login de novo', async () => {
    const garmin = garminFake({ login: { responseStatus: { type: 'MFA_REQUIRED' } }, tokenExp: 0 })
    await garminConnectRoute(post('/api/v1/garmin/connect', { email: 'a@b.com', password: 'x' }), sql, env(garmin.fetcher))
    now = new Date(now.getTime() + 11 * 60 * 1000)

    const response = await garminVerifyRoute(post('/api/v1/garmin/verify', { code: '123456' }), sql, env(garmin.fetcher))

    expect(response.status).toBe(409)
    expect(await response.json()).toEqual({ error: 'garmin_login_expired' })
  })

  it('sem DATA_KEY o servidor não aceita conectar', async () => {
    const garmin = garminFake({ login: {}, tokenExp: 0 })

    const response = await garminConnectRoute(post('/api/v1/garmin/connect', { email: 'a@b.com', password: 'x' }), sql, env(garmin.fetcher, false))

    expect(response.status).toBe(503)
    expect(garmin.calls).toHaveLength(0)
  })
})

describe('sessão para o app', () => {
  it('entrega a sessão e renova quando falta menos de 15 minutos', async () => {
    const soon = Math.floor(now.getTime() / 1000) + 600
    const later = Math.floor(now.getTime() / 1000) + 3600
    const garmin = garminFake({ login: { responseStatus: { type: 'SUCCESSFUL' }, serviceTicketId: 'ST-3' }, tokenExp: soon, refreshExp: later })
    await garminConnectRoute(post('/api/v1/garmin/connect', { email: 'a@b.com', password: 'x' }), sql, env(garmin.fetcher))

    const response = await garminSessionRoute(makeRequest('GET', '/api/v1/garmin/session', { token }), sql, env(garmin.fetcher))
    const session = (await response.json()) as { expiresAt: string; refreshToken: string }

    expect(session.expiresAt).toBe(new Date(later * 1000).toISOString())
    expect(session.refreshToken).toBe('renovar')
    expect(garmin.calls.filter((call) => String(call.init.body).includes('grant_type=refresh_token'))).toHaveLength(1)
  })

  it('desconectar apaga a sessão', async () => {
    const garmin = garminFake({ login: { responseStatus: { type: 'SUCCESSFUL' }, serviceTicketId: 'ST-4' }, tokenExp: 2_000_000_000 })
    await garminConnectRoute(post('/api/v1/garmin/connect', { email: 'a@b.com', password: 'x' }), sql, env(garmin.fetcher))

    await garminStatusRoute(makeRequest('DELETE', '/api/v1/garmin/status', { token }), sql, env(garmin.fetcher))
    const session = await garminSessionRoute(makeRequest('GET', '/api/v1/garmin/session', { token }), sql, env(garmin.fetcher))

    expect(session.status).toBe(404)
  })

  it('sem conta, 401', async () => {
    const garmin = garminFake({ login: {}, tokenExp: 0 })

    const response = await garminSessionRoute(makeRequest('GET', '/api/v1/garmin/session', { token: makeToken(99) }), sql, env(garmin.fetcher))

    expect(response.status).toBe(401)
  })
})
