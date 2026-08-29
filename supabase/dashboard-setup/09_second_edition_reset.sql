delete from public.playoff_matches where true;
delete from public.matches where true;
delete from public.player_standings where true;
delete from public.players where true;

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
  ('Jess', 'women', 1);

with fixed_schedule (
  round_number,
  court_number,
  team_a_player_1,
  team_a_player_2,
  team_b_player_1,
  team_b_player_2
) as (
  values
    (1, 1, 'Harish', 'Jess', 'Gerald', 'Cass'),
    (1, 2, 'Fai', 'Bernie', 'Shehan', 'Wanzhen'),
    (1, 3, 'Din', 'Sophie', 'Maddy', 'Jolene'),
    (2, 1, 'Din', 'Wanzhen', 'Shehan', 'Jess'),
    (2, 2, 'Fai', 'Sophie', 'Harish', 'Bernie'),
    (2, 3, 'Gerald', 'Jolene', 'Kang', 'Katrina'),
    (3, 1, 'Fai', 'Katrina', 'Kang', 'Wanzhen'),
    (3, 2, 'Shehan', 'Sophie', 'Harish', 'Cass'),
    (3, 3, 'Maddy', 'Bernie', 'Gerald', 'Jess'),
    (4, 1, 'Gerald', 'Katrina', 'Fai', 'Jolene'),
    (4, 2, 'Kang', 'Jess', 'Shehan', 'Bernie'),
    (4, 3, 'Din', 'Cass', 'Maddy', 'Wanzhen'),
    (5, 1, 'Kang', 'Jolene', 'Harish', 'Sophie'),
    (5, 2, 'Maddy', 'Cass', 'Din', 'Katrina')
)
insert into public.matches (
  round_number,
  court_number,
  team_a_player_1,
  team_a_player_2,
  team_b_player_1,
  team_b_player_2,
  score_a,
  score_b,
  completed
)
select
  fixed_schedule.round_number,
  fixed_schedule.court_number,
  team_a_1.id,
  team_a_2.id,
  team_b_1.id,
  team_b_2.id,
  null,
  null,
  false
from fixed_schedule
join public.players as team_a_1 on team_a_1.name = fixed_schedule.team_a_player_1
join public.players as team_a_2 on team_a_2.name = fixed_schedule.team_a_player_2
join public.players as team_b_1 on team_b_1.name = fixed_schedule.team_b_player_1
join public.players as team_b_2 on team_b_2.name = fixed_schedule.team_b_player_2;

update public.tournament_state
set current_round = 1
where id = 1;

insert into public.tournament_state (id, current_round)
values (1, 1)
on conflict (id) do nothing;

select public.recalculate_player_standings();
select public.sync_current_round();

notify pgrst, 'reload schema';
