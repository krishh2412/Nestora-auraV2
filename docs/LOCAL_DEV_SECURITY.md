# Local Development Security

The package includes `AURA_LOCAL_DEV_TOKEN` so you can develop before wiring final Nestora login.

This is LOCAL DEVELOPMENT ONLY.

- Edge Function secret: `AURA_LOCAL_DEV_TOKEN`
- browser config: matching `localDevToken`

Before public deployment:
1. remove local dev token from browser config
2. use Supabase Auth session
3. verify membership through `family_members.user_id`
4. keep service-role key only in Edge Function environment
5. never expose service-role key in HTML/JavaScript