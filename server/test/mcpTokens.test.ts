import { createHash } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { accountForMcpToken } from '../src/mcpTokens.js'
import { createAccountRoute, deleteMcpTokenRoute, putMcpTokenRoute } from '../src/routes.js'
import { makeRequest, makeToken, migratedSql } from './helpers.js'

const accountKey = makeToken(1)
const otherKey = makeToken(2)

function hash(token: string): string {
  return createHash('sha256').update(Buffer.from(token, 'base64url')).digest('hex')
}

function put(token: string, key = accountKey): Promise<Response> {
  return putMcpTokenRoute(makeRequest('PUT', '/api/v1/mcp/token', { token: key, body: JSON.stringify({ tokenHash: hash(token) }) }), sql)
}

let sql: Sql

describe('token do MCP', () => {
  beforeEach(async () => {
    sql = await migratedSql()
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: accountKey, ip: '1.1.1.1' }), sql, new Date())
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: otherKey, ip: '2.2.2.2' }), sql, new Date())
  })

  it('grava o hash e resolve a conta', async () => {
    const token = makeToken(50)
    expect((await put(token)).status).toBe(204)
    const account = await accountForMcpToken(sql, hash(token))
    expect(account).toBe(createHash('sha256').update(Buffer.from(accountKey, 'base64url')).digest('hex'))
  })

  it('gerar outro token invalida o anterior', async () => {
    const first = makeToken(50)
    const second = makeToken(51)
    await put(first)
    await put(second)
    expect(await accountForMcpToken(sql, hash(first))).toBeUndefined()
    expect(await accountForMcpToken(sql, hash(second))).toBeDefined()
  })

  it('revoga', async () => {
    const token = makeToken(50)
    await put(token)
    const response = await deleteMcpTokenRoute(makeRequest('DELETE', '/api/v1/mcp/token', { token: accountKey }), sql)
    expect(response.status).toBe(204)
    expect(await accountForMcpToken(sql, hash(token))).toBeUndefined()
  })

  it('não deixa outra conta tomar o mesmo token', async () => {
    const token = makeToken(50)
    await put(token)
    expect((await put(token, otherKey)).status).toBe(409)
  })

  it('recusa sem login e hash inválido', async () => {
    const anonymous = await putMcpTokenRoute(makeRequest('PUT', '/api/v1/mcp/token', { body: JSON.stringify({ tokenHash: 'x' }) }), sql)
    expect(anonymous.status).toBe(401)
    const invalid = await putMcpTokenRoute(makeRequest('PUT', '/api/v1/mcp/token', { token: accountKey, body: JSON.stringify({ tokenHash: 'x' }) }), sql)
    expect(invalid.status).toBe(400)
  })
})
