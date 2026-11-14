import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import { detailedActivityRoute } from '../src/activityRoutes.js'
import { detailedAnalysis } from '../src/analysis/detailedAnalysis.js'
import { dispatch } from '../src/apiRouter.js'
import { seal } from '../src/cipher.js'
import type { Sql } from '../src/db.js'
import { storeFit } from '../src/fit/fitStore.js'
import { saveConnection } from '../src/garmin.js'
import { saveActivity } from '../src/garminSync.js'
import { writeGoal } from '../src/goals.js'
import { createAccountRoute } from '../src/routes.js'
import type { GarminEnv } from '../src/types.js'
import { longGoal, scenarioInput } from './detailedScenario.js'
import { makeRequest, makeToken, migratedSql } from './helpers.js'

const key = randomBytes(32)
const token = makeToken(43)
let sql: Sql
let accountId: string
let downloads: string[]

function env(): GarminEnv {
  const fetcher = (async (input: string | URL | Request) => {
    const url = new URL(String(input))
    if (url.pathname.startsWith('/download-service/')) downloads.push(url.pathname)
    return new Response('', { status: 404 })
  }) as typeof fetch
  return { dataKey: key, fetcher, now: () => new Date('2026-11-14T15:00:00.000Z') }
}

async function call(path: string) {
  const response = await detailedActivityRoute(makeRequest('GET', path, { token }), sql, env())
  return { status: response.status, body: await response.json() }
}

describe('rota da análise detalhada', () => {
  beforeEach(async () => {
    sql = await migratedSql()
    downloads = []
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token }), sql)
    accountId = (await sql<{ id: string }>('select id from accounts'))[0]?.id ?? ''
    await saveConnection(sql, key, accountId, { accessToken: 'a', refreshToken: 'r', clientId: 'C', expiresAt: '2030-01-01T00:00:00.000Z' })
    const input = scenarioInput()
    for (const run of [input.current, ...input.runs]) {
      await saveActivity(sql, key, accountId, run.activity)
      if (run.fit !== null) await storeFit(sql, key, accountId, run.activity.id, run.fit)
    }
    for (const day of input.days) {
      await sql('insert into health_days (account_id, day, data_enc) values ($1, $2, $3)', [accountId, day.day, seal(key, JSON.stringify(day), `health-day:${accountId}:${day.day}`)])
    }
    await writeGoal(sql, key, accountId, longGoal, Number.MAX_SAFE_INTEGER)
  })

  it('devolve a mesma análise do domínio com os dados guardados', async () => {
    const { status, body } = await call('/api/v1/garmin/activity/detailed?id=100')
    expect(status).toBe(200)
    expect(body.analysis).toEqual(detailedAnalysis(scenarioInput()))
    expect(body.analysis.kind).toBe('long')
    expect(body.analysis.fadeKm).toBe(10)
    expect(body.analysis.similar).toHaveLength(8)
    expect(downloads).toEqual([])
  })

  it('tenta baixar o FIT dos parecidos que ainda não estão guardados', async () => {
    await sql('delete from activity_fit where activity_id = 12')
    const { status, body } = await call('/api/v1/garmin/activity/detailed?id=100')
    expect(status).toBe(200)
    expect(downloads).toEqual(['/download-service/files/activity/12'])
    expect(body.analysis.similar.find((item: { activityId: number }) => item.activityId === 12).noPauses).toBeNull()
  })

  it('responde 400 para id inválido, 404 para treino desconhecido ou sem FIT e 400 fora de corrida', async () => {
    expect((await call('/api/v1/garmin/activity/detailed?id=x')).status).toBe(400)
    expect((await call('/api/v1/garmin/activity/detailed?id=999')).status).toBe(404)
    await sql('delete from activity_fit where activity_id = 100')
    const missing = await call('/api/v1/garmin/activity/detailed?id=100')
    expect(missing.status).toBe(404)
    expect(missing.body.error).toBe('fit_unavailable')
    const input = scenarioInput()
    await saveActivity(sql, key, accountId, { ...input.current.activity, id: 101, type: 'cycling' })
    const notRun = await call('/api/v1/garmin/activity/detailed?id=101')
    expect(notRun.status).toBe(400)
    expect(notRun.body.error).toBe('not_a_run')
  })

  it('está no roteador e exige login', async () => {
    const response = await dispatch(makeRequest('GET', '/api/v1/garmin/activity/detailed?id=100'), sql)
    expect(response.status).toBe(401)
  })
})
