-- Let admins keep a player in tournament history while hiding them from rankings.

alter table public.players
add column if not exists ranking_visible boolean not null default true;

update public.players
set ranking_visible = false
where
  (id = '33a5c58f-d6d3-4af2-8ff0-55cef56a10a6'::uuid and name = 'Hihi')
  or
  (id = '15cb5636-7732-434f-9bf7-b7b0ba093e54'::uuid and name = 'Iri');

create or replace function public.set_player_ranking_visibility(
  p_admin_password text,
  p_player_id uuid,
  p_visible boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_admin_password is distinct from 'hihi' then
    raise exception 'Admin password is required.';
  end if;

  update public.players
  set ranking_visible = p_visible
  where id = p_player_id;

  if not found then
    raise exception 'Player was not found.';
  end if;
end;
$$;

grant execute on function public.set_player_ranking_visibility(text, uuid, boolean)
to anon, authenticated;

notify pgrst, 'reload schema';
