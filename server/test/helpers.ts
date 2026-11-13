import { PGlite } from '@electric-sql/pglite'
import { fileURLToPath } from 'node:url'
import type { Query, Sql, SqlStatement } from '../src/db.js'
import type { IncomingRecord } from '../src/types.js'
import { applyMigrations } from '../scripts/migrate.js'

export const migrationsDir = fileURLToPath(new URL('../migrations', import.meta.url))

export function pgliteSql(db: PGlite): Sql {
  const query: Query = async <T>(text: string, params: unknown[] = []) => (await db.query<T>(text, params)).rows
  return Object.assign(query, {
    transaction: (statements: SqlStatement[]) =>
      db.transaction(async (tx) => {
        const results: unknown[][] = []
        for (const statement of statements) {
          results.push((await tx.query(statement.text, statement.params)).rows)
        }
        return results
      }),
  })
}

export async function migratedSql(): Promise<Sql> {
  const sql = pgliteSql(new PGlite())
  await applyMigrations(sql, migrationsDir)
  return sql
}

export function makeToken(fill: number): string {
  return Buffer.alloc(32, fill).toString('base64url')
}

export function makeRequest(
  method: string,
  path: string,
  options: { token?: string; body?: string; ip?: string } = {},
): Request {
  const headers = new Headers()
  if (options.token !== undefined) {
    headers.set('authorization', `Bearer ${options.token}`)
  }
  if (options.ip !== undefined) {
    headers.set('x-forwarded-for', `${options.ip}, 10.0.0.1`)
  }
  if (options.body !== undefined) {
    headers.set('content-type', 'application/json')
  }
  const init: RequestInit = { method, headers }
  if (options.body !== undefined) {
    init.body = options.body
  }
  return new Request(`https://sync.test${path}`, init)
}

export function record(
  overrides: Partial<{ kind: string; id: string; updatedAt: string; deleted: boolean; payload: string | null }> = {},
) {
  return {
    kind: 'race',
    id: 'race-1',
    updatedAt: '2026-11-12T18:30:00.123Z',
    deleted: false,
    payload: 'Y2lmcmFkbw',
    ...overrides,
  }
}

export function incomingRecord(id: string): IncomingRecord {
  return { kind: 'race', id, updatedAt: '2026-11-12T18:30:00.123Z', deleted: false, payload: 'Y2lmcmFkbw' }
}
