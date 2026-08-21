create extension if not exists pgcrypto;

create table if not exists public.games (
  id uuid primary key default gen_random_uuid(),
  room_code varchar(6) not null unique
    check (room_code ~ '^[A-HJ-NP-Z2-9]{4,6}$'),
  white_name varchar(40) not null,
  black_name varchar(40),
  white_token_hash char(64) not null,
  black_token_hash char(64),
  fen text not null,
  status text not null default 'waiting'
    check (status in ('waiting', 'active', 'white_won', 'black_won', 'draw')),
  coach_text text not null default '',
  coach_source text not null default 'quick'
    check (coach_source in ('ai', 'quick', 'lesson')),
  coach_history jsonb not null default '[]'::jsonb,
  last_move jsonb,
  suggested_hint jsonb,
  quiz jsonb,
  move_count integer not null default 0 check (move_count >= 0),
  white_hints_used integer not null default 0 check (white_hints_used >= 0),
  black_hints_used integer not null default 0 check (black_hints_used >= 0),
  hints_day date not null default (timezone('utc', now()))::date,
  version integer not null default 0 check (version >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.games add column if not exists coach_source text not null default 'quick';
alter table public.games add column if not exists coach_history jsonb not null default '[]'::jsonb;
alter table public.games add column if not exists suggested_hint jsonb;
alter table public.games add column if not exists quiz jsonb;
alter table public.games add column if not exists move_count integer not null default 0;
alter table public.games add column if not exists white_hints_used integer not null default 0;
alter table public.games add column if not exists black_hints_used integer not null default 0;
alter table public.games add column if not exists hints_day date not null default (timezone('utc', now()))::date;
alter table public.games add column if not exists move_history jsonb not null default '[]'::jsonb;
alter table public.games add column if not exists review jsonb;
alter table public.games add column if not exists draw_offer_by text
  check (draw_offer_by is null or draw_offer_by in ('white', 'black'));
alter table public.games add column if not exists undo_offer_by text
  check (undo_offer_by is null or undo_offer_by in ('white', 'black'));

create table if not exists public.match_archives (
  id uuid primary key default gen_random_uuid(),
  game_id uuid,
  room_code varchar(6) not null,
  white_name varchar(40) not null,
  black_name varchar(40),
  white_token_hash char(64) not null,
  black_token_hash char(64),
  status text not null check (status in ('white_won', 'black_won', 'draw')),
  move_count integer not null default 0,
  move_history jsonb not null default '[]'::jsonb,
  review jsonb,
  ended_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists match_archives_white_hash_idx on public.match_archives (white_token_hash, ended_at desc);
create index if not exists match_archives_black_hash_idx on public.match_archives (black_token_hash, ended_at desc);
create index if not exists match_archives_game_id_idx on public.match_archives (game_id);

alter table public.games enable row level security;
alter table public.games force row level security;
alter table public.match_archives enable row level security;
alter table public.match_archives force row level security;

revoke all on table public.games from anon, authenticated;
grant all on table public.games to service_role;
revoke all on table public.match_archives from anon, authenticated;
grant all on table public.match_archives to service_role;

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  player_token_hash char(64) not null,
  room_code text,
  apns_token text not null unique,
  updated_at timestamptz not null default now()
);

create index if not exists push_tokens_hash_idx on public.push_tokens (player_token_hash);

alter table public.push_tokens enable row level security;
alter table public.push_tokens force row level security;

revoke all on table public.push_tokens from anon, authenticated;
grant all on table public.push_tokens to service_role;

comment on table public.games is
  'Private game state. No client RLS policies; access is restricted to server-side service role requests.';
comment on table public.match_archives is
  'Finished match scorecards. Survives rematch resets on the live games row.';
