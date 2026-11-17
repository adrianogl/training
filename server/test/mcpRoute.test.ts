import { createHash, randomBytes } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { mcpRoute } from '../src/mcp/mcpRoute.js'
import { readBlob, writeBlob } from '../src/mcp/mcpStore.js'
import { createAccountRoute, putMcpTokenRoute } from '../src/routes.js'
import { makeRequest, makeToken, migratedSql } from './helpers.js'

const accountKey = makeToken(1)
const mcpToken = makeToken(70)
const key = randomBytes(32)
const accountId = createHash('sha256').update(Buffer.from(accountKey, 'base64url')).digest('hex')
const catalog = JSON.parse(readFileSync(new URL('./fixtures/strength-catalog.json', import.meta.url), 'utf8'))
const now = new Date('2026-11-22T10:00:00Z')

const context = {
  periodo: { inicio: '2026-11-23', fim: '2026-11-29', hoje: '2026-11-22' },
  prova: null,
  dias_do_treinador: [{ dia_da_semana: 'ter', foco: 'core', intensidade: 'light', minutos: 25, local: 'home' }],
  mfit: [{ dia_da_semana: 'seg', padroes: [] }],
  corrida: [],
  prontidao: [],
  dor: [],
  ultimas_cargas_kg: {},
  catalogo: catalog,
  regras: ['regra'],
}

const valid = JSON.stringify({
  versao: 1,
  treinos: [{
    dia: '2026-11-24', foco: 'core', minutos: 25, local: 'home', porque: 'motivo',
    exercicios: [
      { id: 'mobilidade-90-90', series: 2, reps: 8, descanso: 15 },
      { id: 'pallof-elastico', series: 3, reps: 10, descanso: 30 },
      { id: 'prancha-lateral', series: 3, segundos: 30, descanso: 30 },
      { id: 'dead-bug', series: 3, reps: 10, descanso: 30 },
      { id: 'mobilidade-tornozelo', series: 2, reps: 8, descanso: 15 },
      { id: 'passaro-cao', series: 3, reps: 10, descanso: 30 },
    ],
  }],
})

let sql: Sql

async function rpc(body: unknown, token: string | null = mcpToken) {
  const response = await mcpRoute(makeRequest('POST', '/mcp', token === null ? { body: JSON.stringify(body) } : { token, body: JSON.stringify(body) }), sql, key, () => now)
  const text = await response.text()
  return { status: response.status, body: text === '' ? null : JSON.parse(text) }
}

const call = (name: string, args: Record<string, unknown> = {}) => rpc({ jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name, arguments: args } })

describe('MCP de força', () => {
  beforeEach(async () => {
    sql = await migratedSql()
    await createAccountRoute(makeRequest('POST', '/api/v1/account', { token: accountKey, ip: '1.1.1.1' }), sql, new Date())
    const hash = createHash('sha256').update(Buffer.from(mcpToken, 'base64url')).digest('hex')
    await putMcpTokenRoute(makeRequest('PUT', '/api/v1/mcp/token', { token: accountKey, body: JSON.stringify({ tokenHash: hash }) }), sql)
  })

  it('recusa sem token ou com token desconhecido', async () => {
    expect((await rpc({ jsonrpc: '2.0', id: 1, method: 'ping' }, null)).status).toBe(401)
    expect((await rpc({ jsonrpc: '2.0', id: 1, method: 'ping' }, makeToken(99))).status).toBe(401)
  })

  it('responde initialize, ping, tools/list e aceita notificação', async () => {
    const init = await rpc({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18' } })
    expect(init.body.result.serverInfo.name).toBe('trAIning')
    expect(init.body.result.capabilities).toEqual({ tools: {} })
    expect((await rpc({ jsonrpc: '2.0', id: 2, method: 'ping' })).body.result).toEqual({})
    const tools = await rpc({ jsonrpc: '2.0', id: 3, method: 'tools/list' })
    expect(tools.body.result.tools.map((tool: { name: string }) => tool.name)).toEqual(['contexto_forca', 'validar_treinos', 'salvar_treinos'])
    expect((await rpc({ jsonrpc: '2.0', method: 'notifications/initialized' })).status).toBe(202)
    expect((await rpc({ jsonrpc: '2.0', id: 4, method: 'outro' })).body.error.code).toBe(-32601)
  })

  it('sem contexto, avisa para abrir o app', async () => {
    const result = await call('contexto_forca')
    expect(result.body.result.isError).toBe(true)
    expect(result.body.result.content[0].text).toContain('Treinador › Força')
  })

  it('lê o contexto, valida e salva', async () => {
    await writeBlob(sql, key, accountId, 'strengthContext', JSON.stringify({ atualizado: '2026-11-22T09:00:00Z', texto: 'PACOTE', contexto: context }), now)
    expect((await call('contexto_forca')).body.result.content[0].text).toContain('PACOTE')

    const invalid = await call('validar_treinos', { json: valid.replace('2026-11-24', '2026-11-23') })
    expect(invalid.body.result.content[0].text).toContain('dia do MFIT')

    const checked = await call('validar_treinos', { json: valid })
    expect(checked.body.result.content[0].text).toContain('1 dia(s) sem erros')

    const saved = await call('salvar_treinos', { json: valid })
    expect(saved.body.result.content[0].text).toContain('Salvo.')
    const blob = await readBlob(sql, key, accountId, 'strengthClaude')
    expect(JSON.parse(blob?.text ?? '{}').json).toBe(valid)
  })

  it('recusa JSON inválido e versão desconhecida', async () => {
    await writeBlob(sql, key, accountId, 'strengthContext', JSON.stringify({ atualizado: 'x', texto: 'x', contexto: context }), now)
    expect((await call('validar_treinos', { json: 'nada' })).body.result.isError).toBe(true)
    expect((await call('validar_treinos', { json: '{"versao": 2, "treinos": []}' })).body.result.content[0].text).toContain('Versão 2')
    expect((await call('validar_treinos')).body.result.content[0].text).toContain('json')
  })

  it('limita a 60 chamadas por minuto', async () => {
    for (let index = 0; index < 60; index += 1) await rpc({ jsonrpc: '2.0', id: index, method: 'ping' })
    expect((await rpc({ jsonrpc: '2.0', id: 61, method: 'ping' })).status).toBe(429)
  })

  it('recusa lote e mensagem nula', async () => {
    const batch = await rpc([{ jsonrpc: '2.0', id: 1, method: 'ping' }, { jsonrpc: '2.0', id: 2, method: 'ping' }])
    expect(batch.status).toBe(400)
    expect(batch.body.error.message).toBe('batch_not_supported')
    const empty = await rpc(null)
    expect(empty.status).toBe(200)
    expect(empty.body.error.code).toBe(-32600)
  })

  it('ignora treino ou exercício nulo sem quebrar', async () => {
    await writeBlob(sql, key, accountId, 'strengthContext', JSON.stringify({ atualizado: 'x', texto: 'x', contexto: context }), now)
    const nullDay = await call('validar_treinos', { json: '{"versao": 1, "treinos": [null]}' })
    expect(nullDay.status).toBe(200)
    expect(nullDay.body.result.content[0].text).toContain('0 dia(s)')
    const nullExercise = await call('validar_treinos', { json: valid.replace('"exercicios":[', '"exercicios":[null,') })
    expect(nullExercise.status).toBe(200)
    expect(nullExercise.body.result.content[0].text).toContain('1 dia(s) sem erros')
  })

  it('só aceita POST', async () => {
    const response = await mcpRoute(makeRequest('GET', '/mcp', { token: mcpToken }), sql, key)
    expect(response.status).toBe(405)
  })
})
