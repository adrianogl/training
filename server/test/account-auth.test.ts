import { beforeEach, describe, expect, it } from 'vitest'
import {
  changePasswordRoute,
  forgotPasswordRoute,
  loginRoute,
  logoutRoute,
  meRoute,
  resendVerificationRoute,
  resetPasswordRoute,
  sessionsRoute,
  signupRoute,
  verifyEmailRoute,
} from '../src/authRoutes.js'
import type { Sql } from '../src/db.js'
import { createAccountRoute, deleteAccountRoute, pullChangesRoute } from '../src/routes.js'
import type { AuthEnv, Mail } from '../src/types.js'
import { makeRequest, makeToken, migratedSql } from './helpers.js'

const password = 'corrida-longa-42'

let sql: Sql
let sent: Mail[]
let now: Date
let env: AuthEnv

function body(value: unknown, token?: string, ip = '203.0.113.7'): { body: string; token?: string; ip: string } {
  return token === undefined ? { body: JSON.stringify(value), ip } : { body: JSON.stringify(value), token, ip }
}

async function signup(email = 'atleta@exemplo.com', extra: Record<string, unknown> = {}): Promise<Response> {
  return signupRoute(
    makeRequest('POST', '/api/v1/auth/signup', body({ name: 'Atleta', email, password, device: 'iPhone', ...extra })),
    sql,
    env,
  )
}

async function signedUp(email = 'atleta@exemplo.com'): Promise<string> {
  return ((await (await signup(email)).json()) as { token: string }).token
}

function linkToken(mail: Mail | undefined): string {
  const match = /token=([A-Za-z0-9_-]+)/.exec(mail?.text ?? '')
  if (match?.[1] === undefined) {
    throw new Error('sem link no e-mail')
  }
  return match[1]
}

beforeEach(async () => {
  sql = await migratedSql()
  sent = []
  now = new Date('2026-11-14T12:00:00.000Z')
  env = { mailer: { send: async (mail) => void sent.push(mail) }, appUrl: 'https://site.test', now: () => now, maxAccounts: 3 }
})

describe('cadastro e login', () => {
  it('cadastra, devolve sessão que vale nas rotas de sync e manda o e-mail de confirmação', async () => {
    const response = await signup()
    const created = (await response.json()) as { token: string; user: unknown }

    const pull = await pullChangesRoute(makeRequest('GET', '/api/v1/changes?since=0', { token: created.token }), sql)

    expect(response.status).toBe(201)
    expect(created.user).toEqual({ email: 'atleta@exemplo.com', name: 'Atleta', emailVerified: false })
    expect(pull.status).toBe(200)
    expect(sent.map((mail) => mail.to)).toEqual(['atleta@exemplo.com'])
    expect(sent[0]?.text).toContain('https://site.test/confirmar?token=')
    expect(JSON.stringify(await sql('select password_hash from users'))).not.toContain(password)
  })

  it('recusa e-mail repetido sem diferenciar maiúsculas', async () => {
    await signup()

    const again = await signup('ATLETA@exemplo.com')

    expect(again.status).toBe(409)
    expect(await again.json()).toEqual({ error: 'email_taken' })
  })

  it.each([
    ['senha curta', { password: 'curta' }, 'invalid_password'],
    ['e-mail inválido', { email: 'sem-arroba' }, 'invalid_email'],
    ['sem nome', { name: ' ' }, 'invalid_name'],
    ['chave antiga malformada', { legacyKey: 'curta' }, 'invalid_legacy_key'],
  ])('400 no cadastro: %s', async (_name, override, error) => {
    const response = await signupRoute(
      makeRequest('POST', '/api/v1/auth/signup', body({ name: 'Atleta', email: 'a@exemplo.com', password, device: 'iPhone', ...override })),
      sql,
      env,
    )

    expect(response.status).toBe(400)
    expect(await response.json()).toEqual({ error })
  })

  it('liga a conta da chave antiga e mantém os registros dela', async () => {
    const legacyKey = makeToken(7)
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: legacyKey }), sql)

    const response = await signup('antigo@exemplo.com', { legacyKey })
    const accounts = await sql<{ count: number }>('select count(*)::int as count from accounts')
    const second = await signup('outro@exemplo.com', { legacyKey })

    expect(response.status).toBe(201)
    expect(accounts[0]?.count).toBe(1)
    expect(second.status).toBe(409)
    expect(await second.json()).toEqual({ error: 'legacy_unavailable' })
  })

  it('a chave antiga continua valendo enquanto o app não migra', async () => {
    const legacyKey = makeToken(9)
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: legacyKey }), sql)

    const pull = await pullChangesRoute(makeRequest('GET', '/api/v1/changes?since=0', { token: legacyKey }), sql)

    expect(pull.status).toBe(200)
  })

  it('respeita o limite de contas', async () => {
    env.maxAccounts = 1
    await signup()

    const response = await signup('segundo@exemplo.com')

    expect(response.status).toBe(429)
  })

  it('entra com a senha certa e recusa a errada com a mesma resposta de e-mail inexistente', async () => {
    await signup()

    const ok = await loginRoute(makeRequest('POST', '/api/v1/auth/login', body({ email: 'Atleta@Exemplo.com', password, device: 'Mac' })), sql, env)
    const wrong = await loginRoute(makeRequest('POST', '/api/v1/auth/login', body({ email: 'atleta@exemplo.com', password: 'errada-1234', device: 'Mac' })), sql, env)
    const unknown = await loginRoute(makeRequest('POST', '/api/v1/auth/login', body({ email: 'ninguem@exemplo.com', password, device: 'Mac' })), sql, env)

    expect(ok.status).toBe(200)
    expect(((await ok.json()) as { token: string }).token).toMatch(/^[A-Za-z0-9_-]{43}$/)
    expect([wrong.status, unknown.status]).toEqual([401, 401])
    expect(await wrong.json()).toEqual(await unknown.json())
  })

  it('bloqueia depois de 10 tentativas erradas pelo mesmo IP', async () => {
    await signup()
    const attempt = () =>
      loginRoute(makeRequest('POST', '/api/v1/auth/login', body({ email: 'atleta@exemplo.com', password: 'errada-1234', device: 'Mac' })), sql, env)
    for (let index = 0; index < 10; index += 1) {
      await attempt()
    }

    const blocked = await attempt()
    now = new Date(now.getTime() + 16 * 60 * 1000)
    const later = await attempt()

    expect(blocked.status).toBe(429)
    expect(later.status).toBe(401)
  })

  it('sair invalida a sessão', async () => {
    const token = await signedUp()

    await logoutRoute(makeRequest('POST', '/api/v1/auth/logout', { token }), sql, env)
    const me = await meRoute(makeRequest('GET', '/api/v1/auth/me', { token }), sql, env)

    expect(me.status).toBe(401)
  })

  it('sessão expira depois de 90 dias sem uso', async () => {
    const token = await signedUp()
    now = new Date(now.getTime() + 91 * 24 * 60 * 60 * 1000)

    const me = await meRoute(makeRequest('GET', '/api/v1/auth/me', { token }), sql, env)

    expect(me.status).toBe(401)
  })
})

describe('perfil e sessões', () => {
  it('lê e troca o nome', async () => {
    const token = await signedUp()

    const patched = await meRoute(makeRequest('PATCH', '/api/v1/auth/me', body({ name: 'Adriano' }, token)), sql, env)

    expect(await patched.json()).toEqual({ user: { email: 'atleta@exemplo.com', name: 'Adriano', emailVerified: false } })
  })

  it('lista as sessões e encerra outra', async () => {
    const first = await signedUp()
    const login = await loginRoute(makeRequest('POST', '/api/v1/auth/login', body({ email: 'atleta@exemplo.com', password, device: 'Mac' })), sql, env)
    const second = ((await login.json()) as { token: string }).token

    const listed = (await (await sessionsRoute(makeRequest('GET', '/api/v1/auth/sessions', { token: first }), sql, env)).json()) as {
      sessions: { id: string; device: string; current: boolean }[]
    }
    const other = listed.sessions.find((session) => !session.current)
    await sessionsRoute(makeRequest('DELETE', `/api/v1/auth/sessions?id=${other?.id}`, { token: first }), sql, env)
    const me = await meRoute(makeRequest('GET', '/api/v1/auth/me', { token: second }), sql, env)

    expect(listed.sessions.map((session) => [session.device, session.current]).sort()).toEqual([['Mac', false], ['iPhone', true]])
    expect(me.status).toBe(401)
  })

  it('apagar a conta pela sessão apaga usuário, sessões e dados', async () => {
    const token = await signedUp()

    const deleted = await deleteAccountRoute(makeRequest('DELETE', '/api/v1/account', { token }), sql)

    expect(deleted.status).toBe(204)
    expect(await sql('select * from users')).toEqual([])
    expect(await sql('select * from sessions')).toEqual([])
    expect(await sql('select * from accounts')).toEqual([])
  })
})

describe('senha e e-mail', () => {
  it('troca a senha com a atual e encerra as outras sessões', async () => {
    const token = await signedUp()
    const other = ((await (await loginRoute(makeRequest('POST', '/api/v1/auth/login', body({ email: 'atleta@exemplo.com', password, device: 'Mac' })), sql, env)).json()) as { token: string }).token

    const wrong = await changePasswordRoute(makeRequest('POST', '/api/v1/auth/password', body({ current: 'errada-1234', next: 'nova-senha-123' }, token)), sql, env)
    const ok = await changePasswordRoute(makeRequest('POST', '/api/v1/auth/password', body({ current: password, next: 'nova-senha-123' }, token)), sql, env)
    const otherMe = await meRoute(makeRequest('GET', '/api/v1/auth/me', { token: other }), sql, env)
    const ownMe = await meRoute(makeRequest('GET', '/api/v1/auth/me', { token }), sql, env)
    const login = await loginRoute(makeRequest('POST', '/api/v1/auth/login', body({ email: 'atleta@exemplo.com', password: 'nova-senha-123', device: 'Mac' })), sql, env)

    expect([wrong.status, ok.status, otherMe.status, ownMe.status, login.status]).toEqual([401, 204, 401, 200, 200])
  })

  it('confirma o e-mail uma vez só', async () => {
    await signedUp()
    const token = linkToken(sent[0])

    const first = await verifyEmailRoute(makeRequest('POST', '/api/v1/auth/verify', body({ token })), sql, env)
    const again = await verifyEmailRoute(makeRequest('POST', '/api/v1/auth/verify', body({ token })), sql, env)
    const verified = await sql<{ email_verified_at: unknown }>('select email_verified_at from users')

    expect([first.status, again.status]).toEqual([204, 400])
    expect(verified[0]?.email_verified_at).not.toBeNull()
  })

  it('link de confirmação vence em 24 horas', async () => {
    await signedUp()
    now = new Date(now.getTime() + 25 * 60 * 60 * 1000)

    const response = await verifyEmailRoute(makeRequest('POST', '/api/v1/auth/verify', body({ token: linkToken(sent[0]) })), sql, env)

    expect(response.status).toBe(400)
  })

  it('reenvia a confirmação e invalida o link anterior', async () => {
    const token = await signedUp()

    await resendVerificationRoute(makeRequest('POST', '/api/v1/auth/resend-verification', { token }), sql, env)
    const old = await verifyEmailRoute(makeRequest('POST', '/api/v1/auth/verify', body({ token: linkToken(sent[0]) })), sql, env)
    const fresh = await verifyEmailRoute(makeRequest('POST', '/api/v1/auth/verify', body({ token: linkToken(sent[1]) })), sql, env)

    expect([old.status, fresh.status]).toEqual([400, 204])
  })

  it('recupera a senha de conta confirmada e encerra todas as sessões', async () => {
    const session = await signedUp()
    await verifyEmailRoute(makeRequest('POST', '/api/v1/auth/verify', body({ token: linkToken(sent[0]) })), sql, env)

    const forgot = await forgotPasswordRoute(makeRequest('POST', '/api/v1/auth/forgot', body({ email: 'atleta@exemplo.com' })), sql, env)
    const reset = await resetPasswordRoute(makeRequest('POST', '/api/v1/auth/reset', body({ token: linkToken(sent[1]), password: 'recuperada-99' })), sql, env)
    const reused = await resetPasswordRoute(makeRequest('POST', '/api/v1/auth/reset', body({ token: linkToken(sent[1]), password: 'outra-senha-99' })), sql, env)
    const me = await meRoute(makeRequest('GET', '/api/v1/auth/me', { token: session }), sql, env)
    const login = await loginRoute(makeRequest('POST', '/api/v1/auth/login', body({ email: 'atleta@exemplo.com', password: 'recuperada-99', device: 'Mac' })), sql, env)

    expect(sent[1]?.text).toContain('https://site.test/redefinir-senha?token=')
    expect([forgot.status, reset.status, reused.status, me.status, login.status]).toEqual([204, 204, 400, 401, 200])
  })

  it('não manda e-mail de recuperação para conta não confirmada nem diz se o e-mail existe', async () => {
    await signedUp()

    const known = await forgotPasswordRoute(makeRequest('POST', '/api/v1/auth/forgot', body({ email: 'atleta@exemplo.com' })), sql, env)
    const unknown = await forgotPasswordRoute(makeRequest('POST', '/api/v1/auth/forgot', body({ email: 'ninguem@exemplo.com' })), sql, env)

    expect([known.status, unknown.status]).toEqual([204, 204])
    expect(sent).toHaveLength(1)
  })

  it('link de recuperação vence em 30 minutos', async () => {
    await signedUp()
    await verifyEmailRoute(makeRequest('POST', '/api/v1/auth/verify', body({ token: linkToken(sent[0]) })), sql, env)
    await forgotPasswordRoute(makeRequest('POST', '/api/v1/auth/forgot', body({ email: 'atleta@exemplo.com' })), sql, env)
    now = new Date(now.getTime() + 31 * 60 * 1000)

    const reset = await resetPasswordRoute(makeRequest('POST', '/api/v1/auth/reset', body({ token: linkToken(sent[1]), password: 'recuperada-99' })), sql, env)

    expect(reset.status).toBe(400)
  })

  it('sem serviço de e-mail, recuperar responde 503 e o cadastro funciona', async () => {
    env.mailer = undefined

    const created = await signup()
    const forgot = await forgotPasswordRoute(makeRequest('POST', '/api/v1/auth/forgot', body({ email: 'atleta@exemplo.com' })), sql, env)

    expect(created.status).toBe(201)
    expect(forgot.status).toBe(503)
  })
})
