import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import { dispatch } from '../src/apiRouter.js'
import type { Sql } from '../src/db.js'
import { trainerRoute } from '../src/trainerRoutes.js'
import { createAccountRoute, pushChangesRoute } from '../src/routes.js'
import type { GarminEnv } from '../src/types.js'
import { makeRequest, makeToken, migratedSql, record } from './helpers.js'

const key = randomBytes(32)
const token = makeToken(41)
const plan = { target: { kind: 'race', name: 'Meia de exemplo' }, paces: {}, weeks: [], workouts: [], versions: [] }
const limits = { maxAccounts: 3, maxAccountBytes: 50 * 1024 * 1024 }
const env: GarminEnv = { dataKey: key, fetcher: (async () => new Response('', { status: 404 })) as typeof fetch, now: () => new Date('2026-11-14T15:00:00.000Z') }
let sql: Sql

async function push(item: ReturnType<typeof record>) {
  const response = await pushChangesRoute(makeRequest('POST', '/api/v1/changes', { token, body: JSON.stringify({ records: [item] }) }), sql, limits, key)
  expect(response.status).toBe(200)
}

async function read() {
  const response = await trainerRoute(makeRequest('GET', '/api/v1/trainer', { token }), sql, env)
  return { status: response.status, body: await response.json() }
}

describe('rota do treinador', () => {
  beforeEach(async () => {
    sql = await migratedSql()
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token }), sql)
  })

  it('devolve o plano enviado pelo app em plain', async () => {
    await push(record({ kind: 'trainer', id: 'plan', payload: JSON.stringify(plan), format: 'plain' }))

    expect(await read()).toEqual({ status: 200, body: plan })
  })

  it('responde 404 sem plano, com plano selado pelo aparelho e com tombstone', async () => {
    expect((await read()).status).toBe(404)
    await push(record({ kind: 'trainer', id: 'plan', payload: 'c2VsYWRv' }))
    expect((await read()).status).toBe(404)
    await push(record({ kind: 'trainer', id: 'plan', updatedAt: '2026-11-12T18:31:00.000Z', deleted: true, payload: null, format: 'plain' }))
    expect((await read()).status).toBe(404)
  })

  it('exige sessão e fica registrada no roteador', async () => {
    const anonymous = await trainerRoute(makeRequest('GET', '/api/v1/trainer'), sql, env)
    const wrongMethod = await dispatch(makeRequest('POST', '/api/v1/trainer', { token }), sql)

    expect(anonymous.status).toBe(401)
    expect(wrongMethod.status).toBe(405)
  })
})
