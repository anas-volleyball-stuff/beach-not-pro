-- Strengthen partner/opponent diversity for databases that already ran setup 13.

do $migration$
declare
  function_definition text;
begin
  select pg_get_functiondef(
    'public.generate_next_round(text,uuid)'::regprocedure
  )
  into function_definition;

  if position('for trial in 1..6000 loop' in function_definition) > 0
    and position('(partner_repeats * 5000)' in function_definition) > 0
    and position('(opponent_repeats * 180)' in function_definition) > 0
    and position('(consecutive_rests * 1000)' in function_definition) > 0 then
    return;
  end if;

  if position('for trial in 1..3000 loop' in function_definition) = 0
    or position('(partner_repeats * 500)' in function_definition) = 0
    or position('(opponent_repeats * 10)' in function_definition) = 0
    or position('(consecutive_rests * 25)' in function_definition) = 0 then
    raise exception 'The adaptive generator is not at the setup 13 version. Run setup 13 first.';
  end if;

  function_definition := replace(
    function_definition,
    'for trial in 1..3000 loop',
    'for trial in 1..6000 loop'
  );
  function_definition := replace(
    function_definition,
    '(partner_repeats * 500)',
    '(partner_repeats * 5000)'
  );
  function_definition := replace(
    function_definition,
    '(opponent_repeats * 10)',
    '(opponent_repeats * 180)'
  );
  function_definition := replace(
    function_definition,
    '(consecutive_rests * 25)',
    '(consecutive_rests * 1000)'
  );

  execute function_definition;
end;
$migration$;

notify pgrst, 'reload schema';
