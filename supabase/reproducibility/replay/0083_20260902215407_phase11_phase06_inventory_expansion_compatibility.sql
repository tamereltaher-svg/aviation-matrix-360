
create or replace function assessment.assert_phase06_configuration(p_bank_id uuid)
returns void
language plpgsql
set search_path to ''
as $function$
declare
  v_count integer;
  v_total integer;
  v_rdg integer;
  v_lng integer;
  v_launch_fe integer;
  v_band text;
  v_expected integer;
  v_actual integer;
  v_manifest_total integer;
  v_manifest_rdg integer;
  v_manifest_lng integer;
  v_max_release integer;
  v_original_release_count integer;
  v_original_release_total integer;
begin
  select launch_form_equivalents into v_launch_fe
  from assessment.assessment_banks
  where id=p_bank_id and bank_code='ENG-GENERAL-P06';

  if v_launch_fe is null then
    raise exception 'ENG-GENERAL-P06 bank not found' using errcode='23514';
  end if;
  if v_launch_fe <> 6 then
    raise exception 'Phase 06 launch_form_equivalents must equal 6, found %',v_launch_fe using errcode='23514';
  end if;

  select count(*),coalesce(sum(item_count_expected),0),coalesce(max(release_number),0)
    into v_count,v_total,v_max_release
  from assessment.releases
  where bank_id=p_bank_id;

  select count(*),
         count(*) filter(where skill_code='RDG'),
         count(*) filter(where skill_code='LNG')
    into v_manifest_total,v_manifest_rdg,v_manifest_lng
  from assessment.phase06_expected_item_identities
  where bank_id=p_bank_id;

  if v_count=0 or v_count<>v_max_release then
    raise exception 'Release ledger must be contiguous from 1 through %, found % releases',
      v_max_release,v_count using errcode='23514';
  end if;

  if exists (
    select 1
    from generate_series(1,v_max_release) g(n)
    left join assessment.releases r
      on r.bank_id=p_bank_id and r.release_number=g.n
    where r.id is null
  ) then
    raise exception 'Release ledger has a missing release number in 1..%',v_max_release using errcode='23514';
  end if;

  if v_total<>v_manifest_total then
    raise exception 'Release ledger expected-item total % does not match identity manifest %',
      v_total,v_manifest_total using errcode='23514';
  end if;

  select count(*),coalesce(sum(item_count_expected),0)
    into v_original_release_count,v_original_release_total
  from assessment.releases
  where bank_id=p_bank_id and release_number between 1 and 14;

  if v_original_release_count<>14 or v_original_release_total<>1536 then
    raise exception 'Frozen original release ledger mismatch: releases %, total %, expected 14 / 1536',
      v_original_release_count,v_original_release_total using errcode='23514';
  end if;

  select count(*), coalesce(sum(required_item_count*v_launch_fe),0),
         coalesce(sum(required_item_count*v_launch_fe) filter(where skill_code='RDG'),0),
         coalesce(sum(required_item_count*v_launch_fe) filter(where skill_code='LNG'),0)
    into v_count,v_total,v_rdg,v_lng
  from assessment.form_blueprint_requirements
  where bank_id=p_bank_id;

  if v_count<>12 then
    raise exception 'Form blueprint must contain 12 Level x Skill rows, found %',v_count using errcode='23514';
  end if;
  if v_total<>1536 or v_rdg<>798 or v_lng<>738 then
    raise exception 'Blueprint launch capacity mismatch: total %, RDG %, LNG %, expected 1536/798/738',
      v_total,v_rdg,v_lng using errcode='23514';
  end if;
  if v_manifest_rdg<v_rdg or v_manifest_lng<v_lng then
    raise exception 'Identity inventory is below six-form blueprint capacity: manifest RDG/LNG %/%; required %/%',
      v_manifest_rdg,v_manifest_lng,v_rdg,v_lng using errcode='23514';
  end if;
  if exists (
    select 1 from assessment.form_blueprint_requirements
    where bank_id=p_bank_id and skill_code not in ('RDG','LNG')
  ) then
    raise exception 'Phase 06 form blueprint may contain only RDG/LNG' using errcode='23514';
  end if;

  select count(*),coalesce(sum(target_count),0)
    into v_count,v_total
  from assessment.difficulty_distribution_targets
  where bank_id=p_bank_id;

  if v_count<>48 or v_total<>1536 then
    raise exception 'Difficulty matrix mismatch: rows %, total %, expected 48 / 1536',
      v_count,v_total using errcode='23514';
  end if;

  if exists (
    select 1
    from assessment.form_blueprint_requirements r
    left join lateral (
      select coalesce(sum(d.target_count),0)::integer as diff_total
      from assessment.difficulty_distribution_targets d
      where d.bank_id=r.bank_id
        and d.cefr_level=r.cefr_level
        and d.skill_code=r.skill_code
    ) x on true
    where r.bank_id=p_bank_id
      and x.diff_total <> r.required_item_count*v_launch_fe
  ) then
    raise exception 'At least one Level x Skill difficulty total does not equal its six-form capacity' using errcode='23514';
  end if;

  foreach v_band in array array['D1','D2','D3','D4'] loop
    v_expected := case v_band when 'D1' then 306 when 'D2' then 768 when 'D3' then 306 else 156 end;
    select coalesce(sum(target_count),0) into v_actual
    from assessment.difficulty_distribution_targets
    where bank_id=p_bank_id and difficulty_band=v_band;
    if v_actual<>v_expected then
      raise exception 'Difficulty % total % does not equal expected %',v_band,v_actual,v_expected using errcode='23514';
    end if;
  end loop;

  select count(*) into v_count
  from assessment.forms
  where bank_id=p_bank_id;
  if v_count<>36 then
    raise exception 'Expected 36 Phase 06 form identities, found %',v_count using errcode='23514';
  end if;

  if exists (
    select l.cefr_level,f.form_family
    from (values ('A1'),('A2'),('B1'),('B2'),('C1'),('C2')) l(cefr_level)
    cross join (values ('A'),('B'),('C'),('R1'),('R2'),('PILOT')) f(form_family)
    left join assessment.forms af
      on af.bank_id=p_bank_id and af.cefr_level=l.cefr_level and af.form_family=f.form_family
    where af.id is null
  ) then
    raise exception 'One or more required A/B/C/R1/R2/PILOT form identities are missing' using errcode='23514';
  end if;

  select count(*) into v_count
  from assessment.forms f
  join assessment.form_versions fv on fv.id=f.current_version_id
  where f.bank_id=p_bank_id
    and fv.form_id=f.id
    and fv.is_current;
  if v_count<>36 then
    raise exception 'Expected 36 valid current form-version pointers, found %',v_count using errcode='23514';
  end if;
end
$function$;

create or replace function assessment.assert_phase06_identity_manifest(p_bank_id uuid)
returns void
language plpgsql
set search_path to ''
as $function$
declare
  v_total integer;
  v_rdg integer;
  v_lng integer;
  v_gap integer;
  v_rec integer;
  v_bad integer;
  v_release_total integer;
  v_required_rdg integer;
  v_required_lng integer;
begin
  select count(*),
         count(*) filter(where skill_code='RDG'),
         count(*) filter(where skill_code='LNG'),
         count(*) filter(where source_expectation='LEGACY_SOURCE_GAP'),
         count(*) filter(where source_expectation='RECOVERABLE_SOURCE_EXPECTED')
    into v_total,v_rdg,v_lng,v_gap,v_rec
  from assessment.phase06_expected_item_identities
  where bank_id=p_bank_id;

  if v_total=0 or v_total<>v_rdg+v_lng or v_total<>v_gap+v_rec then
    raise exception 'Phase06 identity manifest internal reconciliation failed total/RDG/LNG/gap/recoverable = %/%/%/%/%',
      v_total,v_rdg,v_lng,v_gap,v_rec using errcode='23514';
  end if;

  select coalesce(sum(item_count_expected),0) into v_release_total
  from assessment.releases
  where bank_id=p_bank_id;

  if v_total<>v_release_total then
    raise exception 'Phase06 identity manifest total % does not match release ledger %',
      v_total,v_release_total using errcode='23514';
  end if;

  select
    coalesce(sum(r.required_item_count*b.launch_form_equivalents) filter(where r.skill_code='RDG'),0),
    coalesce(sum(r.required_item_count*b.launch_form_equivalents) filter(where r.skill_code='LNG'),0)
    into v_required_rdg,v_required_lng
  from assessment.form_blueprint_requirements r
  join assessment.assessment_banks b on b.id=r.bank_id
  where r.bank_id=p_bank_id;

  if v_rdg<v_required_rdg or v_lng<v_required_lng then
    raise exception 'Phase06 identity manifest is below blueprint capacity RDG/LNG = %/%; required %/%',
      v_rdg,v_lng,v_required_rdg,v_required_lng using errcode='23514';
  end if;

  select count(*) into v_bad
  from assessment.releases r
  left join lateral (
    select count(*) c
    from assessment.phase06_expected_item_identities e
    where e.release_id=r.id
  ) x on true
  where r.bank_id=p_bank_id and coalesce(x.c,0)<>r.item_count_expected;

  if v_bad>0 then
    raise exception 'Phase06 identity manifest has % release-count mismatches',v_bad using errcode='23514';
  end if;
end
$function$;

create or replace function assessment.phase06_master_import_readiness(p_bank_id uuid)
returns table(metric_code text, expected_value integer, actual_value integer, status text)
language sql
stable
set search_path to ''
as $function$
with m as (
  select
    (select count(*)::int from assessment.phase06_expected_item_identities e where e.bank_id=p_bank_id) exp_total,
    (select count(*)::int from assessment.phase06_expected_item_identities e where e.bank_id=p_bank_id and e.skill_code='RDG') exp_rdg,
    (select count(*)::int from assessment.phase06_expected_item_identities e where e.bank_id=p_bank_id and e.skill_code='LNG') exp_lng,
    (select count(*)::int from assessment.phase06_expected_item_identities e where e.bank_id=p_bank_id and e.source_expectation='RECOVERABLE_SOURCE_EXPECTED') exp_rec,
    (select count(*)::int from assessment.phase06_expected_item_identities e where e.bank_id=p_bank_id and e.source_expectation='LEGACY_SOURCE_GAP') exp_gap,
    (select count(*)::int from assessment.items i where i.bank_id=p_bank_id) act_total,
    (select count(*)::int from assessment.items i where i.bank_id=p_bank_id and i.skill_code='RDG') act_rdg,
    (select count(*)::int from assessment.items i where i.bank_id=p_bank_id and i.skill_code='LNG') act_lng,
    (select count(*)::int from assessment.items i where i.bank_id=p_bank_id and i.current_version_id is not null) hydrated,
    (select count(*)::int
     from assessment.items i
     join assessment.phase06_expected_item_identities e
       on e.bank_id=i.bank_id and e.item_code=i.item_code
     where i.bank_id=p_bank_id
       and e.source_expectation='LEGACY_SOURCE_GAP'
       and i.current_version_id is null) remaining_gap
)
select 'IDENTITY_TOTAL',exp_total,act_total,case when act_total=exp_total then 'PASS' else 'FAIL' end from m
union all
select 'READING_IDENTITIES',exp_rdg,act_rdg,case when act_rdg=exp_rdg then 'PASS' else 'FAIL' end from m
union all
select 'LNG_IDENTITIES',exp_lng,act_lng,case when act_lng=exp_lng then 'PASS' else 'FAIL' end from m
union all
select 'EXPECTED_RECOVERABLE_SOURCE_CLASS',exp_rec,exp_rec,'PASS' from m
union all
select 'EXPECTED_LEGACY_SOURCE_GAP_CLASS',exp_gap,exp_gap,'PASS' from m
union all
select 'CURRENTLY_HYDRATED_ITEMS',exp_rec,hydrated,case when hydrated>=exp_rec then 'TARGET_MET' else 'IN_PROGRESS' end from m
union all
select 'LEGACY_ROWS_STILL_WITHOUT_CONTENT',0,remaining_gap,case when remaining_gap=0 then 'RECOVERED' else 'SOURCE_GAP_REMAINS' end from m;
$function$;

revoke execute on function assessment.assert_phase06_configuration(uuid) from public, anon, authenticated;
revoke execute on function assessment.assert_phase06_identity_manifest(uuid) from public, anon, authenticated;
revoke execute on function assessment.phase06_master_import_readiness(uuid) from public, anon, authenticated;
