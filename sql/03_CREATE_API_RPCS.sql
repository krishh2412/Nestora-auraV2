-- ============================================================
-- Public wrapper functions used by the Edge Function.
-- The Edge Function holds service-role credentials; browser does not.
-- ============================================================

create or replace function public.aura_profile_upsert(
  p_id uuid,
  p_family_id uuid,
  p_family_member_id uuid,
  p_owner text,
  p_name text,
  p_profile_type text,
  p_pregnancy_enabled boolean,
  p_postpartum_enabled boolean,
  p_status text,
  p_preferences jsonb,
  p_motivation_config jsonb,
  p_privacy_config jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, aura
as $$
declare v_id uuid;
begin
  insert into aura.profiles(
    id, family_id, family_member_id, owner, name, profile_type,
    pregnancy_enabled, postpartum_enabled, status,
    preferences, motivation_config, privacy_config
  )
  values(
    coalesce(p_id, gen_random_uuid()), p_family_id, p_family_member_id,
    p_owner, p_name, coalesce(p_profile_type,'standard_adult'),
    coalesce(p_pregnancy_enabled,false), coalesce(p_postpartum_enabled,false),
    coalesce(p_status,'active'),
    coalesce(p_preferences,'{}'::jsonb),
    coalesce(p_motivation_config,'{}'::jsonb),
    coalesce(p_privacy_config,'{}'::jsonb)
  )
  on conflict (id) do update set
    family_member_id = excluded.family_member_id,
    owner = excluded.owner,
    name = excluded.name,
    profile_type = excluded.profile_type,
    pregnancy_enabled = excluded.pregnancy_enabled,
    postpartum_enabled = excluded.postpartum_enabled,
    status = excluded.status,
    preferences = excluded.preferences,
    motivation_config = excluded.motivation_config,
    privacy_config = excluded.privacy_config,
    updated_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.aura_plan_upsert(
  p_id uuid,
  p_family_id uuid,
  p_profile_id uuid,
  p_name text,
  p_plan_type text,
  p_goal text,
  p_start_date date,
  p_end_date date,
  p_status text,
  p_nutrition_config jsonb,
  p_motivation_config jsonb,
  p_metadata jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, aura
as $$
declare v_id uuid;
begin
  insert into aura.plans(
    id, family_id, profile_id, name, plan_type, goal,
    start_date, end_date, status, nutrition_config,
    motivation_config, metadata
  )
  values(
    coalesce(p_id, gen_random_uuid()), p_family_id, p_profile_id,
    p_name, coalesce(p_plan_type,'fitness'), p_goal,
    p_start_date, p_end_date, coalesce(p_status,'draft'),
    coalesce(p_nutrition_config,'{}'::jsonb),
    coalesce(p_motivation_config,'{}'::jsonb),
    coalesce(p_metadata,'{}'::jsonb)
  )
  on conflict (id) do update set
    name = excluded.name,
    plan_type = excluded.plan_type,
    goal = excluded.goal,
    start_date = excluded.start_date,
    end_date = excluded.end_date,
    status = excluded.status,
    nutrition_config = excluded.nutrition_config,
    motivation_config = excluded.motivation_config,
    metadata = excluded.metadata,
    updated_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

-- JSON session upsert:
-- one call creates/updates day, session, all items, and optionally Nestora calendar.
create or replace function public.aura_session_upsert_json(
  p_family_id uuid,
  p_profile_id uuid,
  p_plan_id uuid,
  p_session jsonb,
  p_sync_nestora boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, aura
as $$
declare
  v_day_id uuid;
  v_session_id uuid;
  v_date date := (p_session->>'date')::date;
  v_item jsonb;
  v_order integer;
begin
  insert into aura.plan_days(family_id, plan_id, plan_date, day_label)
  values(p_family_id, p_plan_id, v_date, p_session->>'day_label')
  on conflict(plan_id, plan_date) do update
    set day_label = excluded.day_label, updated_at = now()
  returning id into v_day_id;

  v_session_id := coalesce((p_session->>'id')::uuid, gen_random_uuid());

  insert into aura.sessions(
    id, family_id, profile_id, plan_id, plan_day_id,
    title, session_type, start_time, duration_minutes,
    location, status, nestora_sync_enabled, metadata
  )
  values(
    v_session_id, p_family_id, p_profile_id, p_plan_id, v_day_id,
    p_session->>'title',
    coalesce(p_session->>'session_type','workout'),
    nullif(p_session->>'start_time','')::time,
    nullif(p_session->>'duration_minutes','')::integer,
    p_session->>'location',
    coalesce(p_session->>'status','planned'),
    p_sync_nestora,
    coalesce(p_session->'metadata','{}'::jsonb)
  )
  on conflict(id) do update set
    plan_day_id = excluded.plan_day_id,
    title = excluded.title,
    session_type = excluded.session_type,
    start_time = excluded.start_time,
    duration_minutes = excluded.duration_minutes,
    location = excluded.location,
    status = excluded.status,
    nestora_sync_enabled = excluded.nestora_sync_enabled,
    metadata = excluded.metadata,
    updated_at = now();

  delete from aura.session_items where session_id = v_session_id;

  for v_item in select value from jsonb_array_elements(coalesce(p_session->'warmups','[]'::jsonb))
  loop
    v_order := coalesce((v_item->>'sort_order')::integer, 0);
    insert into aura.session_items(
      family_id, session_id, block_type, sort_order,
      name, prescription, equipment, notes, metadata
    ) values(
      p_family_id, v_session_id, 'warmup', v_order,
      v_item->>'name', v_item->>'prescription',
      v_item->>'equipment', v_item->>'notes',
      coalesce(v_item->'metadata','{}'::jsonb)
    );
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(p_session->'workout','[]'::jsonb))
  loop
    v_order := coalesce((v_item->>'sort_order')::integer, 0);
    insert into aura.session_items(
      family_id, session_id, block_type, sort_order,
      name, prescription, equipment, notes, metadata
    ) values(
      p_family_id, v_session_id, 'workout', v_order,
      v_item->>'name', v_item->>'prescription',
      v_item->>'equipment', v_item->>'notes',
      coalesce(v_item->'metadata','{}'::jsonb)
    );
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(p_session->'cooldown','[]'::jsonb))
  loop
    v_order := coalesce((v_item->>'sort_order')::integer, 0);
    insert into aura.session_items(
      family_id, session_id, block_type, sort_order,
      name, prescription, equipment, notes, metadata
    ) values(
      p_family_id, v_session_id, 'cooldown', v_order,
      v_item->>'name', v_item->>'prescription',
      v_item->>'equipment', v_item->>'notes',
      coalesce(v_item->'metadata','{}'::jsonb)
    );
  end loop;

  if p_sync_nestora then
    perform public.aura_sync_session_to_nestora(v_session_id);
  end if;

  return v_session_id;
end;
$$;