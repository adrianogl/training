import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import { open } from '../src/cipher.js'
import type { Sql } from '../src/db.js'
import { signState } from '../src/strava.js'
import { stravaCallbackRoute, stravaConnectRoute, stravaDescribeRoute, stravaStatusRoute } from '../src/stravaRoutes.js'
import { createAccountRoute } from '../src/routes.js'
import { accountIdFromAuthorization } from '../src/auth.js'
import type { StravaEnv } from '../src/types.js'
import { makeRequest, makeToken, migratedSql } from './helpers.js'

const token = makeToken(7)
const key = randomBytes(32)
const accountId = accountIdFromAuthorization(`Bearer ${token}`) ?? ''
const startTime = '2026-11-14T09:00:00.000Z'
const blockOne = 'VO2 máx | 5 × 1 km @ 3:48/km · nota 88\nvia https://training.aglv.dev'
const blockTwo = 'VO2 máx | 5 × 1 km @ 3:45/km · nota 90\nvia https://training.aglv.dev'
const legacyBlock = 'VO2 máx | 5 × 1 km @ 3:48/km · nota 88\nvia training.aglv.dev'

interface Fake {
  calls: { url: string; method: string; body: string }[]
  description: string | null
  runs: { id: number; distance: number; type: string; start_date: string }[]
  tokenExpiresAt: number
  status: Record<string, number>
}

function stravaFake(): { fake: Fake; fetcher: typeof fetch } {
  const fake: Fake = {
    calls: [],
    description: null,
    runs: [{ id: 99, distance: 10050, type: 'Run', start_date: startTime }],
    tokenExpiresAt: 1_900_000_000,
    status: {},
  }
  const fetcher = (async (input: string | URL | Request, init: RequestInit = {}) => {
    const url = String(input)
    const method = init.method ?? 'GET'
    fake.calls.push({ url, method, body: String(init.body ?? '') })
    const forced = fake.status[`${method} ${new URL(url).pathname}`]
    if (forced !== undefined) {
      return new Response('{}', { status: forced })
    }
    if (url.endsWith('/oauth/token')) {
      const form = new URLSearchParams(String(init.body))
      const refreshed = form.get('grant_type') === 'refresh_token'
      return Response.json({
        access_token: refreshed ? 'acesso-novo' : 'acesso-1',
        refresh_token: refreshed ? 'renovar-novo' : 'renovar-1',
        expires_at: fake.tokenExpiresAt,
        athlete: { id: 4242, firstname: 'Adriano', lastname: 'G' },
      })
    }
    if (url.endsWith('/oauth/deauthorize')) {
      return Response.json({})
    }
    if (url.includes('/athlete/activities')) {
      return Response.json(fake.runs.map((run) => ({ ...run, sport_type: run.type })))
    }
    if (method === 'PUT') {
      fake.description = (JSON.parse(String(init.body)) as { description: string }).description
      return Response.json({})
    }
    return Response.json({ id: 99, description: fake.description })
  }) as typeof fetch
  return { fake, fetcher }
}

let sql: Sql
let now: Date

function env(fetcher: typeof fetch, overrides: Partial<StravaEnv> = {}): StravaEnv {
  return { dataKey: key, fetcher, now: () => now, clientId: 'cid', clientSecret: 'csecret', ...overrides }
}

function callback(state: string, extra = 'code=abc&scope=read,activity:read_all,activity:write'): Request {
  return makeRequest('GET', `/api/v1/strava/callback?state=${encodeURIComponent(state)}&${extra}`)
}

async function connect(fetcher: typeof fetch): Promise<void> {
  await stravaCallbackRoute(callback(signState(key, accountId, now)), sql, env(fetcher))
}

function describe_(fetcher: typeof fetch, text = blockOne, extra: Record<string, unknown> = {}): Promise<Response> {
  const body = { activityId: 'a1', startTime, elapsedSeconds: 2700, distanceMeters: 10000, text, ...extra }
  return stravaDescribeRoute(makeRequest('POST', '/api/v1/strava/describe', { token, body: JSON.stringify(body) }), sql, env(fetcher))
}

beforeEach(async () => {
  sql = await migratedSql()
  now = new Date('2026-11-14T12:00:00.000Z')
  await createAccountRoute(makeRequest('POST', '/api/v1/account', { token }), sql)
})

describe('conectar ao Strava', () => {
  it('sem env responde 503', async () => {
    const { fetcher } = stravaFake()

    const response = await stravaConnectRoute(makeRequest('GET', '/api/v1/strava/connect', { token }), sql, env(fetcher, { clientId: undefined }))

    expect(response.status).toBe(503)
    expect(await response.json()).toEqual({ error: 'strava_not_configured' })
  })

  it('connect devolve a URL de autorização com escopos, redirect e state assinado', async () => {
    const { fetcher } = stravaFake()

    const response = await stravaConnectRoute(makeRequest('GET', '/api/v1/strava/connect', { token }), sql, env(fetcher))
    const url = new URL(((await response.json()) as { url: string }).url)

    expect(url.origin + url.pathname).toBe('https://www.strava.com/oauth/authorize')
    expect(url.searchParams.get('scope')).toBe('activity:read_all,activity:write')
    expect(url.searchParams.get('redirect_uri')).toBe('https://training.aglv.dev/api/v1/strava/callback')
    expect(url.searchParams.get('approval_prompt')).toBe('auto')
    expect(url.searchParams.get('state')).toContain('.')
  })

  it('connect sem sessão responde 401', async () => {
    const { fetcher } = stravaFake()

    const response = await stravaConnectRoute(makeRequest('GET', '/api/v1/strava/connect'), sql, env(fetcher))

    expect(response.status).toBe(401)
  })

  it('callback com state válido troca o code, cifra os tokens e volta ao app', async () => {
    const { fake, fetcher } = stravaFake()

    const response = await stravaCallbackRoute(callback(signState(key, accountId, now)), sql, env(fetcher))
    const rows = await sql<{ access_token_enc: string; refresh_token_enc: string; athlete_name: string }>('select * from strava_links')

    expect(response.headers.get('location')).toBe('training://strava?connected=1')
    expect(fake.calls[0]?.body).toContain('code=abc')
    expect(rows[0]?.athlete_name).toBe('Adriano G')
    expect(rows[0]?.access_token_enc).not.toContain('acesso-1')
    expect(rows[0]?.refresh_token_enc).not.toContain('renovar-1')
    expect(open(key, rows[0]?.access_token_enc ?? '', `strava-access:${accountId}`)).toBe('acesso-1')
    expect(open(key, rows[0]?.refresh_token_enc ?? '', `strava-refresh:${accountId}`)).toBe('renovar-1')
  })

  it('callback com state expirado, adulterado ou escopo faltando volta com erro e não grava', async () => {
    const { fetcher } = stravaFake()
    const state = signState(key, accountId, now)
    const later = new Date(now.getTime() + 11 * 60 * 1000)

    const expired = await stravaCallbackRoute(callback(state), sql, { ...env(fetcher), now: () => later })
    const forged = await stravaCallbackRoute(callback(`${state}x`), sql, env(fetcher))
    const scope = await stravaCallbackRoute(callback(state, 'code=abc&scope=read'), sql, env(fetcher))
    const denied = await stravaCallbackRoute(callback(state, 'error=access_denied'), sql, env(fetcher))

    expect(expired.headers.get('location')).toBe('training://strava?error=invalid_state')
    expect(forged.headers.get('location')).toBe('training://strava?error=invalid_state')
    expect(scope.headers.get('location')).toBe('training://strava?error=scope')
    expect(denied.headers.get('location')).toBe('training://strava?error=access_denied')
    expect(await sql('select 1 from strava_links')).toEqual([])
  })
})

describe('status, liga/desliga e desconectar', () => {
  it('lê o status, desliga e desconecta apagando tudo', async () => {
    const { fake, fetcher } = stravaFake()
    await connect(fetcher)

    const status = await stravaStatusRoute(makeRequest('GET', '/api/v1/strava', { token }), sql, env(fetcher))
    const off = await stravaStatusRoute(makeRequest('PATCH', '/api/v1/strava', { token, body: JSON.stringify({ enabled: false }) }), sql, env(fetcher))
    const removed = await stravaStatusRoute(makeRequest('DELETE', '/api/v1/strava', { token }), sql, env(fetcher))
    const after = await stravaStatusRoute(makeRequest('GET', '/api/v1/strava', { token }), sql, env(fetcher))

    expect(await status.json()).toMatchObject({ connected: true, athleteName: 'Adriano G', format: 'B', enabled: true })
    expect(await off.json()).toMatchObject({ enabled: false })
    expect(removed.status).toBe(204)
    expect(fake.calls.some((call) => call.url.endsWith('/oauth/deauthorize'))).toBe(true)
    expect(await sql('select 1 from strava_links')).toEqual([])
    expect(((await after.json()) as { connected: boolean }).connected).toBe(false)
  })
})

describe('renovar o token', () => {
  it('renova antes de expirar e guarda os tokens novos cifrados', async () => {
    const { fake, fetcher } = stravaFake()
    fake.tokenExpiresAt = Math.floor(now.getTime() / 1000) + 60
    await connect(fetcher)

    await describe_(fetcher)
    const refresh = fake.calls.find((call) => call.body.includes('grant_type=refresh_token'))
    const rows = await sql<{ access_token_enc: string }>('select access_token_enc from strava_links')

    expect(refresh?.body).toContain('refresh_token=renovar-1')
    expect(open(key, rows[0]?.access_token_enc ?? '', `strava-access:${accountId}`)).toBe('acesso-novo')
  })

  it('não renova com o token longe de expirar', async () => {
    const { fake, fetcher } = stravaFake()
    await connect(fetcher)

    await describe_(fetcher)

    expect(fake.calls.some((call) => call.body.includes('grant_type=refresh_token'))).toBe(false)
  })
})

describe('escrever o resumo', () => {
  it('anexa o bloco ao fim da descrição existente com linha em branco', async () => {
    const { fake, fetcher } = stravaFake()
    fake.description = 'Treino leve com a turma'
    await connect(fetcher)

    const response = await describe_(fetcher)

    expect(await response.json()).toEqual({ status: 'posted', stravaActivityId: 99 })
    expect(fake.description).toBe(`Treino leve com a turma\n\n${blockOne}`)
    expect(await sql('select * from strava_posts')).toHaveLength(1)
  })

  it('escreve direto quando a descrição está vazia', async () => {
    const { fake, fetcher } = stravaFake()
    await connect(fetcher)

    await describe_(fetcher)

    expect(fake.description).toBe(blockOne)
  })

  it('substitui só o bloco do trAIning quando ninguém editou', async () => {
    const { fake, fetcher } = stravaFake()
    fake.description = 'Treino leve'
    await connect(fetcher)
    await describe_(fetcher)
    fake.description = `${fake.description}\n\nobrigado, pessoal`

    const response = await describe_(fetcher, blockTwo)

    expect(await response.json()).toEqual({ status: 'updated', stravaActivityId: 99 })
    expect(fake.description).toBe(`Treino leve\n\n${blockTwo}\n\nobrigado, pessoal`)
  })

  it('troca o bloco antigo, sem link, pelo novo com link', async () => {
    const { fake, fetcher } = stravaFake()
    fake.description = 'Treino leve'
    await connect(fetcher)
    await describe_(fetcher, legacyBlock)
    fake.description = `${fake.description}\n\nobrigado, pessoal`

    const response = await describe_(fetcher, blockTwo)

    expect(await response.json()).toEqual({ status: 'updated', stravaActivityId: 99 })
    expect(fake.description).toBe(`Treino leve\n\n${blockTwo}\n\nobrigado, pessoal`)
  })

  it('não mexe quando o usuário editou o bloco', async () => {
    const { fake, fetcher } = stravaFake()
    await connect(fetcher)
    await describe_(fetcher)
    const edited = blockOne.replace('88', '99')
    fake.description = edited

    const response = await describe_(fetcher, blockTwo)

    expect(await response.json()).toEqual({ status: 'edited_by_user', stravaActivityId: 99 })
    expect(fake.description).toBe(edited)
  })

  it('reenviar o mesmo texto não escreve de novo', async () => {
    const { fake, fetcher } = stravaFake()
    await connect(fetcher)
    await describe_(fetcher)
    const before = fake.calls.filter((call) => call.method === 'PUT').length

    const response = await describe_(fetcher)

    expect(((await response.json()) as { status: string }).status).toBe('updated')
    expect(fake.calls.filter((call) => call.method === 'PUT')).toHaveLength(before)
  })

  it('responde not_found quando a atividade não chegou ou não bate com a distância e o tipo', async () => {
    const { fake, fetcher } = stravaFake()
    await connect(fetcher)
    fake.runs = [
      { id: 1, distance: 5000, type: 'Run', start_date: startTime },
      { id: 2, distance: 10000, type: 'Ride', start_date: startTime },
    ]

    const far = await describe_(fetcher)
    fake.runs = []
    const empty = await describe_(fetcher)

    expect(await far.json()).toEqual({ status: 'not_found' })
    expect(await empty.json()).toEqual({ status: 'not_found' })
  })

  it('consulta a janela de 15 minutos em volta do início', async () => {
    const { fake, fetcher } = stravaFake()
    await connect(fetcher)

    await describe_(fetcher)
    const list = new URL(fake.calls.find((call) => call.url.includes('/athlete/activities'))?.url ?? '')
    const start = Date.parse(startTime) / 1000

    expect(Number(list.searchParams.get('after'))).toBe(start - 900)
    expect(Number(list.searchParams.get('before'))).toBe(start + 900)
  })

  it('429 vira retry_later, desligado vira disabled e body inválido 400', async () => {
    const { fake, fetcher } = stravaFake()
    await connect(fetcher)
    fake.status['GET /api/v3/athlete/activities'] = 429

    const limited = await describe_(fetcher)
    const invalid = await describe_(fetcher, 'sem assinatura')
    await stravaStatusRoute(makeRequest('PATCH', '/api/v1/strava', { token, body: JSON.stringify({ enabled: false }) }), sql, env(fetcher))
    const disabled = await describe_(fetcher)

    expect(await limited.json()).toEqual({ status: 'retry_later' })
    expect(invalid.status).toBe(400)
    expect(await disabled.json()).toEqual({ status: 'disabled' })
  })
})
