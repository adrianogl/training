import { randomBytes } from 'node:crypto'
import { Encoder } from '@garmin/fitsdk'
import { zipSync } from 'fflate'
import { beforeEach, describe, expect, it } from 'vitest'
import { activityRoute, plannedRoute, renameActivityRoute, shortDay } from '../src/activityRoutes.js'
import { seal } from '../src/cipher.js'
import type { Sql } from '../src/db.js'
import { saveConnection } from '../src/garmin.js'
import { createAccountRoute } from '../src/routes.js'
import type { ActivitySummary, GarminEnv } from '../src/types.js'
import { makeRequest, makeToken, migratedSql } from './helpers.js'

const key = randomBytes(32)
const token = makeToken(41)
let sql: Sql
let accountId: string
let calls: { method: string; path: string; body: string | null }[]

function intervalFit(start: Date, sprintSeconds: number, sprintHeartRate: number): Uint8Array {
  const encoder = new Encoder()
  const write = (mesgNum: number, mesg: Record<string, unknown>) => encoder.onMesg(mesgNum, mesg as never)
  const at = (seconds: number) => new Date(start.getTime() + seconds * 1000)
  write(0, { type: 'activity', manufacturer: 'development', product: 0, timeCreated: start, serialNumber: 1 })
  write(26, { wktName: 'Tiros 3 x 1000', sport: 'running', numValidSteps: 4 })
  write(27, { messageIndex: 0, intensity: 'warmup', durationType: 'time', durationValue: 600_000, targetType: 'open' })
  write(27, { messageIndex: 1, intensity: 'active', durationType: 'distance', durationValue: 100_000, targetType: 'speed', targetValue: 0, customTargetValueLow: 3_900, customTargetValueHigh: 4_300 })
  write(27, { messageIndex: 2, intensity: 'recovery', durationType: 'time', durationValue: 120_000, targetType: 'open' })
  write(27, { messageIndex: 3, durationType: 'repeatUntilStepsCmplt', durationValue: 1, targetType: 'open', targetValue: 3 })
  const segments: [number, string, number, number, number][] = [[0, 'warmup', 600, 1800, 130]]
  for (let i = 0; i < 3; i += 1) segments.push([1, 'active', sprintSeconds, 1000, sprintHeartRate], [2, 'recovery', 120, 250, 140])
  let t = 0
  let meters = 0
  for (const [stepIndex, intensity, seconds, distance, heartRate] of segments) {
    for (let s = 0; s < seconds; s += 5) write(20, { timestamp: at(t + s), heartRate, distance: meters + (distance * s) / seconds, enhancedSpeed: distance / seconds })
    write(19, { timestamp: at(t + seconds), startTime: at(t), totalTimerTime: seconds, totalDistance: distance, enhancedAvgSpeed: distance / seconds, avgHeartRate: heartRate, maxHeartRate: heartRate + 8, intensity, lapTrigger: 'distance', wktStepIndex: stepIndex })
    t += seconds
    meters += distance
  }
  write(216, { timestamp: at(t), referenceMesg: 'session', referenceIndex: 0, hrZoneHighBoundary: [120, 135, 147, 160, 175], hrCalcType: 'percentMaxHr', maxHeartRate: 190, restingHeartRate: 48 })
  return zipSync({ 'a.fit': encoder.close() })
}

function summary(id: number, day: string, name: string): ActivitySummary {
  return {
    id, name, type: 'running', startLocal: `${day}T07:00:00`, day, distanceMeters: 5550, durationSeconds: 1700, movingSeconds: 1680, elevationGain: 10,
    averageSpeed: 3.3, maxSpeed: 4.3, averageHeartRate: 150, maxHeartRate: 175, cadence: 172, trainingLoad: 90, aerobicEffect: 3, anaerobicEffect: 2, vo2max: 52,
    zoneSeconds: [100, 600, 400, 400, 100], fastestKmSeconds: 240, fastest5kSeconds: null, laps: 7, workoutId: 77,
  }
}

const fits = new Map<number, Uint8Array>([
  [1, intervalFit(new Date('2026-11-12T10:00:00Z'), 240, 165)],
  [2, intervalFit(new Date('2026-11-05T10:00:00Z'), 245, 170)],
  [3, intervalFit(new Date('2026-10-29T10:00:00Z'), 250, 172)],
])

function env(status = 200): GarminEnv {
  const fetcher = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input))
    calls.push({ method: init?.method ?? 'GET', path: url.pathname, body: typeof init?.body === 'string' ? init.body : null })
    if (status !== 200) return new Response('', { status })
    if (url.pathname.startsWith('/download-service/')) {
      const fit = fits.get(Number(url.pathname.split('/').at(-1)))
      return fit === undefined ? new Response('', { status: 404 }) : new Response(Buffer.from(fit))
    }
    if (url.pathname.startsWith('/activity-service/activity/')) return new Response(null, { status: 204 })
    if (url.pathname === '/calendar-service/year/2026/month/10') return Response.json({ calendarItems: [{ itemType: 'workout', date: '2026-11-17', title: 'Rodagem', workoutId: 501, sportTypeKey: 'running' }, { itemType: 'workout', date: '2026-11-15', title: 'Tiros', workoutId: 500, sportTypeKey: 'running' }] })
    if (url.pathname === '/workout-service/workout/500') return Response.json({ workoutId: 500, workoutName: 'Tiros 5x1000', estimatedDistanceInMeters: 9800, estimatedDurationInSecs: 3300 })
    if (url.pathname === '/workout-service/workout/501') return Response.json({ workoutId: 501, workoutName: 'Rodagem 8 km', estimatedDistanceInMeters: 8000 })
    return new Response('', { status: 404 })
  }) as typeof fetch
  return { dataKey: key, fetcher, now: () => new Date('2026-11-14T15:00:00.000Z') }
}

async function call(route: typeof activityRoute, method: string, path: string, value?: unknown, garmin = env()) {
  const response = await route(makeRequest(method, path, { token, ...(value === undefined ? {} : { body: JSON.stringify(value) }) }), sql, garmin)
  return { status: response.status, body: await response.json() }
}

describe('rota do treino', () => {
  beforeEach(async () => {
    sql = await migratedSql()
    calls = []
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token }), sql)
    accountId = (await sql<{ id: string }>('select id from accounts'))[0]?.id ?? ''
    await saveConnection(sql, key, accountId, { accessToken: 'a', refreshToken: 'r', clientId: 'C', expiresAt: '2030-01-01T00:00:00.000Z' })
    for (const item of [summary(1, '2026-11-12', 'Tiros'), summary(2, '2026-11-05', 'Tiros'), summary(3, '2026-10-29', 'Tiros')]) {
      await sql('insert into activities (account_id, activity_id, day, data_enc) values ($1, $2, $3, $4)', [accountId, item.id, item.day, seal(key, JSON.stringify(item), `activity:${accountId}:${item.id}`)])
    }
  })

  it('analisa o treino com blocos, avaliação em texto, nota e comparação', async () => {
    const { status, body } = await call(activityRoute, 'GET', '/api/v1/garmin/activity?id=1')
    const analysis = body.analysis
    expect(status).toBe(200)
    expect(analysis.workoutName).toBe('Tiros 3 x 1000')
    expect(analysis.blocks.map((b: { label: string }) => b.label)).toEqual(['Aquecimento', 'Tiro 1', 'Recuperação 1', 'Tiro 2', 'Recuperação 2', 'Tiro 3', 'Recuperação 3'])
    expect(analysis.blocks.filter((b: { kind: string }) => b.kind === 'active').every((b: { status: string }) => b.status === 'inTarget')).toBe(true)
    expect(analysis.findings[0].text).toBe('Todos os blocos ativos dentro do alvo prescrito: 3 de 3.')
    expect(analysis.score.value).toBeGreaterThan(0)
    expect(analysis.comparison.rows.map((r: { activityId: number }) => r.activityId)).toEqual([1, 2, 3])
    expect(analysis.comparison.evolution).toMatch(/s\/km mais rápido, FC \d+ bpm menor, em relação a 29 de out\./)
    expect(analysis.zoneSeconds).toHaveLength(5)
    expect(analysis.splits.length).toBeGreaterThan(0)
    expect(calls.filter((c) => c.path.startsWith('/download-service/')).length).toBe(3)
  })

  it('usa o cache na segunda abertura e responde 404 para treino desconhecido', async () => {
    await call(activityRoute, 'GET', '/api/v1/garmin/activity?id=1')
    calls = []
    await call(activityRoute, 'GET', '/api/v1/garmin/activity?id=1')
    expect(calls).toEqual([])
    expect((await call(activityRoute, 'GET', '/api/v1/garmin/activity?id=999')).status).toBe(404)
    expect((await call(activityRoute, 'GET', '/api/v1/garmin/activity?id=x')).status).toBe(400)
  })

  it('renomeia na Garmin e no cache', async () => {
    const renamed = await call(renameActivityRoute, 'PUT', '/api/v1/garmin/activity?id=1', { name: '  Tiros na pista  ' })
    const after = await call(activityRoute, 'GET', '/api/v1/garmin/activity?id=1')
    const put = calls.find((c) => c.method === 'PUT')
    expect(renamed).toEqual({ status: 200, body: { id: 1, name: 'Tiros na pista' } })
    expect(put?.path).toBe('/activity-service/activity/1')
    expect(JSON.parse(put?.body ?? '{}')).toEqual({ activityId: 1, activityName: 'Tiros na pista' })
    expect(after.body.activity.name).toBe('Tiros na pista')
    expect((await call(renameActivityRoute, 'PUT', '/api/v1/garmin/activity?id=1', { name: '' })).body.error).toBe('invalid_activity_name')
    expect((await call(renameActivityRoute, 'PUT', '/api/v1/garmin/activity?id=1', { name: 'x' }, env(429))).status).toBe(429)
  })

  it('data curta em português', () => {
    expect([shortDay('2026-10-29'), shortDay('2026-01-05')]).toEqual(['29 de out', '5 de jan'])
  })

  it('lista os treinos planejados dos próximos 14 dias em ordem', async () => {
    const { status, body } = await call(plannedRoute, 'GET', '/api/v1/garmin/planned')
    expect(status).toBe(200)
    expect(body.planned.map((item: { day: string; title: string }) => [item.day, item.title])).toEqual([['2026-11-15', 'Tiros 5x1000'], ['2026-11-17', 'Rodagem 8 km']])
    expect(calls.map((c) => c.path)).toContain('/calendar-service/year/2026/month/10')
  })
})
