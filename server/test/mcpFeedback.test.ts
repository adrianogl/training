import { createHash, randomBytes } from 'node:crypto'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import type { Sql } from '../src/db.js'
import { mcpRoute } from '../src/mcp/mcpRoute.js'
import { readBlob, writeBlob } from '../src/mcp/mcpStore.js'
import { createAccountRoute, putMcpTokenRoute } from '../src/routes.js'
import { makeRequest, makeToken, migratedSql } from './helpers.js'

const key = randomBytes(32)
const now = new Date('2026-11-22T10:00:00Z')
const referenceSeconds = (date: Date) => date.getTime() / 1000 - 978307200

const adminKey = makeToken(1)
const otherKey = makeToken(2)
const adminMcp = makeToken(70)
const otherMcp = makeToken(71)
const idOf = (token: string) => createHash('sha256').update(Buffer.from(token, 'base64url')).digest('hex')
const adminAccount = idOf(adminKey)
const otherAccount = idOf(otherKey)

let sql: Sql

function entry(id: string, overrides: Record<string, unknown> = {}) {
  return {
    id,
    exercise: { catalog: { _0: 'SQUAT/GOBLET_SQUAT' } },
    exerciseName: 'Agachamento goblet',
    mediaId: 'media-1',
    verdict: 'doesNotMatch',
    noneMatched: false,
    note: 'a imagem mostra outro movimento',
    createdAt: 785000000.5,
    updatedAt: 785000100.25,
    workoutDay: '2026-11-20',
    status: 'pending',
    ...overrides,
  }
}

async function rpc(token: string, body: unknown) {
  const response = await mcpRoute(makeRequest('POST', '/mcp', { token, body: JSON.stringify(body) }), sql, key, () => now)
  return JSON.parse(await response.text())
}
const call = (token: string, name: string, args: Record<string, unknown> = {}) =>
  rpc(token, { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name, arguments: args } })
const listTools = async (token: string) =>
  (await rpc(token, { jsonrpc: '2.0', id: 1, method: 'tools/list' })).result.tools.map((tool: { name: string }) => tool.name)

async function setup(token: string, mcp: string, email: string) {
  await createAccountRoute(makeRequest('POST', '/api/v1/account', { token, ip: '1.1.1.1' }), sql, new Date())
  await putMcpTokenRoute(makeRequest('PUT', '/api/v1/mcp/token', { token, body: JSON.stringify({ tokenHash: idOf(mcp) }) }), sql)
  await sql('insert into users (id, account_id, email, name, password_hash) values ($1, $2, $3, $4, $5)', [`u-${email}`, idOf(token), email, 'x', 'x'])
}

const feedbackBlob = (account: string, entries: unknown[]) => writeBlob(sql, key, account, 'exerciseFeedback', JSON.stringify(entries), now)

describe('MCP de avaliações de imagem', () => {
  beforeEach(async () => {
    process.env.ADMIN_EMAILS = 'admin@example.com'
    sql = await migratedSql()
    await setup(adminKey, adminMcp, 'admin@example.com')
    await setup(otherKey, otherMcp, 'atleta@example.com')
  })

  afterEach(() => {
    delete process.env.ADMIN_EMAILS
  })

  it('non_admin_does_not_see_feedback_tools', async () => {
    expect(await listTools(otherMcp)).toEqual(['contexto_forca', 'validar_treinos', 'salvar_treinos'])
    expect(await listTools(adminMcp)).toEqual(['contexto_forca', 'validar_treinos', 'salvar_treinos', 'avaliacoes_imagens', 'resolver_avaliacao'])
    const list = await call(otherMcp, 'avaliacoes_imagens')
    expect(list.result.isError).toBe(true)
    const resolve = await call(otherMcp, 'resolver_avaliacao', { conta: 'x', id: 'y', resolucao: 'z', versao: '1' })
    expect(resolve.result.isError).toBe(true)
  })

  it('lists_pending_from_two_accounts', async () => {
    await feedbackBlob(adminAccount, [
      entry('11111111-1111-1111-1111-111111111111'),
      entry('22222222-2222-2222-2222-222222222222', { verdict: 'matches' }),
      entry('33333333-3333-3333-3333-333333333333', { status: 'resolved' }),
      entry('44444444-4444-4444-4444-444444444444'),
      entry('55555555-5555-5555-5555-555555555555', { undoes: '44444444-4444-4444-4444-444444444444' }),
    ])
    await feedbackBlob(otherAccount, [
      entry('66666666-6666-6666-6666-666666666666', { exerciseName: 'Remada curvada', chosenMediaId: 'media-9', note: 'prefiro a outra' }),
    ])
    const text: string = (await call(adminMcp, 'avaliacoes_imagens')).result.content[0].text
    expect(text).toContain(adminAccount.slice(0, 8))
    expect(text).toContain(otherAccount.slice(0, 8))
    expect(text).toContain('11111111-1111-1111-1111-111111111111')
    expect(text).toContain('66666666-6666-6666-6666-666666666666')
    expect(text).toContain('Remada curvada')
    expect(text).toContain('media-9')
    expect(text).toContain('prefiro a outra')
    expect(text).toContain('2025-11-')
    expect(text).not.toContain('22222222-2222')
    expect(text).not.toContain('33333333-3333')
    expect(text).not.toContain('44444444-4444')
    expect(text).not.toContain('55555555-5555')
  })

  it('resolve_updates_only_that_entry_and_keeps_others', async () => {
    const target = '11111111-1111-1111-1111-111111111111'
    const keep = entry('22222222-2222-2222-2222-222222222222', { updatedAt: 785000200.75 })
    await feedbackBlob(otherAccount, [entry(target), keep])
    const before = await readBlob(sql, key, otherAccount, 'exerciseFeedback')
    const result = await call(adminMcp, 'resolver_avaliacao', { conta: otherAccount.slice(0, 8), id: target, resolucao: 'Imagem trocada', versao: '1.4.0' })
    expect(result.result.isError).toBeUndefined()
    const after = await readBlob(sql, key, otherAccount, 'exerciseFeedback')
    const entries = JSON.parse(after?.text ?? '[]')
    expect(entries).toHaveLength(2)
    expect(entries[1]).toEqual(keep)
    const changed = entries[0]
    expect(changed).toMatchObject({ id: target, status: 'resolved', resolution: 'Imagem trocada', resolvedIn: '1.4.0', note: 'a imagem mostra outro movimento', createdAt: 785000000.5 })
    expect(changed.updatedAt).toBeGreaterThan(785000200.75)
    expect(changed.updatedAt).toBeCloseTo(referenceSeconds(now), 3)
    expect(Date.parse(after?.updatedAt ?? '')).toBeGreaterThan(Date.parse(before?.updatedAt ?? ''))
    const again = (await call(adminMcp, 'avaliacoes_imagens')).result.content[0].text
    expect(again).not.toContain(target)
    expect((await call(adminMcp, 'resolver_avaliacao', { conta: 'zzzz', id: target, resolucao: 'a', versao: '1' })).result.isError).toBe(true)
    expect((await call(adminMcp, 'resolver_avaliacao', { conta: otherAccount.slice(0, 8), id: 'nao-existe', resolucao: 'a', versao: '1' })).result.isError).toBe(true)
  })

  it('bumps updatedAt past a future stored stamp', async () => {
    const target = '11111111-1111-1111-1111-111111111111'
    const future = referenceSeconds(now) + 5000
    await feedbackBlob(otherAccount, [entry(target, { updatedAt: future })])
    await call(adminMcp, 'resolver_avaliacao', { conta: otherAccount.slice(0, 8), id: target, resolucao: 'ok', versao: '1' })
    const entries = JSON.parse((await readBlob(sql, key, otherAccount, 'exerciseFeedback'))?.text ?? '[]')
    expect(entries[0].updatedAt).toBeGreaterThan(future)
  })

  it('notes_never_listed', async () => {
    await writeBlob(sql, key, otherAccount, 'exerciseNotes', JSON.stringify([{ id: 'n1', text: 'NOTA PRIVADA DO ATLETA' }]), now)
    await feedbackBlob(otherAccount, [entry('11111111-1111-1111-1111-111111111111')])
    const text: string = (await call(adminMcp, 'avaliacoes_imagens')).result.content[0].text
    expect(text).not.toContain('NOTA PRIVADA')
  })

  it('keeps unknown keys and undoes after resolve', async () => {
    const target = '11111111-1111-1111-1111-111111111111'
    const other = entry('22222222-2222-2222-2222-222222222222', { undoes: '99999999-9999-9999-9999-999999999999', futureField: { a: [1, 2] } })
    await feedbackBlob(otherAccount, [entry(target, { extra: 'x' }), other])
    await call(adminMcp, 'resolver_avaliacao', { conta: otherAccount.slice(0, 8), id: target, resolucao: 'ok', versao: '1' })
    const entries = JSON.parse((await readBlob(sql, key, otherAccount, 'exerciseFeedback'))?.text ?? '[]')
    expect(entries[0].extra).toBe('x')
    expect(entries[1]).toEqual(other)
  })

  it('rejects an ambiguous prefix', async () => {
    await feedbackBlob(adminAccount, [entry('11111111-1111-1111-1111-111111111111')])
    await feedbackBlob(otherAccount, [entry('22222222-2222-2222-2222-222222222222')])
    const result = await call(adminMcp, 'resolver_avaliacao', { conta: '', id: '11111111-1111-1111-1111-111111111111', resolucao: 'a', versao: '1' })
    expect(result.result.isError).toBe(true)
    const shared = await call(adminMcp, 'resolver_avaliacao', { conta: '0123456789abcdef'.slice(0, 0) + '0', id: 'x', resolucao: 'a', versao: '1' })
    expect(shared.result.isError).toBe(true)
  })

  it('skips a corrupt account in the list', async () => {
    await writeBlob(sql, key, adminAccount, 'exerciseFeedback', 'isto não é json', now)
    await feedbackBlob(otherAccount, [null, 3, entry('22222222-2222-2222-2222-222222222222', { updatedAt: undefined })])
    const text: string = (await call(adminMcp, 'avaliacoes_imagens')).result.content[0].text
    expect(text).toContain('22222222-2222-2222-2222-222222222222')
  })

  function racing(times: number): Sql {
    let injected = 0
    const wrapped = (async (text: string, params: unknown[] = []) => {
      const rows = await sql(text, params)
      if (text.includes("id = $2 and not deleted") && params[0] === otherAccount && params[1] === 'exerciseFeedback' && injected < times) {
        injected += 1
        const current = await readBlob(sql, key, otherAccount, 'exerciseFeedback')
        await writeBlob(sql, key, otherAccount, 'exerciseFeedback', current?.text ?? '[]', new Date(now.getTime() + injected * 3_600_000))
      }
      return rows
    }) as Sql
    return Object.assign(wrapped, { transaction: sql.transaction })
  }

  const resolveWith = async (wrapped: Sql, target: string) => {
    const response = await mcpRoute(
      makeRequest('POST', '/mcp', {
        token: adminMcp,
        body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'resolver_avaliacao', arguments: { conta: otherAccount.slice(0, 8), id: target, resolucao: 'ok', versao: '1' } } }),
      }),
      wrapped, key, () => now,
    )
    return JSON.parse(await response.text()).result
  }

  it('resolve_retries_when_write_is_ignored', async () => {
    const target = '11111111-1111-1111-1111-111111111111'
    await feedbackBlob(otherAccount, [entry(target)])
    const result = await resolveWith(racing(1), target)
    expect(result.isError).toBeUndefined()
    const entries = JSON.parse((await readBlob(sql, key, otherAccount, 'exerciseFeedback'))?.text ?? '[]')
    expect(entries[0].status).toBe('resolved')
  })

  it('resolve_reports_failure_when_write_is_ignored', async () => {
    const target = '11111111-1111-1111-1111-111111111111'
    await feedbackBlob(otherAccount, [entry(target)])
    const result = await resolveWith(racing(10), target)
    expect(result.isError).toBe(true)
    expect(result.content[0].text).toContain('Não deu para gravar')
    const entries = JSON.parse((await readBlob(sql, key, otherAccount, 'exerciseFeedback'))?.text ?? '[]')
    expect(entries[0].status).toBe('pending')
  })
})
