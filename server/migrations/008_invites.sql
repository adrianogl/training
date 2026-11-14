alter table users add column role text not null default 'member' check (role in ('member', 'guest'));

create table invites (
  id text primary key,
  token_hash text not null unique,
  name text not null,
  email text,
  channel text not null check (channel in ('email', 'whatsapp', 'link')),
  created_by text references users(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_user_id text references users(id) on delete set null,
  accepted_at timestamptz,
  canceled_at timestamptz
);

create index invites_created on invites (created_at desc);
