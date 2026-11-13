import { beforeEach, describe, expect, it } from 'vitest'
import {
  ACCOUNT_CREATION_LIMIT,
  ACCOUNT_CREATION_WINDOW_MS,
  DEFAULT_MAX_ACCOUNT_BYTES,
  DEFAULT_MAX_ACCOUNTS,
} from '../src/constants.js'
import { limitsFromEnv } from '../src/limits.js'
import type { Sql } from '../src/db.js'
import { createAccountRoute, deleteAccountRoute, pullChangesRoute, pushChangesRoute } from '../src/routes.js'
import { makeRequest, makeToken, migratedSql, record } from './helpers.js'

const now = new Date('2026-11-12T18:00:00.000Z')
const roomy = { maxAccounts: 1000, maxAccountBytes: DEFAULT_MAX_ACCOUNT_BYTES }

describe('POST /api/v1/account', () => {
  let sql: Sql

  beforeEach(async () => {
    sql = await migratedSql()
  })

  it('cria a conta e depois responde created false', async () => {
    const first = await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: makeToken(1), ip: '1.1.1.1' }), sql, now)
    const second = await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: makeToken(1), ip: '1.1.1.1' }), sql, now)

    expect(first.status).toBe(201)
    expect(await first.json()).toEqual({ created: true })
    expect(second.status).toBe(200)
    expect(await second.json()).toEqual({ created: false })
  })

  it('401 sem token válido', async () => {
    const response = await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: 'curto' }), sql, now)

    expect(response.status).toBe(401)
    expect(await response.json()).toEqual({ error: 'unauthorized' })
  })

  it('429 depois do limite de criações por IP na janela', async () => {
    for (let i = 0; i < ACCOUNT_CREATION_LIMIT; i++) {
      const response = await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: makeToken(i), ip: '2.2.2.2' }), sql, now, roomy)
      expect(response.status).toBe(201)
    }

    const blocked = await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: makeToken(200), ip: '2.2.2.2' }), sql, now, roomy)
    const otherIp = await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: makeToken(201), ip: '3.3.3.3' }), sql, now, roomy)
    const existing = await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: makeToken(0), ip: '2.2.2.2' }), sql, now, roomy)
    const later = await createAccountRoute(
      makeRequest('POST', '/api/v1/account', { token: makeToken(202), ip: '2.2.2.2' }),
      sql,
      new Date(now.getTime() + ACCOUNT_CREATION_WINDOW_MS + 1),
      roomy,
    )

    expect(blocked.status).toBe(429)
    expect(await blocked.json()).toEqual({ error: 'rate_limited' })
    expect(otherIp.status).toBe(201)
    expect(existing.status).toBe(200)
    expect(later.status).toBe(201)
  })

  it('429 acima do limite total de contas; conta existente continua 200', async () => {
    const limits = { maxAccounts: 2, maxAccountBytes: DEFAULT_MAX_ACCOUNT_BYTES }
    const create = (fill: number, ip: string) =>
      createAccountRoute(makeRequest('POST', '/api/v1/account', { token: makeToken(fill), ip }), sql, now, limits)

    const statuses = [(await create(1, '1.1.1.1')).status, (await create(2, '2.2.2.2')).status]
    const third = await create(3, '3.3.3.3')
    const existing = await create(1, '4.4.4.4')

    expect(statuses).toEqual([201, 201])
    expect(third.status).toBe(429)
    expect(await third.json()).toEqual({ error: 'rate_limited' })
    expect(existing.status).toBe(200)
    expect(await sql('select id from accounts')).toHaveLength(2)
  })

  it('limite padrão de contas vem do ambiente', async () => {
    const statuses: number[] = []
    for (let i = 0; i < DEFAULT_MAX_ACCOUNTS + 1; i++) {
      const response = await createAccountRoute(
        makeRequest('POST', '/api/v1/account', { token: makeToken(i), ip: `9.9.9.${i}` }),
        sql,
        now,
      )
      statuses.push(response.status)
    }

    expect(statuses).toEqual([...Array.from({ length: DEFAULT_MAX_ACCOUNTS }, () => 201), 429])
  })

  it('guarda o IP só como hash', async () => {
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: makeToken(1), ip: '4.4.4.4' }), sql, now)

    const rows = await sql<{ ip_hash: string }>('select ip_hash from account_creations')
    expect(rows).toHaveLength(1)
    expect(rows[0]?.ip_hash).toMatch(/^[0-9a-f]{64}$/)
  })
})

describe('DELETE /api/v1/account', () => {
  let sql: Sql

  beforeEach(async () => {
    sql = await migratedSql()
  })

  it('apaga conta e registros com 204', async () => {
    const token = makeToken(1)
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token, ip: '1.1.1.1' }), sql, now)
    await pushChangesRoute(makeRequest('POST', '/api/v1/changes', { token, body: JSON.stringify({ records: [record()] }) }), sql)

    const response = await deleteAccountRoute(makeRequest('DELETE', '/api/v1/account', { token }), sql)

    expect(response.status).toBe(204)
    expect(await response.text()).toBe('')
    expect(await sql('select * from records')).toEqual([])
    expect((await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token }), sql)).status).toBe(401)
  })

  it('401 para conta inexistente', async () => {
    const response = await deleteAccountRoute(makeRequest('DELETE', '/api/v1/account', { token: makeToken(9) }), sql)

    expect(response.status).toBe(401)
  })
})

describe('limitsFromEnv', () => {
  it('usa os padrões sem env', () => {
    expect(limitsFromEnv({})).toEqual({ maxAccounts: DEFAULT_MAX_ACCOUNTS, maxAccountBytes: DEFAULT_MAX_ACCOUNT_BYTES })
  })

  it('lê MAX_ACCOUNTS e MAX_ACCOUNT_BYTES', () => {
    expect(limitsFromEnv({ MAX_ACCOUNTS: '5', MAX_ACCOUNT_BYTES: '1000' })).toEqual({ maxAccounts: 5, maxAccountBytes: 1000 })
  })

  it.each(['', '0', '-1', 'abc', '1.5'])('valor inválido %j cai no padrão', (value) => {
    expect(limitsFromEnv({ MAX_ACCOUNTS: value, MAX_ACCOUNT_BYTES: value })).toEqual({
      maxAccounts: DEFAULT_MAX_ACCOUNTS,
      maxAccountBytes: DEFAULT_MAX_ACCOUNT_BYTES,
    })
  })
})
