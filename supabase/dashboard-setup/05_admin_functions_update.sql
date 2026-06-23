drop function if exists public.save_match_score(uuid, integer, integer);

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
    completed = false;

  update public.tournament_state
  set current_round = 1
  where id = 1;

  perform public.recalculate_player_standings();
  perform public.sync_current_round();
end;
$$;

grant execute on function public.save_match_score(uuid, integer, integer, text) to anon, authenticated;
grant execute on function public.reset_tournament(text) to anon, authenticated;
