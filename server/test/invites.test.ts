import { beforeEach, describe, expect, it } from 'vitest'
import { adminCreateInviteRoute, adminDeleteUserRoute, adminInviteActionRoute, adminOverviewRoute, invitePreviewRoute } from '../src/adminRoutes.js'
import { loginRoute, signupRoute } from '../src/authRoutes.js'
import type { Sql } from '../src/db.js'
import type { AuthEnv, Mail } from '../src/types.js'
import { makeRequest, migratedSql } from './helpers.js'

const password = 'corrida-longa-42'

let sql: Sql
let sent: Mail[]
let now: Date
let env: AuthEnv
let adminToken: string

function req(method: string, path: string, body?: unknown, token?: string, headers: Record<string, string> = {}): Request {
  const request = makeRequest(method, path, body === undefined ? (token === undefined ? {} : { token }) : token === undefined ? { body: JSON.stringify(body) } : { body: JSON.stringify(body), token })
  for (const [key, value] of Object.entries(headers)) {
    request.headers.set(key, value)
  }
  return request
}

async function invite(body: Record<string, unknown>): Promise<{ link: string; message: string; invite: { id: string; status: string } }> {
  const response = await adminCreateInviteRoute(req('POST', '/api/v1/admin/invites', body, adminToken), sql, env)
  return (await response.json()) as { link: string; message: string; invite: { id: string; status: string } }
}

function tokenFrom(link: string): string {
  return new URL(link).searchParams.get('c') ?? ''
}

async function guestSignup(inviteToken: string, email = 'marina@exemplo.com', headers: Record<string, string> = {}): Promise<Response> {
  return signupRoute(req('POST', '/api/v1/auth/signup', { name: 'Marina', email, password, device: 'Site', inviteToken }, undefined, headers), sql, env)
}

beforeEach(async () => {
  sql = await migratedSql()
  sent = []
  now = new Date('2026-11-14T12:00:00.000Z')
  env = { mailer: { send: async (mail) => void sent.push(mail) }, appUrl: 'https://site.test/app', now: () => now, maxAccounts: 20, adminEmails: ['admin@exemplo.com'] }
  const created = await signupRoute(req('POST', '/api/v1/auth/signup', { name: 'Adriano', email: 'Admin@Exemplo.com', password, device: 'Site' }), sql, env)
  adminToken = ((await created.json()) as { token: string }).token
  sent = []
})

describe('cadastro só por convite', () => {
  it('sem convite e sem ser administrador, recusa', async () => {
    const response = await signupRoute(req('POST', '/api/v1/auth/signup', { name: 'X', email: 'x@exemplo.com', password, device: 'Site' }), sql, env)

    expect(response.status).toBe(403)
    expect(await response.json()).toEqual({ error: 'invite_required' })
  })

  it('o convite cria uma conta de convidado e não vale de novo', async () => {
    const created = await invite({ name: 'Marina', channel: 'link' })

    const first = await guestSignup(tokenFrom(created.link))
    const again = await guestSignup(tokenFrom(created.link), 'outra@exemplo.com')
    const body = (await first.json()) as { user: { role: string; admin: boolean } }

    expect(first.status).toBe(201)
    expect(body.user.role).toBe('guest')
    expect(body.user.admin).toBe(false)
    expect(again.status).toBe(400)
    expect(await again.json()).toEqual({ error: 'invalid_invite' })
  })

  it('convite vencido depois de 7 dias', async () => {
    const created = await invite({ name: 'Marina', channel: 'link' })
    now = new Date(now.getTime() + 8 * 24 * 60 * 60 * 1000)

    expect((await guestSignup(tokenFrom(created.link))).status).toBe(400)
  })

  it('convidado não entra pelo app, só pelo site', async () => {
    const created = await invite({ name: 'Marina', channel: 'link' })
    await guestSignup(tokenFrom(created.link))

    const app = await loginRoute(req('POST', '/api/v1/auth/login', { email: 'marina@exemplo.com', password, device: 'iPhone' }, undefined, { 'x-training-client': 'app' }), sql, env)
    const site = await loginRoute(req('POST', '/api/v1/auth/login', { email: 'marina@exemplo.com', password, device: 'Site' }), sql, env)
    const admin = await loginRoute(req('POST', '/api/v1/auth/login', { email: 'admin@exemplo.com', password, device: 'iPhone' }, undefined, { 'x-training-client': 'app' }), sql, env)

    expect(app.status).toBe(403)
    expect(await app.json()).toEqual({ error: 'web_only' })
    expect([site.status, admin.status]).toEqual([200, 200])
  })

  it('cadastro de convidado pelo app é recusado antes de criar a conta', async () => {
    const created = await invite({ name: 'Marina', channel: 'link' })

    const response = await guestSignup(tokenFrom(created.link), 'marina@exemplo.com', { 'x-training-client': 'app' })
    const users = await sql<{ count: number }>('select count(*)::int as count from users')

    expect(response.status).toBe(403)
    expect(users[0]?.count).toBe(1)
  })

  it('a prévia do convite mostra quem convidou', async () => {
    const created = await invite({ name: 'Marina', channel: 'whatsapp' })

    const preview = await invitePreviewRoute(req('GET', `/api/v1/invites/preview?c=${tokenFrom(created.link)}`), sql, env)

    expect(await preview.json()).toMatchObject({ name: 'Marina', inviterName: 'Adriano', email: null })
    expect(created.message).toContain('Adriano te convidou')
    expect(created.message).toContain(created.link)
    expect(created.link.startsWith('https://site.test/app/convite?c=')).toBe(true)
  })
})

describe('administração', () => {
  it('só o administrador acessa', async () => {
    const created = await invite({ name: 'Marina', channel: 'link' })
    const guest = ((await (await guestSignup(tokenFrom(created.link))).json()) as { token: string }).token

    const forbidden = await adminOverviewRoute(req('GET', '/api/v1/admin/overview', undefined, guest), sql, env)
    const anonymous = await adminOverviewRoute(req('GET', '/api/v1/admin/overview'), sql, env)

    expect([forbidden.status, anonymous.status]).toEqual([403, 401])
  })

  it('convite por e-mail envia a mensagem com o link', async () => {
    const created = await invite({ name: 'Rafael', email: 'rafael@exemplo.com', channel: 'email' })

    expect(sent.map((mail) => mail.to)).toEqual(['rafael@exemplo.com'])
    expect(sent[0]?.text).toContain(created.link)
  })

  it('cancelar invalida o link e renovar gera outro', async () => {
    const created = await invite({ name: 'Bruno', channel: 'link' })

    await adminInviteActionRoute(req('POST', '/api/v1/admin/invites/action', { id: created.invite.id, action: 'cancel' }, adminToken), sql, env)
    const canceled = await guestSignup(tokenFrom(created.link), 'bruno@exemplo.com')
    const renewed = (await (await adminInviteActionRoute(req('POST', '/api/v1/admin/invites/action', { id: created.invite.id, action: 'renew' }, adminToken), sql, env)).json()) as { link: string }
    const accepted = await guestSignup(tokenFrom(renewed.link), 'bruno@exemplo.com')

    expect([canceled.status, accepted.status]).toEqual([400, 201])
  })

  it('o painel traz métricas, contas e convites', async () => {
    const created = await invite({ name: 'Marina', channel: 'link' })
    await guestSignup(tokenFrom(created.link))
    now = new Date(now.getTime() + 60_000)
    await invite({ name: 'Rafael', channel: 'whatsapp' })

    const body = (await (await adminOverviewRoute(req('GET', '/api/v1/admin/overview', undefined, adminToken), sql, env)).json()) as {
      overview: { accounts: number; maxAccounts: number; pendingInvites: number; activeAccounts: number }
      users: { name: string; role: string; admin: boolean }[]
      invites: { name: string; status: string }[]
    }

    expect(body.overview).toMatchObject({ accounts: 2, maxAccounts: 20, pendingInvites: 1, activeAccounts: 2 })
    expect(body.users.map((user) => [user.name, user.role, user.admin])).toEqual([['Adriano', 'member', true], ['Marina', 'guest', false]])
    expect(body.invites.map((row) => [row.name, row.status])).toEqual([['Rafael', 'pending'], ['Marina', 'accepted']])
  })

  it('remove um convidado mas nunca o administrador', async () => {
    const created = await invite({ name: 'Marina', channel: 'link' })
    await guestSignup(tokenFrom(created.link))
    const users = (await (await adminOverviewRoute(req('GET', '/api/v1/admin/overview', undefined, adminToken), sql, env)).json()) as { users: { id: string; admin: boolean }[] }
    const guestId = users.users.find((user) => !user.admin)?.id
    const adminId = users.users.find((user) => user.admin)?.id

    const removed = await adminDeleteUserRoute(req('DELETE', `/api/v1/admin/users?id=${guestId}`, undefined, adminToken), sql, env)
    const self = await adminDeleteUserRoute(req('DELETE', `/api/v1/admin/users?id=${adminId}`, undefined, adminToken), sql, env)

    expect([removed.status, self.status]).toEqual([204, 409])
    expect(await sql('select id from users where id = $1', [guestId])).toEqual([])
  })
})
