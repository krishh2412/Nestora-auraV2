# Aura v2 — GitHub -> Vercel deployment

## 1. Supabase database
In the SAME Supabase project used by Nestora, run SQL files in this order only if the earlier files are not already installed:
- `sql/00_PRECHECK.sql`
- `sql/01_CREATE_AURA_SCHEMA.sql`
- `sql/02_CREATE_NESTORA_BRIDGE.sql`
- `sql/03_CREATE_API_RPCS.sql`
- `sql/05_AURA_V2_GAMIFICATION_AND_SYNC_FIX.sql` (new; run this for v2)

The v2 migration removes accidental Aura calendar duplicates and enforces one Nestora calendar item per Aura session.

## 2. Edge Function
Deploy `supabase/functions/aura-api/index.ts` as function name `aura-api`.
The function needs `AURA_LOCAL_DEV_TOKEN` while temporary dev-token access is in use. Do not put the service-role key in Vercel or browser code.

## 3. GitHub
Put the CONTENTS of this folder at the root of the GitHub repo. `package.json` must be visible on the first page of the repo.

## 4. Vercel project
Import that GitHub repo.
- Framework preset: Other
- Root Directory: `./`
- Build command: `npm run build` (also stored in vercel.json)
- Output: `dist` (also stored in vercel.json)

Add Environment Variables in Vercel:
- `AURA_FAMILY_ID`
- `AURA_API_URL`
- `AURA_LOCAL_DEV_TOKEN` (temporary; remove after Supabase Auth rollout)

Apply them to Production + Preview + Development, then deploy.

## 5. Acceptance test
1. Open Krishna profile, generate plan, assign dates, sync.
2. Confirm Nestora calendar has one event per Aura session.
3. Change a session time and sync again. It must update the same Nestora event.
4. Complete a Daily Quest. Refresh Aura: local state must remain.
5. Confirm `aura.quest_logs` and `aura.player_state` receive cloud records.
6. Repeat plan sync for Varshini.

## Important
The temporary dev token is a bridge for the current private family deployment only. It is not suitable for a public multi-family product. The next security phase is Supabase Auth + family membership authorization.
