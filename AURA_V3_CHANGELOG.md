# Aura v3 — Systems

## Experience architecture
Identity → Systems → Today → Execute → Reward → Review → Adapt.

## Workout execution
- Workout player is inline inside each profile's Workout page; the old modal is disabled.
- Session timer counts upward for the whole session.
- Strength work is set-driven: no artificial 45-second deadline for 3×6 chest press.
- Automatic timing uses exercise context: low-rep strength receives longer rest; moderate/high-rep work receives shorter rest; timed cardio/mobility uses the prescribed duration.
- Per-exercise Automatic / Custom / No Timer controls.
- Voice coach is contextual and counts down timed work/rest.
- Previous, skip, pause/resume and finish controls remain inline.

## Atomic Habits-inspired systems
- Identity statement and identity votes.
- Four-law design prompts: obvious, attractive, easy, satisfying.
- Habit builder additions for cue/stack, minimum version, environment, pairing, friction and recovery rule.
- Never-miss-twice recovery framing.
- Systems navigation and cleaner information hierarchy.

## Profiles
Krishna and Varshini remain independent. Varshini's postpartum pathway and clinician-guided progression are preserved.

## Persistence
The UI works with current local persistence. `sql/06_AURA_V3_SYSTEMS.sql` is an optional incremental Supabase schema for the next persistence/API step. Do not run old migrations again.

## v3.2 Premium Responsive IA
- Reworked desktop/tablet/mobile visual hierarchy.
- Reduced dashboard-score emphasis; identity and daily actions lead Today.
- Consolidated primary navigation to Today / Workout / Systems / Progress / Review / You.
- Preserved legacy Habits, Motivation, Connections, Hanuma and Admin features and exposed them from Systems hub.
- Neutralized legacy dark configuration surfaces for a consistent light premium UI.
- Improved mobile bottom navigation, card sizing, table overflow and touch targets.
