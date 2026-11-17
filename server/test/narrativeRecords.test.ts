import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { createAccountRoute, pullChangesRoute, pushChangesRoute } from '../src/routes.js'
import { makeRequest, makeToken, migratedSql, record } from './helpers.js'

const token = makeToken(1)
const id = 'a'.repeat(64)

async function push(sql: Sql, records: unknown[]) {
  const response = await pushChangesRoute(
    makeRequest('POST', '/api/v1/changes', { token, body: JSON.stringify({ records }) }),
    sql,
    { maxAccounts: 3, maxAccountBytes: 50 * 1024 * 1024 },
    randomBytes(32),
  )
  return { status: response.status, body: await response.json() }
}

async function pull(sql: Sql) {
  const response = await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token }), sql)
  return (await response.json()) as { records: { kind: string; id: string; payload: string | null; updatedAt: string }[] }
}

describe('registro do texto gerado', () => {
  let sql: Sql

  beforeEach(async () => {
    sql = await migratedSql()
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token, ip: '1.1.1.1' }), sql, new Date())
  })

  it('grava o texto selado pelo hash dos fatos e devolve no pull', async () => {
    const pushed = await push(sql, [record({ kind: 'narrative', id, payload: 'c2VsYWRv' })])
    const pulled = await pull(sql)

    expect(pushed.status).toBe(200)
    expect(pulled.records[0]).toMatchObject({ kind: 'narrative', id, payload: 'c2VsYWRv' })
  })

  it('recusa id que não é um hash', async () => {
    const pushed = await push(sql, [record({ kind: 'narrative', id: 'treino-de-ontem' })])

    expect(pushed).toEqual({ status: 400, body: { error: 'invalid_id' } })
  })

  it('aceita plain com o texto em base64', async () => {
    const pushed = await push(sql, [record({ kind: 'narrative', id, payload: JSON.stringify({ data: 'dGV4dG8=' }), format: 'plain' })])

    expect(pushed.status).toBe(200)
  })

  it('o texto mais novo vence', async () => {
    await push(sql, [record({ kind: 'narrative', id, payload: 'bm92bw==' })])
    const older = await push(sql, [record({ kind: 'narrative', id, updatedAt: '2026-11-12T18:29:00.000Z', payload: 'dmVsaG8=' })])
    const pulled = await pull(sql)

    expect(older.body.ignored).toEqual([{ kind: 'narrative', id }])
    expect(pulled.records).toEqual([expect.objectContaining({ payload: 'bm92bw==' })])
  })
})
