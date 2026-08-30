insert into public.players (name, gender, rating)
values
  ('Kang', 'men', 3),
  ('Harish', 'men', 3),
  ('Fai', 'men', 2),
  ('Gerald', 'men', 2),
  ('Shehan', 'men', 2),
  ('Din', 'men', 1),
  ('Maddy', 'men', 1),
  ('Jolene', 'women', 3),
  ('Sophie', 'women', 3),
  ('Katrina', 'women', 3),
  ('Bernie', 'women', 2),
  ('Cass', 'women', 2),
  ('Wanzhen', 'women', 2),
  ('Jess', 'women', 1)
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
    (1, 1, 'Shehan', 'Cass', 'Maddy', 'Katrina'),
    (1, 2, 'Fai', 'Bernie', 'Din', 'Sophie'),
    (1, 3, 'Kang', 'Wanzhen', 'Gerald', 'Jolene'),
    (2, 1, 'Harish', 'Jess', 'Shehan', 'Wanzhen'),
    (2, 2, 'Gerald', 'Cass', 'Din', 'Jolene'),
    (2, 3, 'Kang', 'Bernie', 'Fai', 'Katrina'),
    (3, 1, 'Kang', 'Jess', 'Maddy', 'Sophie'),
    (3, 2, 'Harish', 'Katrina', 'Fai', 'Jolene'),
    (3, 3, 'Gerald', 'Wanzhen', 'Shehan', 'Bernie'),
    (4, 1, 'Shehan', 'Jess', 'Din', 'Cass'),
    (4, 2, 'Fai', 'Sophie', 'Maddy', 'Jolene'),
    (4, 3, 'Kang', 'Katrina', 'Harish', 'Wanzhen'),
    (5, 1, 'Harish', 'Cass', 'Gerald', 'Sophie'),
    (5, 2, 'Din', 'Bernie', 'Maddy', 'Jess')
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
grant execute on function public.save_match_score(uuid, integer, integer, text) to anon, authenticated;
grant execute on function public.reset_tournament(text) to anon, authenticated;

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
