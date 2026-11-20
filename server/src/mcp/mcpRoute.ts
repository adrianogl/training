import { createHash } from 'node:crypto'
import { dataKeyFromEnv } from '../cipher.js'
import { LOG_ACCOUNT_PREFIX_LENGTH, TOKEN_PATTERN } from '../constants.js'
import type { Sql } from '../db.js'
import { accountForMcpToken } from '../mcpTokens.js'
import { recordRequest } from '../requestLog.js'
import { JSON_RPC, MCP } from './mcpConstants.js'
import { withinRateLimit } from './mcpStore.js'
import { MCP_TEXT } from './mcpText.js'
import { toolsFor, callTool } from './mcpTools.js'

interface RpcMessage {
  jsonrpc?: string
  id?: string | number | null
  method?: string
  params?: Record<string, unknown>
}

const rpcResult = (id: RpcMessage['id'], result: unknown) => ({ jsonrpc: '2.0', id: id ?? null, result })
const rpcError = (id: RpcMessage['id'], code: number, message: string) => ({ jsonrpc: '2.0', id: id ?? null, error: { code, message } })

function tokenHash(header: string | null): string | undefined {
  const token = header === null ? undefined : TOKEN_PATTERN.exec(header)?.[1]
  if (token === undefined) return undefined
  const bytes = Buffer.from(token, 'base64url')
  if (bytes.length !== MCP.tokenBytes || bytes.toString('base64url') !== token) return undefined
  return createHash('sha256').update(bytes).digest('hex')
}

function unauthorized(): Response {
  return Response.json(rpcError(null, JSON_RPC.invalidRequest, MCP_TEXT.unauthorized), { status: 401, headers: { 'www-authenticate': 'Bearer' } })
}

async function handle(message: RpcMessage, sql: Sql, key: Buffer, accountId: string, now: Date): Promise<object | null> {
  if (typeof message !== 'object' || message === null) return rpcError(null, JSON_RPC.invalidRequest, 'invalid_request')
  if (message.jsonrpc !== '2.0' || typeof message.method !== 'string') return rpcError(message.id, JSON_RPC.invalidRequest, 'invalid_request')
  const isNotification = message.id === undefined
  switch (message.method) {
    case 'initialize': {
      const requested = typeof message.params?.protocolVersion === 'string' ? message.params.protocolVersion : MCP.protocolVersion
      return rpcResult(message.id, {
        protocolVersion: requested,
        capabilities: { tools: {} },
        serverInfo: { name: MCP.serverName, version: MCP.serverVersion },
        instructions: MCP_TEXT.instructions,
      })
    }
    case 'ping':
      return rpcResult(message.id, {})
    case 'tools/list':
      return rpcResult(message.id, { tools: await toolsFor(sql, accountId) })
    case 'tools/call': {
      const name = typeof message.params?.name === 'string' ? message.params.name : ''
      const args = (message.params?.arguments ?? {}) as Record<string, unknown>
      return rpcResult(message.id, await callTool(sql, key, accountId, name, args, now))
    }
    default:
      return isNotification ? null : rpcError(message.id, JSON_RPC.methodNotFound, 'method_not_found')
  }
}

export async function mcpRoute(request: Request, sql: Sql, dataKey: Buffer | undefined = dataKeyFromEnv(process.env), now: () => Date = () => new Date()): Promise<Response> {
  if (request.method !== 'POST') return new Response(null, { status: 405, headers: { allow: 'POST' } })
  const hash = tokenHash(request.headers.get('authorization'))
  const accountId = hash === undefined ? undefined : await accountForMcpToken(sql, hash)
  if (accountId === undefined) return unauthorized()
  if (dataKey === undefined) return Response.json(rpcError(null, JSON_RPC.internalError, 'storage_unavailable'), { status: 503 })
  const accountPrefix = accountId.slice(0, LOG_ACCOUNT_PREFIX_LENGTH)
  if (!(await withinRateLimit(sql, accountPrefix))) {
    return Response.json(rpcError(null, JSON_RPC.internalError, MCP_TEXT.rateLimited), { status: 429 })
  }
  const body = await request.text()
  let status = 200
  try {
    if (Buffer.byteLength(body) > MCP.maxBodyBytes) {
      status = 413
      return Response.json(rpcError(null, JSON_RPC.invalidRequest, 'body_too_large'), { status })
    }
    let parsed: unknown
    try {
      parsed = JSON.parse(body)
    } catch {
      status = 400
      return Response.json(rpcError(null, JSON_RPC.parseError, 'parse_error'), { status })
    }
    if (Array.isArray(parsed)) {
      status = 400
      return Response.json(rpcError(null, JSON_RPC.invalidRequest, 'batch_not_supported'), { status })
    }
    const reply = await handle(parsed as RpcMessage, sql, dataKey, accountId, now())
    if (reply === null) {
      status = 202
      return new Response(null, { status })
    }
    return Response.json(reply)
  } catch (error) {
    status = 500
    console.error(JSON.stringify({ route: MCP.route, error: error instanceof Error ? error.name : 'unknown' }))
    return Response.json(rpcError(null, JSON_RPC.internalError, 'internal_error'), { status })
  } finally {
    await recordRequest(sql, { method: 'POST', route: MCP.route, status, recordCount: null, accountPrefix })
  }
}
