-- Aura v3 Systems incremental migration. Safe additive schema; does not replace Nestora tables.
create schema if not exists aura;
create table if not exists aura.behavior_systems (
  id uuid primary key default gen_random_uuid(), family_id text not null, profile_key text not null,
  identity_statement text, name text not null, minimum_version text, cue text, environment_setup text,
  attractive_pairing text, friction_plan text, recovery_rule text default 'never_miss_twice', active boolean default true,
  created_at timestamptz default now(), updated_at timestamptz default now()
);
create table if not exists aura.workout_preferences (
  id uuid primary key default gen_random_uuid(), family_id text not null, profile_key text not null,
  timing_mode text default 'automatic', heavy_rest_seconds int default 120, moderate_rest_seconds int default 90,
  high_rep_rest_seconds int default 60, voice_coach boolean default true, countdown_seconds int default 5,
  unique(family_id, profile_key)
);
create table if not exists aura.identity_votes (
  id uuid primary key default gen_random_uuid(), family_id text not null, profile_key text not null,
  vote_date date not null default current_date, source_type text not null, source_id text not null,
  full_completion boolean default true, xp_awarded int default 0, created_at timestamptz default now(),
  unique(family_id, profile_key, vote_date, source_type, source_id)
);
create index if not exists aura_behavior_systems_family_profile_idx on aura.behavior_systems(family_id,profile_key);
create index if not exists aura_identity_votes_family_profile_date_idx on aura.identity_votes(family_id,profile_key,vote_date);
