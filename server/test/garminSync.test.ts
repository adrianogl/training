import { randomBytes } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { saveConnection } from '../src/garmin.js'
import { parseActivity, parseHealthDay } from '../src/garminParse.js'
import { garminActivitiesRoute, garminCronRoute, garminEvolutionRoute, garminDaysRoute, garminSyncRoute } from '../src/garminRoutes.js'
import { addDays, localDay } from '../src/garminSync.js'
import { createAccountRoute } from '../src/routes.js'
import type { GarminEnv } from '../src/types.js'
import { makeRequest, makeToken, migratedSql } from './helpers.js'

const key = randomBytes(32)
const token = makeToken(11)

const summary = (day: string) => ({ calendarDate: day, restingHeartRate: 48, averageStressLevel: 30, totalSteps: 9000, bodyBatteryHighestValue: 80, bodyBatteryLowestValue: 20, bodyBatteryAtWakeTime: 78, bodyBatteryChargedValue: 60, bodyBatteryDrainedValue: 50 })
const hrv = (day: string) => ({ hrvSummary: { calendarDate: day, weeklyAvg: 50, lastNightAvg: 52, status: 'BALANCED', baseline: { lowUpper: 44, balancedLow: 47, balancedUpper: 56 } } })
const sleep = (day: string) => ({ dailySleepDTO: { calendarDate: day, sleepTimeSeconds: 27000, deepSleepSeconds: 5000, lightSleepSeconds: 15000, remSleepSeconds: 5000, awakeSleepSeconds: 2000, sleepStartTimestampGMT: 1_800_000_000_000, sleepEndTimestampGMT: 1_800_027_000_000, sleepScores: { overall: { value: 81 } } } })
const readiness = (day: string) => [
  { calendarDate: day, timestamp: `${day}T05:00:00.0`, score: 60, level: 'MODERATE', sleepScore: 81, recoveryTime: 600, acuteLoad: 900 },
  { calendarDate: day, timestamp: `${day}T09:00:00.0`, score: 72, level: 'HIGH', sleepScore: 81, recoveryTime: 300, acuteLoad: 900 },
]
const activity = (id: number, start: string) => ({
  activityId: id, activityName: 'Rodagem', startTimeLocal: start, activityType: { typeKey: 'running' }, distance: 8000, duration: 2700, movingDuration: 2650,
  averageSpeed: 2.96, maxSpeed: 4, averageHR: 140, maxHR: 160, activityTrainingLoad: 80, vO2MaxValue: 50, hrTimeInZone_1: 100, hrTimeInZone_2: 2000, hrTimeInZone_3: 500, hrTimeInZone_4: 100, hrTimeInZone_5: 0, lapCount: 8,
})

let sql: Sql
let now: Date
let calls: string[]

function fakeGarmin(activities: unknown[]): typeof fetch {
  return (async (input: string | URL | Request) => {
    const url = new URL(String(input))
    calls.push(url.pathname)
    const path = url.pathname
    const day = url.searchParams.get('calendarDate') ?? url.searchParams.get('date') ?? path.split('/').at(-1) ?? ''
    if (path.endsWith('/socialProfile')) return Response.json({ displayName: 'corredor' })
    if (path.includes('/usersummary/daily/')) return Response.json(summary(day))
    if (path.startsWith('/hrv-service/')) return Response.json(hrv(day))
    if (path.includes('/dailySleepData/')) return Response.json(sleep(day))
    if (path.includes('/trainingreadiness/')) return Response.json(readiness(day))
    if (path.includes('/activities/search/activities')) {
      const start = Number(url.searchParams.get('start'))
      return Response.json(activities.slice(start, start + 50))
    }
    return new Response('', { status: 404 })
  }) as typeof fetch
}

function env(fetcher: typeof fetch): GarminEnv {
  return { dataKey: key, fetcher, now: () => now }
}

beforeEach(async () => {
  sql = await migratedSql()
  now = new Date('2026-11-14T15:00:00.000Z')
  calls = []
  await createAccountRoute(makeRequest('POST', '/api/v1/account', { token }), sql)
  const [account] = await sql<{ id: string }>('select id from accounts')
  await saveConnection(sql, key, account?.id ?? '', { accessToken: 'a', refreshToken: 'r', clientId: 'C', expiresAt: '2030-01-01T00:00:00.000Z' })
})

describe('parsers', () => {
  it('pega a prontidão mais recente do dia e ignora sono vazio', () => {
    const day = parseHealthDay('2026-11-14', summary('2026-11-14'), hrv('2026-11-14'), { dailySleepDTO: { sleepTimeSeconds: 0 } }, readiness('2026-11-14'))

    expect(day.readiness?.score).toBe(72)
    expect(day.sleep).toBeNull()
    expect(day.hrv?.lastNight).toBe(52)
    expect(day.restingHeartRate).toBe(48)
  })

  it('lê a atividade com as zonas e o dia local', () => {
    const parsed = parseActivity(activity(7, '2026-11-12 19:01:07'))

    expect(parsed?.day).toBe('2026-11-12')
    expect(parsed?.startLocal).toBe('2026-11-12T19:01:07')
    expect(parsed?.zoneSeconds).toEqual([100, 2000, 500, 100, 0])
    expect(parseActivity({ activityName: 'sem id' })).toBeUndefined()
  })

  it('dia local em São Paulo', () => {
    expect(localDay(new Date('2026-11-15T01:00:00.000Z'))).toBe('2026-11-14')
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28')
  })
})

describe('sync', () => {
  it('a primeira carga vai em lotes até 180 dias e guarda tudo cifrado', async () => {
    const list = [activity(3, '2026-11-13 07:00:00'), activity(2, '2026-11-10 07:00:00'), activity(1, '2025-01-01 07:00:00')]
    const request = () => makeRequest('POST', '/api/v1/garmin/sync', { token })

    let progress = (await (await garminSyncRoute(request(), sql, env(fakeGarmin(list)))).json()) as { done: boolean; days: number; activities: number }
    let rounds = 1
    while (!progress.done && rounds < 20) {
      progress = (await (await garminSyncRoute(request(), sql, env(fakeGarmin(list)))).json()) as { done: boolean; days: number; activities: number }
      rounds += 1
    }
    const days = await sql<{ count: number }>('select count(*)::int as count from health_days')
    const stored = await sql<{ data_enc: string }>('select data_enc from health_days limit 1')

    expect(progress.done).toBe(true)
    expect(days[0]?.count).toBe(181)
    expect(await sql('select activity_id from activities order by activity_id')).toEqual([{ activity_id: 2 }, { activity_id: 3 }])
    expect(stored[0]?.data_enc).not.toContain('BALANCED')
  })

  it('depois da carga, só os dias recentes e as atividades novas', async () => {
    const list = [activity(3, '2026-11-13 07:00:00')]
    for (let round = 0; round < 20; round += 1) {
      const body = (await (await garminSyncRoute(makeRequest('POST', '/api/v1/garmin/sync', { token }), sql, env(fakeGarmin(list)))).json()) as { done: boolean }
      if (body.done) break
    }
    calls = []

    await garminSyncRoute(makeRequest('POST', '/api/v1/garmin/sync', { token }), sql, env(fakeGarmin([activity(4, '2026-11-14 07:00:00'), ...list])))

    expect(calls.filter((path) => path.startsWith('/hrv-service/'))).toHaveLength(3)
    expect(calls.filter((path) => path.endsWith('/socialProfile'))).toHaveLength(0)
    expect(await sql('select activity_id from activities order by activity_id')).toEqual([{ activity_id: 3 }, { activity_id: 4 }])
  })

  it('o site lê os dias e as atividades decifrados', async () => {
    await garminSyncRoute(makeRequest('POST', '/api/v1/garmin/sync', { token }), sql, env(fakeGarmin([activity(3, '2026-11-13 07:00:00')])))

    const days = (await (await garminDaysRoute(makeRequest('GET', '/api/v1/garmin/days?from=2026-11-12&to=2026-11-14', { token }), sql, env(fakeGarmin([])))).json()) as { days: { day: string; readiness: { score: number } }[] }
    const activities = (await (await garminActivitiesRoute(makeRequest('GET', '/api/v1/garmin/activities?limit=5', { token }), sql, env(fakeGarmin([])))).json()) as { activities: { id: number; name: string }[] }
    const bad = await garminDaysRoute(makeRequest('GET', '/api/v1/garmin/days?from=2026-01-01&to=2026-11-14', { token }), sql, env(fakeGarmin([])))

    expect(days.days.map((day) => [day.day, day.readiness.score])).toEqual([['2026-11-12', 72], ['2026-11-13', 72], ['2026-11-14', 72]])
    expect(activities.activities.map((item) => [item.id, item.name])).toEqual([[3, 'Rodagem']])
    expect(bad.status).toBe(400)
  })

  it('a evolução usa o período pedido e cai no padrão quando ele não existe', async () => {
    await garminSyncRoute(makeRequest('POST', '/api/v1/garmin/sync', { token }), sql, env(fakeGarmin([activity(3, '2026-11-13 07:00:00')])))

    const short = (await (await garminEvolutionRoute(makeRequest('GET', '/api/v1/garmin/evolution?days=42', { token }), sql, env(fakeGarmin([])))).json()) as { periodDays: number; series: { key: string }[] }
    const fallback = (await (await garminEvolutionRoute(makeRequest('GET', '/api/v1/garmin/evolution?days=7', { token }), sql, env(fakeGarmin([])))).json()) as { periodDays: number }
    const anonymous = await garminEvolutionRoute(makeRequest('GET', '/api/v1/garmin/evolution'), sql, env(fakeGarmin([])))

    expect(short.periodDays).toBe(42)
    expect(short.series.map((item) => item.key)).toContain('vo2max')
    expect(fallback.periodDays).toBe(91)
    expect(anonymous.status).toBe(401)
  })

  it('o cron exige o segredo e passa por todas as contas conectadas', async () => {
    const denied = await garminCronRoute(makeRequest('GET', '/api/v1/cron/garmin-sync'), sql, env(fakeGarmin([])), 'segredo')
    const request = makeRequest('GET', '/api/v1/cron/garmin-sync')
    request.headers.set('authorization', 'Bearer segredo')
    const ok = await garminCronRoute(request, sql, env(fakeGarmin([])), 'segredo')

    expect(denied.status).toBe(401)
    expect(await ok.json()).toEqual({ accounts: 1, synced: 1 })
  })
})
