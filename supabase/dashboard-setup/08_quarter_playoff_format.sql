alter table public.playoff_matches
drop constraint if exists playoff_matches_stage_check;

alter table public.playoff_matches
add constraint playoff_matches_stage_check
check (stage in ('quarter', 'semi', 'final'));

drop function if exists public.initialize_playoffs(text);

create or replace function public.initialize_playoffs(
  p_admin_password text,
  p_format text default 'semis'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  men_ids uuid[];
  women_ids uuid[];
begin
  if p_admin_password is distinct from 'hihi' then
    raise exception 'Admin password is required.';
  end if;

  if p_format not in ('semis', 'quarters') then
    raise exception 'Invalid playoff format.';
  end if;

  select array_agg(player_id order by ranking_score desc, wins desc, point_differential desc, name)
  into men_ids
  from (
    select
      player_standings.player_id,
      player_standings.wins,
      player_standings.point_differential,
      players.name,
      (0.95 * player_standings.wins + 0.05 * player_standings.point_differential) as ranking_score
    from public.player_standings
    join public.players on players.id = player_standings.player_id
    where players.gender = 'men'
    order by ranking_score desc, player_standings.wins desc, player_standings.point_differential desc, players.name
    limit case when p_format = 'quarters' then 7 else 4 end
  ) ranked_men;

  select array_agg(player_id order by ranking_score desc, wins desc, point_differential desc, name)
  into women_ids
  from (
    select
      player_standings.player_id,
      player_standings.wins,
      player_standings.point_differential,
      players.name,
      (0.95 * player_standings.wins + 0.05 * player_standings.point_differential) as ranking_score
    from public.player_standings
    join public.players on players.id = player_standings.player_id
    where players.gender = 'women'
    order by ranking_score desc, player_standings.wins desc, player_standings.point_differential desc, players.name
    limit case when p_format = 'quarters' then 7 else 4 end
  ) ranked_women;

  if p_format = 'quarters' and (
    coalesce(array_length(men_ids, 1), 0) < 7
    or coalesce(array_length(women_ids, 1), 0) < 7
  ) then
    raise exception 'Need top 7 men and top 7 women before creating quarterfinals.';
  end if;

  if p_format = 'semis' and (
    coalesce(array_length(men_ids, 1), 0) < 4
    or coalesce(array_length(women_ids, 1), 0) < 4
  ) then
    raise exception 'Need top 4 men and top 4 women before creating semifinals.';
  end if;

  delete from public.playoff_matches where true;

  if p_format = 'quarters' then
    insert into public.playoff_matches (
      match_key,
      stage,
      match_number,
      team_a_seed,
      team_b_seed,
      team_a_player_1,
      team_a_player_2,
      team_b_player_1,
      team_b_player_2
    )
    values
      ('quarter_1', 'quarter', 1, 2, 7, men_ids[2], women_ids[2], men_ids[7], women_ids[7]),
      ('quarter_2', 'quarter', 2, 3, 6, men_ids[3], women_ids[3], men_ids[6], women_ids[6]),
      ('quarter_3', 'quarter', 3, 4, 5, men_ids[4], women_ids[4], men_ids[5], women_ids[5]);

    insert into public.playoff_matches (
      match_key,
      stage,
      match_number,
      team_a_seed,
      team_a_player_1,
      team_a_player_2
    )
    values ('semi_1', 'semi', 1, 1, men_ids[1], women_ids[1]);

    insert into public.playoff_matches (match_key, stage, match_number)
    values ('semi_2', 'semi', 2);
  else
    insert into public.playoff_matches (
      match_key,
      stage,
      match_number,
      team_a_seed,
      team_b_seed,
      team_a_player_1,
      team_a_player_2,
      team_b_player_1,
      team_b_player_2
    )
    values
      ('semi_1', 'semi', 1, 1, 4, men_ids[1], women_ids[1], men_ids[4], women_ids[4]),
      ('semi_2', 'semi', 2, 2, 3, men_ids[2], women_ids[2], men_ids[3], women_ids[3]);
  end if;

  insert into public.playoff_matches (match_key, stage, match_number)
  values ('final', 'final', 1);
end;
$$;

create or replace function public.reset_playoff_match(p_match_key text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.playoff_matches
  set
    score_a = null,
    score_b = null,
    set1_a = null,
    set1_b = null,
    set2_a = null,
    set2_b = null,
    set3_a = null,
    set3_b = null,
    completed = false
  where match_key = p_match_key;
$$;

create or replace function public.sync_semis_from_quarters()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  quarter1 public.playoff_matches;
  quarter2 public.playoff_matches;
  quarter3 public.playoff_matches;
  winner1 uuid[];
  winner2 uuid[];
  winner3 uuid[];
begin
  select * into quarter1 from public.playoff_matches where match_key = 'quarter_1';
  select * into quarter2 from public.playoff_matches where match_key = 'quarter_2';
  select * into quarter3 from public.playoff_matches where match_key = 'quarter_3';

  if quarter1.id is not null and quarter1.completed then
    winner1 := public.playoff_winner_players(quarter1);

    update public.playoff_matches
    set
      team_b_seed = null,
      team_b_player_1 = winner1[1],
      team_b_player_2 = winner1[2],
      score_a = null,
      score_b = null,
      completed = false
    where match_key = 'semi_1';

    perform public.reset_playoff_match('final');
  end if;

  if quarter2.id is not null and quarter3.id is not null and quarter2.completed and quarter3.completed then
    winner2 := public.playoff_winner_players(quarter2);
    winner3 := public.playoff_winner_players(quarter3);

    update public.playoff_matches
    set
      team_a_seed = null,
      team_b_seed = null,
      team_a_player_1 = winner2[1],
      team_a_player_2 = winner2[2],
      team_b_player_1 = winner3[1],
      team_b_player_2 = winner3[2],
      score_a = null,
      score_b = null,
      completed = false
    where match_key = 'semi_2';

    perform public.reset_playoff_match('final');
  end if;
end;
$$;

create or replace function public.sync_final_from_semis()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  semi1 public.playoff_matches;
  semi2 public.playoff_matches;
  winner1 uuid[];
  winner2 uuid[];
begin
  select * into semi1 from public.playoff_matches where match_key = 'semi_1';
  select * into semi2 from public.playoff_matches where match_key = 'semi_2';

  if semi1.completed and semi2.completed then
    winner1 := public.playoff_winner_players(semi1);
    winner2 := public.playoff_winner_players(semi2);

    update public.playoff_matches
    set
      team_a_seed = null,
      team_b_seed = null,
      team_a_player_1 = winner1[1],
      team_a_player_2 = winner1[2],
      team_b_player_1 = winner2[1],
      team_b_player_2 = winner2[2],
      score_a = null,
      score_b = null,
      set1_a = null,
      set1_b = null,
      set2_a = null,
      set2_b = null,
      set3_a = null,
      set3_b = null,
      completed = false
    where match_key = 'final';
  else
    update public.playoff_matches
    set
      team_a_player_1 = null,
      team_a_player_2 = null,
      team_b_player_1 = null,
      team_b_player_2 = null,
      score_a = null,
      score_b = null,
      set1_a = null,
      set1_b = null,
      set2_a = null,
      set2_b = null,
      set3_a = null,
      set3_b = null,
      completed = false
    where match_key = 'final';
  end if;
end;
$$;

create or replace function public.save_playoff_score(
  p_match_id uuid,
  p_score_a integer,
  p_score_b integer,
  p_admin_password text
)
returns public.playoff_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  saved_match public.playoff_matches;
begin
  if p_admin_password is distinct from 'hihi' then
    raise exception 'Admin password is required.';
  end if;

  if not public.is_valid_capped_score(p_score_a, p_score_b, 21, 24) then
    raise exception 'Playoff matches must be to 21, win by 2, capped at 24.';
  end if;

  update public.playoff_matches
  set
    score_a = p_score_a,
    score_b = p_score_b,
    completed = true
  where id = p_match_id
    and stage in ('quarter', 'semi')
  returning * into saved_match;

  if saved_match.id is null then
    raise exception 'Playoff match not found.';
  end if;

  if saved_match.stage = 'quarter' then
    perform public.sync_semis_from_quarters();
  end if;

  perform public.sync_final_from_semis();
  return saved_match;
end;
$$;

grant execute on function public.initialize_playoffs(text, text) to anon, authenticated;
grant execute on function public.save_playoff_score(uuid, integer, integer, text) to anon, authenticated;

notify pgrst, 'reload schema';
