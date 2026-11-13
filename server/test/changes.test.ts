import { beforeEach, describe, expect, it } from 'vitest'
import { MAX_BODY_BYTES, MAX_PAYLOAD_CHARS, MAX_PULL_PAGE_BYTES, PULL_PAGE_SIZE } from '../src/constants.js'
import type { Sql } from '../src/db.js'
import { createAccountRoute, pullChangesRoute, pushChangesRoute } from '../src/routes.js'
import { makeRequest, makeToken, migratedSql, record } from './helpers.js'

const token = makeToken(1)

async function push(sql: Sql, records: unknown[], auth = token, maxAccountBytes = 50 * 1024 * 1024) {
  const response = await pushChangesRoute(
    makeRequest('POST', '/api/v1/changes', { token: auth, body: JSON.stringify({ records }) }),
    sql,
    { maxAccounts: 3, maxAccountBytes },
  )
  return { status: response.status, body: await response.json() }
}

async function pull(sql: Sql, since?: string, auth = token) {
  const query = since === undefined ? '' : `?since=${since}`
  const response = await pullChangesRoute(makeRequest('GET', `/api/v1/changes${query}`, { token: auth }), sql)
  return { status: response.status, body: await response.json() }
}

describe('changes', () => {
  let sql: Sql

  beforeEach(async () => {
    sql = await migratedSql()
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token, ip: '1.1.1.1' }), sql, new Date())
  })

  it('grava registro novo e devolve no pull com updatedAt em milissegundos', async () => {
    const pushed = await push(sql, [record()])
    const pulled = await pull(sql)

    expect(pushed).toEqual({ status: 200, body: { cursor: pulled.body.cursor, ignored: [] } })
    expect(pulled.status).toBe(200)
    expect(pulled.body).toEqual({
      records: [{ ...record(), seq: pulled.body.cursor }],
      cursor: pulled.body.cursor,
      hasMore: false,
    })
    expect(typeof pulled.body.cursor).toBe('number')
  })

  it('mais novo vence', async () => {
    await push(sql, [record({ payload: 'velho' })])

    const pushed = await push(sql, [record({ updatedAt: '2026-11-12T18:30:00.124Z', payload: 'novo' })])
    const pulled = await pull(sql)

    expect(pushed.body.ignored).toEqual([])
    expect(pulled.body.records).toHaveLength(1)
    expect(pulled.body.records[0]).toMatchObject({ updatedAt: '2026-11-12T18:30:00.124Z', payload: 'novo' })
  })

  it('empate e mais velho mantêm o do servidor', async () => {
    const first = await push(sql, [record({ payload: 'servidor' })])

    const pushed = await push(sql, [
      record({ payload: 'empate' }),
      record({ updatedAt: '2026-11-12T18:29:59.999Z', payload: 'velho' }),
    ])
    const pulled = await pull(sql)

    expect(pushed.body).toEqual({
      cursor: first.body.cursor,
      ignored: [
        { kind: 'race', id: 'race-1' },
        { kind: 'race', id: 'race-1' },
      ],
    })
    expect(pulled.body.records[0]).toMatchObject({ payload: 'servidor', seq: first.body.cursor })
  })

  it('tombstone vence registro mais velho e guarda payload null', async () => {
    await push(sql, [record()])

    await push(sql, [record({ updatedAt: '2026-11-13T00:00:00.000Z', deleted: true, payload: null })])
    const pulled = await pull(sql)

    expect(pulled.body.records[0]).toMatchObject({ deleted: true, payload: null, updatedAt: '2026-11-13T00:00:00.000Z' })
  })

  it('registro mais velho não ressuscita tombstone', async () => {
    await push(sql, [record({ updatedAt: '2026-11-13T00:00:00.000Z', deleted: true, payload: null })])

    const pushed = await push(sql, [record()])

    expect(pushed.body.ignored).toEqual([{ kind: 'race', id: 'race-1' }])
  })

  it('mesmo id em kinds diferentes são registros diferentes', async () => {
    await push(sql, [record({ kind: 'race', id: 'x' }), record({ kind: 'decision', id: 'x' })])

    const pulled = await pull(sql)

    expect(pulled.body.records.map((r: { kind: string }) => r.kind)).toEqual(['race', 'decision'])
  })

  it('id repetido no mesmo lote: fica o mais novo', async () => {
    const pushed = await push(sql, [
      record({ payload: 'a' }),
      record({ updatedAt: '2026-11-12T18:30:00.200Z', payload: 'b' }),
    ])
    const pulled = await pull(sql)

    expect(pushed.body.ignored).toEqual([{ kind: 'race', id: 'race-1' }])
    expect(pulled.body.records).toHaveLength(1)
    expect(pulled.body.records[0].payload).toBe('b')
  })

  it('pull só devolve seq > since e regravação ganha seq novo', async () => {
    await push(sql, [record({ id: 'a' }), record({ id: 'b' })])
    const all = await pull(sql)
    const afterFirst = all.body.records[0].seq

    await push(sql, [record({ id: 'a', updatedAt: '2026-11-14T00:00:00.000Z' })])
    const pulled = await pull(sql, String(all.body.cursor))
    const sinceFirst = await pull(sql, String(afterFirst))

    expect(pulled.body.records.map((r: { id: string }) => r.id)).toEqual(['a'])
    expect(pulled.body.records[0].seq).toBeGreaterThan(all.body.cursor)
    expect(sinceFirst.body.records.map((r: { id: string }) => r.id)).toEqual(['b', 'a'])
  })

  it('pagina em blocos com hasMore e cursor', async () => {
    const total = PULL_PAGE_SIZE + 3
    for (let start = 0; start < total; start += 100) {
      const batch = Array.from({ length: Math.min(100, total - start) }, (_, i) => record({ id: `r${start + i}` }))
      await push(sql, batch)
    }

    const first = await pull(sql)
    const second = await pull(sql, String(first.body.cursor))
    const empty = await pull(sql, String(second.body.cursor))

    expect(first.body.records).toHaveLength(PULL_PAGE_SIZE)
    expect(first.body.hasMore).toBe(true)
    expect(first.body.cursor).toBe(first.body.records.at(-1).seq)
    expect(second.body.records).toHaveLength(3)
    expect(second.body.hasMore).toBe(false)
    expect(empty.body).toEqual({ records: [], cursor: second.body.cursor, hasMore: false })
  })

  it('pagina por bytes de payload: 5 payloads de 1 MB saem em páginas abaixo do limite da Vercel', async () => {
    for (let i = 0; i < 5; i++) {
      await push(sql, [record({ id: `gpx${i}`, payload: String(i).repeat(MAX_PAYLOAD_CHARS) })])
    }

    const firstResponse = await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token }), sql)
    const firstText = await firstResponse.text()
    const first = JSON.parse(firstText)
    const second = await pull(sql, String(first.cursor))
    const third = await pull(sql, String(second.body.cursor))

    expect(MAX_PULL_PAGE_BYTES).toBeLessThan(4.5 * 1000 * 1000)
    expect(Buffer.byteLength(firstText)).toBeLessThan(4.5 * 1000 * 1000)
    expect(first.records.map((r: { id: string }) => r.id)).toEqual(['gpx0', 'gpx1', 'gpx2'])
    expect(first.hasMore).toBe(true)
    expect(second.body.records.map((r: { id: string }) => r.id)).toEqual(['gpx3', 'gpx4'])
    expect(second.body.hasMore).toBe(false)
    expect(third.body).toEqual({ records: [], cursor: second.body.cursor, hasMore: false })
  })

  it('cota por conta: acima → 413 quota_exceeded e nada gravado', async () => {
    const quota = 100
    const first = await push(sql, [record({ id: 'a', payload: 'x'.repeat(60) })], token, quota)

    const over = await push(sql, [record({ id: 'b', payload: 'x'.repeat(10) }), record({ id: 'c', payload: 'x'.repeat(40) })], token, quota)
    const replace = await push(
      sql,
      [record({ id: 'a', updatedAt: '2026-11-13T00:00:00.000Z', payload: 'x'.repeat(90) })],
      token,
      quota,
    )
    const pulled = await pull(sql)

    expect(first.status).toBe(200)
    expect(over).toEqual({ status: 413, body: { error: 'quota_exceeded' } })
    expect(replace.status).toBe(200)
    expect(pulled.body.records.map((r: { id: string }) => r.id)).toEqual(['a'])
  })

  it('cota: push que não aumenta o uso passa mesmo acima do limite', async () => {
    await push(sql, [record({ id: 'a', payload: 'x'.repeat(80) }), record({ id: 'b', payload: 'x'.repeat(80) })])

    const tombstone = await push(
      sql,
      [record({ id: 'a', updatedAt: '2026-11-13T00:00:00.000Z', deleted: true, payload: null })],
      token,
      100,
    )

    expect(tombstone.status).toBe(200)
  })

  it('não vê registros de outra conta', async () => {
    const other = makeToken(2)
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: other, ip: '1.1.1.1' }), sql, new Date())
    await push(sql, [record()], other)

    const pulled = await pull(sql)

    expect(pulled.body).toEqual({ records: [], cursor: 0, hasMore: false })
  })

  it('cursor do push é o maior seq da conta', async () => {
    await push(sql, [record({ id: 'a' }), record({ id: 'b' })])
    const all = await pull(sql)

    const pushed = await push(sql, [record({ id: 'a' })])

    expect(pushed.body.cursor).toBe(all.body.cursor)
  })

  it('401 em GET e POST para conta inexistente ou token inválido', async () => {
    const unknown = makeToken(9)

    expect((await pull(sql, undefined, unknown)).status).toBe(401)
    expect((await push(sql, [record()], unknown)).status).toBe(401)
    expect((await pull(sql, undefined, 'x')).body).toEqual({ error: 'unauthorized' })
  })

  it('400 para since inválido', async () => {
    expect(await pull(sql, '-1')).toEqual({ status: 400, body: { error: 'invalid_since' } })
  })

  it('400 para payload acima de 1 MB e nada é gravado', async () => {
    const pushed = await push(sql, [record({ id: 'ok' }), record({ id: 'big', payload: 'a'.repeat(MAX_PAYLOAD_CHARS + 1) })])

    expect(pushed).toEqual({ status: 400, body: { error: 'payload_too_large' } })
    expect((await pull(sql)).body.records).toEqual([])
  })

  it('aceita payload de 1 MB', async () => {
    const pushed = await push(sql, [record({ payload: 'a'.repeat(MAX_PAYLOAD_CHARS) })])

    expect(pushed.status).toBe(200)
  })

  it('413 para corpo acima de 4 MB', async () => {
    const big = JSON.stringify({ records: [record({ payload: 'a'.repeat(MAX_BODY_BYTES) })] })

    const response = await pushChangesRoute(makeRequest('POST', '/api/v1/changes', { token, body: big }), sql)

    expect(response.status).toBe(413)
    expect(await response.json()).toEqual({ error: 'body_too_large' })
  })
})
