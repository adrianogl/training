import {
  ACCOUNT_CREATION_LIMIT,
  ACCOUNT_CREATION_LOCK_KEY,
  ACCOUNT_CREATION_WINDOW_MS,
} from './constants.js'
import type { Sql, SqlStatement } from './db.js'
import type { CreateAccountOutcome } from './types.js'

export function createAccountStatements(
  accountId: string,
  ipHash: string,
  now: Date,
  maxAccounts: number,
): SqlStatement[] {
  const windowStart = new Date(now.getTime() - ACCOUNT_CREATION_WINDOW_MS).toISOString()
  return [
    {
      text: 'select 1 as locked from pg_advisory_xact_lock(hashtext($1))',
      params: [ACCOUNT_CREATION_LOCK_KEY],
    },
    {
      text: 'delete from account_creations where created_at <= $1::timestamptz',
      params: [windowStart],
    },
    {
      text: `with created as (
               insert into accounts (id)
               select $1::text
               where not exists (select 1 from accounts where id = $1::text)
                 and (select count(*) from accounts) < $3::int
                 and (select count(*) from account_creations
                      where ip_hash = $2::text and created_at > $4::timestamptz) < $5::int
               on conflict do nothing
               returning id
             ),
             logged as (
               insert into account_creations (ip_hash, created_at)
               select $2::text, $6::timestamptz from created
             )
             select (select count(*) from created)::int as created,
                    exists (select 1 from accounts where id = $1::text) as existed`,
      params: [accountId, ipHash, maxAccounts, windowStart, ACCOUNT_CREATION_LIMIT, now.toISOString()],
    },
  ]
}

export async function createAccount(
  sql: Sql,
  accountId: string,
  ipHash: string,
  now: Date,
  maxAccounts: number,
): Promise<CreateAccountOutcome> {
  const results = await sql.transaction(createAccountStatements(accountId, ipHash, now, maxAccounts))
  const row = results.at(-1)?.[0] as { created: number; existed: boolean } | undefined
  if (row?.created === 1) {
    return 'created'
  }
  return row?.existed === true ? 'exists' : 'rate_limited'
}

export async function deleteAccount(sql: Sql, accountId: string): Promise<boolean> {
  const deleted = await sql('delete from accounts where id = $1 returning id', [accountId])
  return deleted.length > 0
}
