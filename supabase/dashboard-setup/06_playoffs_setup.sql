create table if not exists public.playoff_matches (
  id uuid primary key default gen_random_uuid(),
  match_key text not null unique,
  stage text not null check (stage in ('semi', 'final')),
  match_number integer not null,
  team_a_seed integer,
  team_b_seed integer,
  team_a_player_1 uuid references public.players(id) on delete restrict,
  team_a_player_2 uuid references public.players(id) on delete restrict,
  team_b_player_1 uuid references public.players(id) on delete restrict,
  team_b_player_2 uuid references public.players(id) on delete restrict,
  score_a integer check (score_a >= 0),
  score_b integer check (score_b >= 0),
  final_format text not null default 'single_21' check (final_format in ('single_21', 'best_of_3')),
  set1_a integer check (set1_a >= 0),
  set1_b integer check (set1_b >= 0),
  set2_a integer check (set2_a >= 0),
  set2_b integer check (set2_b >= 0),
  set3_a integer check (set3_a >= 0),
  set3_b integer check (set3_b >= 0),
  completed boolean not null default false,
  updated_at timestamptz not null default now()
);

drop trigger if exists playoff_matches_touch_updated_at on public.playoff_matches;
create trigger playoff_matches_touch_updated_at
before update on public.playoff_matches
for each row
execute function public.touch_updated_at();

create or replace function public.is_valid_capped_score(
  p_score_a integer,
  p_score_b integer,
  p_target integer,
  p_cap integer
)
returns boolean
language sql
immutable
as $$
  select
    p_score_a is not null
    and p_score_b is not null
    and p_score_a >= 0
    and p_score_b >= 0
    and p_score_a <> p_score_b
    and greatest(p_score_a, p_score_b) between p_target and p_cap
    and (
      (
        greatest(p_score_a, p_score_b) < p_cap
        and abs(p_score_a - p_score_b) >= 2
      )
      or (
        greatest(p_score_a, p_score_b) = p_cap
        and least(p_score_a, p_score_b) <= p_cap - 1
      )
    );
$$;

create or replace function public.initialize_playoffs(p_admin_password text)
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
    limit 4
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
    limit 4
  ) ranked_women;

  if coalesce(array_length(men_ids, 1), 0) < 4 or coalesce(array_length(women_ids, 1), 0) < 4 then
    raise exception 'Need top 4 men and top 4 women before creating playoffs.';
  end if;

  delete from public.playoff_matches where true;

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

  insert into public.playoff_matches (match_key, stage, match_number)
  values ('final', 'final', 1);
end;
$$;

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

  if not public.is_valid_capped_score(p_score_a, p_score_b, 15, 18) then
    raise exception 'Group games must be to 15, win by 2, capped at 18.';
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

create or replace function public.playoff_winner_players(p_match public.playoff_matches)
returns uuid[]
language sql
stable
as $$
  select case
    when p_match.score_a > p_match.score_b then array[p_match.team_a_player_1, p_match.team_a_player_2]
    else array[p_match.team_b_player_1, p_match.team_b_player_2]
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
    raise exception 'Semifinals must be to 21, win by 2, capped at 24.';
  end if;

  update public.playoff_matches
  set
    score_a = p_score_a,
    score_b = p_score_b,
    completed = true
  where id = p_match_id
    and stage = 'semi'
  returning * into saved_match;

  if saved_match.id is null then
    raise exception 'Semifinal not found.';
  end if;

  perform public.sync_final_from_semis();
  return saved_match;
end;
$$;

create or replace function public.save_final_score(
  p_match_id uuid,
  p_final_format text,
  p_set1_a integer,
  p_set1_b integer,
  p_set2_a integer,
  p_set2_b integer,
  p_set3_a integer,
  p_set3_b integer,
  p_admin_password text
)
returns public.playoff_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  saved_match public.playoff_matches;
  team_a_sets integer := 0;
  team_b_sets integer := 0;
begin
  if p_admin_password is distinct from 'hihi' then
    raise exception 'Admin password is required.';
  end if;

  if p_final_format not in ('single_21', 'best_of_3') then
    raise exception 'Invalid final format.';
  end if;

  if p_final_format = 'single_21' then
    if not public.is_valid_capped_score(p_set1_a, p_set1_b, 21, 24) then
      raise exception 'Final game must be to 21, win by 2, capped at 24.';
    end if;

    update public.playoff_matches
    set
      final_format = p_final_format,
      score_a = p_set1_a,
      score_b = p_set1_b,
      set1_a = p_set1_a,
      set1_b = p_set1_b,
      set2_a = null,
      set2_b = null,
      set3_a = null,
      set3_b = null,
      completed = true
    where id = p_match_id
      and stage = 'final'
    returning * into saved_match;
  else
    if not public.is_valid_capped_score(p_set1_a, p_set1_b, 21, 24)
      or not public.is_valid_capped_score(p_set2_a, p_set2_b, 21, 24) then
      raise exception 'First two final sets must be to 21, win by 2, capped at 24.';
    end if;

    team_a_sets := (p_set1_a > p_set1_b)::integer + (p_set2_a > p_set2_b)::integer;
    team_b_sets := (p_set1_b > p_set1_a)::integer + (p_set2_b > p_set2_a)::integer;

    if team_a_sets < 2 and team_b_sets < 2 then
      if not public.is_valid_capped_score(p_set3_a, p_set3_b, 15, 18) then
        raise exception 'Third final set must be to 15, win by 2, capped at 18.';
      end if;
      team_a_sets := team_a_sets + (p_set3_a > p_set3_b)::integer;
      team_b_sets := team_b_sets + (p_set3_b > p_set3_a)::integer;
    end if;

    if team_a_sets <> 2 and team_b_sets <> 2 then
      raise exception 'Best of 3 final must have a winner.';
    end if;

    update public.playoff_matches
    set
      final_format = p_final_format,
      score_a = team_a_sets,
      score_b = team_b_sets,
      set1_a = p_set1_a,
      set1_b = p_set1_b,
      set2_a = p_set2_a,
      set2_b = p_set2_b,
      set3_a = case when team_a_sets = 2 or team_b_sets = 2 then p_set3_a else null end,
      set3_b = case when team_a_sets = 2 or team_b_sets = 2 then p_set3_b else null end,
      completed = true
    where id = p_match_id
      and stage = 'final'
    returning * into saved_match;
  end if;

  if saved_match.id is null then
    raise exception 'Final not found.';
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

  delete from public.playoff_matches where true;

  update public.tournament_state
  set current_round = 1
  where id = 1;

  perform public.recalculate_player_standings();
  perform public.sync_current_round();
end;
$$;

alter table public.playoff_matches enable row level security;

drop policy if exists "Public read playoff matches" on public.playoff_matches;
create policy "Public read playoff matches"
on public.playoff_matches
for select
to anon, authenticated
using (true);

grant select on public.playoff_matches to anon, authenticated;
grant execute on function public.initialize_playoffs(text) to anon, authenticated;
grant execute on function public.save_playoff_score(uuid, integer, integer, text) to anon, authenticated;
grant execute on function public.save_final_score(uuid, text, integer, integer, integer, integer, integer, integer, text) to anon, authenticated;
grant execute on function public.reset_tournament(text) to anon, authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.playoff_matches;
    exception
      when duplicate_object then null;
    end;
  end if;
end;
$$;

notify pgrst, 'reload schema';
