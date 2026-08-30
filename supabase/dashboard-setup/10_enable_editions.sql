create table if not exists public.tournament_editions (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  label text not null,
  is_active boolean not null default false,
  sort_order integer not null unique,
  created_at timestamptz not null default now()
);

drop trigger if exists matches_after_change on public.matches;
drop function if exists public.sync_current_round();

insert into public.tournament_editions (slug, name, label, is_active, sort_order)
values
  ('edition-1', 'Beach Not Pro Tour', 'Edition 1', false, 1),
  ('edition-2', 'Beach Not Pro Tour Second Edition', 'Edition 2', true, 2)
on conflict (slug) do update set
  name = excluded.name,
  label = excluded.label,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

alter table public.players
add column if not exists edition_id uuid references public.tournament_editions(id) on delete restrict;

alter table public.matches
add column if not exists edition_id uuid references public.tournament_editions(id) on delete restrict;

alter table public.tournament_state
add column if not exists edition_id uuid references public.tournament_editions(id) on delete restrict;

alter table public.playoff_matches
add column if not exists edition_id uuid references public.tournament_editions(id) on delete restrict;

update public.players
set edition_id = (select id from public.tournament_editions where slug = 'edition-1')
where edition_id is null;

update public.matches
set edition_id = (select id from public.tournament_editions where slug = 'edition-1')
where edition_id is null;

update public.tournament_state
set edition_id = (select id from public.tournament_editions where slug = 'edition-1')
where edition_id is null;

update public.playoff_matches
set edition_id = (select id from public.tournament_editions where slug = 'edition-1')
where edition_id is null;

alter table public.players alter column edition_id set not null;
alter table public.matches alter column edition_id set not null;
alter table public.tournament_state alter column edition_id set not null;
alter table public.playoff_matches alter column edition_id set not null;

alter table public.players drop constraint if exists players_name_key;
alter table public.players
drop constraint if exists players_edition_id_name_key;
alter table public.players
add constraint players_edition_id_name_key unique (edition_id, name);

alter table public.matches
drop constraint if exists matches_round_number_court_number_key;
alter table public.matches
drop constraint if exists matches_edition_id_round_number_court_number_key;
alter table public.matches
add constraint matches_edition_id_round_number_court_number_key unique (edition_id, round_number, court_number);

alter table public.tournament_state
drop constraint if exists tournament_state_id_check;
alter table public.tournament_state
drop constraint if exists tournament_state_edition_id_key;
alter table public.tournament_state
add constraint tournament_state_edition_id_key unique (edition_id);

alter table public.playoff_matches
drop constraint if exists playoff_matches_match_key_key;
alter table public.playoff_matches
drop constraint if exists playoff_matches_edition_id_match_key_key;
alter table public.playoff_matches
add constraint playoff_matches_edition_id_match_key_key unique (edition_id, match_key);

insert into public.tournament_state (id, edition_id, current_round)
values (
  2,
  (select id from public.tournament_editions where slug = 'edition-2'),
  1
)
on conflict (edition_id) do update set current_round = excluded.current_round;

insert into public.players (edition_id, name, gender, rating)
values
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Kang', 'men', 3),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Harish', 'men', 3),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Fai', 'men', 2),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Gerald', 'men', 2),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Shehan', 'men', 2),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Din', 'men', 1),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Maddy', 'men', 1),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Jolene', 'women', 3),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Sophie', 'women', 3),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Katrina', 'women', 3),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Bernie', 'women', 2),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Cass', 'women', 2),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Wanzhen', 'women', 2),
  ((select id from public.tournament_editions where slug = 'edition-2'), 'Jess', 'women', 1)
on conflict (edition_id, name) do update set
  gender = excluded.gender,
  rating = excluded.rating;

delete from public.playoff_matches
where edition_id = (select id from public.tournament_editions where slug = 'edition-2');

delete from public.matches
where edition_id = (select id from public.tournament_editions where slug = 'edition-2');

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
  (select id from public.tournament_editions where slug = 'edition-2'),
  fixed_schedule.round_number,
  fixed_schedule.court_number,
  team_a_1.id,
  team_a_2.id,
  team_b_1.id,
  team_b_2.id
from fixed_schedule
join public.players as team_a_1
  on team_a_1.name = fixed_schedule.team_a_player_1
  and team_a_1.edition_id = (select id from public.tournament_editions where slug = 'edition-2')
join public.players as team_a_2
  on team_a_2.name = fixed_schedule.team_a_player_2
  and team_a_2.edition_id = (select id from public.tournament_editions where slug = 'edition-2')
join public.players as team_b_1
  on team_b_1.name = fixed_schedule.team_b_player_1
  and team_b_1.edition_id = (select id from public.tournament_editions where slug = 'edition-2')
join public.players as team_b_2
  on team_b_2.name = fixed_schedule.team_b_player_2
  and team_b_2.edition_id = (select id from public.tournament_editions where slug = 'edition-2');

create or replace function public.sync_current_round(p_edition_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_edition_id uuid;
  next_round integer;
begin
  target_edition_id := coalesce(
    p_edition_id,
    (select id from public.tournament_editions where is_active = true order by sort_order desc limit 1)
  );

  select min(round_number)
  into next_round
  from public.matches
  where completed = false
    and edition_id = target_edition_id;

  if next_round is null then
    select max(round_number)
    into next_round
    from public.matches
    where edition_id = target_edition_id;
  end if;

  insert into public.tournament_state (edition_id, current_round, updated_at)
  values (target_edition_id, coalesce(next_round, 1), now())
  on conflict (edition_id) do update set
    current_round = excluded.current_round,
    updated_at = excluded.updated_at;
end;
$$;

create or replace function public.sync_all_current_rounds()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  edition_record record;
begin
  for edition_record in select id from public.tournament_editions loop
    perform public.sync_current_round(edition_record.id);
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
  perform public.sync_all_current_rounds();
  return null;
end;
$$;

create trigger matches_after_change
after insert or update or delete on public.matches
for each statement
execute function public.after_match_change();

drop function if exists public.reset_tournament(text);

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
begin
  if p_admin_password is distinct from 'hihi' then
    raise exception 'Admin password is required.';
  end if;

  target_edition_id := coalesce(
    p_edition_id,
    (select id from public.tournament_editions where is_active = true order by sort_order desc limit 1)
  );

  update public.matches
  set
    score_a = null,
    score_b = null,
    completed = false
  where edition_id = target_edition_id;

  delete from public.playoff_matches
  where edition_id = target_edition_id;

  update public.tournament_state
  set current_round = 1
  where edition_id = target_edition_id;

  perform public.recalculate_player_standings();
  perform public.sync_current_round(target_edition_id);
end;
$$;

alter table public.tournament_editions enable row level security;

drop policy if exists "Public read tournament editions" on public.tournament_editions;
create policy "Public read tournament editions"
on public.tournament_editions
for select
to anon, authenticated
using (true);

grant select on public.tournament_editions to anon, authenticated;
grant execute on function public.reset_tournament(text, uuid) to anon, authenticated;
grant execute on function public.sync_current_round(uuid) to anon, authenticated;

create or replace function public.initialize_playoffs(
  p_admin_password text,
  p_format text default 'semis',
  p_edition_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_edition_id uuid;
  men_ids uuid[];
  women_ids uuid[];
begin
  if p_admin_password is distinct from 'hihi' then
    raise exception 'Admin password is required.';
  end if;

  if p_format not in ('semis', 'quarters') then
    raise exception 'Invalid playoff format.';
  end if;

  target_edition_id := coalesce(
    p_edition_id,
    (select id from public.tournament_editions where is_active = true order by sort_order desc limit 1)
  );

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
      and players.edition_id = target_edition_id
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
      and players.edition_id = target_edition_id
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

  delete from public.playoff_matches where edition_id = target_edition_id;

  if p_format = 'quarters' then
    insert into public.playoff_matches (
      edition_id,
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
      (target_edition_id, 'quarter_1', 'quarter', 1, 2, 7, men_ids[2], women_ids[2], men_ids[7], women_ids[7]),
      (target_edition_id, 'quarter_2', 'quarter', 2, 3, 6, men_ids[3], women_ids[3], men_ids[6], women_ids[6]),
      (target_edition_id, 'quarter_3', 'quarter', 3, 4, 5, men_ids[4], women_ids[4], men_ids[5], women_ids[5]);

    insert into public.playoff_matches (
      edition_id,
      match_key,
      stage,
      match_number,
      team_a_seed,
      team_a_player_1,
      team_a_player_2
    )
    values (target_edition_id, 'semi_1', 'semi', 1, 1, men_ids[1], women_ids[1]);

    insert into public.playoff_matches (edition_id, match_key, stage, match_number)
    values (target_edition_id, 'semi_2', 'semi', 2);
  else
    insert into public.playoff_matches (
      edition_id,
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
      (target_edition_id, 'semi_1', 'semi', 1, 1, 4, men_ids[1], women_ids[1], men_ids[4], women_ids[4]),
      (target_edition_id, 'semi_2', 'semi', 2, 2, 3, men_ids[2], women_ids[2], men_ids[3], women_ids[3]);
  end if;

  insert into public.playoff_matches (edition_id, match_key, stage, match_number)
  values (target_edition_id, 'final', 'final', 1);
end;
$$;

create or replace function public.reset_playoff_match(
  p_match_key text,
  p_edition_id uuid
)
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
  where match_key = p_match_key
    and edition_id = p_edition_id;
$$;

create or replace function public.sync_semis_from_quarters(p_edition_id uuid)
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
  select * into quarter1 from public.playoff_matches where match_key = 'quarter_1' and edition_id = p_edition_id;
  select * into quarter2 from public.playoff_matches where match_key = 'quarter_2' and edition_id = p_edition_id;
  select * into quarter3 from public.playoff_matches where match_key = 'quarter_3' and edition_id = p_edition_id;

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
    where match_key = 'semi_1'
      and edition_id = p_edition_id;

    perform public.reset_playoff_match('final', p_edition_id);
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
    where match_key = 'semi_2'
      and edition_id = p_edition_id;

    perform public.reset_playoff_match('final', p_edition_id);
  end if;
end;
$$;

create or replace function public.sync_final_from_semis(p_edition_id uuid)
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
  select * into semi1 from public.playoff_matches where match_key = 'semi_1' and edition_id = p_edition_id;
  select * into semi2 from public.playoff_matches where match_key = 'semi_2' and edition_id = p_edition_id;

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
    where match_key = 'final'
      and edition_id = p_edition_id;
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
    where match_key = 'final'
      and edition_id = p_edition_id;
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
    perform public.sync_semis_from_quarters(saved_match.edition_id);
  end if;

  perform public.sync_final_from_semis(saved_match.edition_id);
  return saved_match;
end;
$$;

grant execute on function public.initialize_playoffs(text, text, uuid) to anon, authenticated;
grant execute on function public.save_playoff_score(uuid, integer, integer, text) to anon, authenticated;

select public.recalculate_player_standings();
select public.sync_all_current_rounds();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.tournament_editions;
    exception
      when duplicate_object then null;
    end;
  end if;
end;
$$;

notify pgrst, 'reload schema';
