import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { applyGoalEdit, parseGoalEdit } from '../src/goalInput.js'
import { deleteGoalRoute, goalsRoute, saveGoalRoute } from '../src/goalRoutes.js'
import { createAccountRoute, pullChangesRoute, pushChangesRoute } from '../src/routes.js'
import type { GarminEnv } from '../src/types.js'
import { seal } from '../src/cipher.js'
import { storeFit } from '../src/fit/fitStore.js'
import { FIT } from '../src/fit/fitConstants.js'
import { makeRequest, makeToken, migratedSql, record } from './helpers.js'

const key = randomBytes(32)
const token = makeToken(31)
const today = '2026-11-14'
let sql: Sql

const env = (): GarminEnv => ({ dataKey: key, fetcher: (async () => new Response('', { status: 404 })) as typeof fetch, now: () => new Date(`${today}T15:00:00.000Z`) })

async function call(route: typeof goalsRoute, method: string, path: string, body?: unknown) {
  const request = makeRequest(method, path, { token, ...(body === undefined ? {} : { body: JSON.stringify(body) }) })
  const response = await route(request, sql, env())
  return { status: response.status, body: response.status === 204 ? null : await response.json() }
}

const timeGoal = { kind: 'time', distanceKm: 10, targetSeconds: 2400, deadline: '2027-03-15' }
const longGoal = { kind: 'continuousLong', distanceKm: 16, paceSecondsPerKm: 290 }

describe('validação da meta', () => {
  it('aceita os dois tipos e recusa campos fora da faixa', () => {
    expect(parseGoalEdit(timeGoal)).toMatchObject({ kind: 'time', targetSeconds: 2400, paceSecondsPerKm: null })
    expect(parseGoalEdit(longGoal)).toMatchObject({ kind: 'continuousLong', paceSecondsPerKm: 290, deadline: null })
    expect(parseGoalEdit({ ...timeGoal, kind: 'weight' })).toBe('invalid_goal_kind')
    expect(parseGoalEdit({ ...timeGoal, distanceKm: 0 })).toBe('invalid_distance')
    expect(parseGoalEdit({ ...timeGoal, targetSeconds: 10 })).toBe('invalid_target_time')
    expect(parseGoalEdit({ ...timeGoal, deadline: '15/03/2027' })).toBe('invalid_deadline')
    expect(parseGoalEdit({ ...longGoal, paceSecondsPerKm: 60 })).toBe('invalid_target_pace')
  })

  it('zera a data de cumprida quando o alvo muda', () => {
    const edit = parseGoalEdit(timeGoal)
    if (typeof edit === 'string') throw new Error(edit)
    const current = { ...applyGoalEdit(null, 'A', edit, '2026-11-01T00:00:00.000Z'), achievedAt: '2026-11-10' }
    expect(applyGoalEdit(current, 'A', { ...edit, deadline: null }, '2026-11-14T00:00:00.000Z').achievedAt).toBe('2026-11-10')
    expect(applyGoalEdit(current, 'A', { ...edit, targetSeconds: 2380 }, '2026-11-14T00:00:00.000Z').achievedAt).toBeNull()
  })
})

describe('rotas de metas', () => {
  beforeEach(async () => {
    sql = await migratedSql()
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token }), sql)
  })

  it('cria, lista, edita, arquiva e apaga', async () => {
    const created = await call(saveGoalRoute, 'POST', '/api/v1/goals', timeGoal)
    const long = await call(saveGoalRoute, 'POST', '/api/v1/goals', longGoal)
    expect([created.status, long.status]).toEqual([201, 201])
    const id = created.body.id as string

    const listed = await call(goalsRoute, 'GET', '/api/v1/goals')
    expect(listed.body.goals.map((goal: { kind: string }) => goal.kind).sort()).toEqual(['continuousLong', 'time'])

    const archived = await call(saveGoalRoute, 'PUT', `/api/v1/goals?id=${id}`, { ...timeGoal, archived: true })
    expect(archived.status).toBe(200)
    const after = await call(goalsRoute, 'GET', '/api/v1/goals')
    expect(after.body.goals.map((goal: { id: string; archived: boolean }) => [goal.id === id, goal.archived])).toEqual([[false, false], [true, true]])

    expect((await call(deleteGoalRoute, 'DELETE', `/api/v1/goals?id=${id}`)).status).toBe(204)
    expect((await call(goalsRoute, 'GET', '/api/v1/goals')).body.goals).toHaveLength(1)
  })

  it('recusa prazo no passado e meta inexistente', async () => {
    expect((await call(saveGoalRoute, 'POST', '/api/v1/goals', { ...timeGoal, deadline: '2026-01-01' })).body.error).toBe('invalid_deadline')
    expect((await call(saveGoalRoute, 'PUT', '/api/v1/goals?id=NAO-EXISTE', timeGoal)).status).toBe(404)
  })

  it('a meta criada no site chega ao app pelo pull, aberta', async () => {
    await call(saveGoalRoute, 'POST', '/api/v1/goals', longGoal)
    const pulled = await pullChangesRoute(makeRequest('GET', '/api/v1/changes?since=0', { token }), sql, key)
    const records = (await pulled.json()).records as { kind: string; payload: string }[]
    const goal = records.find((item) => item.kind === 'goal')
    expect(JSON.parse(goal?.payload ?? '{}')).toMatchObject({ kind: 'continuousLong', distanceKm: 16, paceSecondsPerKm: 290 })
  })

  it('a meta enviada pelo app aparece no site', async () => {
    const payload = { id: 'B1', kind: 'time', distanceKm: 10, targetSeconds: 2400, deadline: null, paceSecondsPerKm: null, archived: false, achievedAt: null, createdAt: '2026-11-14T10:00:00.000Z', updatedAt: '2026-11-14T10:00:00.000Z' }
    const pushed = await pushChangesRoute(makeRequest('POST', '/api/v1/changes', { token, body: JSON.stringify({ records: [record({ kind: 'goal', id: 'B1', payload: JSON.stringify(payload), format: 'plain' })] }) }), sql, { maxAccounts: 3, maxAccountBytes: 50 * 1024 * 1024 }, key)
    expect(pushed.status).toBe(200)
    const listed = await call(goalsRoute, 'GET', '/api/v1/goals')
    expect(listed.body.goals[0]).toMatchObject({ id: 'B1', targetSeconds: 2400 })
  })

  it('devolve o progresso da meta de longão a partir do FIT guardado', async () => {
    const accountId = (await sql<{ id: string }>('select id from accounts'))[0]?.id ?? ''
    const activity = { id: 501, name: 'Longão', type: 'running', startLocal: '2026-11-12T07:00:00', day: '2026-11-12', distanceMeters: 16000, durationSeconds: 4560, movingSeconds: 4560, elevationGain: 0, averageSpeed: 3.5, maxSpeed: 4, averageHeartRate: 150, maxHeartRate: 170, cadence: 170, trainingLoad: 150, aerobicEffect: 3.5, anaerobicEffect: 1, vo2max: 52, zoneSeconds: [0, 0, 0, 0, 0], fastestKmSeconds: 270, fastest5kSeconds: 1400, laps: 16, workoutId: null }
    await sql('insert into activities (account_id, activity_id, day, data_enc) values ($1, $2, $3, $4)', [accountId, 501, '2026-11-12', seal(key, JSON.stringify(activity), `activity:${accountId}:501`)])
    const samples = Array.from({ length: 4561 }, (_, t) => ({ t, heartRate: null, speed: null, altitude: null, distance: t < 3000 ? t * 3.5 : t < 3040 ? 10500 : 10500 + (t - 3040) * 3.5 }))
    await storeFit(sql, key, accountId, 501, { version: FIT.processingVersion, samples, route: [], physio: null, structure: { prescription: null, laps: [] }, zoneInfo: null })
    await call(saveGoalRoute, 'POST', '/api/v1/goals', { ...longGoal, paceSecondsPerKm: 300 })

    const listed = await call(goalsRoute, 'GET', '/api/v1/goals')

    const progress = listed.body.goals[0].progress
    expect(progress.kind).toBe('continuousLong')
    expect(progress.runs).toHaveLength(1)
    expect(progress.runs[0].met).toBe(false)
    expect(progress.runs[0].pauses[0].km).toBeCloseTo(10.5, 1)
    expect(progress.bestContinuousKm).toBeCloseTo(10.5, 1)
  })
})
