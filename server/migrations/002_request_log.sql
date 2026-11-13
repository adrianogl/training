alter table records add column written_at timestamptz not null default now();

create table request_log (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  method text not null,
  route text not null,
  status integer not null,
  record_count integer,
  account_prefix text check (char_length(account_prefix) <= 8)
);

create index request_log_created_at on request_log (created_at);
