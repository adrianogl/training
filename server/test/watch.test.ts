import { createHash } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import {
  createAccountRoute,
  deleteAccountRoute,
  deleteWatchTokenRoute,
  getWatchReadinessRoute,
  pullChangesRoute,
  putWatchReadinessRoute,
  putWatchTokenRoute,
} from '../src/routes.js'
import { makeRequest, makeToken, migratedSql } from './helpers.js'

const accountKey = makeToken(1)
const watchToken = makeToken(101)
const readiness = { day: '2026-11-12', score: 63, verdict: 'Moderado' }
const face = {
  vo2Delta: 1.2,
  weekPlannedKm: 51.8,
  weekGoalKm: 45,
  workout: 'Intervalado 5×1000 m',
  workoutShape: [[30, 2], [9, 4], [5, 1], [20, 2]],
  workoutTip: 'FC até 165 · gel no km 10',
  raceName: 'Meia de exemplo',
  raceDay: '2026-12-28',
  raceGoal: 5880,
  racePrediction: 5970,
}

function tokenHash(token: string): string {
  return createHash('sha256').update(Buffer.from(token, 'base64url')).digest('hex')
}

function putToken(body: unknown, key = accountKey): Promise<Response> {
  return putWatchTokenRoute(makeRequest('PUT', '/api/v1/watch/token', { token: key, body: JSON.stringify(body) }), sql)
}

function putReadiness(body: unknown, key = accountKey): Promise<Response> {
  return putWatchReadinessRoute(makeRequest('PUT', '/api/v1/watch/readiness', { token: key, body: JSON.stringify(body) }), sql)
}

function getReadiness(token?: string): Promise<Response> {
  return getWatchReadinessRoute(
    makeRequest('GET', '/api/v1/watch/readiness', token === undefined ? {} : { token }),
    sql,
  )
}

let sql: Sql

async function createAccount(key: string, ip: string): Promise<void> {
  const response = await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: key, ip }), sql, new Date())
  expect(response.status).toBe(201)
}

beforeEach(async () => {
  sql = await migratedSql()
  await createAccount(accountKey, '1.1.1.1')
})

describe('PUT /api/v1/watch/token', () => {
  it('grava o hash e responde 204', async () => {
    const response = await putToken({ tokenHash: tokenHash(watchToken) })

    expect(response.status).toBe(204)
    expect(await response.text()).toBe('')
    expect(await sql('select token_hash from watch_tokens')).toEqual([{ token_hash: tokenHash(watchToken) }])
  })

  it('troca o token anterior da conta', async () => {
    const other = makeToken(102)
    await putToken({ tokenHash: tokenHash(watchToken) })
    await putReadiness(readiness)

    const response = await putToken({ tokenHash: tokenHash(other) })

    expect(response.status).toBe(204)
    expect(await sql('select token_hash from watch_tokens')).toEqual([{ token_hash: tokenHash(other) }])
    expect((await getReadiness(watchToken)).status).toBe(401)
    expect((await getReadiness(other)).status).toBe(200)
  })

  it('repetir o mesmo hash mantém um token', async () => {
    await putToken({ tokenHash: tokenHash(watchToken) })

    const response = await putToken({ tokenHash: tokenHash(watchToken) })

    expect(response.status).toBe(204)
    expect(await sql('select token_hash from watch_tokens')).toHaveLength(1)
  })

  it('409 se o hash já é de outra conta, sem mexer no dono', async () => {
    const otherKey = makeToken(2)
    await createAccount(otherKey, '2.2.2.2')
    await putToken({ tokenHash: tokenHash(watchToken) })

    const response = await putToken({ tokenHash: tokenHash(watchToken) }, otherKey)

    expect(response.status).toBe(409)
    expect(await response.json()).toEqual({ error: 'token_conflict' })
    const owners = await sql<{ account_id: string }>('select account_id from watch_tokens')
    expect(owners).toEqual([{ account_id: tokenHash(accountKey) }])
  })

  it.each([
    ['sem tokenHash', {}],
    ['curto', { tokenHash: 'ab' }],
    ['maiúsculo', { tokenHash: 'A'.repeat(64) }],
    ['não hex', { tokenHash: 'g'.repeat(64) }],
    ['número', { tokenHash: 1 }],
  ])('400 invalid_token_hash: %s', async (_name, body) => {
    const response = await putToken(body)

    expect(response.status).toBe(400)
    expect(await response.json()).toEqual({ error: 'invalid_token_hash' })
  })

  it('400 invalid_json', async () => {
    const response = await putWatchTokenRoute(
      makeRequest('PUT', '/api/v1/watch/token', { token: accountKey, body: '{' }),
      sql,
    )

    expect(response.status).toBe(400)
    expect(await response.json()).toEqual({ error: 'invalid_json' })
  })

  it('401 com conta inexistente', async () => {
    const response = await putToken({ tokenHash: tokenHash(watchToken) }, makeToken(9))

    expect(response.status).toBe(401)
    expect(await sql('select * from watch_tokens')).toEqual([])
  })
})

describe('DELETE /api/v1/watch/token', () => {
  it('revoga o token e responde 204', async () => {
    await putToken({ tokenHash: tokenHash(watchToken) })
    await putReadiness(readiness)

    const response = await deleteWatchTokenRoute(makeRequest('DELETE', '/api/v1/watch/token', { token: accountKey }), sql)

    expect(response.status).toBe(204)
    expect(await sql('select * from watch_tokens')).toEqual([])
    expect((await getReadiness(watchToken)).status).toBe(401)
  })

  it('204 sem token cadastrado', async () => {
    const response = await deleteWatchTokenRoute(makeRequest('DELETE', '/api/v1/watch/token', { token: accountKey }), sql)

    expect(response.status).toBe(204)
  })

  it('401 com conta inexistente', async () => {
    const response = await deleteWatchTokenRoute(makeRequest('DELETE', '/api/v1/watch/token', { token: makeToken(9) }), sql)

    expect(response.status).toBe(401)
  })
})

describe('PUT /api/v1/watch/readiness', () => {
  it('faz upsert da nota do dia', async () => {
    const first = await putReadiness(readiness)
    const second = await putReadiness({ day: '2026-11-13', score: 80, verdict: 'Pronto' })

    expect(first.status).toBe(204)
    expect(second.status).toBe(204)
    const rows = await sql<{ day: string; score: number; verdict: string }>(
      "select to_char(day, 'YYYY-MM-DD') as day, score, verdict from readiness",
    )
    expect(rows).toEqual([{ day: '2026-11-13', score: 80, verdict: 'Pronto' }])
  })

  it.each([0, 100])('aceita nota %i', async (score) => {
    expect((await putReadiness({ ...readiness, score })).status).toBe(204)
  })

  it('aceita veredito de 24 caracteres com acento', async () => {
    expect((await putReadiness({ ...readiness, verdict: 'é'.repeat(24) })).status).toBe(204)
  })

  it.each([
    ['dia ausente', { score: 63, verdict: 'Moderado' }, 'invalid_day'],
    ['dia com hora', { ...readiness, day: '2026-11-12T00:00:00Z' }, 'invalid_day'],
    ['dia inexistente', { ...readiness, day: '2026-02-30' }, 'invalid_day'],
    ['mês 13', { ...readiness, day: '2026-13-01' }, 'invalid_day'],
    ['nota negativa', { ...readiness, score: -1 }, 'invalid_score'],
    ['nota acima de 100', { ...readiness, score: 101 }, 'invalid_score'],
    ['nota fracionária', { ...readiness, score: 63.5 }, 'invalid_score'],
    ['nota texto', { ...readiness, score: '63' }, 'invalid_score'],
    ['veredito vazio', { ...readiness, verdict: '' }, 'invalid_verdict'],
    ['veredito com 25', { ...readiness, verdict: 'a'.repeat(25) }, 'invalid_verdict'],
    ['veredito número', { ...readiness, verdict: 1 }, 'invalid_verdict'],
    ['corpo array', [], 'invalid_body'],
  ])('400: %s', async (_name, body, error) => {
    const response = await putReadiness(body)

    expect(response.status).toBe(400)
    expect(await response.json()).toEqual({ error })
    expect(await sql('select * from readiness')).toEqual([])
  })

  it('grava os dados do mostrador e troca por null quando não vêm', async () => {
    await putReadiness({ ...readiness, face: { ...face, extra: 'ignorado' } })
    const withFace = await sql<{ face: unknown }>('select face from readiness')
    await putReadiness(readiness)
    const withoutFace = await sql<{ face: unknown }>('select face from readiness')

    expect(withFace).toEqual([{ face }])
    expect(withoutFace).toEqual([{ face: null }])
  })

  it.each([
    ['face array', []],
    ['vo2Delta texto', { vo2Delta: '1' }],
    ['vo2Delta fora da faixa', { vo2Delta: 25 }],
    ['km negativo', { weekPlannedKm: -1 }],
    ['meta acima do limite', { weekGoalKm: 1001 }],
    ['treino vazio', { workout: '' }],
    ['treino com 41', { workout: 'a'.repeat(41) }],
    ['dica com 41', { workoutTip: 'a'.repeat(41) }],
    ['shape vazio', { workoutShape: [] }],
    ['shape com zona 6', { workoutShape: [[10, 6]] }],
    ['shape com peso 0', { workoutShape: [[0, 2]] }],
    ['shape com 25 passos', { workoutShape: Array.from({ length: 25 }, () => [1, 1]) }],
    ['dia da prova inválido', { raceDay: '2026-02-30' }],
    ['meta fracionária', { raceGoal: 5880.5 }],
  ])('400 invalid_face: %s', async (_name, invalid) => {
    const response = await putReadiness({ ...readiness, face: invalid })

    expect(response.status).toBe(400)
    expect(await response.json()).toEqual({ error: 'invalid_face' })
  })

  it('401 com conta inexistente', async () => {
    const response = await putReadiness(readiness, makeToken(9))

    expect(response.status).toBe(401)
  })

  it('token do relógio não autentica as rotas de conta', async () => {
    await putToken({ tokenHash: tokenHash(watchToken) })

    const readinessPut = await putReadiness(readiness, watchToken)
    const tokenPut = await putToken({ tokenHash: tokenHash(makeToken(103)) }, watchToken)
    const tokenDelete = await deleteWatchTokenRoute(makeRequest('DELETE', '/api/v1/watch/token', { token: watchToken }), sql)
    const pull = await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token: watchToken }), sql)

    expect([readinessPut.status, tokenPut.status, tokenDelete.status, pull.status]).toEqual([401, 401, 401, 401])
    expect(await sql('select token_hash from watch_tokens')).toEqual([{ token_hash: tokenHash(watchToken) }])
  })
})

describe('GET /api/v1/watch/readiness', () => {
  beforeEach(async () => {
    await putToken({ tokenHash: tokenHash(watchToken) })
  })

  it('200 com a nota e no-store', async () => {
    await putReadiness(readiness)

    const response = await getReadiness(watchToken)

    expect(response.status).toBe(200)
    expect(response.headers.get('cache-control')).toBe('no-store')
    expect(await response.json()).toEqual(readiness)
  })

  it('200 com os dados do mostrador junto da nota', async () => {
    await putReadiness({ ...readiness, face })

    const response = await getReadiness(watchToken)

    expect(await response.json()).toEqual({ ...readiness, ...face })
  })

  it('404 no_readiness sem nota', async () => {
    const response = await getReadiness(watchToken)

    expect(response.status).toBe(404)
    expect(response.headers.get('cache-control')).toBe('no-store')
    expect(await response.json()).toEqual({ error: 'no_readiness' })
  })

  it.each([
    ['token desconhecido', makeToken(200)],
    ['token malformado', 'curto'],
    ['chave de conta', accountKey],
  ])('401 com %s', async (_name, token) => {
    await putReadiness(readiness)

    const response = await getReadiness(token)

    expect(response.status).toBe(401)
    expect(response.headers.get('cache-control')).toBe('no-store')
    expect(await response.json()).toEqual({ error: 'unauthorized' })
  })

  it('401 sem Authorization', async () => {
    expect((await getReadiness()).status).toBe(401)
  })

  it('faz uma única query', async () => {
    await putReadiness(readiness)
    let calls = 0
    const counting = Object.assign(
      <T>(text: string, params?: unknown[]) => {
        calls++
        return sql<T>(text, params)
      },
      {
        transaction: (statements: Parameters<Sql['transaction']>[0]) => {
          calls++
          return sql.transaction(statements)
        },
      },
    ) as Sql

    const response = await getWatchReadinessRoute(
      makeRequest('GET', '/api/v1/watch/readiness', { token: watchToken }),
      counting,
    )

    expect(response.status).toBe(200)
    expect(calls).toBe(1)
  })

  it('grava no request_log só método, rota, status e prefixo da conta', async () => {
    await getReadiness(watchToken)
    await putReadiness(readiness)
    await getReadiness(watchToken)
    await getReadiness(makeToken(200))

    const rows = await sql<{ method: string; route: string; status: number; record_count: number | null; account_prefix: string }>(
      "select method, route, status, record_count, account_prefix from request_log where route = 'watch/readiness' order by id",
    )
    const prefix = tokenHash(accountKey).slice(0, 8)
    expect(rows).toEqual([
      { method: 'GET', route: 'watch/readiness', status: 404, record_count: null, account_prefix: prefix },
      { method: 'PUT', route: 'watch/readiness', status: 204, record_count: null, account_prefix: prefix },
      { method: 'GET', route: 'watch/readiness', status: 200, record_count: null, account_prefix: prefix },
    ])
    const dump = JSON.stringify(await sql('select * from request_log'))
    expect(dump).not.toContain(tokenHash(watchToken).slice(0, 8))
    expect(dump).not.toContain(watchToken)
  })
})

describe('DELETE /api/v1/account com relógio', () => {
  it('apaga token e nota em cascata', async () => {
    await putToken({ tokenHash: tokenHash(watchToken) })
    await putReadiness(readiness)

    const response = await deleteAccountRoute(makeRequest('DELETE', '/api/v1/account', { token: accountKey }), sql)

    expect(response.status).toBe(204)
    expect(await sql('select * from watch_tokens')).toEqual([])
    expect(await sql('select * from readiness')).toEqual([])
    expect((await getReadiness(watchToken)).status).toBe(401)
  })
})
