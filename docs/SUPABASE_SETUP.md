# Supabase Setup

## 1. Create the Project

Create a new Supabase project and wait for the database to become available.

## 2. Run the Migration

Open the Supabase SQL editor and run:

```sql
-- Paste the contents of:
-- supabase/migrations/20260623000000_init_beach_not_pro_tour.sql
```

The migration creates the tables, functions, triggers, row-level security policies, Realtime publication entries, and fixed tournament seed data.

If the dashboard paste fails with an `unterminated dollar-quoted string` error,
run the dashboard setup chunks instead, in this exact order:

1. `supabase/dashboard-setup/01_schema.sql`
2. `supabase/dashboard-setup/02_functions.sql`
3. `supabase/dashboard-setup/03_seed_security_realtime.sql`

Use a blank SQL Editor query for each chunk and run the full contents of that
chunk before moving to the next one.

## 3. Confirm Realtime

In Supabase, open Database > Replication and confirm these tables are enabled for Realtime:

- `matches`
- `player_standings`
- `tournament_state`
- `players`

The migration attempts to add them automatically to the `supabase_realtime` publication.

## 4. Get API Keys

Open Project Settings > API and copy:

- Project URL
- anon public key

Use those values for `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.

## Security Notes

The app allows public score saving through the `save_match_score` RPC because no login requirement was specified. Table writes are blocked directly by RLS; the exposed action is only the validated score-save function. For a private scorer workflow, add Supabase Auth and restrict RPC execution to approved users.
