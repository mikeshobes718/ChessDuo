alter table public.push_tokens add column if not exists turn_alerts_enabled boolean not null default true;

comment on column public.push_tokens.turn_alerts_enabled is
  'Per-device opt-out for your-turn and nudge pushes, set from Settings > Sounds & Haptics.';
