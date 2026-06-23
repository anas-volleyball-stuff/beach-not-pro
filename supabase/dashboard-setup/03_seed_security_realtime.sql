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
