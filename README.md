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

- `players`: all 14 tournament players with gender and rating.
- `matches`: the fixed five-round schedule only.
- `tournament_state`: the current round.
- `player_standings`: persisted wins, losses, points, and point differential.

Scores are saved through the `save_match_score` database function. Database triggers recalculate standings and advance `current_round` to the lowest incomplete round.

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
