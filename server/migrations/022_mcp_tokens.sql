create table mcp_tokens (
  token_hash text primary key,
  account_id text not null references accounts(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);

create index mcp_tokens_account on mcp_tokens (account_id);
