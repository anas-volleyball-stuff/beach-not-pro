-- Admin roster changes for adaptive editions. Completed scores are never deleted.

alter table public.players
add column if not exists active boolean not null default true;

create or replace function public.generate_next_round(
  p_admin_password text,
  p_edition_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  next_round integer;
  active_player_count integer;
  match_count integer;
  players_in_round integer;
  trial integer;
  court_index integer;
  base_index integer;
  candidate_players uuid[];
  best_players uuid[];
  a1 uuid;
  a2 uuid;
  b1 uuid;
  b2 uuid;
  g_a1 text;
  g_a2 text;
  g_b1 text;
  g_b2 text;
  r_a1 numeric;
  r_a2 numeric;
  r_b1 numeric;
  r_b2 numeric;
  partner_repeats integer;
  opponent_repeats integer;
  consecutive_rests integer;
  candidate_score numeric;
  best_score numeric := null;
  is_valid boolean;
begin
  if p_admin_password is distinct from 'hihi' then
    raise exception 'Admin password is required.';
  end if;

  if not exists (
    select 1
    from public.tournament_editions
    where id = p_edition_id
      and adaptive_scheduling = true
  ) then
    raise exception 'This edition does not use adaptive rounds.';
  end if;

  if exists (
    select 1
    from public.matches
    where edition_id = p_edition_id
      and completed = false
  ) then
    raise exception 'Complete every match in the current round first.';
  end if;

  select count(*)::integer
  into active_player_count
  from public.players
  where edition_id = p_edition_id
    and active = true;

  if active_player_count < 4 then
    raise exception 'At least four active players are required.';
  end if;

  match_count := least(3, floor(active_player_count / 4.0)::integer);
  players_in_round := match_count * 4;

  perform public.recalculate_form_ratings(p_edition_id);

  select coalesce(max(round_number), 0) + 1
  into next_round
  from public.matches
  where edition_id = p_edition_id;

  create temporary table if not exists adaptive_player_stats (
    id uuid primary key,
    gender text not null,
    form_rating numeric not null,
    matches_played integer not null
  ) on commit drop;
  truncate adaptive_player_stats;

  insert into adaptive_player_stats (id, gender, form_rating, matches_played)
  select
    players.id,
    players.gender,
    coalesce(players.form_rating, players.rating),
    coalesce(player_standings.matches_played, 0)
  from public.players
  left join public.player_standings on player_standings.player_id = players.id
  where players.edition_id = p_edition_id
    and players.active = true;

  create temporary table if not exists adaptive_interactions (
    player_1 uuid not null,
    player_2 uuid not null,
    partner_count integer not null default 0,
    opponent_count integer not null default 0,
    primary key (player_1, player_2)
  ) on commit drop;
  truncate adaptive_interactions;

  insert into adaptive_interactions (player_1, player_2, partner_count)
  select least(pair.player_1, pair.player_2), greatest(pair.player_1, pair.player_2), count(*)
  from public.matches
  cross join lateral (
    values
      (team_a_player_1, team_a_player_2),
      (team_b_player_1, team_b_player_2)
  ) as pair(player_1, player_2)
  where edition_id = p_edition_id
  group by least(pair.player_1, pair.player_2), greatest(pair.player_1, pair.player_2)
  on conflict (player_1, player_2) do update set
    partner_count = excluded.partner_count;

  insert into adaptive_interactions (player_1, player_2, opponent_count)
  select least(pair.player_1, pair.player_2), greatest(pair.player_1, pair.player_2), count(*)
  from public.matches
  cross join lateral (
    values
      (team_a_player_1, team_b_player_1),
      (team_a_player_1, team_b_player_2),
      (team_a_player_2, team_b_player_1),
      (team_a_player_2, team_b_player_2)
  ) as pair(player_1, player_2)
  where edition_id = p_edition_id
  group by least(pair.player_1, pair.player_2), greatest(pair.player_1, pair.player_2)
  on conflict (player_1, player_2) do update set
    opponent_count = excluded.opponent_count;

  for trial in 1..6000 loop
    select array_agg(id order by random())
    into candidate_players
    from (
      select id
      from adaptive_player_stats
      order by matches_played, random()
      limit players_in_round
    ) selected_players;

    candidate_score := 0;
    partner_repeats := 0;
    opponent_repeats := 0;
    is_valid := true;

    for court_index in 1..match_count loop
      base_index := ((court_index - 1) * 4) + 1;
      a1 := candidate_players[base_index];
      a2 := candidate_players[base_index + 1];
      b1 := candidate_players[base_index + 2];
      b2 := candidate_players[base_index + 3];

      select gender, form_rating into g_a1, r_a1 from adaptive_player_stats where id = a1;
      select gender, form_rating into g_a2, r_a2 from adaptive_player_stats where id = a2;
      select gender, form_rating into g_b1, r_b1 from adaptive_player_stats where id = b1;
      select gender, form_rating into g_b2, r_b2 from adaptive_player_stats where id = b2;

      if (g_a1 = 'women' and g_a2 = 'women')
        or (g_b1 = 'women' and g_b2 = 'women') then
        is_valid := false;
        exit;
      end if;

      if (g_a1 = 'women' and not (
          (g_b1 = 'men' and abs(r_a1 - r_b1) <= 1.5)
          or (g_b2 = 'men' and abs(r_a1 - r_b2) <= 1.5)
        ))
        or (g_a2 = 'women' and not (
          (g_b1 = 'men' and abs(r_a2 - r_b1) <= 1.5)
          or (g_b2 = 'men' and abs(r_a2 - r_b2) <= 1.5)
        ))
        or (g_b1 = 'women' and not (
          (g_a1 = 'men' and abs(r_b1 - r_a1) <= 1.5)
          or (g_a2 = 'men' and abs(r_b1 - r_a2) <= 1.5)
        ))
        or (g_b2 = 'women' and not (
          (g_a1 = 'men' and abs(r_b2 - r_a1) <= 1.5)
          or (g_a2 = 'men' and abs(r_b2 - r_a2) <= 1.5)
        )) then
        is_valid := false;
        exit;
      end if;

      partner_repeats := partner_repeats
        + coalesce((select partner_count from adaptive_interactions where player_1 = least(a1, a2) and player_2 = greatest(a1, a2)), 0)
        + coalesce((select partner_count from adaptive_interactions where player_1 = least(b1, b2) and player_2 = greatest(b1, b2)), 0);

      opponent_repeats := opponent_repeats
        + coalesce((select opponent_count from adaptive_interactions where player_1 = least(a1, b1) and player_2 = greatest(a1, b1)), 0)
        + coalesce((select opponent_count from adaptive_interactions where player_1 = least(a1, b2) and player_2 = greatest(a1, b2)), 0)
        + coalesce((select opponent_count from adaptive_interactions where player_1 = least(a2, b1) and player_2 = greatest(a2, b1)), 0)
        + coalesce((select opponent_count from adaptive_interactions where player_1 = least(a2, b2) and player_2 = greatest(a2, b2)), 0);

      candidate_score := candidate_score
        + abs((r_a1 + r_a2) - (r_b1 + r_b2)) * 20;
    end loop;

    if not is_valid then
      continue;
    end if;

    select count(*)::integer
    into consecutive_rests
    from adaptive_player_stats stats
    where not (stats.id = any(candidate_players))
      and next_round > 1
      and not exists (
        select 1
        from public.matches previous_match
        where previous_match.edition_id = p_edition_id
          and previous_match.round_number = next_round - 1
          and stats.id in (
            previous_match.team_a_player_1,
            previous_match.team_a_player_2,
            previous_match.team_b_player_1,
            previous_match.team_b_player_2
          )
      );

    candidate_score := candidate_score
      + (partner_repeats * 5000)
      + (opponent_repeats * 180)
      + (consecutive_rests * 1000)
      + random() / 100;

    if best_score is null or candidate_score < best_score then
      best_score := candidate_score;
      best_players := candidate_players;
    end if;
  end loop;

  if best_players is null then
    raise exception 'No valid round was found. Check active player genders and ratings.';
  end if;

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
    p_edition_id,
    next_round,
    generated_court,
    best_players[((generated_court - 1) * 4) + 1],
    best_players[((generated_court - 1) * 4) + 2],
    best_players[((generated_court - 1) * 4) + 3],
    best_players[((generated_court - 1) * 4) + 4]
  from generate_series(1, match_count) as generated_court;

  perform public.sync_current_round(p_edition_id);
  return next_round;
end;
$$;

create or replace function public.manage_adaptive_player(
  p_admin_password text,
  p_edition_id uuid,
  p_player_id uuid,
  p_name text,
  p_gender text,
  p_rating numeric,
  p_active boolean
)
returns public.players
language plpgsql
security definer
set search_path = public
as $$
declare
  saved_player public.players;
  existing_player_id uuid;
  has_completed_matches boolean;
  has_open_matches boolean;
  open_round integer;
begin
  if p_admin_password is distinct from 'hihi' then
    raise exception 'Admin password is required.';
  end if;

  if not exists (
    select 1
    from public.tournament_editions
    where id = p_edition_id
      and adaptive_scheduling = true
  ) then
    raise exception 'Roster management is only available for adaptive editions.';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'Player name is required.';
  end if;

  if p_gender not in ('men', 'women') then
    raise exception 'Gender must be M or F.';
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 10 then
    raise exception 'Skill score must be between 1 and 10.';
  end if;

  select exists (
    select 1 from public.matches
    where edition_id = p_edition_id and completed = true
  ) into has_completed_matches;

  select exists (
    select 1 from public.matches
    where edition_id = p_edition_id and completed = false
  ) into has_open_matches;

  select min(round_number)
  into open_round
  from public.matches
  where edition_id = p_edition_id
    and completed = false;

  if open_round is not null and exists (
    select 1
    from public.matches
    where edition_id = p_edition_id
      and round_number = open_round
      and completed = true
  ) then
    raise exception 'Finish the partially played current round before changing the roster.';
  end if;

  if p_player_id is null then
    select id into existing_player_id
    from public.players
    where edition_id = p_edition_id
      and lower(name) = lower(trim(p_name))
    limit 1;

    if existing_player_id is null then
      insert into public.players (edition_id, name, gender, rating, form_rating, active)
      values (p_edition_id, trim(p_name), p_gender, p_rating, p_rating, p_active)
      returning * into saved_player;
    else
      update public.players
      set name = trim(p_name), gender = p_gender, rating = p_rating, active = p_active
      where id = existing_player_id
      returning * into saved_player;
    end if;
  else
    update public.players
    set name = trim(p_name), gender = p_gender, rating = p_rating, active = p_active
    where id = p_player_id
      and edition_id = p_edition_id
    returning * into saved_player;

    if saved_player.id is null then
      raise exception 'Player was not found in this edition.';
    end if;
  end if;

  if (
    select count(*)
    from public.players
    where edition_id = p_edition_id and active = true
  ) < 4 then
    raise exception 'At least four active players are required.';
  end if;

  perform public.recalculate_player_standings();
  perform public.recalculate_form_ratings(p_edition_id);

  if has_open_matches then
    delete from public.matches
    where edition_id = p_edition_id
      and completed = false;
    perform public.sync_current_round(p_edition_id);
    perform public.generate_next_round(p_admin_password, p_edition_id);
  elsif not has_completed_matches then
    perform public.generate_next_round(p_admin_password, p_edition_id);
  end if;

  return saved_player;
end;
$$;

grant execute on function public.manage_adaptive_player(text, uuid, uuid, text, text, numeric, boolean)
to anon, authenticated;

notify pgrst, 'reload schema';
