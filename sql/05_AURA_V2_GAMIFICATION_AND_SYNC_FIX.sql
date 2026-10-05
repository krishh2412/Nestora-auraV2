-- Aura v2: gamification persistence + safer Nestora calendar sync
create table if not exists aura.quest_logs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  quest_key text not null,
  quest_date date not null default current_date,
  title text not null,
  category text not null default 'daily',
  xp integer not null default 0,
  completed boolean not null default false,
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(profile_id, quest_key, quest_date)
);

create table if not exists aura.player_state (
  profile_id uuid primary key references aura.profiles(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  xp integer not null default 0,
  level integer not null default 1,
  current_streak integer not null default 0,
  longest_streak integer not null default 0,
  hard_mode boolean not null default false,
  last_active_date date,
  updated_at timestamptz not null default now()
);

create table if not exists aura.achievements (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references aura.profiles(id) on delete cascade,
  achievement_key text not null,
  title text not null,
  description text,
  unlocked_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique(profile_id, achievement_key)
);

-- Clean accidental Aura calendar duplicates before enforcing idempotency.
with ranked as (
  select id, row_number() over(partition by family_id,source_table,source_id order by updated_at desc nulls last, created_at desc nulls last, id) rn
  from public.family_calendar_items
  where source_table='aura.sessions' and source_id is not null
)
delete from public.family_calendar_items f using ranked r where f.id=r.id and r.rn>1;

create unique index if not exists uq_family_calendar_aura_source
on public.family_calendar_items(family_id, source_table, source_id)
where source_table='aura.sessions' and source_id is not null;

create or replace function public.aura_quest_toggle(
  p_family_id uuid, p_profile_id uuid, p_quest_key text, p_title text,
  p_category text, p_xp integer, p_completed boolean, p_quest_date date default current_date,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,aura as $$
declare v_old boolean:=false; v_delta integer:=0; v_total integer; v_level integer; v_streak integer;
begin
  select completed into v_old from aura.quest_logs where profile_id=p_profile_id and quest_key=p_quest_key and quest_date=p_quest_date;
  if not found then v_old:=false; end if;
  insert into aura.quest_logs(family_id,profile_id,quest_key,quest_date,title,category,xp,completed,completed_at,metadata)
  values(p_family_id,p_profile_id,p_quest_key,p_quest_date,p_title,coalesce(p_category,'daily'),greatest(coalesce(p_xp,0),0),p_completed,case when p_completed then now() end,coalesce(p_metadata,'{}'::jsonb))
  on conflict(profile_id,quest_key,quest_date) do update set title=excluded.title,category=excluded.category,xp=excluded.xp,completed=excluded.completed,completed_at=case when excluded.completed then coalesce(aura.quest_logs.completed_at,now()) else null end,metadata=excluded.metadata,updated_at=now();
  if p_completed and not v_old then v_delta:=greatest(coalesce(p_xp,0),0); elsif not p_completed and v_old then v_delta:=-greatest(coalesce(p_xp,0),0); end if;
  insert into aura.player_state(profile_id,family_id,xp,level,last_active_date)
  values(p_profile_id,p_family_id,greatest(v_delta,0),1,current_date)
  on conflict(profile_id) do update set xp=greatest(0,aura.player_state.xp+v_delta),last_active_date=current_date,updated_at=now();
  select xp into v_total from aura.player_state where profile_id=p_profile_id;
  v_level:=greatest(1,floor(sqrt(v_total::numeric/100))+1)::integer;
  select count(*) into v_streak from (select quest_date from aura.quest_logs where profile_id=p_profile_id and completed group by quest_date order by quest_date desc limit 66) q;
  update aura.player_state set level=v_level,current_streak=v_streak,longest_streak=greatest(longest_streak,v_streak) where profile_id=p_profile_id;
  return jsonb_build_object('xp',v_total,'level',v_level,'streak',v_streak,'delta',v_delta);
end $$;

create or replace function public.aura_player_snapshot(p_profile_id uuid)
returns jsonb language sql security definer set search_path=public,aura as $$
select jsonb_build_object(
 'player',coalesce((select to_jsonb(s) from aura.player_state s where s.profile_id=p_profile_id),'{}'::jsonb),
 'quests',coalesce((select jsonb_agg(to_jsonb(q) order by q.quest_date desc,q.created_at) from aura.quest_logs q where q.profile_id=p_profile_id and q.quest_date>=current_date-30),'[]'::jsonb),
 'achievements',coalesce((select jsonb_agg(to_jsonb(a) order by a.unlocked_at desc) from aura.achievements a where a.profile_id=p_profile_id),'[]'::jsonb)
); $$;
