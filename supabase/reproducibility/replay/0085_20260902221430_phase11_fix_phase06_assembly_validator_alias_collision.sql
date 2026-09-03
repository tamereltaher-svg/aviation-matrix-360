
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('assessment.validate_phase06_form_assembly_attempt(uuid)'::regprocedure)
    into v_def;

  if strpos(v_def,'select r.* into v_run')=0
     or strpos(v_def,'join assessment.form_assembly_runs r on r.id=a.run_id')=0 then
    raise exception 'Expected validator alias anchors not found; migration aborted';
  end if;

  v_def := replace(v_def,
    'select r.* into v_run',
    'select run_row.* into v_run');
  v_def := replace(v_def,
    'join assessment.form_assembly_runs r on r.id=a.run_id',
    'join assessment.form_assembly_runs run_row on run_row.id=a.run_id');

  execute v_def;
end
$migration$;

revoke execute on function assessment.validate_phase06_form_assembly_attempt(uuid)
  from public, anon, authenticated;
