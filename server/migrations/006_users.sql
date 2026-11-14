create table users (
  id text primary key,
  account_id text not null unique references accounts(id) on delete cascade,
  email text not null,
  name text not null,
  password_hash text not null,
  email_verified_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index users_email on users (lower(email));

create table sessions (
  token_hash text primary key,
  id text not null unique,
  user_id text not null references users(id) on delete cascade,
  device text not null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create index sessions_user on sessions (user_id);

create table email_tokens (
  token_hash text primary key,
  user_id text not null references users(id) on delete cascade,
  purpose text not null check (purpose in ('verify', 'reset')),
  expires_at timestamptz not null,
  used_at timestamptz
);

create table login_attempts (
  ip_hash text not null,
  created_at timestamptz not null default now()
);

create index login_attempts_ip_created on login_attempts (ip_hash, created_at);
