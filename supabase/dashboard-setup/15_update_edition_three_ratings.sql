-- Update Edition 3 starting ratings without changing completed results.

do $$
declare
  target_edition_id uuid;
  current_open_round integer;
  matched_players integer;
begin
  select id
  into target_edition_id
  from public.tournament_editions
  where slug = 'edition-3';

  if target_edition_id is null then
    raise exception 'Edition 3 was not found. Run setup 12 first.';
  end if;

  select count(*)::integer
  into matched_players
  from public.players
  where edition_id = target_edition_id
    and name in (
      'Sophie', 'Harish', 'Shehan', 'Maddy', 'Din', 'Barath', 'Yatha',
      'Sat', 'Ash', 'Cass', 'Stanley', 'Anas', 'Cynthia', 'Alex'
    );

  if matched_players <> 14 then
    raise exception 'Expected all 14 Edition 3 players before updating ratings.';
  end if;

  update public.players as player
  set rating = new_rating.rating
  from (
    values
      ('Sophie', 7.0::numeric),
      ('Harish', 10.0::numeric),
      ('Shehan', 8.0::numeric),
      ('Maddy', 6.0::numeric),
      ('Din', 5.5::numeric),
      ('Barath', 10.0::numeric),
      ('Yatha', 7.0::numeric),
      ('Sat', 6.0::numeric),
      ('Ash', 7.5::numeric),
      ('Cass', 6.0::numeric),
      ('Stanley', 9.0::numeric),
      ('Anas', 8.5::numeric),
      ('Cynthia', 6.0::numeric),
      ('Alex', 8.5::numeric)
  ) as new_rating(name, rating)
  where player.edition_id = target_edition_id
    and player.name = new_rating.name;

  perform public.recalculate_form_ratings(target_edition_id);

  select min(round_number)
  into current_open_round
  from public.matches
  where edition_id = target_edition_id
    and completed = false;

  if current_open_round is not null and not exists (
    select 1
    from public.matches
    where edition_id = target_edition_id
      and round_number = current_open_round
      and completed = true
  ) then
    delete from public.matches
    where edition_id = target_edition_id
      and completed = false;

    perform public.generate_next_round('hihi', target_edition_id);
  elsif not exists (
    select 1 from public.matches where edition_id = target_edition_id
  ) then
    perform public.generate_next_round('hihi', target_edition_id);
  end if;
end;
$$;

notify pgrst, 'reload schema';
