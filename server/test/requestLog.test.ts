import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { recordRequest } from '../src/requestLog.js'
import { createAccountRoute, pullChangesRoute, pushChangesRoute } from '../src/routes.js'
import { makeRequest, makeToken, migratedSql, record } from './helpers.js'

interface LogRow {
  method: string
  route: string
  status: number
  record_count: number | null
  account_prefix: string | null
}

async function logRows(sql: Sql): Promise<LogRow[]> {
  return sql<LogRow>('select method, route, status, record_count, account_prefix from request_log order by id')
}

describe('request_log', () => {
  let sql: Sql
  const token = makeToken(1)

  beforeEach(async () => {
    sql = await migratedSql()
  })

  it('grava método, rota, status, contagem e só o prefixo da conta em cada rota v1', async () => {
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token, ip: '1.1.1.1' }), sql, new Date())
    await pushChangesRoute(
      makeRequest('POST', '/api/v1/changes', {
        token,
        body: JSON.stringify({ records: [record({ id: 'a', payload: 'segredo-cifrado' }), record({ id: 'b' })] }),
      }),
      sql,
    )
    await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token }), sql)
    await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token: 'invalido' }), sql)

    const rows = await logRows(sql)
    const prefix = rows[0]?.account_prefix

    expect(prefix).toMatch(/^[0-9a-f]{8}$/)
    expect(rows).toEqual([
      { method: 'POST', route: 'account', status: 201, record_count: null, account_prefix: prefix },
      { method: 'POST', route: 'changes', status: 200, record_count: 2, account_prefix: prefix },
      { method: 'GET', route: 'changes', status: 200, record_count: 2, account_prefix: prefix },
    ])
    const dump = JSON.stringify(await sql('select * from request_log'))
    expect(dump).not.toContain('segredo-cifrado')
    expect(dump).not.toContain(token)
    expect(dump).not.toContain('1.1.1.1')
  })

  it('não grava request sem conta autenticada (401) nem criação bloqueada (429)', async () => {
    await pullChangesRoute(makeRequest('GET', '/api/v1/changes', { token: makeToken(7) }), sql)
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: 'x' }), sql, new Date())
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: makeToken(8), ip: '5.5.5.5' }), sql, new Date(), {
      maxAccounts: 0,
      maxAccountBytes: 1,
    })

    expect(await logRows(sql)).toEqual([])
  })

  it('apaga linhas com mais de 7 dias ao gravar', async () => {
    await sql(
      "insert into request_log (method, route, status, created_at) values ('GET', 'changes', 200, now() - interval '8 days'), ('GET', 'changes', 200, now() - interval '6 days')",
    )

    await recordRequest(sql, { method: 'GET', route: 'changes', status: 200, recordCount: 0, accountPrefix: null })

    const rows = await sql<{ age_days: number }>(
      "select extract(day from now() - created_at)::int as age_days from request_log order by created_at",
    )
    expect(rows.map((row) => row.age_days)).toEqual([6, 0])
  })

  it('falha ao gravar o log não derruba a resposta', async () => {
    await sql('drop table request_log')

    const response = await createAccountRoute(makeRequest('POST', '/api/v1/account', { token, ip: '1.1.1.1' }), sql, new Date())

    expect(response.status).toBe(201)
  })
})
