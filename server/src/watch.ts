import { LOG_ACCOUNT_PREFIX_LENGTH, REQUEST_LOG_RETENTION_DAYS, WATCH_READINESS_ROUTE } from './constants.js'
import type { Sql, SqlStatement } from './db.js'
import type { Readiness, WatchReadinessLookup } from './types.js'

export function replaceWatchTokenStatements(accountId: string, tokenHash: string): SqlStatement[] {
  return [
    {
      text: 'select 1 as locked from pg_advisory_xact_lock(hashtext($1))',
      params: [`watch_token:${accountId}`],
    },
    {
      text: `delete from watch_tokens
             where account_id = $1::text
               and not exists (select 1 from watch_tokens where token_hash = $2::text and account_id <> $1::text)`,
      params: [accountId, tokenHash],
    },
    {
      text: `insert into watch_tokens (token_hash, account_id)
             values ($2::text, $1::text)
             on conflict (token_hash) do update set account_id = watch_tokens.account_id
             returning account_id = $1::text as owned`,
      params: [accountId, tokenHash],
    },
  ]
}

export async function replaceWatchToken(sql: Sql, accountId: string, tokenHash: string): Promise<boolean> {
  const results = await sql.transaction(replaceWatchTokenStatements(accountId, tokenHash))
  return (results.at(-1)?.[0] as { owned: boolean } | undefined)?.owned === true
}

export async function revokeWatchToken(sql: Sql, accountId: string): Promise<void> {
  await sql('delete from watch_tokens where account_id = $1', [accountId])
}

export async function saveReadiness(sql: Sql, accountId: string, readiness: Readiness): Promise<void> {
  await sql(
    `insert into readiness (account_id, day, score, verdict) values ($1, $2::date, $3, $4)
     on conflict (account_id) do update
     set day = excluded.day, score = excluded.score, verdict = excluded.verdict, updated_at = now()`,
    [accountId, readiness.day, readiness.score, readiness.verdict],
  )
}

export async function readinessForWatchToken(sql: Sql, tokenHash: string): Promise<WatchReadinessLookup> {
  const rows = await sql<{ day: string | null; score: number | null; verdict: string | null }>(
    `with hit as (
       select w.account_id, r.day, r.score, r.verdict
       from watch_tokens w
       left join readiness r on r.account_id = w.account_id
       where w.token_hash = $1
     ),
     expired as (
       delete from request_log
       where exists (select 1 from hit) and created_at < now() - make_interval(days => $3::int)
     ),
     logged as (
       insert into request_log (method, route, status, account_prefix)
       select 'GET', $4, case when day is null then 404 else 200 end, left(account_id, $2::int) from hit
     )
     select to_char(day, 'YYYY-MM-DD') as day, score, verdict from hit`,
    [tokenHash, LOG_ACCOUNT_PREFIX_LENGTH, REQUEST_LOG_RETENTION_DAYS, WATCH_READINESS_ROUTE],
  )
  const row = rows[0]
  if (row === undefined) {
    return { status: 'unknown_token' }
  }
  if (row.day === null || row.score === null || row.verdict === null) {
    return { status: 'no_readiness' }
  }
  return { status: 'ok', readiness: { day: row.day, score: row.score, verdict: row.verdict } }
}
