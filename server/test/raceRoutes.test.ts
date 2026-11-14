import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import { seal } from '../src/cipher.js'
import type { Sql } from '../src/db.js'
import { addDays } from '../src/garminSync.js'
import { saveConnection } from '../src/garmin.js'
import { deleteRaceRoute, racesRoute, saveRaceRoute } from '../src/raceRoutes.js'
import { createAccountRoute, pullChangesRoute, pushChangesRoute } from '../src/routes.js'
import type { ActivitySummary, GarminEnv } from '../src/types.js'
import { makeRequest, makeToken, migratedSql, record } from './helpers.js'

const key = randomBytes(32)
const token = makeToken(21)
const today = '2026-11-14'
let sql: Sql
let accountId: string
let calls: string[]

function fetcher(): typeof fetch {
  return (async (input: string | URL | Request) => {
    const url = new URL(String(input))
    calls.push(`${url.host}${url.pathname}`)
    if (url.pathname.endsWith('/splits')) return Response.json({ lapDTOs: Array.from({ length: 8 }, () => ({ distance: 1000, duration: 285 })) })
    if (url.host.startsWith('geocoding')) return Response.json({ results: [{ latitude: -19.92, longitude: -43.94 }] })
    if (url.pathname === '/v1/forecast') return Response.json({ hourly: { time: [`${url.searchParams.get('start_date')}T07:00`], temperature_2m: [24], dew_point_2m: [19] } })
    return new Response('', { status: 404 })
  }) as typeof fetch
}

const env = (): GarminEnv => ({ dataKey: key, fetcher: fetcher(), now: () => new Date(`${today}T15:00:00.000Z`) })

function run(id: number, day: string, seconds5k: number): ActivitySummary {
  return {
    id, name: 'Rodagem', type: 'running', startLocal: `${day}T07:00:00`, day, distanceMeters: 10000, durationSeconds: 3000, movingSeconds: 2950, elevationGain: 20,
    averageSpeed: 3.3, maxSpeed: 4, averageHeartRate: 140, maxHeartRate: 160, cadence: 170, trainingLoad: 80, aerobicEffect: 3, anaerobicEffect: 1, vo2max: 50,
    zoneSeconds: [100, 2000, 500, 100, 0], fastestKmSeconds: 270, fastest5kSeconds: seconds5k, laps: 10, workoutId: null,
  }
}

async function call(route: typeof racesRoute, method: string, path: string, body?: unknown) {
  const request = makeRequest(method, path, { token, ...(body === undefined ? {} : { body: JSON.stringify(body) }) })
  const response = await route(request, sql, env())
  return { status: response.status, body: response.status === 204 ? null : await response.json() }
}

const edit = { name: 'Meia de exemplo', day: addDays(today, 10), distance: 21097.5, goalSeconds: 5940, priority: 'A', startTime: '07:00', city: 'Belo Horizonte' }

describe('rotas de provas', () => {
  beforeEach(async () => {
    sql = await migratedSql()
    calls = []
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token }), sql)
    accountId = (await sql<{ id: string }>('select id from accounts'))[0]?.id ?? ''
    await saveConnection(sql, key, accountId, { accessToken: 'a', refreshToken: 'r', clientId: 'C', expiresAt: '2030-01-01T00:00:00.000Z' })
    for (let offset = 60; offset >= 0; offset -= 2) {
      const activity = run(1000 + offset, addDays(today, -offset), 1500 + offset)
      await sql('insert into activities (account_id, activity_id, day, data_enc) values ($1, $2, $3, $4)', [accountId, activity.id, activity.day, seal(key, JSON.stringify(activity), `activity:${accountId}:${activity.id}`)])
    }
  })

  it('cria pelo site, calcula e o app recebe no pull', async () => {
    const created = await call(saveRaceRoute, 'POST', '/api/v1/races', edit)
    const list = await call(racesRoute, 'GET', '/api/v1/races')
    const pulled = await (await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token }), sql, key)).json()

    expect(created.status).toBe(201)
    const race = list.body.races[0]
    expect(race).toMatchObject({ id: created.body.id, name: 'Meia de exemplo', status: 'upcoming', daysUntil: 10, locked: false })
    expect(race.outlook.today).toBeGreaterThan(0)
    expect(race.strategy.target.source).toBe('raceDayProjection')
    expect(race.strategy.heat.weather).toEqual({ hour: 7, temperature: 24, dewPoint: 19 })
    expect(race.strategy.heat.fraction).toBeGreaterThan(0)
    expect(race.strategy.kms).toHaveLength(22)
    expect(race.block).toHaveLength(12)
    expect(race.checklist.map((item: { kind: string }) => item.kind)).toEqual(['weeklyVolume', 'racePace', 'tuneUp', 'course', 'goal'])
    expect(calls.filter((call) => call.endsWith('/splits')).length).toBe(15)
    expect(pulled.records[0]).toMatchObject({ kind: 'race', id: created.body.id, format: 'plain' })
    expect(JSON.parse(pulled.records[0].payload)).toMatchObject({ name: 'Meia de exemplo', priority: 'A', goalSeconds: 5940 })
  })

  it('voltas ficam em cache e a busca continua de onde parou', async () => {
    await call(saveRaceRoute, 'POST', '/api/v1/races', edit)
    await call(racesRoute, 'GET', '/api/v1/races')
    calls = []
    await call(racesRoute, 'GET', '/api/v1/races')
    expect(calls.filter((call) => call.endsWith('/splits')).length).toBe(15)
    calls = []
    await call(racesRoute, 'GET', '/api/v1/races')
    expect(calls.filter((call) => call.endsWith('/splits')).length).toBe(1)
    calls = []
    await call(racesRoute, 'GET', '/api/v1/races')
    expect(calls.filter((call) => call.endsWith('/splits')).length).toBe(0)
  })

  it('edita mantendo os campos do app e apaga com tombstone', async () => {
    const id = '6F1C2A4E-0B7D-4C55-9A1E-3D2F8B7C6A10'
    const payload = { id, name: 'Antiga', day: addDays(today, 20), distance: 10000, priority: 'B', gpxData: null, resultActivityId: null, frozenTargetSeconds: 2700, frozenTargetDay: addDays(today, 19), updatedAt: '2026-11-01T10:00:00.000Z' }
    await pushChangesRoute(makeRequest('POST', '/api/v1/changes', { token, body: JSON.stringify({ records: [record({ id, payload: JSON.stringify(payload), format: 'plain', updatedAt: '2026-11-01T10:00:00.000Z' })] }) }), sql, undefined, key)

    const updated = await call(saveRaceRoute, 'PUT', `/api/v1/races?id=${id.toLowerCase()}`, { ...edit, day: addDays(today, 20), manualPaces: [[3, 280]] })
    const list = await call(racesRoute, 'GET', '/api/v1/races')
    const removed = await call(deleteRaceRoute, 'DELETE', `/api/v1/races?id=${id}`)
    const after = await call(racesRoute, 'GET', '/api/v1/races')

    expect(updated.status).toBe(200)
    expect(list.body.races[0]).toMatchObject({ id, name: 'Meia de exemplo', manualPaces: [[3, 280]] })
    expect(list.body.races[0].strategy.target).toEqual({ seconds: 2700, source: 'frozen', frozenOn: addDays(today, 19) })
    expect(removed.status).toBe(204)
    expect(after.body.races).toEqual([])
  })

  it('prova ainda cifrada pelo app aparece travada e não edita', async () => {
    await pushChangesRoute(makeRequest('POST', '/api/v1/changes', { token, body: JSON.stringify({ records: [record({ id: 'legado' })] }) }), sql, undefined, key)
    const list = await call(racesRoute, 'GET', '/api/v1/races')
    const save = await call(saveRaceRoute, 'PUT', '/api/v1/races?id=legado', edit)
    expect(list.body.races).toEqual([expect.objectContaining({ id: 'legado', status: 'locked', locked: true })])
    expect(save.status).toBe(409)
  })

  it('valida o corpo e a prova inexistente', async () => {
    const bad = await call(saveRaceRoute, 'POST', '/api/v1/races', { ...edit, priority: 'Z' })
    const time = await call(saveRaceRoute, 'POST', '/api/v1/races', { ...edit, startTime: '25:00' })
    const missing = await call(saveRaceRoute, 'PUT', '/api/v1/races?id=nao-existe', edit)
    const gone = await call(deleteRaceRoute, 'DELETE', '/api/v1/races?id=nao-existe')
    expect([bad.body.error, time.body.error, missing.status, gone.status]).toEqual(['invalid_priority', 'invalid_start_time', 404, 404])
  })

  it('prova feita mostra o resultado e prova longe não busca o tempo', async () => {
    await call(saveRaceRoute, 'POST', '/api/v1/races', { ...edit, day: addDays(today, 60) })
    calls = []
    const list = await call(racesRoute, 'GET', '/api/v1/races')
    expect(list.body.races[0].strategy.weatherNote).toBe('tooFar')
    expect(calls.some((call) => call.includes('forecast'))).toBe(false)
  })
})
