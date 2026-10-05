create extension if not exists pgcrypto;
create schema if not exists aura;

-- ------------------------------------------------------------
-- Permanent Aura profile configuration for a Nestora family member.
-- One person may have multiple Aura profiles if desired, but normally
-- one long-lived wellness identity can own many time-bound plans.
-- ------------------------------------------------------------
create table if not exists aura.profiles (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  family_member_id uuid references public.family_members(id) on delete set null,
  owner text not null,
  name text not null,
  profile_type text not null default 'standard_adult',
  pregnancy_enabled boolean not null default false,
  postpartum_enabled boolean not null default false,
  status text not null default 'active',
  preferences jsonb not null default '{}'::jsonb,
  motivation_config jsonb not null default '{}'::jsonb,
  privacy_config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ix_aura_profiles_family_member
  on aura.profiles(family_id, family_member_id);

-- ------------------------------------------------------------
-- Time-bound or ongoing plans.
-- Examples:
-- Krishna - Protein Plan Sep-Nov
-- Krishna - Strength Plan Dec-Mar
-- Varshini - Postpartum Recovery
-- ------------------------------------------------------------
create table if not exists aura.plans (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  name text not null,
  plan_type text not null default 'fitness',
  goal text,
  start_date date,
  end_date date,
  status text not null default 'draft',
  nutrition_config jsonb not null default '{}'::jsonb,
  motivation_config jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ix_aura_plans_profile_dates
  on aura.plans(profile_id, start_date, end_date);

-- ------------------------------------------------------------
-- Day structure for each plan.
-- ------------------------------------------------------------
create table if not exists aura.plan_days (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  plan_id uuid not null references aura.plans(id) on delete cascade,
  plan_date date not null,
  day_label text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(plan_id, plan_date)
);

-- ------------------------------------------------------------
-- Multiple sessions per day.
-- One session becomes one Nestora calendar entry.
-- ------------------------------------------------------------
create table if not exists aura.sessions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  plan_id uuid not null references aura.plans(id) on delete cascade,
  plan_day_id uuid not null references aura.plan_days(id) on delete cascade,
  title text not null,
  session_type text not null default 'workout',
  start_time time,
  duration_minutes integer,
  location text,
  status text not null default 'planned',
  nestora_sync_enabled boolean not null default true,
  nestora_calendar_item_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ix_aura_sessions_plan_day
  on aura.sessions(plan_day_id, start_time);

-- ------------------------------------------------------------
-- Warm-up / workout / cooldown items.
-- ------------------------------------------------------------
create table if not exists aura.session_items (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  session_id uuid not null references aura.sessions(id) on delete cascade,
  block_type text not null check (block_type in ('warmup','workout','cooldown')),
  sort_order integer not null default 0,
  name text not null,
  prescription text,
  sets numeric,
  reps text,
  duration_minutes numeric,
  distance numeric,
  distance_unit text,
  equipment text,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ix_aura_session_items_session
  on aura.session_items(session_id, block_type, sort_order);

-- ------------------------------------------------------------
-- Actual workout execution.
-- ------------------------------------------------------------
create table if not exists aura.workout_logs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  session_id uuid references aura.sessions(id) on delete set null,
  logged_at timestamptz not null default now(),
  status text not null default 'completed',
  perceived_effort numeric,
  energy_before numeric,
  energy_after numeric,
  notes text,
  metrics jsonb not null default '{}'::jsonb
);

-- ------------------------------------------------------------
-- Habits and habit logs.
-- ------------------------------------------------------------
create table if not exists aura.habits (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  plan_id uuid references aura.plans(id) on delete cascade,
  name text not null,
  habit_type text not null default 'daily',
  start_date date,
  end_date date,
  target jsonb not null default '{}'::jsonb,
  rules jsonb not null default '{}'::jsonb,
  why_text text,
  family_impact_text text,
  minimum_version text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists aura.habit_logs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  habit_id uuid not null references aura.habits(id) on delete cascade,
  log_date date not null,
  status text not null default 'done',
  value jsonb not null default '{}'::jsonb,
  note text,
  created_at timestamptz not null default now(),
  unique(habit_id, log_date)
);

-- ------------------------------------------------------------
-- Automatic motivation state + history.
-- Decision logic can run without an AI model.
-- ------------------------------------------------------------
create table if not exists aura.motivation_state (
  profile_id uuid primary key references aura.profiles(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  momentum_score numeric not null default 0,
  current_streak integer not null default 0,
  consecutive_misses integer not null default 0,
  current_priority text,
  current_tone text,
  current_message text,
  context jsonb not null default '{}'::jsonb,
  evaluated_at timestamptz not null default now()
);

create table if not exists aura.motivation_events (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  event_type text not null,
  priority text,
  tone text,
  message text,
  context jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Postpartum / recovery data stays private in Aura.
-- Nestora only receives intentionally shared support actions.
-- ------------------------------------------------------------
create table if not exists aura.recovery_checkins (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  checkin_at timestamptz not null default now(),
  mood text,
  energy numeric,
  sleep_quality text,
  pain_level numeric,
  overwhelm text,
  support_need text,
  recovery_mode text,
  recovery_score numeric,
  private_note text,
  share_summary boolean not null default false,
  shared_summary jsonb not null default '{}'::jsonb
);

-- ------------------------------------------------------------
-- Nutrition assignments reference Nestora recipe library.
-- No duplicate Aura recipe master.
-- ------------------------------------------------------------
create table if not exists aura.meal_assignments (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  plan_id uuid references aura.plans(id) on delete cascade,
  planned_date date not null,
  meal_type text not null,
  recipe_id uuid references public.recipes(id) on delete set null,
  protein_target_g numeric,
  calorie_target numeric,
  notes text,
  nestora_sync_enabled boolean not null default true,
  nestora_meal_link_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Detailed Apple Health / HealthKit samples live ONLY in Aura.
-- ------------------------------------------------------------
create table if not exists aura.health_samples (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  sample_id text not null,
  metric_type text not null,
  recorded_at timestamptz not null,
  value_numeric numeric,
  value_text text,
  unit text,
  source_bundle text,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(profile_id, sample_id)
);

create index if not exists ix_aura_health_samples_metric_time
  on aura.health_samples(profile_id, metric_type, recorded_at);

create table if not exists aura.health_daily_summaries (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  summary_date date not null,
  steps numeric,
  active_energy_kcal numeric,
  exercise_minutes numeric,
  sleep_minutes numeric,
  resting_heart_rate numeric,
  hrv_ms numeric,
  workouts_count integer,
  summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(profile_id, summary_date)
);

-- ------------------------------------------------------------
-- External integration links.
-- ------------------------------------------------------------
create table if not exists aura.integration_links (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  integration_type text not null,
  external_profile_id text,
  active boolean not null default true,
  permissions jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(profile_id, integration_type, external_profile_id)
);

-- Generic updated_at trigger.
create or replace function aura.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles','plans','plan_days','sessions','session_items',
    'habits','meal_assignments','health_daily_summaries','integration_links'
  ]
  loop
    execute format('drop trigger if exists trg_touch_%I on aura.%I', t, t);
    execute format(
      'create trigger trg_touch_%I before update on aura.%I
       for each row execute function aura.touch_updated_at()', t, t
    );
  end loop;
end $$;