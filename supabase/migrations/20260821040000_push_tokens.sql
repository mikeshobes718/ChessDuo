create extension if not exists pgcrypto;

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

comment on table public.push_tokens is
  'APNs device tokens per player. Access is restricted to server-side service role requests.';
