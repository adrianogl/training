create table garmin_connections (
  account_id text primary key references accounts(id) on delete cascade,
  session_enc text not null,
  expires_at timestamptz not null,
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table garmin_pending_logins (
  account_id text primary key references accounts(id) on delete cascade,
  state_enc text not null,
  expires_at timestamptz not null
);
