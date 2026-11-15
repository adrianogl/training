import { randomBytes } from 'node:crypto'
import { Encoder } from '@garmin/fitsdk'
import { zipSync } from 'fflate'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { open, seal } from '../src/cipher.js'
import { FIT } from '../src/fit/fitConstants.js'
import { fetchFits, fitFor, missingFitIds, readRunMetrics, recalculateMetrics } from '../src/fit/fitStore.js'
import { saveConnection } from '../src/garmin.js'
import { createAccountRoute } from '../src/routes.js'
import type { GarminEnv } from '../src/types.js'
import { makeRequest, makeToken, migratedSql } from './helpers.js'

const key = randomBytes(32)
const token = makeToken(31)
let sql: Sql
let accountId: string
let downloads: number[]

function zip(): Uint8Array {
  const encoder = new Encoder()
  const write = (mesgNum: number, mesg: Record<string, unknown>) => encoder.onMesg(mesgNum, mesg as never)
  const start = new Date('2026-11-12T09:10:00.000Z')
  write(0, { type: 'activity', manufacturer: 'development', product: 0, timeCreated: start, serialNumber: 1 })
  for (let second = 0; second < 10; second += 1) write(20, { timestamp: new Date(start.getTime() + second * 1000), heartRate: 140, distance: second * 3 })
  return zipSync({ 'atividade.fit': encoder.close() })
}

function env(status = 200): GarminEnv {
  const fetcher = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input))
    const id = Number(url.pathname.split('/').at(-1))
    downloads.push(id)
    if (status !== 200) return new Response('', { status })
    expect(init?.headers).toMatchObject({ accept: '*/*' })
    if (id === 404) return new Response('', { status: 404 })
    if (id === 500) return new Response(Buffer.from([1, 2, 3]))
    return new Response(Buffer.from(zip()))
  }) as typeof fetch
  return { dataKey: key, fetcher, now: () => new Date('2026-11-14T12:00:00.000Z') }
}

describe('FITs guardados', () => {
  beforeEach(async () => {
    sql = await migratedSql()
    downloads = []
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token }), sql)
    accountId = (await sql<{ id: string }>('select id from accounts'))[0]?.id ?? ''
    await saveConnection(sql, key, accountId, { accessToken: 'a', refreshToken: 'r', clientId: 'C', expiresAt: '2030-01-01T00:00:00.000Z' })
  })

  it('baixa, lê e guarda cifrado; na segunda vez usa o cache', async () => {
    const first = await fitFor(sql, { ...env(), dataKey: key }, accountId, 11)
    const second = await fitFor(sql, { ...env(), dataKey: key }, accountId, 11)
    const stored = await sql<{ data_enc: string }>('select data_enc from activity_fit')
    expect(first?.samples).toHaveLength(2)
    expect(second).toEqual(first)
    expect(downloads).toEqual([11])
    expect(stored[0]?.data_enc).not.toContain('samples')
  })

  it('backfill respeita o limite, pula 404 e FIT inválido', async () => {
    const fetched = await fetchFits(sql, { ...env(), dataKey: key }, accountId, [1, 404, 500, 2, 3], 4)
    expect(fetched).toBe(2)
    expect(downloads).toEqual([1, 404, 500, 2])
    expect(await missingFitIds(sql, accountId, [1, 2, 3, 404])).toEqual([3, 404])
  })

  it('recusa da Garmin no download não derruba: o FIT fica faltando', async () => {
    const fetched = await fetchFits(sql, { ...env(403), dataKey: key }, accountId, [1, 2], 2)
    expect(fetched).toBe(0)
    expect(await missingFitIds(sql, accountId, [1, 2])).toEqual([1, 2])
  })

  it('para no 429 da Garmin', async () => {
    await expect(fetchFits(sql, { ...env(429), dataKey: key }, accountId, [1, 2], 2)).rejects.toThrow()
  })

  describe('recálculo das métricas', () => {
    const summary = {
      version: FIT.processingVersion,
      samples: [],
      route: [],
      physio: null,
      zoneInfo: null,
      structure: {
        prescription: { name: null, description: null, steps: [{ index: 0, intensity: 'active', duration: { kind: 'distance', meters: 1000 }, target: { kind: 'open' } }] },
        laps: [{ stepIndex: 0, intensity: 'active', trigger: 'distance', startOffset: 0, timerSeconds: 300, distance: 1000, avgSpeed: 3.33, avgHeartRate: 170, maxHeartRate: 175 }],
      },
    }

    async function insertOld(id: number, data: string = JSON.stringify(summary)): Promise<void> {
      await sql(
        'insert into activity_fit (account_id, activity_id, version, data_enc, metrics_enc, metrics_version) values ($1, $2, $3, $4, $5, 0)',
        [accountId, id, FIT.processingVersion, seal(key, data, `activity-fit:${accountId}:${id}`), seal(key, '{"zone2Pace":null,"thresholdPace":null,"decoupling":null,"hillIndex":null}', `activity-fit-metrics:${accountId}:${id}`)],
      )
    }

    it('FIT antiga ganha workPace e passa a valer na versão nova', async () => {
      await insertOld(1)
      expect(await recalculateMetrics(sql, key, accountId, 20)).toBe(1)
      const metrics = (await readRunMetrics(sql, key, accountId, [1])).get(1)
      expect(metrics?.workPace).toEqual({ seconds: 300, meters: 1000 })
      const [row] = await sql<{ metrics_version: number }>('select metrics_version from activity_fit')
      expect(row?.metrics_version).toBe(FIT.metricsVersion)
    })

    it('respeita o limite por rodada', async () => {
      for (const id of [1, 2, 3]) await insertOld(id)
      expect(await recalculateMetrics(sql, key, accountId, 2)).toBe(2)
      expect(await recalculateMetrics(sql, key, accountId, 2)).toBe(1)
      expect(await recalculateMetrics(sql, key, accountId, 2)).toBe(0)
    })

    it('data_enc inválido não bloqueia as outras e não é tentado de novo', async () => {
      await insertOld(1, 'não é json')
      await insertOld(2)
      expect(await recalculateMetrics(sql, key, accountId, 20)).toBe(1)
      const rows = await sql<{ activity_id: string; metrics_version: number; metrics_enc: string }>('select activity_id, metrics_version, metrics_enc from activity_fit order by activity_id')
      expect(rows.map((row) => row.metrics_version)).toEqual([FIT.metricsVersion, FIT.metricsVersion])
      expect(open(key, rows[0]?.metrics_enc ?? '', `activity-fit-metrics:${accountId}:1`)).toContain('zone2Pace')
      expect(await recalculateMetrics(sql, key, accountId, 20)).toBe(0)
    })

    it('FIT já na versão nova não é reprocessada', async () => {
      await fetchFits(sql, { ...env(), dataKey: key }, accountId, [1], 1)
      const before = await sql<{ metrics_enc: string }>('select metrics_enc from activity_fit')
      expect(await recalculateMetrics(sql, key, accountId, 20)).toBe(0)
      expect(await sql<{ metrics_enc: string }>('select metrics_enc from activity_fit')).toEqual(before)
    })
  })
})
