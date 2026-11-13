import { neon } from '@neondatabase/serverless'
import { readdir, readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import type { Query } from '../src/db.js'

export async function applyMigrations(sql: Query, dir: string): Promise<string[]> {
  await sql('create table if not exists schema_migrations (name text primary key, applied_at timestamptz not null default now())')
  const applied = new Set((await sql<{ name: string }>('select name from schema_migrations')).map((row) => row.name))
  const pending = (await readdir(dir)).filter((name) => name.endsWith('.sql') && !applied.has(name)).sort()
  for (const name of pending) {
    const statements = (await readFile(join(dir, name), 'utf8'))
      .split(/;\s*(?:\n|$)/)
      .map((statement) => statement.trim())
      .filter((statement) => statement !== '')
    for (const statement of statements) {
      await sql(statement)
    }
    await sql('insert into schema_migrations (name) values ($1)', [name])
  }
  return pending
}

async function main(): Promise<void> {
  const url = process.env.DATABASE_URL
  if (url === undefined || url === '') {
    throw new Error('DATABASE_URL não definida')
  }
  const client = neon(url)
  const sql: Query = async <T>(text: string, params: unknown[] = []) => (await client.query(text, params)) as T[]
  const dir = fileURLToPath(new URL('../migrations', import.meta.url))
  const applied = await applyMigrations(sql, dir)
  console.log(applied.length === 0 ? 'nenhuma migração pendente' : `aplicadas: ${applied.join(', ')}`)
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main()
}
