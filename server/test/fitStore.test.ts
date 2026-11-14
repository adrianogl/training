import { randomBytes } from 'node:crypto'
import { Encoder } from '@garmin/fitsdk'
import { zipSync } from 'fflate'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { fetchFits, fitFor, missingFitIds } from '../src/fit/fitStore.js'
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
})
