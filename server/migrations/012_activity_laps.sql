create table activity_laps (
  account_id text not null references accounts(id) on delete cascade,
  activity_id bigint not null,
  data_enc text not null,
  fetched_at timestamptz not null default now(),
  primary key (account_id, activity_id)
);
