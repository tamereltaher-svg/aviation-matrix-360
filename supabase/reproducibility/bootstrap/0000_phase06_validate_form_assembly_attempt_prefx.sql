CREATE OR REPLACE FUNCTION assessment.validate_phase06_form_assembly_attempt(p_attempt_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_run assessment.form_assembly_runs%rowtype;
  v_expected integer;
  v_assigned integer;
  v_blockers integer;
  v_majors integer;
  v_soft numeric(18,6);
  r record;
begin
  select r.* into v_run
  from assessment.form_assembly_attempts a
  join assessment.form_assembly_runs r on r.id=a.run_id
  where a.id=p_attempt_id;
  if not found then raise exception 'Unknown attempt %',p_attempt_id using errcode='23503'; end if;

  delete from assessment.form_assembly_findings
  where attempt_id=p_attempt_id and rule_code like 'VAL%';

  select coalesce(sum(required_item_count),0)*(select launch_form_equivalents from assessment.assessment_banks where id=v_run.bank_id)
    into v_expected
  from assessment.form_blueprint_requirements
  where bank_id=v_run.bank_id and cefr_level=v_run.cefr_level and skill_code in ('RDG','LNG');
  select count(*)::integer into v_assigned from assessment.form_assembly_assignments where attempt_id=p_attempt_id;

  if v_assigned<>v_expected then
    perform assessment.add_form_assembly_finding(p_attempt_id,null,'VAL001','BLOCKER','TOTAL_ASSIGNMENTS',
      format('Attempt assigned %s items; expected %s',v_assigned,v_expected));
  end if;

  for r in
    select a.form_id,a.item_id,i.item_code
    from assessment.form_assembly_assignments a
    join assessment.items i on i.id=a.item_id
    where a.attempt_id=p_attempt_id
      and not assessment.item_gate_passes(a.item_id,v_run.pool_gate)
  loop
    perform assessment.add_form_assembly_finding(p_attempt_id,r.form_id,'VAL002','BLOCKER',r.item_code,'Assigned item no longer passes the selected pool gate');
  end loop;

  for r in
    select stimulus_id,count(distinct form_id)::integer form_count
    from assessment.form_assembly_assignments
    where attempt_id=p_attempt_id and stimulus_id is not null
    group by stimulus_id having count(distinct form_id)>1
  loop
    perform assessment.add_form_assembly_finding(p_attempt_id,null,'VAL003','BLOCKER',r.stimulus_id::text,
      format('Stimulus identity appears across %s sibling forms',r.form_count));
  end loop;

  for r in
    select a.form_id,i.item_code
    from assessment.form_assembly_assignments a
    join assessment.items i on i.id=a.item_id
    join assessment.item_versions iv on iv.id=a.item_version_id
    where a.attempt_id=p_attempt_id and a.skill_code='RDG'
      and (a.stimulus_id is null or a.stimulus_version_id is null or a.stimulus_version_id is distinct from iv.stimulus_version_id)
  loop
    perform assessment.add_form_assembly_finding(p_attempt_id,r.form_id,'VAL004','BLOCKER',r.item_code,'Reading assignment lacks a valid stimulus snapshot');
  end loop;

  for r in
    select form_id,stimulus_id,count(distinct stimulus_version_id)::integer version_count
    from assessment.form_assembly_assignments
    where attempt_id=p_attempt_id and stimulus_id is not null
    group by form_id,stimulus_id
    having count(distinct stimulus_version_id)>1
  loop
    perform assessment.add_form_assembly_finding(p_attempt_id,r.form_id,'VAL005','BLOCKER',r.stimulus_id::text,
      format('One stimulus identity uses %s different stimulus versions inside the same form',r.version_count));
  end loop;

  perform assessment.refresh_phase06_form_equivalence_metrics(p_attempt_id);

  for r in
    select m.form_id,m.dimension_code,m.dimension_key,m.actual_count,m.target_count
    from assessment.form_equivalence_metrics m
    where m.attempt_id=p_attempt_id and m.status='BLOCKER'
  loop
    perform assessment.add_form_assembly_finding(p_attempt_id,r.form_id,'VAL010','BLOCKER',r.dimension_code||':'||r.dimension_key,
      format('Hard equivalence constraint failed: actual=%s target=%s',coalesce(r.actual_count::text,'null'),coalesce(r.target_count::text,'null')));
  end loop;

  for r in
    select m.form_id,m.dimension_code,m.dimension_key,m.actual_share,m.deviation
    from assessment.form_equivalence_metrics m
    where m.attempt_id=p_attempt_id and m.status='MAJOR'
  loop
    perform assessment.add_form_assembly_finding(p_attempt_id,r.form_id,'VAL020','MAJOR',r.dimension_code||':'||r.dimension_key,
      format('Major equivalence concentration: share=%s deviation=%s',coalesce(round(r.actual_share,4)::text,'null'),coalesce(round(r.deviation,4)::text,'null')));
  end loop;

  for r in
    select m.form_id,m.dimension_code,m.dimension_key,m.actual_share,m.deviation
    from assessment.form_equivalence_metrics m
    where m.attempt_id=p_attempt_id and m.status='REVIEW'
  loop
    perform assessment.add_form_assembly_finding(p_attempt_id,r.form_id,'VAL021','WARNING',r.dimension_code||':'||r.dimension_key,
      format('Soft equivalence review: share=%s deviation=%s',coalesce(round(r.actual_share,4)::text,'null'),coalesce(round(r.deviation,4)::text,'null')));
  end loop;

  select count(*) filter(where severity='BLOCKER'),count(*) filter(where severity='MAJOR')
    into v_blockers,v_majors
  from assessment.form_assembly_findings where attempt_id=p_attempt_id;

  with metric_penalty as (
    select coalesce(sum(
      case
        when dimension_code='DIFFICULTY' then abs(coalesce(deviation,0))*12
        when dimension_code='DOMAIN' and status='MAJOR' then 180
        when dimension_code='DOMAIN' and status='REVIEW' then 45
        when dimension_code='READING_WORD_LOAD' then abs(coalesce(deviation,0))*120
        when dimension_code='SIMILARITY_CLUSTER' and status='REVIEW' then 35
        else 0
      end
    ),0)::numeric p
    from assessment.form_equivalence_metrics where attempt_id=p_attempt_id
  ), spread_penalty as (
    select coalesce(sum(mx-mn),0)::numeric p
    from (
      select dimension_code,dimension_key,max(actual_count) mx,min(actual_count) mn
      from assessment.form_equivalence_metrics
      where attempt_id=p_attempt_id and dimension_code in ('CONSTRUCT','ITEM_TYPE')
      group by dimension_code,dimension_key
    ) s
  ), assignment_penalty as (
    select coalesce(sum(candidate_penalty),0)::numeric p
    from assessment.form_assembly_assignments where attempt_id=p_attempt_id
  )
  select (m.p + s.p*3 + a.p*0.01)::numeric(18,6) into v_soft
  from metric_penalty m cross join spread_penalty s cross join assignment_penalty a;

  update assessment.form_assembly_attempts
  set assigned_count=v_assigned,expected_count=v_expected,
      hard_violation_count=v_blockers,major_finding_count=v_majors,
      soft_equivalence_score=v_soft,
      validated_plan_sha256=assessment.phase06_form_assembly_plan_sha256(p_attempt_id),
      validated_config_sha256=assessment.phase06_form_assembly_config_sha256(v_run.bank_id,v_run.cefr_level),
      validated_at=now(),
      status=case when v_blockers=0 then 'PASS' else 'FAIL' end,
      finished_at=now()
  where id=p_attempt_id;

  return case when v_blockers=0 then 'PASS' else 'FAIL' end;
end $function$;
