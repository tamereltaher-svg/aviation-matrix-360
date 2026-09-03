
do $migration$
declare
  v_def text;
  v_anchor text := 'return query select case when v_block=0 then ''PASS'' else ''FAIL'' end,v_block,v_warn;';
  v_replacement text := $inject$
update assessment_staging.phase06_stimuli_import s
  set row_status=case when exists(
    select 1
    from assessment.phase06_item_import_findings f
    where f.batch_id=p_batch_id
      and f.rule_code like 'P06STM%'
      and f.severity='BLOCKER'
      and f.status='OPEN'
      and f.item_code is null
      and f.row_number=s.row_number
  ) then 'FAIL' else 'PASS' end
  where s.batch_id=p_batch_id;
  return query select case when v_block=0 then 'PASS' else 'FAIL' end,v_block,v_warn;
$inject$;
begin
  select pg_get_functiondef('assessment.validate_phase06_item_import_batch(uuid)'::regprocedure)
    into v_def;

  if strpos(v_def, v_anchor)=0 then
    raise exception 'Expected validation return anchor not found; migration aborted';
  end if;

  v_def := replace(v_def, v_anchor, v_replacement);
  execute v_def;
end
$migration$;

revoke execute on function assessment.validate_phase06_item_import_batch(uuid)
  from public, anon, authenticated;
