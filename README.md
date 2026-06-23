# Beach Not Pro Tour

A production-ready single-tournament web app for the Beach Not Pro Tour. The schedule is fixed, Supabase is the source of truth, and every score save updates standings plus all connected browsers through Supabase Realtime.

## Stack

- React, TypeScript, Vite
- Tailwind CSS
- Supabase Postgres, RPC, Row Level Security, Realtime
- GitHub Pages hosting

## Local Setup

1. Create a Supabase project.
2. Run the SQL migration in `supabase/migrations/20260623000000_init_beach_not_pro_tour.sql`.
3. Copy `.env.example` to `.env` and fill in:

```bash
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-supabase-anon-key
```

4. Install dependencies and start the app:

```bash
npm install
npm run dev
```

## Data Model

The migration creates and seeds:

- `players`: all 14 tournament players with gender and internal seeding metadata.
- `matches`: the fixed five-round schedule only.
- `tournament_state`: the current round.
- `player_standings`: persisted wins, losses, points, and point differential.

Scores are saved through the `save_match_score` database function. Database triggers recalculate standings and advance `current_round` to the lowest incomplete round.

Rankings are calculated in the app with:

```text
0.95 * wins + 0.05 * point differential
```

Admin mode is unlocked in the app with the event password. Admins can save score
changes and reset the tournament back to an unplayed state.

Playoffs use the top 4 men and top 4 women after group play. Seed 1 pairs with
seed 1, seed 2 with seed 2, and so on. Team 1 plays Team 4, Team 2 plays Team 3,
and semifinal winners advance to the final.

Score rules:

- Group games: first to 15, win by 2, capped at 18.
- Semifinals: first to 21, win by 2, capped at 24.
- Final: one game to 21, or best of 3 with first two sets to 21 and third set to 15.

## Realtime

The app subscribes to Supabase Realtime changes for:

- `matches`
- `player_standings`
- `tournament_state`

When one scorekeeper saves a result, other open browsers refresh automatically without page reload.

## Scripts

```bash
npm run dev
npm run build
npm run preview
npm run lint
```

## Deployment

See `docs/SUPABASE_SETUP.md` and `docs/GITHUB_PAGES_DEPLOYMENT.md`.
