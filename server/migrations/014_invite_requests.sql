create table invite_requests (
  id text primary key,
  data_enc text not null,
  ip_hash text not null,
  status text not null default 'pending' check (status in ('pending', 'invited', 'declined')),
  created_at timestamptz not null default now(),
  handled_at timestamptz
);

create index invite_requests_status on invite_requests (status, created_at desc);
create index invite_requests_ip on invite_requests (ip_hash, created_at);
