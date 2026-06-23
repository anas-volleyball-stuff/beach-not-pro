create extension if not exists pgcrypto;

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  gender text not null check (gender in ('men', 'women')),
  rating integer not null check (rating between 1 and 3),
  created_at timestamptz not null default now()
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  round_number integer not null check (round_number between 1 and 5),
  court_number integer not null check (court_number between 1 and 3),
  team_a_player_1 uuid not null references public.players(id) on delete restrict,
  team_a_player_2 uuid not null references public.players(id) on delete restrict,
  team_b_player_1 uuid not null references public.players(id) on delete restrict,
  team_b_player_2 uuid not null references public.players(id) on delete restrict,
  score_a integer check (score_a >= 0),
  score_b integer check (score_b >= 0),
  completed boolean not null default false,
  updated_at timestamptz not null default now(),
  unique (round_number, court_number),
  check (
    completed = false
    or (
      score_a is not null
      and score_b is not null
      and score_a <> score_b
    )
  )
);

create table if not exists public.tournament_state (
  id integer primary key default 1 check (id = 1),
  current_round integer not null default 1 check (current_round between 1 and 5),
  updated_at timestamptz not null default now()
);

create table if not exists public.player_standings (
  player_id uuid primary key references public.players(id) on delete cascade,
  wins integer not null default 0,
  losses integer not null default 0,
  points_for integer not null default 0,
  points_against integer not null default 0,
  point_differential integer generated always as (points_for - points_against) stored,
  matches_played integer not null default 0,
  updated_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists matches_touch_updated_at on public.matches;
create trigger matches_touch_updated_at
before update on public.matches
for each row
execute function public.touch_updated_at();

drop trigger if exists tournament_state_touch_updated_at on public.tournament_state;
create trigger tournament_state_touch_updated_at
before update on public.tournament_state
for each row
execute function public.touch_updated_at();
