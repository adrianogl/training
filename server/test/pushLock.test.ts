import { PGlite } from '@electric-sql/pglite'
import { describe, expect, it } from 'vitest'
import { pushStatements } from '../src/merge.js'
import { incomingRecord, migrationsDir, pgliteSql } from './helpers.js'
import { applyMigrations } from '../scripts/migrate.js'

describe('pushStatements', () => {
  it('pega o advisory lock da conta antes de gravar e segura até o commit', async () => {
    const db = new PGlite()
    await applyMigrations(pgliteSql(db), migrationsDir)
    await db.query("insert into accounts (id) values ('conta')")

    const locks = await db.transaction(async (tx) => {
      const [first] = pushStatements('conta', [incomingRecord('r1')], 1024)
      await tx.query(first?.text ?? '', first?.params ?? [])
      return (
        await tx.query<{ held: boolean }>(
          "select (objid::int = hashtext('conta')) as held from pg_locks where locktype = 'advisory' and mode = 'ExclusiveLock'",
        )
      ).rows
    })
    const afterCommit = await db.query("select 1 from pg_locks where locktype = 'advisory'")

    expect(locks).toEqual([{ held: true }])
    expect(afterCommit.rows).toEqual([])
  })
})
