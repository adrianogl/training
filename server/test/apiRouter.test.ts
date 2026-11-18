import { describe, expect, it } from 'vitest'
import { dispatch, routeKey } from '../src/apiRouter.js'
import { makeRequest, migratedSql } from './helpers.js'

describe('roteador da API', () => {
  it('lê a rota do parâmetro do rewrite ou do caminho original', () => {
    expect(routeKey(new Request('https://x.test/api/router?route=auth/login'))).toBe('auth/login')
    expect(routeKey(new Request('https://x.test/api/v1/watch/readiness'))).toBe('watch/readiness')
    expect(routeKey(new Request('https://x.test/api/v1/changes/?since=3'))).toBe('changes')
  })

  it('despacha pelo método e responde 404 e 405', async () => {
    const sql = await migratedSql()

    const pull = await dispatch(makeRequest('GET', '/api/v1/changes?since=0'), sql)
    const unknown = await dispatch(makeRequest('GET', '/api/v1/nada'), sql)
    const wrongMethod = await dispatch(makeRequest('GET', '/api/v1/auth/login'), sql)

    expect(pull.status).toBe(401)
    expect(unknown.status).toBe(404)
    expect(wrongMethod.status).toBe(405)
    expect(wrongMethod.headers.get('allow')).toBe('POST')
  })

  it('as rotas que só o site usava não existem mais', async () => {
    const sql = await migratedSql()
    const removed = ['garmin/sync', 'garmin/planned', 'garmin/activity', 'garmin/activity/detailed', 'garmin/evolution', 'garmin/today', 'garmin/days', 'garmin/activities', 'cron/garmin-sync', 'races', 'goals', 'trainer']

    const statuses = await Promise.all(removed.map(async (route) => (await dispatch(makeRequest('GET', `/api/v1/${route}`), sql)).status))

    expect(statuses).toEqual(removed.map(() => 404))
  })
})
