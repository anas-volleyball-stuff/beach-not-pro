with fixed_schedule (
  round_number,
  court_number,
  team_a_player_1,
  team_a_player_2,
  team_b_player_1,
  team_b_player_2
) as (
  values
    (1, 1, 'Anas', 'Yvonne', 'Shehan', 'Cass'),
    (1, 2, 'Harish', 'Sophie', 'Kang', 'Jolene'),
    (1, 3, 'Din', 'Elif', 'Supi', 'Jing'),
    (2, 1, 'Anas', 'Jing', 'Kang', 'Bernie'),
    (2, 2, 'Shehan', 'Yvonne', 'Maddy', 'Elif'),
    (2, 3, 'Din', 'Jolene', 'Supi', 'Cass'),
    (3, 1, 'Harish', 'Cass', 'Shehan', 'Sophie'),
    (3, 2, 'Kang', 'Elif', 'Din', 'Bernie'),
    (3, 3, 'Maddy', 'Jing', 'Supi', 'Jolene'),
    (4, 1, 'Anas', 'Cass', 'Harish', 'Elif'),
    (4, 2, 'Shehan', 'Jolene', 'Supi', 'Bernie'),
    (4, 3, 'Maddy', 'Yvonne', 'Din', 'Sophie'),
    (5, 1, 'Anas', 'Bernie', 'Maddy', 'Sophie'),
    (5, 2, 'Harish', 'Yvonne', 'Kang', 'Jing')
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
