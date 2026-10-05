-- ============================================================
-- AURA SEPARATED-SCHEMA ARCHITECTURE PRECHECK
-- Nestora stays in public; Aura detail data goes into schema aura.
-- Run this file first.
-- ============================================================

-- Confirm core Nestora objects exist.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'families',
    'family_members',
    'family_calendar_items',
    'wellness_meal_links',
    'recipes',
    'health_fitness_external_profiles',
    'health_fitness_profile_mappings',
    'pregnancy_profile'
  )
order by table_name;

-- Check for duplicate calendar source mappings BEFORE adding unique index.
select family_id, source_table, source_id, count(*) as duplicate_count
from public.family_calendar_items
where source_table is not null
  and source_id is not null
group by family_id, source_table, source_id
having count(*) > 1;

-- Show family IDs for configuration.
select id, name, created_at
from public.families
order by created_at;