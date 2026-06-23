create or replace function public.recalculate_player_standings()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.player_standings (
    player_id,
    wins,
    losses,
    points_for,
    points_against,
    matches_played,
    updated_at
  )
  select
    players.id,
    coalesce(sum(match_stats.win), 0)::integer as wins,
    coalesce(sum(match_stats.loss), 0)::integer as losses,
    coalesce(sum(match_stats.points_for), 0)::integer as points_for,
    coalesce(sum(match_stats.points_against), 0)::integer as points_against,
    coalesce(count(match_stats.player_id), 0)::integer as matches_played,
    now() as updated_at
  from public.players
  left join (
    select
      team_a_player_1 as player_id,
      (score_a > score_b)::integer as win,
      (score_a < score_b)::integer as loss,
      score_a as points_for,
      score_b as points_against
    from public.matches
    where completed = true
    union all
    select
      team_a_player_2 as player_id,
      (score_a > score_b)::integer as win,
      (score_a < score_b)::integer as loss,
      score_a as points_for,
      score_b as points_against
    from public.matches
    where completed = true
    union all
    select
      team_b_player_1 as player_id,
      (score_b > score_a)::integer as win,
      (score_b < score_a)::integer as loss,
      score_b as points_for,
      score_a as points_against
    from public.matches
    where completed = true
    union all
    select
      team_b_player_2 as player_id,
      (score_b > score_a)::integer as win,
      (score_b < score_a)::integer as loss,
      score_b as points_for,
      score_a as points_against
    from public.matches
    where completed = true
  ) as match_stats on match_stats.player_id = players.id
  group by players.id
  on conflict (player_id) do update set
    wins = excluded.wins,
    losses = excluded.losses,
    points_for = excluded.points_for,
    points_against = excluded.points_against,
    matches_played = excluded.matches_played,
    updated_at = excluded.updated_at;
end;
$$;

create or replace function public.sync_current_round()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  next_round integer;
begin
  select min(round_number)
  into next_round
  from public.matches
  where completed = false;

  if next_round is null then
    select max(round_number)
    into next_round
    from public.matches;
  end if;

  insert into public.tournament_state (id, current_round, updated_at)
  values (1, coalesce(next_round, 1), now())
  on conflict (id) do update set
    current_round = excluded.current_round,
    updated_at = excluded.updated_at;
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
  perform public.sync_current_round();
  return null;
end;
$$;

drop trigger if exists matches_after_change on public.matches;
create trigger matches_after_change
after insert or update or delete on public.matches
for each statement
execute function public.after_match_change();

create or replace function public.save_match_score(
  p_match_id uuid,
  p_score_a integer,
  p_score_b integer,
  p_admin_password text
)
returns public.matches
language plpgsql
security definer
set search_path = public
as $$
declare
  saved_match public.matches;
begin
  if p_admin_password is distinct from 'hihi' then
    raise exception 'Admin password is required.';
  end if;

  if p_score_a is null or p_score_b is null then
    raise exception 'Both team scores are required.';
  end if;

  if p_score_a < 0 or p_score_b < 0 then
    raise exception 'Scores must be zero or greater.';
  end if;

  if p_score_a = p_score_b then
    raise exception 'Matches cannot end in a tie.';
  end if;

  update public.matches
  set
    score_a = p_score_a,
    score_b = p_score_b,
    completed = true
  where id = p_match_id
  returning * into saved_match;

  if saved_match.id is null then
    raise exception 'Match not found.';
  end if;

  return saved_match;
end;
$$;

create or replace function public.reset_tournament(p_admin_password text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_admin_password is distinct from 'hihi' then
    raise exception 'Admin password is required.';
  end if;

  update public.matches
  set
    score_a = null,
    score_b = null,
    completed = false
  where true;

  update public.tournament_state
  set current_round = 1
  where id = 1;

  perform public.recalculate_player_standings();
  perform public.sync_current_round();
end;
$$;
