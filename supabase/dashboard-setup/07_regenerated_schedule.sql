with fixed_schedule (
  round_number,
  court_number,
  team_a_player_1,
  team_a_player_2,
  team_b_player_1,
  team_b_player_2
) as (
  values
    (1, 1, 'Din', 'Bernie', 'Maddy', 'Cass'),
    (1, 2, 'Anas', 'Yvonne', 'Kang', 'Jolene'),
    (1, 3, 'Supi', 'Sophie', 'Harish', 'Elif'),
    (2, 1, 'Kang', 'Elif', 'Harish', 'Cass'),
    (2, 2, 'Anas', 'Jolene', 'Supi', 'Bernie'),
    (2, 3, 'Din', 'Sophie', 'Shehan', 'Jing'),
    (3, 1, 'Din', 'Jing', 'Supi', 'Jolene'),
    (3, 2, 'Kang', 'Yvonne', 'Shehan', 'Bernie'),
    (3, 3, 'Anas', 'Cass', 'Maddy', 'Sophie'),
    (4, 1, 'Din', 'Cass', 'Harish', 'Yvonne'),
    (4, 2, 'Anas', 'Elif', 'Kang', 'Jing'),
    (4, 3, 'Maddy', 'Jolene', 'Shehan', 'Sophie'),
    (5, 1, 'Supi', 'Elif', 'Shehan', 'Yvonne'),
    (5, 2, 'Maddy', 'Bernie', 'Harish', 'Jing')
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
