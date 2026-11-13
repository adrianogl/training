import { describe, expect, it } from 'vitest'
import { MAX_PAYLOAD_CHARS, MAX_PUSH_RECORDS } from '../src/constants.js'
import { parsePushBody, parseSince } from '../src/validate.js'
import { record } from './helpers.js'

function body(records: unknown): string {
  return JSON.stringify({ records })
}

describe('parsePushBody', () => {
  it('aceita registro válido e tombstone com payload null', () => {
    const result = parsePushBody(body([record(), record({ id: 'r2', deleted: true, payload: null })]))

    expect(result).toEqual({ ok: true, records: [record(), record({ id: 'r2', deleted: true, payload: null })] })
  })

  it('aceita payload no limite', () => {
    expect(parsePushBody(body([record({ payload: 'a'.repeat(MAX_PAYLOAD_CHARS) })])).ok).toBe(true)
  })

  it.each([
    ['json inválido', '{', 'invalid_json'],
    ['sem records', '{}', 'invalid_body'],
    ['records não é array', body('x'), 'invalid_body'],
    ['registro não é objeto', body([1]), 'invalid_record'],
    ['kind inválido', body([record({ kind: 'workout' })]), 'invalid_kind'],
    ['id vazio', body([record({ id: '' })]), 'invalid_id'],
    ['id longo', body([record({ id: 'x'.repeat(129) })]), 'invalid_id'],
    ['updatedAt sem milissegundos', body([record({ updatedAt: '2026-11-12T18:30:00Z' })]), 'invalid_updated_at'],
    ['updatedAt com offset', body([record({ updatedAt: '2026-11-12T18:30:00.123+00:00' })]), 'invalid_updated_at'],
    ['updatedAt impossível', body([record({ updatedAt: '2026-02-30T18:30:00.123Z' })]), 'invalid_updated_at'],
    ['deleted ausente', body([{ ...record(), deleted: undefined }]), 'invalid_deleted'],
    ['vivo sem payload', body([record({ payload: null })]), 'missing_payload'],
    ['vivo com payload vazio', body([record({ payload: '' })]), 'missing_payload'],
    ['payload não é string', body([{ ...record(), payload: 1 }]), 'invalid_payload'],
    ['payload grande', body([record({ payload: 'a'.repeat(MAX_PAYLOAD_CHARS + 1) })]), 'payload_too_large'],
    [
      'registros demais',
      body(Array.from({ length: MAX_PUSH_RECORDS + 1 }, (_, i) => record({ id: `r${i}` }))),
      'too_many_records',
    ],
  ])('%s → %s', (_, text, error) => {
    expect(parsePushBody(text)).toEqual({ ok: false, error })
  })
})

describe('parseSince', () => {
  it.each([
    [null, 0],
    ['0', 0],
    ['42', 42],
  ])('%s → %s', (value, expected) => {
    expect(parseSince(value)).toBe(expected)
  })

  it.each(['-1', '1.5', 'abc', '', '99999999999999999999'])('%s → undefined', (value) => {
    expect(parseSince(value)).toBeUndefined()
  })
})
