import { neon } from '@neondatabase/serverless'

export type Query = <T = Record<string, unknown>>(text: string, params?: unknown[]) => Promise<T[]>

export interface SqlStatement {
  text: string
  params: unknown[]
}

export type Sql = Query & {
  transaction: (statements: SqlStatement[]) => Promise<unknown[][]>
}

export function neonSql(databaseUrl: string): Sql {
  const client = neon(databaseUrl)
  const query: Query = async <T>(text: string, params: unknown[] = []) => (await client.query(text, params)) as T[]
  return Object.assign(query, {
    transaction: async (statements: SqlStatement[]) =>
      (await client.transaction((txn) => statements.map((s) => txn.query(s.text, s.params)))) as unknown[][],
  })
}

let shared: Sql | undefined

export function sharedSql(): Sql {
  if (shared === undefined) {
    const url = process.env.DATABASE_URL
    if (url === undefined || url === '') {
      throw new Error('DATABASE_URL não definida')
    }
    shared = neonSql(url)
  }
  return shared
}
