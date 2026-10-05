# Data Ownership Rules

| Data | Master |
|---|---|
| Family identity | Nestora `public.family_members` |
| Family calendar | Nestora `public.family_calendar_items` |
| Shared recipe library | Nestora `public.recipes` |
| Pregnancy clinical facts | Nestora `public.pregnancy_profile` |
| Workout plan detail | Aura `aura.*` |
| Warmups / sets / reps | Aura |
| Habits / motivation | Aura |
| Private postpartum check-ins | Aura |
| Apple Health raw samples | Aura |
| Family support action | Nestora after explicit share |
| Meal assignment | Aura, optionally linked to Nestora |

Rule: do not duplicate permanent family identity or the recipe master.