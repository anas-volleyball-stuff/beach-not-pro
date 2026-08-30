do $$
declare
  target_edition_id uuid;
begin
  select id
  into target_edition_id
  from public.tournament_editions
  where slug = 'edition-2';

  if target_edition_id is null then
    raise exception 'Edition 2 was not found. Run 10_enable_editions.sql first.';
  end if;

  delete from public.playoff_matches
  where edition_id = target_edition_id;

  delete from public.matches
  where edition_id = target_edition_id;

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
    edition_id,
    round_number,
    court_number,
    team_a_player_1,
    team_a_player_2,
    team_b_player_1,
    team_b_player_2
  )
  select
    target_edition_id,
    fixed_schedule.round_number,
    fixed_schedule.court_number,
    team_a_1.id,
    team_a_2.id,
    team_b_1.id,
    team_b_2.id
  from fixed_schedule
  join public.players as team_a_1
    on team_a_1.name = fixed_schedule.team_a_player_1
    and team_a_1.edition_id = target_edition_id
  join public.players as team_a_2
    on team_a_2.name = fixed_schedule.team_a_player_2
    and team_a_2.edition_id = target_edition_id
  join public.players as team_b_1
    on team_b_1.name = fixed_schedule.team_b_player_1
    and team_b_1.edition_id = target_edition_id
  join public.players as team_b_2
    on team_b_2.name = fixed_schedule.team_b_player_2
    and team_b_2.edition_id = target_edition_id;

  update public.tournament_state
  set current_round = 1
  where edition_id = target_edition_id;

  perform public.recalculate_player_standings();
  perform public.sync_current_round(target_edition_id);
end;
$$;

notify pgrst, 'reload schema';
