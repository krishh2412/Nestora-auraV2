-- ============================================================
-- SELECTIVE AURA -> NESTORA BRIDGE
-- Detailed Aura data stays in schema aura.
-- Only summaries/actions are written into Nestora public tables.
-- ============================================================

-- PRECHECK:
-- This must return zero rows before creating the unique index.
select family_id, source_table, source_id, count(*) as duplicate_count
from public.family_calendar_items
where source_table = 'aura.sessions'
  and source_id is not null
group by family_id, source_table, source_id
having count(*) > 1;

create unique index if not exists uq_family_calendar_aura_source
on public.family_calendar_items(family_id, source_table, source_id)
where source_table = 'aura.sessions' and source_id is not null;

-- ------------------------------------------------------------
-- Sync ONE Aura session to ONE Nestora calendar item.
-- Warmups/exercises/cooldown remain in Aura; Nestora gets summary.
-- ------------------------------------------------------------
create or replace function public.aura_sync_session_to_nestora(p_session_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, aura
as $$
declare
  s aura.sessions%rowtype;
  d aura.plan_days%rowtype;
  p aura.plans%rowtype;
  v_calendar_id uuid;
  v_end_time time;
  v_detail text;
begin
  select * into s from aura.sessions where id = p_session_id;
  if not found then
    raise exception 'Aura session not found: %', p_session_id;
  end if;

  if not s.nestora_sync_enabled then
    return null;
  end if;

  select * into d from aura.plan_days where id = s.plan_day_id;
  select * into p from aura.plans where id = s.plan_id;

  if s.start_time is not null and s.duration_minutes is not null then
    v_end_time := (s.start_time + make_interval(mins => s.duration_minutes))::time;
  else
    v_end_time := null;
  end if;

  v_detail := concat_ws(
    E'\n',
    'Aura plan: ' || p.name,
    case when p.goal is not null then 'Goal: ' || p.goal end,
    case when s.duration_minutes is not null then 'Duration: ' || s.duration_minutes || ' min' end,
    'Open Aura for warm-up, exercises, cooldown and logs.'
  );

  insert into public.family_calendar_items (
    family_id,
    title,
    item_date,
    start_time,
    end_time,
    owner,
    module,
    item_type,
    source_table,
    source_id,
    notes,
    status,
    created_by,
    created_at,
    updated_at
  )
  values (
    s.family_id::text,
    s.title,
    d.plan_date,
    s.start_time,
    v_end_time,
    (select owner from aura.profiles where id = s.profile_id),
    'Fitness',
    s.session_type,
    'aura.sessions',
    s.id::text,
    v_detail,
    s.status,
    'Aura',
    now(),
    now()
  )
  on conflict (family_id, source_table, source_id)
  where source_table = 'aura.sessions' and source_id is not null
  do update set
    title = excluded.title,
    item_date = excluded.item_date,
    start_time = excluded.start_time,
    end_time = excluded.end_time,
    owner = excluded.owner,
    module = excluded.module,
    item_type = excluded.item_type,
    notes = excluded.notes,
    status = excluded.status,
    updated_at = now()
  returning id into v_calendar_id;

  update aura.sessions
  set nestora_calendar_item_id = v_calendar_id
  where id = s.id;

  return v_calendar_id;
end;
$$;

-- ------------------------------------------------------------
-- Sync all sessions in a plan.
-- ------------------------------------------------------------
create or replace function public.aura_sync_plan_calendar_to_nestora(p_plan_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, aura
as $$
declare
  r record;
  v_count integer := 0;
begin
  for r in
    select id from aura.sessions
    where plan_id = p_plan_id
      and nestora_sync_enabled = true
  loop
    perform public.aura_sync_session_to_nestora(r.id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ------------------------------------------------------------
-- Sync a meal assignment to existing wellness_meal_links.
-- Recipe library remains public.recipes.
-- ------------------------------------------------------------
create or replace function public.aura_sync_meal_to_nestora(p_meal_assignment_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, aura
as $$
declare
  m aura.meal_assignments%rowtype;
  pr aura.profiles%rowtype;
  v_id uuid;
  v_wellness_plan_id uuid;
begin
  select * into m from aura.meal_assignments where id = p_meal_assignment_id;
  if not found then
    raise exception 'Aura meal assignment not found';
  end if;

  if not m.nestora_sync_enabled then
    return null;
  end if;

  select * into pr from aura.profiles where id = m.profile_id;

  -- We deliberately keep Aura plan as the detailed master.
  -- wellness_plan_id may remain null unless you choose to create
  -- a public wellness plan summary later.
  insert into public.wellness_meal_links (
    family_id,
    wellness_plan_id,
    owner,
    source_item_id,
    recipe_id,
    meal_type,
    planned_date,
    protein_target_g,
    calorie_target,
    notes,
    created_at,
    updated_at
  )
  values (
    m.family_id::text,
    v_wellness_plan_id,
    pr.owner,
    m.id::text,
    m.recipe_id,
    m.meal_type,
    m.planned_date,
    m.protein_target_g,
    m.calorie_target,
    m.notes,
    now(),
    now()
  )
  returning id into v_id;

  update aura.meal_assignments
  set nestora_meal_link_id = v_id
  where id = m.id;

  return v_id;
end;
$$;

-- ------------------------------------------------------------
-- Daily Health summary stays optional.
-- Raw HealthKit samples NEVER move into Nestora.
-- ------------------------------------------------------------
create or replace view public.aura_health_summary_for_nestora as
select
  h.family_id::text as family_id,
  p.owner,
  h.summary_date,
  h.steps,
  h.active_energy_kcal,
  h.exercise_minutes,
  h.sleep_minutes,
  h.resting_heart_rate,
  h.hrv_ms,
  h.workouts_count
from aura.health_daily_summaries h
join aura.profiles p on p.id = h.profile_id;