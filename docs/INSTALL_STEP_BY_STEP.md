# Installation — follow in this order

## 1. Back up Nestora Supabase
Create a database backup before migrations.

## 2. Run precheck
Supabase SQL Editor:
`sql/00_PRECHECK.sql`

The duplicate-calendar query should return no rows.

## 3. Create Aura schema
Run:
`sql/01_CREATE_AURA_SCHEMA.sql`

## 4. Create selective Nestora bridge
Run:
`sql/02_CREATE_NESTORA_BRIDGE.sql`

## 5. Create API RPCs
Run:
`sql/03_CREATE_API_RPCS.sql`

Read `04_SECURITY_NOTES.sql`.

## 6. Deploy Edge Function
From a Supabase CLI project:

supabase functions deploy aura-api

Set secrets:

supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
supabase secrets set SUPABASE_ANON_KEY=...
supabase secrets set AURA_LOCAL_DEV_TOKEN=<a long random local-only token>

Never put the service-role key in browser files.

## 7. Configure local Aura
Copy:
`web/js/aura-config.example.js`
to:
`web/js/aura-config.js`

Set:
- familyId
- deployed aura-api URL
- localDevToken (local development only)

## 8. Copy Web files
Replace your current Aura:
`aura-development-package/web/index.html`

with this package:
`web/index.html`

Copy all files in:
`web/js/`
into:
`aura-development-package/web/js/`

## 9. Start Aura
From `aura-development-package`:

npm run serve

## 10. First controlled test
Krishna -> My Plan:
- generate one day
- create 2 sessions
- include warmups/workout/cooldown
- click Sync

## 11. Verify Aura detail storage

select p.owner, pl.name, d.plan_date, s.title, s.start_time, i.block_type, i.name
from aura.sessions s
join aura.profiles p on p.id = s.profile_id
join aura.plans pl on pl.id = s.plan_id
join aura.plan_days d on d.id = s.plan_day_id
left join aura.session_items i on i.session_id = s.id
order by d.plan_date, s.start_time, i.block_type, i.sort_order;

## 12. Verify Nestora only received session summaries

select
  owner,
  item_date,
  start_time,
  end_time,
  title,
  source_table,
  source_id,
  notes
from public.family_calendar_items
where source_table = 'aura.sessions'
order by item_date, start_time;

Expected:
2 Aura sessions = 2 Nestora calendar rows.
Warmups and individual exercises stay in `aura.session_items`.

## 13. Edit + resync
Change session time/title.
Sync again.

Expected:
same Nestora calendar row updates, no duplicate.

## 14. Only after this works
Proceed with:
- recipes/meals
- habits
- postpartum sharing
- Apple Health
- deployment/authentication