create table accounts (
  id text primary key,
  created_at timestamptz not null default now()
);

create table records (
  account_id text not null references accounts(id) on delete cascade,
  kind text not null check (kind in ('race', 'decision')),
  id text not null,
  updated_at timestamptz not null,
  deleted boolean not null default false,
  payload text,
  seq bigserial not null,
  primary key (account_id, kind, id)
);

create index records_account_seq on records (account_id, seq);

create table account_creations (
  ip_hash text not null,
  created_at timestamptz not null default now()
);

create index account_creations_ip_created on account_creations (ip_hash, created_at);
