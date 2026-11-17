import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { createAccountRoute, pullChangesRoute, pushChangesRoute } from '../src/routes.js'
import { makeRequest, makeToken, migratedSql, record } from './helpers.js'

const token = makeToken(1)

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
  return (await response.json()) as { records: { kind: string; id: string; payload: string | null }[] }
}

describe('preferências e conversas', () => {
  let sql: Sql

  beforeEach(async () => {
    sql = await migratedSql()
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token, ip: '1.1.1.1' }), sql, new Date())
  })

  it('grava preferência e conversa seladas e devolve no pull', async () => {
    const pushed = await push(sql, [
      record({ kind: 'preference', id: 'weeklyGoalKm', payload: 'c2VsYWRv' }),
      record({ kind: 'preference', id: 'raceWater.0F8FAD5B-D9CB-469F-A165-70867728950E', payload: 'c2VsYWRv' }),
      record({ kind: 'chat', id: 'workout.25102950476', payload: 'Y2hhdA==' }),
    ])
    const pulled = await pull(sql)

    expect(pushed.status).toBe(200)
    expect(pulled.records.map((item) => `${item.kind}:${item.id}`).sort()).toEqual([
      'chat:workout.25102950476',
      'preference:raceWater.0F8FAD5B-D9CB-469F-A165-70867728950E',
      'preference:weeklyGoalKm',
    ])
  })

  it('recusa id fora do padrão', async () => {
    const pushed = await push(sql, [record({ kind: 'preference', id: '../segredo' })])

    expect(pushed).toEqual({ status: 400, body: { error: 'invalid_id' } })
  })

  it('recusa o formato plain', async () => {
    const preference = await push(sql, [record({ kind: 'preference', id: 'share', payload: '{}', format: 'plain' })])
    const chat = await push(sql, [record({ kind: 'chat', id: 'trainer', payload: '{}', format: 'plain' })])

    expect(preference).toEqual({ status: 400, body: { error: 'invalid_format' } })
    expect(chat).toEqual({ status: 400, body: { error: 'invalid_format' } })
  })
})
