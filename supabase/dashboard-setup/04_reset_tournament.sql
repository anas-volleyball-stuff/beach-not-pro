update public.matches
set
  score_a = null,
  score_b = null,
  completed = false;

update public.tournament_state
set current_round = 1
where id = 1;

select public.recalculate_player_standings();
select public.sync_current_round();
