import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { createAccountRoute, pullChangesRoute, pushChangesRoute } from '../src/routes.js'
import { makeRequest, makeToken, migratedSql, record } from './helpers.js'

const token = makeToken(1)
const key = randomBytes(32)
const raceId = '6f1c2a4e-0b7d-4c55-9a1e-3d2f8b7c6a10'
const race = {
  id: raceId.toUpperCase(), name: 'Meia de exemplo', day: '2026-11-29', distance: 21097.5, goalSeconds: 5940, priority: 'A',
  updatedAt: '2026-11-12T18:30:00.123Z',
}
const limits = { maxAccounts: 3, maxAccountBytes: 50 * 1024 * 1024 }

async function push(sql: Sql, records: unknown[], dataKey: Buffer | null = key) {
  const response = await pushChangesRoute(makeRequest('POST', '/api/v1/changes', { token, body: JSON.stringify({ records }) }), sql, limits, dataKey ?? undefined)
  return { status: response.status, body: await response.json() }
}

async function pull(sql: Sql, dataKey: Buffer | undefined = key) {
  const response = await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token }), sql, dataKey)
  return { status: response.status, body: await response.json() }
}

describe('registros em formato plain', () => {
  let sql: Sql

  beforeEach(async () => {
    sql = await migratedSql()
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token, ip: '1.1.1.1' }), sql, new Date())
  })

  it('cifra no servidor e devolve o JSON no pull', async () => {
    const payload = JSON.stringify(race)
    const pushed = await push(sql, [record({ id: raceId, payload, format: 'plain' })])
    const stored = await sql<{ payload: string; format: string }>('select payload, format from records')
    const pulled = await pull(sql)

    expect(pushed.status).toBe(200)
    expect(stored[0]?.format).toBe('plain')
    expect(stored[0]?.payload).not.toContain('Meia')
    expect(pulled.body.records[0]).toMatchObject({ id: raceId, payload, format: 'plain' })
  })

  it('registro cifrado pelo app continua passando intacto e sem format', async () => {
    await push(sql, [record()])
    const pulled = await pull(sql)
    expect(pulled.body.records[0]).toEqual({ ...record(), seq: pulled.body.cursor })
  })

  it('plain substitui o legado mais velho da mesma prova', async () => {
    await push(sql, [record({ id: raceId })])
    await push(sql, [record({ id: raceId, updatedAt: '2026-11-13T10:00:00.000Z', payload: JSON.stringify(race), format: 'plain' })])
    const pulled = await pull(sql)
    expect(pulled.body.records).toHaveLength(1)
    expect(pulled.body.records[0].format).toBe('plain')
  })

  it('reenvio em plain com o mesmo updatedAt substitui o legado, e o contrário não', async () => {
    await push(sql, [record({ id: raceId })])
    const same = await push(sql, [record({ id: raceId, payload: JSON.stringify(race), format: 'plain' })])
    const back = await push(sql, [record({ id: raceId })])
    const pulled = await pull(sql)
    expect(same.body.ignored).toEqual([])
    expect(back.body.ignored).toEqual([{ kind: 'race', id: raceId }])
    expect(pulled.body.records[0].format).toBe('plain')
  })

  it('rejeita prova inválida, id trocado e decisão sem activityId', async () => {
    const bad = await push(sql, [record({ id: raceId, payload: JSON.stringify({ ...race, distance: -1 }), format: 'plain' })])
    const otherId = await push(sql, [record({ id: 'outra', payload: JSON.stringify(race), format: 'plain' })])
    const decision = await push(sql, [record({ kind: 'decision', id: '42', payload: JSON.stringify({ decision: 'race' }), format: 'plain' })])
    const format = await push(sql, [record({ format: 'zip' })])
    expect([bad.status, otherId.status, decision.status, format.status]).toEqual([400, 400, 400, 400])
    expect(format.body.error).toBe('invalid_format')
  })

  it('aceita decisão e tombstone em plain', async () => {
    const decision = await push(sql, [record({ kind: 'decision', id: '42', payload: JSON.stringify({ activityId: 42, decision: 'race' }), format: 'plain' })])
    const deleted = await push(sql, [record({ id: raceId, deleted: true, payload: null, format: 'plain' })])
    expect([decision.status, deleted.status]).toEqual([200, 200])
  })

  it('sem DATA_KEY recusa plain e segue aceitando o legado', async () => {
    const saved = process.env.DATA_KEY
    delete process.env.DATA_KEY
    try {
      const plain = await push(sql, [record({ id: raceId, payload: JSON.stringify(race), format: 'plain' })], null)
      const legacy = await push(sql, [record()], null)
      expect([plain.status, legacy.status]).toEqual([503, 200])
    } finally {
      if (saved !== undefined) process.env.DATA_KEY = saved
    }
  })
})
