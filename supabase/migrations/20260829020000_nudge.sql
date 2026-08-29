alter table public.games add column if not exists white_last_seen timestamptz;
alter table public.games add column if not exists black_last_seen timestamptz;
alter table public.games add column if not exists white_last_nudge_at timestamptz;
alter table public.games add column if not exists black_last_nudge_at timestamptz;
alter table public.games add column if not exists white_nudge_count integer not null default 0;
alter table public.games add column if not exists black_nudge_count integer not null default 0;
alter table public.games add column if not exists last_nudge jsonb;

comment on column public.games.last_nudge is
  'Latest nudge event {id, fromColor, fromName, createdAt} for in-app poll delivery.';
