create table activity_fit (
  account_id text not null references accounts(id) on delete cascade,
  activity_id bigint not null,
  version smallint not null,
  data_enc text not null,
  metrics_enc text,
  fetched_at timestamptz not null default now(),
  primary key (account_id, activity_id)
);
