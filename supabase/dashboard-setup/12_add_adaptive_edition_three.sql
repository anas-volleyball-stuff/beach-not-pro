-- Edition 3: adaptive pool-only rounds generated from live player form.

alter table public.tournament_editions
add column if not exists adaptive_scheduling boolean not null default false;

alter table public.tournament_editions
add column if not exists has_playoffs boolean not null default true;

alter table public.players
drop constraint if exists players_rating_check;

alter table public.players
alter column rating type numeric(4, 1) using rating::numeric;

alter table public.players
add constraint players_rating_check check (rating between 1 and 10);

alter table public.players
add column if not exists form_rating numeric(6, 3);

alter table public.matches
drop constraint if exists matches_round_number_check;

alter table public.matches
add constraint matches_round_number_check check (round_number >= 1);

alter table public.tournament_state
drop constraint if exists tournament_state_current_round_check;

alter table public.tournament_state
add constraint tournament_state_current_round_check check (current_round >= 1);

update public.tournament_editions
set is_active = false;

insert into public.tournament_editions (
  slug,
  name,
  label,
  is_active,
  sort_order,
  adaptive_scheduling,
  has_playoffs
)
values (
  'edition-3',
  'Beach Not Pro Tour Third Edition',
  'Edition 3',
  true,
  3,
  true,
  false
)
on conflict (slug) do update set
  name = excluded.name,
  label = excluded.label,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order,
  adaptive_scheduling = excluded.adaptive_scheduling,
  has_playoffs = excluded.has_playoffs;

insert into public.tournament_state (id, edition_id, current_round)
values (
  3,
  (select id from public.tournament_editions where slug = 'edition-3'),
  1
)
on conflict (edition_id) do nothing;

insert into public.players (edition_id, name, gender, rating, form_rating)
values
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Sophie', 'women', 7, 7),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Harish', 'men', 10, 10),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Shehan', 'men', 8, 8),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Maddy', 'men', 6, 6),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Din', 'men', 6, 6),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Barath', 'men', 10, 10),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Yatha', 'men', 7, 7),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Sat', 'men', 6, 6),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Ash', 'men', 7, 7),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Cass', 'women', 6, 6),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Stanley', 'men', 9, 9),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Anas', 'men', 9, 9),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Cynthia', 'women', 6, 6),
  ((select id from public.tournament_editions where slug = 'edition-3'), 'Alex', 'men', 8.5, 8.5)
on conflict (edition_id, name) do update set
  gender = excluded.gender,
  rating = excluded.rating;

create or replace function public.recalculate_form_ratings(
  p_edition_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  match_record record;
  team_a_rating numeric;
  team_b_rating numeric;
  expected_a numeric;
  actual_a numeric;
  margin_multiplier numeric;
  adjustment numeric;
begin
  update public.players
  set form_rating = rating
  where p_edition_id is null or edition_id = p_edition_id;

  for match_record in
    select *
    from public.matches
    where completed = true
      and (p_edition_id is null or edition_id = p_edition_id)
    order by edition_id, round_number, court_number
  loop
    select (p1.form_rating + p2.form_rating) / 2
    into team_a_rating
    from public.players p1
    cross join public.players p2
    where p1.id = match_record.team_a_player_1
      and p2.id = match_record.team_a_player_2;

    select (p1.form_rating + p2.form_rating) / 2
    into team_b_rating
    from public.players p1
    cross join public.players p2
    where p1.id = match_record.team_b_player_1
      and p2.id = match_record.team_b_player_2;

    expected_a := 1 / (1 + power(10::numeric, (team_b_rating - team_a_rating) / 4));
    actual_a := case when match_record.score_a > match_record.score_b then 1 else 0 end;
    margin_multiplier := least(
      1.75,
      1 + abs(match_record.score_a - match_record.score_b)::numeric / 15
    );
    adjustment := 0.45 * margin_multiplier * (actual_a - expected_a);

    update public.players
    set form_rating = greatest(1, least(10, form_rating + adjustment))
    where id in (match_record.team_a_player_1, match_record.team_a_player_2);

    update public.players
    set form_rating = greatest(1, least(10, form_rating - adjustment))
    where id in (match_record.team_b_player_1, match_record.team_b_player_2);
  end loop;
end;
$$;

create or replace function public.after_match_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recalculate_player_standings();
  perform public.recalculate_form_ratings();
  perform public.sync_all_current_rounds();
  return null;
end;
$$;

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

  if (select count(*) from public.players where edition_id = p_edition_id) <> 14 then
    raise exception 'Adaptive scheduling currently requires exactly 14 players.';
  end if;

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
  where players.edition_id = p_edition_id;

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

  for trial in 1..2500 loop
    select array_agg(id order by random())
    into candidate_players
    from (
      select id
      from adaptive_player_stats
      order by matches_played, random()
      limit 12
    ) selected_players;

    candidate_score := 0;
    partner_repeats := 0;
    opponent_repeats := 0;
    is_valid := true;

    for court_index in 1..3 loop
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
      + (partner_repeats * 500)
      + (opponent_repeats * 10)
      + (consecutive_rests * 25)
      + random() / 100;

    if best_score is null or candidate_score < best_score then
      best_score := candidate_score;
      best_players := candidate_players;
    end if;
  end loop;

  if best_players is null then
    raise exception 'No valid round was found. Check player genders and ratings.';
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
  values
    (p_edition_id, next_round, 1, best_players[1], best_players[2], best_players[3], best_players[4]),
    (p_edition_id, next_round, 2, best_players[5], best_players[6], best_players[7], best_players[8]),
    (p_edition_id, next_round, 3, best_players[9], best_players[10], best_players[11], best_players[12]);

  perform public.sync_current_round(p_edition_id);
  return next_round;
end;
$$;

create or replace function public.reset_tournament(
  p_admin_password text,
  p_edition_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_edition_id uuid;
  uses_adaptive_rounds boolean;
begin
  if p_admin_password is distinct from 'hihi' then
    raise exception 'Admin password is required.';
  end if;

  target_edition_id := coalesce(
    p_edition_id,
    (select id from public.tournament_editions where is_active = true order by sort_order desc limit 1)
  );

  select adaptive_scheduling
  into uses_adaptive_rounds
  from public.tournament_editions
  where id = target_edition_id;

  delete from public.playoff_matches
  where edition_id = target_edition_id;

  if uses_adaptive_rounds then
    delete from public.matches
    where edition_id = target_edition_id;
  else
    update public.matches
    set score_a = null, score_b = null, completed = false
    where edition_id = target_edition_id;
  end if;

  update public.tournament_state
  set current_round = 1
  where edition_id = target_edition_id;

  perform public.recalculate_player_standings();
  perform public.recalculate_form_ratings(target_edition_id);

  if uses_adaptive_rounds then
    perform public.generate_next_round(p_admin_password, target_edition_id);
  else
    perform public.sync_current_round(target_edition_id);
  end if;
end;
$$;

grant execute on function public.generate_next_round(text, uuid) to anon, authenticated;

select public.recalculate_player_standings();
select public.recalculate_form_ratings();

do $$
declare
  target_edition_id uuid;
begin
  select id into target_edition_id
  from public.tournament_editions
  where slug = 'edition-3';

  if not exists (
    select 1 from public.matches where edition_id = target_edition_id
  ) then
    perform public.generate_next_round('hihi', target_edition_id);
  end if;
end;
$$;

notify pgrst, 'reload schema';
