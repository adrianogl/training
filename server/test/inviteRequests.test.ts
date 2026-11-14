import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import { adminOverviewRoute } from '../src/adminRoutes.js'
import { signupRoute } from '../src/authRoutes.js'
import type { Sql } from '../src/db.js'
import { inviteRequestActionRoute, inviteRequestRoute } from '../src/inviteRequestRoutes.js'
import type { AuthEnv, Mail } from '../src/types.js'
import { makeRequest, migratedSql } from './helpers.js'

const key = randomBytes(32)
let sql: Sql
let sent: Mail[]
let env: AuthEnv
let adminToken: string

function req(method: string, path: string, body?: unknown, token?: string, ip = '10.0.0.1'): Request {
  const request = makeRequest(method, path, { ...(body === undefined ? {} : { body: JSON.stringify(body) }), ...(token === undefined ? {} : { token }) })
  request.headers.set('x-forwarded-for', ip)
  return request
}

const ask = (body: Record<string, unknown>, ip?: string) => inviteRequestRoute(req('POST', '/api/v1/invite-requests', body, undefined, ip), sql, env, key)
const marina = { name: 'Marina', email: 'marina@exemplo.com', watch: 'garmin', message: 'Treino para a primeira meia' }

async function overview() {
  return (await (await adminOverviewRoute(req('GET', '/api/v1/admin/overview', undefined, adminToken), sql, env, key)).json()) as { requests: { id: string; name: string; email: string; watch: string; message: string }[] }
}

beforeEach(async () => {
  sql = await migratedSql()
  sent = []
  env = { mailer: { send: async (mail) => void sent.push(mail) }, appUrl: 'https://site.test/app', now: () => new Date('2026-11-14T12:00:00.000Z'), maxAccounts: 20, adminEmails: ['admin@exemplo.com'] }
  const created = await signupRoute(req('POST', '/api/v1/auth/signup', { name: 'Adriano', email: 'admin@exemplo.com', password: 'corrida-longa-42', device: 'Site' }), sql, env)
  adminToken = ((await created.json()) as { token: string }).token
  sent = []
})

describe('pedido de convite', () => {
  it('guarda cifrado, avisa o administrador por e-mail e aparece na administração', async () => {
    const response = await ask(marina)
    const stored = await sql<{ data_enc: string }>('select data_enc from invite_requests')
    const list = await overview()
    expect(response.status).toBe(202)
    expect(stored[0]?.data_enc).not.toContain('marina')
    expect(sent).toHaveLength(1)
    expect(sent[0]).toMatchObject({ to: 'admin@exemplo.com', subject: 'Novo pedido de convite no trAIning' })
    expect(sent[0]?.text).toContain('Marina (marina@exemplo.com) pediu um convite.')
    expect(sent[0]?.text).toContain('Relógio: Garmin')
    expect(list.requests).toEqual([expect.objectContaining({ name: 'Marina', email: 'marina@exemplo.com', watch: 'garmin', message: 'Treino para a primeira meia' })])
  })

  it('valida os campos', async () => {
    const errors = await Promise.all([
      ask({ ...marina, name: '' }),
      ask({ ...marina, email: 'sem-arroba' }),
      ask({ ...marina, watch: 'polar' }),
      ask({ ...marina, message: 'x'.repeat(501) }),
    ].map(async (response) => ((await (await response).json()) as { error: string }).error))
    expect(errors).toEqual(['invalid_name', 'invalid_email', 'invalid_watch', 'invalid_message'])
  })

  it('isca de robô finge sucesso sem guardar e limite de 3 por hora por IP', async () => {
    const bot = await ask({ ...marina, website: 'http://spam' })
    expect(bot.status).toBe(202)
    expect(await sql('select id from invite_requests')).toEqual([])
    for (let i = 0; i < 3; i += 1) expect((await ask({ ...marina, email: `p${i}@exemplo.com` })).status).toBe(202)
    expect((await ask(marina)).status).toBe(429)
    expect((await ask(marina, '10.0.0.2')).status).toBe(202)
  })

  it('convidar cria o convite por e-mail e tira da lista; recusar só tira', async () => {
    await ask(marina)
    await ask({ ...marina, name: 'Rafael', email: 'rafa@exemplo.com', watch: 'other' }, '10.0.0.9')
    const list = (await overview()).requests
    const first = list.find((item) => item.name === 'Marina')
    const rafael = list.find((item) => item.name === 'Rafael')
    sent = []
    const invited = await inviteRequestActionRoute(req('POST', '/api/v1/admin/invite-requests/action', { id: first?.id, action: 'invite' }, adminToken), sql, env, key)
    const declined = await inviteRequestActionRoute(req('POST', '/api/v1/admin/invite-requests/action', { id: rafael?.id, action: 'decline' }, adminToken), sql, env, key)
    const body = (await invited.json()) as { invite: { name: string; email: string; channel: string }; mailed: boolean }
    expect(body).toMatchObject({ invite: { name: 'Marina', email: 'marina@exemplo.com', channel: 'email' }, mailed: true })
    expect(sent[0]?.to).toBe('marina@exemplo.com')
    expect(declined.status).toBe(200)
    expect((await overview()).requests).toEqual([])
    const again = await inviteRequestActionRoute(req('POST', '/api/v1/admin/invite-requests/action', { id: first?.id, action: 'invite' }, adminToken), sql, env, key)
    expect(again.status).toBe(404)
  })

  it('só administrador age sobre pedidos', async () => {
    await ask(marina)
    const response = await inviteRequestActionRoute(req('POST', '/api/v1/admin/invite-requests/action', { id: 'x', action: 'decline' }), sql, env, key)
    expect(response.status).toBe(401)
  })
})
