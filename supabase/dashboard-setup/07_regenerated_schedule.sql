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
update public.matches
set
  team_a_player_1 = team_a_1.id,
  team_a_player_2 = team_a_2.id,
  team_b_player_1 = team_b_1.id,
  team_b_player_2 = team_b_2.id,
  score_a = null,
  score_b = null,
  completed = false
from fixed_schedule
join public.players as team_a_1 on team_a_1.name = fixed_schedule.team_a_player_1
join public.players as team_a_2 on team_a_2.name = fixed_schedule.team_a_player_2
join public.players as team_b_1 on team_b_1.name = fixed_schedule.team_b_player_1
join public.players as team_b_2 on team_b_2.name = fixed_schedule.team_b_player_2
where public.matches.round_number = fixed_schedule.round_number
  and public.matches.court_number = fixed_schedule.court_number;

delete from public.playoff_matches where true;

update public.tournament_state
set current_round = 1
where id = 1;

select public.recalculate_player_standings();
select public.sync_current_round();

notify pgrst, 'reload schema';
