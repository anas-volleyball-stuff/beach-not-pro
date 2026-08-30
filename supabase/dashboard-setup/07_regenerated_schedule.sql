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
