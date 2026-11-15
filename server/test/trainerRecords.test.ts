import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { createAccountRoute, pullChangesRoute, pushChangesRoute } from '../src/routes.js'
import { makeRequest, makeToken, migratedSql, record } from './helpers.js'

const token = makeToken(1)

const key = randomBytes(32)
const plan = { target: { kind: 'race', name: 'Meia de exemplo' }, paces: {}, weeks: [], workouts: [], versions: [] }

async function push(sql: Sql, records: unknown[], dataKey?: Buffer) {
  const response = await pushChangesRoute(
    makeRequest('POST', '/api/v1/changes', { token, body: JSON.stringify({ records }) }),
    sql,
    { maxAccounts: 3, maxAccountBytes: 50 * 1024 * 1024 },
    dataKey,
  )
  return { status: response.status, body: await response.json() }
}

async function pull(sql: Sql) {
  const response = await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token }), sql)
  return (await response.json()) as { records: { kind: string; id: string; deleted: boolean; payload: string | null; updatedAt: string }[] }
}

describe('registro do treinador', () => {
  let sql: Sql

  beforeEach(async () => {
    sql = await migratedSql()
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token, ip: '1.1.1.1' }), sql, new Date())
  })

  it('grava o plano selado com id fixo e devolve no pull sem interpretar o payload', async () => {
    const pushed = await push(sql, [record({ kind: 'trainer', id: 'plan', payload: 'c2VsYWRv' })])
    const pulled = await pull(sql)

    expect(pushed.status).toBe(200)
    expect(pulled.records).toHaveLength(1)
    expect(pulled.records[0]).toMatchObject({ kind: 'trainer', id: 'plan', deleted: false, payload: 'c2VsYWRv' })
  })

  it('recusa id diferente de plan', async () => {
    const pushed = await push(sql, [record({ kind: 'trainer', id: 'outro' })])

    expect(pushed).toEqual({ status: 400, body: { error: 'invalid_id' } })
  })

  it('aceita o plano em plain, cifra no servidor e devolve o JSON no pull', async () => {
    const payload = JSON.stringify(plan)
    const pushed = await push(sql, [record({ kind: 'trainer', id: 'plan', payload, format: 'plain' })], key)
    const stored = await sql<{ payload: string; format: string }>("select payload, format from records where kind = 'trainer'")
    const pulled = await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token }), sql, key)
    const body = (await pulled.json()) as { records: { payload: string; format: string }[] }

    expect(pushed.status).toBe(200)
    expect(stored[0]?.format).toBe('plain')
    expect(stored[0]?.payload).not.toContain('Meia')
    expect(body.records[0]).toMatchObject({ payload, format: 'plain' })
  })

  it('recusa plain que não é um plano ou com id diferente de plan', async () => {
    const notPlan = await push(sql, [record({ kind: 'trainer', id: 'plan', payload: '{}', format: 'plain' })], key)
    const wrongId = await push(sql, [record({ kind: 'trainer', id: 'outro', payload: JSON.stringify(plan), format: 'plain' })], key)

    expect(notPlan).toEqual({ status: 400, body: { error: 'invalid_plain_payload' } })
    expect(wrongId).toEqual({ status: 400, body: { error: 'invalid_id' } })
  })

  it('plain substitui o plano selado pelo aparelho com o mesmo updatedAt', async () => {
    await push(sql, [record({ kind: 'trainer', id: 'plan', payload: 'c2VsYWRv' })])
    await push(sql, [record({ kind: 'trainer', id: 'plan', payload: JSON.stringify(plan), format: 'plain' })], key)
    const stored = await sql<{ format: string }>("select format from records where kind = 'trainer'")

    expect(stored.map((row) => row.format)).toEqual(['plain'])
  })

  it('o mais novo vence e o tombstone apaga o plano', async () => {
    await push(sql, [record({ kind: 'trainer', id: 'plan', payload: 'dmVsaG8=' })])
    const older = await push(sql, [record({ kind: 'trainer', id: 'plan', updatedAt: '2026-11-12T18:29:00.000Z', payload: 'b2xkZXI=' })])
    await push(sql, [record({ kind: 'trainer', id: 'plan', updatedAt: '2026-11-12T18:31:00.000Z', deleted: true, payload: null })])
    const pulled = await pull(sql)

    expect(older.body.ignored).toEqual([{ kind: 'trainer', id: 'plan' }])
    expect(pulled.records).toHaveLength(1)
    expect(pulled.records[0]).toMatchObject({ deleted: true, payload: null, updatedAt: '2026-11-12T18:31:00.000Z' })
  })
})
