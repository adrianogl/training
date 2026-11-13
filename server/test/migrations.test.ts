import { PGlite } from '@electric-sql/pglite'
import { describe, expect, it } from 'vitest'
import { applyMigrations } from '../scripts/migrate.js'
import { migrationsDir, pgliteSql } from './helpers.js'

describe('applyMigrations', () => {
  it('cria accounts, records, account_creations e request_log', async () => {
    const sql = pgliteSql(new PGlite())

    await applyMigrations(sql, migrationsDir)

    const tables = await sql<{ table_name: string }>(
      "select table_name from information_schema.tables where table_schema = 'public' order by table_name",
    )
    expect(tables.map((t) => t.table_name)).toEqual([
      'account_creations',
      'accounts',
      'records',
      'request_log',
      'schema_migrations',
    ])
  })

  it('não reaplica migração já registrada', async () => {
    const sql = pgliteSql(new PGlite())

    const first = await applyMigrations(sql, migrationsDir)
    const second = await applyMigrations(sql, migrationsDir)

    expect(first).toEqual(['001_init.sql', '002_request_log.sql'])
    expect(second).toEqual([])
  })

  it('apagar a conta apaga os registros', async () => {
    const sql = pgliteSql(new PGlite())
    await applyMigrations(sql, migrationsDir)
    await sql("insert into accounts (id) values ('a')")
    await sql(
      "insert into records (account_id, kind, id, updated_at, deleted, payload) values ('a', 'race', 'r1', now(), false, 'x')",
    )

    await sql("delete from accounts where id = 'a'")

    expect(await sql('select * from records')).toEqual([])
  })
})
