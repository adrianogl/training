create table watch_tokens (
  token_hash text primary key,
  account_id text not null references accounts(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table readiness (
  account_id text primary key references accounts(id) on delete cascade,
  day date not null,
  score smallint not null check (score between 0 and 100),
  verdict text not null check (char_length(verdict) <= 24),
  updated_at timestamptz not null default now()
);
