# Aura + Nestora Architecture

## One Supabase project, two data domains

### `public` = Nestora
Nestora remains the Family OS:
- families
- family_members
- family_calendar_items
- tasks / notifications
- recipes
- meal planning
- pregnancy_profile
- other family coordination

### `aura` = Personal Health / Fitness / Recovery OS
Aura owns detailed:
- profiles
- time-bound plans
- day plans
- multiple workout sessions per day
- warm-up / workout / cooldown items
- workout logs
- habits
- automatic motivation
- private postpartum recovery check-ins
- meal assignments
- raw Apple Health / Apple Watch samples
- health summaries

## Bridge principle

Only selected summaries move from Aura into Nestora.

### Sync to Nestora
- workout session date/time/title/duration/status
- selected meal plan links
- intentionally shared family-support actions
- optional daily health summary
- active plan summary if desired

### Keep only in Aura
- sets / reps / weights
- every warm-up
- workout-detail history
- raw heart-rate / HRV / step samples
- motivation history
- private postpartum journal
- recovery/mood details unless explicitly shared

## Calendar hierarchy

Aura:
Plan -> Date -> Session -> Warmup/Workout/Cooldown

Nestora:
one `family_calendar_items` row per SESSION.

This avoids calendar clutter.