create table strava_links (
  account_id text primary key references accounts(id) on delete cascade,
  athlete_id bigint not null,
  athlete_name text not null default '',
  access_token_enc text not null,
  refresh_token_enc text not null,
  expires_at timestamptz not null,
  scope text not null default '',
  format text not null default 'B',
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table strava_posts (
  account_id text not null references accounts(id) on delete cascade,
  activity_id text not null,
  strava_activity_id bigint not null,
  posted_at timestamptz not null default now(),
  text_hash text not null,
  primary key (account_id, strava_activity_id)
);
