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

create or replace function public.recalculate_player_standings()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.player_standings (
    player_id,
    wins,
    losses,
    points_for,
    points_against,
    matches_played,
    updated_at
  )
  select
    players.id,
    coalesce(sum(match_stats.win), 0)::integer as wins,
    coalesce(sum(match_stats.loss), 0)::integer as losses,
    coalesce(sum(match_stats.points_for), 0)::integer as points_for,
    coalesce(sum(match_stats.points_against), 0)::integer as points_against,
    coalesce(count(match_stats.player_id), 0)::integer as matches_played,
    now() as updated_at
  from public.players
  left join (
    select
      team_a_player_1 as player_id,
      (score_a > score_b)::integer as win,
      (score_a < score_b)::integer as loss,
      score_a as points_for,
      score_b as points_against
    from public.matches
    where completed = true
    union all
    select
      team_a_player_2 as player_id,
      (score_a > score_b)::integer as win,
      (score_a < score_b)::integer as loss,
      score_a as points_for,
      score_b as points_against
    from public.matches
    where completed = true
    union all
    select
      team_b_player_1 as player_id,
      (score_b > score_a)::integer as win,
      (score_b < score_a)::integer as loss,
      score_b as points_for,
      score_a as points_against
    from public.matches
    where completed = true
    union all
    select
      team_b_player_2 as player_id,
      (score_b > score_a)::integer as win,
      (score_b < score_a)::integer as loss,
      score_b as points_for,
      score_a as points_against
    from public.matches
    where completed = true
  ) as match_stats on match_stats.player_id = players.id
  group by players.id
  on conflict (player_id) do update set
    wins = excluded.wins,
    losses = excluded.losses,
    points_for = excluded.points_for,
    points_against = excluded.points_against,
    matches_played = excluded.matches_played,
    updated_at = excluded.updated_at;
end;
$$;

create or replace function public.sync_current_round()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  next_round integer;
begin
  select min(round_number)
  into next_round
  from public.matches
  where completed = false;

  if next_round is null then
    select max(round_number)
    into next_round
    from public.matches;
  end if;

  insert into public.tournament_state (id, current_round, updated_at)
  values (1, coalesce(next_round, 1), now())
  on conflict (id) do update set
    current_round = excluded.current_round,
    updated_at = excluded.updated_at;
end;
$$;

create or replace function public.after_match_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recalculate_player_standings();
  perform public.sync_current_round();
  return null;
end;
$$;

drop trigger if exists matches_after_change on public.matches;
create trigger matches_after_change
after insert or update or delete on public.matches
for each statement
execute function public.after_match_change();

create or replace function public.save_match_score(
  p_match_id uuid,
  p_score_a integer,
  p_score_b integer
)
returns public.matches
language plpgsql
security definer
set search_path = public
as $$
declare
  saved_match public.matches;
begin
  if p_score_a is null or p_score_b is null then
    raise exception 'Both team scores are required.';
  end if;

  if p_score_a < 0 or p_score_b < 0 then
    raise exception 'Scores must be zero or greater.';
  end if;

  if p_score_a = p_score_b then
    raise exception 'Matches cannot end in a tie.';
  end if;

  update public.matches
  set
    score_a = p_score_a,
    score_b = p_score_b,
    completed = true
  where id = p_match_id
  returning * into saved_match;

  if saved_match.id is null then
    raise exception 'Match not found.';
  end if;

  return saved_match;
end;
$$;

insert into public.players (name, gender, rating)
values
  ('Anas', 'men', 3),
  ('Harish', 'men', 3),
  ('Kang', 'men', 3),
  ('Shehan', 'men', 2),
  ('Maddy', 'men', 2),
  ('Din', 'men', 1),
  ('Supi', 'men', 1),
  ('Sophie', 'women', 3),
  ('Bernie', 'women', 3),
  ('Jolene', 'women', 2),
  ('Jing', 'women', 2),
  ('Cass', 'women', 2),
  ('Yvonne', 'women', 1),
  ('Elif', 'women', 1)
on conflict (name) do update set
  gender = excluded.gender,
  rating = excluded.rating;

with fixed_schedule (
  round_number,
  court_number,
  team_a_player_1,
  team_a_player_2,
  team_b_player_1,
  team_b_player_2
) as (
  values
    (1, 1, 'Kang', 'Jing', 'Anas', 'Jolene'),
    (1, 2, 'Shehan', 'Elif', 'Din', 'Cass'),
    (1, 3, 'Harish', 'Yvonne', 'Supi', 'Sophie'),
    (2, 1, 'Shehan', 'Jing', 'Maddy', 'Cass'),
    (2, 2, 'Harish', 'Elif', 'Supi', 'Bernie'),
    (2, 3, 'Anas', 'Yvonne', 'Din', 'Sophie'),
    (3, 1, 'Supi', 'Jolene', 'Shehan', 'Yvonne'),
    (3, 2, 'Anas', 'Elif', 'Maddy', 'Jing'),
    (3, 3, 'Harish', 'Sophie', 'Kang', 'Bernie'),
    (4, 1, 'Maddy', 'Yvonne', 'Din', 'Jolene'),
    (4, 2, 'Shehan', 'Cass', 'Kang', 'Elif'),
    (4, 3, 'Harish', 'Bernie', 'Anas', 'Sophie'),
    (5, 1, 'Din', 'Jing', 'Supi', 'Cass'),
    (5, 2, 'Kang', 'Jolene', 'Maddy', 'Bernie')
)
insert into public.matches (
  round_number,
  court_number,
  team_a_player_1,
  team_a_player_2,
  team_b_player_1,
  team_b_player_2
)
select
  fixed_schedule.round_number,
  fixed_schedule.court_number,
  team_a_1.id,
  team_a_2.id,
  team_b_1.id,
  team_b_2.id
from fixed_schedule
join public.players as team_a_1 on team_a_1.name = fixed_schedule.team_a_player_1
join public.players as team_a_2 on team_a_2.name = fixed_schedule.team_a_player_2
join public.players as team_b_1 on team_b_1.name = fixed_schedule.team_b_player_1
join public.players as team_b_2 on team_b_2.name = fixed_schedule.team_b_player_2
on conflict (round_number, court_number) do update set
  team_a_player_1 = excluded.team_a_player_1,
  team_a_player_2 = excluded.team_a_player_2,
  team_b_player_1 = excluded.team_b_player_1,
  team_b_player_2 = excluded.team_b_player_2;

insert into public.tournament_state (id, current_round)
values (1, 1)
on conflict (id) do nothing;

select public.recalculate_player_standings();
select public.sync_current_round();

alter table public.players enable row level security;
alter table public.matches enable row level security;
alter table public.tournament_state enable row level security;
alter table public.player_standings enable row level security;

drop policy if exists "Public read players" on public.players;
create policy "Public read players"
on public.players
for select
to anon, authenticated
using (true);

drop policy if exists "Public read matches" on public.matches;
create policy "Public read matches"
on public.matches
for select
to anon, authenticated
using (true);

drop policy if exists "Public read tournament state" on public.tournament_state;
create policy "Public read tournament state"
on public.tournament_state
for select
to anon, authenticated
using (true);

drop policy if exists "Public read player standings" on public.player_standings;
create policy "Public read player standings"
on public.player_standings
for select
to anon, authenticated
using (true);

grant usage on schema public to anon, authenticated;
grant select on public.players to anon, authenticated;
grant select on public.matches to anon, authenticated;
grant select on public.tournament_state to anon, authenticated;
grant select on public.player_standings to anon, authenticated;
grant execute on function public.save_match_score(uuid, integer, integer) to anon, authenticated;

do $$
declare
  table_name text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach table_name in array array[
      'players',
      'matches',
      'tournament_state',
      'player_standings'
    ]
    loop
      begin
        execute format('alter publication supabase_realtime add table public.%I', table_name);
      exception
        when duplicate_object then null;
      end;
    end loop;
  end if;
end;
$$;
