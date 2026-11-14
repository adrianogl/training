create table health_days (
  account_id text not null references accounts(id) on delete cascade,
  day date not null,
  data_enc text not null,
  updated_at timestamptz not null default now(),
  primary key (account_id, day)
);

create table activities (
  account_id text not null references accounts(id) on delete cascade,
  activity_id bigint not null,
  day date not null,
  data_enc text not null,
  updated_at timestamptz not null default now(),
  primary key (account_id, activity_id)
);

create index activities_account_day on activities (account_id, day desc);

create table garmin_sync_state (
  account_id text primary key references accounts(id) on delete cascade,
  profile_enc text,
  oldest_day date,
  activities_done boolean not null default false,
  last_sync_at timestamptz
);
