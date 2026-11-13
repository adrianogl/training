import { beforeEach, describe, expect, it } from 'vitest'
import { adminRoute, collectMetrics } from '../src/admin.js'
import type { Sql } from '../src/db.js'
import { createAccountRoute, pullChangesRoute, pushChangesRoute } from '../src/routes.js'
import { makeRequest, makeToken, migratedSql, record } from './helpers.js'

const adminToken = 'token-de-admin-bem-comprido-para-teste'
const DAY_MS = 24 * 60 * 60 * 1000

function adminRequest(options: { bearer?: string; cookie?: string; form?: string } = {}): Request {
  const headers = new Headers()
  if (options.bearer !== undefined) {
    headers.set('authorization', `Bearer ${options.bearer}`)
  }
  if (options.cookie !== undefined) {
    headers.set('cookie', options.cookie)
  }
  if (options.form !== undefined) {
    headers.set('content-type', 'application/x-www-form-urlencoded')
    return new Request('https://sync.test/admin', { method: 'POST', headers, body: options.form })
  }
  return new Request('https://sync.test/admin', { method: 'GET', headers })
}

function expectPrivateHeaders(response: Response): void {
  expect(response.headers.get('cache-control')).toBe('no-store')
  expect(response.headers.get('x-robots-tag')).toBe('noindex')
}

async function seed(sql: Sql): Promise<string> {
  const token = makeToken(1)
  await createAccountRoute(makeRequest('POST', '/api/v1/account', { token, ip: '1.1.1.1' }), sql, new Date())
  await pushChangesRoute(
    makeRequest('POST', '/api/v1/changes', {
      token,
      body: JSON.stringify({
        records: [
          record({ id: 'r1', payload: 'conteudo-cifrado' }),
          record({ id: 'r2', deleted: true, payload: null }),
          record({ id: 'r3' }),
          record({ kind: 'decision', id: 'd1' }),
        ],
      }),
    }),
    sql,
  )
  await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token }), sql)
  await pushChangesRoute(makeRequest('POST', '/api/v1/changes', { token, body: '{' }), sql)
  return token
}

describe('adminRoute', () => {
  let sql: Sql

  beforeEach(async () => {
    sql = await migratedSql()
  })

  it.each([undefined, '', 'x'.repeat(31)])('503 quando ADMIN_TOKEN é %j', async (configured) => {
    const response = await adminRoute(adminRequest({ bearer: adminToken }), sql, configured)

    expect(response.status).toBe(503)
    expectPrivateHeaders(response)
  })

  it('401 com formulário de login sem credencial', async () => {
    const response = await adminRoute(adminRequest(), sql, adminToken)

    expect(response.status).toBe(401)
    expectPrivateHeaders(response)
    expect(await response.text()).toContain('<form method="post"')
  })

  it.each([
    ['Bearer errado', { bearer: 'outro-token' }],
    ['Bearer prefixo do certo', { bearer: adminToken.slice(0, 10) }],
    ['cookie errado', { cookie: 'admin_session=abc' }],
    ['cookie com o token em claro', { cookie: `admin_session=${adminToken}` }],
  ])('401 com %s', async (_, options) => {
    const response = await adminRoute(adminRequest(options), sql, adminToken)

    expect(response.status).toBe(401)
  })

  it('login por formulário: token errado 401, certo 303 com cookie que abre o painel', async () => {
    const wrong = await adminRoute(adminRequest({ form: 'token=errado' }), sql, adminToken)
    const right = await adminRoute(adminRequest({ form: `token=${encodeURIComponent(adminToken)}` }), sql, adminToken)
    const setCookie = right.headers.get('set-cookie') ?? ''
    const cookie = setCookie.split(';')[0] ?? ''
    const panel = await adminRoute(adminRequest({ cookie: `outro=1; ${cookie}` }), sql, adminToken)

    expect(wrong.status).toBe(401)
    expect(await wrong.text()).toContain('Token inválido')
    expect(right.status).toBe(303)
    expect(right.headers.get('location')).toBe('/admin')
    expect(setCookie).toMatch(/^admin_session=\d+\.[A-Za-z0-9_-]+; /)
    expect(setCookie).toContain('HttpOnly')
    expect(setCookie).toContain('Secure')
    expect(setCookie).toContain('SameSite=Lax')
    expect(setCookie).not.toContain(adminToken)
    expectPrivateHeaders(right)
    expect(panel.status).toBe(200)
  })

  it('cookie de sessão deixa de valer quando o ADMIN_TOKEN muda', async () => {
    const login = await adminRoute(adminRequest({ form: `token=${adminToken}` }), sql, adminToken)
    const cookie = (login.headers.get('set-cookie') ?? '').split(';')[0] ?? ''

    const response = await adminRoute(adminRequest({ cookie }), sql, 'token-novo-depois-da-rotacao-com-32-chars')

    expect(response.status).toBe(401)
  })

  it('cookie de sessão vale 7 dias, checado no servidor', async () => {
    const issued = new Date('2026-11-12T12:00:00.000Z')
    const login = await adminRoute(adminRequest({ form: `token=${adminToken}` }), sql, adminToken, issued)
    const cookie = (login.headers.get('set-cookie') ?? '').split(';')[0] ?? ''
    const at = (offset: number) => adminRoute(adminRequest({ cookie }), sql, adminToken, new Date(issued.getTime() + offset))

    expect(cookie).toMatch(/^admin_session=\d+\.[A-Za-z0-9_-]+$/)
    expect((await at(7 * DAY_MS - 1000)).status).toBe(200)
    expect((await at(7 * DAY_MS + 1000)).status).toBe(401)
    expect((await at(-60 * 60 * 1000)).status).toBe(401)
  })

  it('timestamp do cookie adulterado invalida a sessão', async () => {
    const issued = new Date('2026-11-12T12:00:00.000Z')
    const login = await adminRoute(adminRequest({ form: `token=${adminToken}` }), sql, adminToken, issued)
    const [name, value] = ((login.headers.get('set-cookie') ?? '').split(';')[0] ?? '').split('=')
    const [, mac] = (value ?? '').split('.')
    const forged = `${name}=${Math.floor(issued.getTime() / 1000) + 6 * 24 * 3600}.${mac}`

    const response = await adminRoute(adminRequest({ cookie: forged }), sql, adminToken, new Date(issued.getTime() + 8 * DAY_MS))

    expect(response.status).toBe(401)
  })

  it('200 com Bearer certo e HTML com as métricas, sem payload nem conta completa', async () => {
    const token = await seed(sql)

    const response = await adminRoute(adminRequest({ bearer: adminToken }), sql, adminToken)
    const html = await response.text()

    expect(response.status).toBe(200)
    expect(response.headers.get('content-type')).toBe('text/html; charset=utf-8')
    expectPrivateHeaders(response)
    expect(html).toContain('Barlow Condensed')
    expect(html).toContain('#07080A')
    expect(html).not.toContain('<script')
    expect(html).toMatch(/Status<\/span><span class="num ok">OK<\/span>/)
    expect(html).toMatch(/Contas<\/span><span class="num">1<\/span>/)
    expect(html).toMatch(/Provas<\/span><span class="num">2<\/span><span class="sub">1 apagada<\/span>/)
    expect(html).toMatch(/Respostas<\/span><span class="num">1<\/span><span class="sub">0 apagadas<\/span>/)
    expect(html).toMatch(/seq \d+/)
    expect(html).toMatch(/Erros 24 h<\/span><span class="num err">1<\/span>/)
    expect(html).toContain('>400<')
    expect(html.match(/<span class="bar/g)).toHaveLength(24)
    expect(html).toContain('POST changes')
    expect(html).toContain('4 registros')
    expect(html).not.toContain('conteudo-cifrado')
    expect(html).not.toContain(token)
  })

  it('banco fora: 503 com status ERRO', async () => {
    const broken = Object.assign(
      async () => {
        throw new Error('sem conexão')
      },
      { transaction: async () => [] },
    ) as unknown as Sql

    const response = await adminRoute(adminRequest({ bearer: adminToken }), broken, adminToken)

    expect(response.status).toBe(503)
    expectPrivateHeaders(response)
    expect(await response.text()).toContain('ERRO')
  })
})

describe('collectMetrics', () => {
  it('conta registros, última escrita, erros e requisições por hora', async () => {
    const sql = await migratedSql()
    await seed(sql)

    const metrics = await collectMetrics(sql, new Date())

    expect(metrics.database.latencyMs).toBeGreaterThanOrEqual(0)
    expect(metrics.accounts).toBe(1)
    expect(metrics.records).toEqual({ race: { live: 2, deleted: 1 }, decision: { live: 1, deleted: 0 } })
    expect(metrics.lastWrite.seq).toBeGreaterThan(0)
    expect(metrics.lastWrite.at).not.toBeNull()
    expect(metrics.errors24h).toBe(1)
    expect(metrics.hourly).toHaveLength(24)
    expect(metrics.hourly.reduce((sum, bucket) => sum + bucket.total, 0)).toBe(4)
    expect(metrics.hourly.at(-1)?.total).toBe(4)
    expect(metrics.recent.map((entry) => `${entry.method} ${entry.route} ${entry.status}`)).toEqual([
      'POST changes 400',
      'GET changes 200',
      'POST changes 200',
      'POST account 201',
    ])
  })

  it('mostra no máximo 20 requisições recentes', async () => {
    const sql = await migratedSql()
    await sql(
      "insert into request_log (method, route, status) select 'GET', 'changes', 200 from generate_series(1, 25)",
    )

    const metrics = await collectMetrics(sql, new Date())

    expect(metrics.recent).toHaveLength(20)
  })
})
