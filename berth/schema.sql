-- Chess Duo owner tables (live on Berth app chessduo).
-- Created via: berth tables create ... --read owner --write owner [--updated-at]
--
-- profiles (owner_id unique via upsert on owner_id)
--   display_name text
--   settings jsonb   Stamped<SyncedSettings>
--   stats jsonb      Stamped<PlayerStats>
--   active_room jsonb Stamped<OnlineSessionInfo>
--   recent_rooms jsonb { codes: string[] }
--
-- game_records (upsert on id)
--   id uuid (client game id)
--   mode text
--   started_at, ended_at timestamptz
--   is_finished boolean
--   data jsonb (GameRecord)
--   deleted_at timestamptz (tombstone)
--   updated_at timestamptz (row sync cursor)

alter table profiles
  add constraint profiles_owner_one unique (owner_id);;

create index if not exists game_records_owner_updated on game_records (owner_id, updated_at asc);;
