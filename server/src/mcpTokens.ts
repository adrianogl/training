import type { Sql } from './db.js'

export async function replaceMcpToken(sql: Sql, accountId: string, tokenHash: string): Promise<boolean> {
  const results = await sql.transaction([
    { text: 'select 1 as locked from pg_advisory_xact_lock(hashtext($1))', params: [`mcp_token:${accountId}`] },
    { text: 'delete from mcp_tokens where account_id = $1::text', params: [accountId] },
    {
      text: `insert into mcp_tokens (token_hash, account_id) values ($2::text, $1::text)
             on conflict (token_hash) do update set account_id = mcp_tokens.account_id
             returning account_id = $1::text as owned`,
      params: [accountId, tokenHash],
    },
  ])
  return (results.at(-1)?.[0] as { owned: boolean } | undefined)?.owned === true
}

export async function revokeMcpToken(sql: Sql, accountId: string): Promise<void> {
  await sql('delete from mcp_tokens where account_id = $1', [accountId])
}

export async function accountForMcpToken(sql: Sql, tokenHash: string): Promise<string | undefined> {
  const rows = await sql<{ account_id: string }>(
    'update mcp_tokens set last_used_at = now() where token_hash = $1 returning account_id',
    [tokenHash],
  )
  return rows[0]?.account_id
}
