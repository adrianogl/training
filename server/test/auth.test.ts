import { createHash } from 'node:crypto'
import { describe, expect, it } from 'vitest'
import { accountIdFromAuthorization } from '../src/auth.js'
import { makeToken } from './helpers.js'

describe('accountIdFromAuthorization', () => {
  it('devolve o sha256 em hex dos 32 bytes', () => {
    const expected = createHash('sha256').update(Buffer.alloc(32, 7)).digest('hex')

    expect(accountIdFromAuthorization(`Bearer ${makeToken(7)}`)).toBe(expected)
  })

  it.each([
    ['sem header', null],
    ['sem Bearer', makeToken(1)],
    ['esquema errado', `Basic ${makeToken(1)}`],
    ['31 bytes', `Bearer ${Buffer.alloc(31, 1).toString('base64url')}`],
    ['33 bytes', `Bearer ${Buffer.alloc(33, 1).toString('base64url')}`],
    ['com padding', `Bearer ${Buffer.alloc(32, 1).toString('base64')}`],
    ['base64 padrão com +', `Bearer ${'+'.repeat(43)}`],
    ['caractere fora do alfabeto', `Bearer ${'*'.repeat(43)}`],
    ['último caractere não canônico', `Bearer ${makeToken(0).slice(0, 42)}B`],
  ])('%s → undefined', (_, header) => {
    expect(accountIdFromAuthorization(header)).toBeUndefined()
  })
})
