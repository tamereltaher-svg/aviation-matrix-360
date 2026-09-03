create or replace function assessment.phase06_form_assembly_preflight(p_bank_id uuid, p_cefr_level text, p_pool_gate text)
returns table(rule_code text, severity text, entity_key text, expected_value numeric, actual_value numeric, message text)
language plpgsql
stable
set search_path to ''
as $function$
declare
  v_fe integer;
  v_forms integer;
  v_blueprint integer;
  v_pool integer;
  r record;
begin
  if p_cefr_level not in ('A1','A2','B1','B2','C1','C2') then
    return query select 'PF000','BLOCKER',p_cefr_level,null::numeric,null::numeric,'Invalid CEFR level';
    return;
  end if;
  if not exists(select 1 from assessment.ref_form_assembly_pool_gates g where g.code=p_pool_gate and g.is_active) then
    return query select 'PF001','BLOCKER',p_pool_gate,null::numeric,null::numeric,'Pool gate is not allowed for form assembly';
    return;
  end if;
  if not exists(select 1 from assessment.assessment_banks b where b.id=p_bank_id and b.bank_code='ENG-GENERAL-P06') then
    return query select 'PF002','BLOCKER',p_bank_id::text,null::numeric,null::numeric,'MC-10I currently supports ENG-GENERAL-P06 only';
    return;
  end if;

  select launch_form_equivalents into v_fe from assessment.assessment_banks where id=p_bank_id;
  select count(*)::integer into v_forms
  from assessment.forms f
  join assessment.form_versions fv on fv.id=f.current_version_id and fv.form_id=f.id and fv.is_current
  where f.bank_id=p_bank_id and f.cefr_level=p_cefr_level
    and f.form_family in ('A','B','C','R1','R2','PILOT');

  if v_forms<>v_fe then
    return query select 'PF010','BLOCKER','FORM_SHELLS',v_fe::numeric,v_forms::numeric,
      format('Expected %s current form shells for %s but found %s',v_fe,p_cefr_level,v_forms);
  else
    return query select 'PF010','INFO','FORM_SHELLS',v_fe::numeric,v_forms::numeric,'Six-form shell architecture is present';
  end if;

  select coalesce(sum(bpr_total.required_item_count),0)::integer into v_blueprint
  from assessment.form_blueprint_requirements bpr_total
  where bpr_total.bank_id=p_bank_id and bpr_total.cefr_level=p_cefr_level and bpr_total.skill_code in ('RDG','LNG');
  select count(*)::integer into v_pool
  from assessment.phase06_item_pool(p_bank_id,p_pool_gate) p
  where p.cefr_level=p_cefr_level;

  if v_pool < v_blueprint*v_fe then
    return query select 'PF020','BLOCKER','TOTAL_CAPACITY',(v_blueprint*v_fe)::numeric,v_pool::numeric,
      format('%s pool has %s eligible items; six forms require %s',p_cefr_level,v_pool,v_blueprint*v_fe);
  else
    return query select 'PF020','INFO','TOTAL_CAPACITY',(v_blueprint*v_fe)::numeric,v_pool::numeric,'Total pool capacity is sufficient';
  end if;

  for r in
    select bpr.skill_code,bpr.required_item_count,
           count(p.item_id)::integer available
    from assessment.form_blueprint_requirements bpr
    left join assessment.phase06_item_pool(p_bank_id,p_pool_gate) p
      on p.cefr_level=bpr.cefr_level and p.skill_code=bpr.skill_code
    where bpr.bank_id=p_bank_id and bpr.cefr_level=p_cefr_level and bpr.skill_code in ('RDG','LNG')
    group by bpr.skill_code,bpr.required_item_count
  loop
    if r.available < r.required_item_count*v_fe then
      return query select 'PF021','BLOCKER',r.skill_code,(r.required_item_count*v_fe)::numeric,r.available::numeric,
        format('%s %s capacity deficit: need %s, available %s',p_cefr_level,r.skill_code,r.required_item_count*v_fe,r.available);
    else
      return query select 'PF021','INFO',r.skill_code,(r.required_item_count*v_fe)::numeric,r.available::numeric,
        format('%s %s six-form capacity is sufficient',p_cefr_level,r.skill_code);
    end if;
  end loop;

  for r in
    select bpr.skill_code,bpr.required_item_count,
           coalesce(sum(lcr.required_per_form) filter(where lcr.source_status='AUTHORITATIVE_CONFIRMED'),0)::integer lo_slots,
           count(lcr.id) filter(where lcr.source_status='AUTHORITATIVE_CONFIRMED')::integer lo_rows
    from assessment.form_blueprint_requirements bpr
    left join assessment.learning_outcomes lo
      on lo.cefr_level=bpr.cefr_level and lo.skill_code=bpr.skill_code
    left join assessment.lo_capacity_requirements lcr
      on lcr.bank_id=bpr.bank_id and lcr.lo_id=lo.id
    where bpr.bank_id=p_bank_id and bpr.cefr_level=p_cefr_level and bpr.skill_code in ('RDG','LNG')
    group by bpr.skill_code,bpr.required_item_count
  loop
    if r.lo_rows=0 or r.lo_slots<>r.required_item_count then
      return query select 'PF030','BLOCKER',r.skill_code,r.required_item_count::numeric,r.lo_slots::numeric,
        format('%s %s authoritative Primary-LO vector is incomplete',p_cefr_level,r.skill_code);
    else
      return query select 'PF030','INFO',r.skill_code,r.required_item_count::numeric,r.lo_slots::numeric,
        format('%s %s authoritative Primary-LO vector reconciles to the blueprint',p_cefr_level,r.skill_code);
    end if;
  end loop;

  for r in
    select lo.lo_code,lcr.required_per_form,
           count(p.item_id)::integer available
    from assessment.lo_capacity_requirements lcr
    join assessment.learning_outcomes lo on lo.id=lcr.lo_id
    left join assessment.phase06_item_pool(p_bank_id,p_pool_gate) p
      on p.cefr_level=lo.cefr_level and p.skill_code=lo.skill_code and p.primary_lo_id=lo.id
    where lcr.bank_id=p_bank_id and lcr.source_status='AUTHORITATIVE_CONFIRMED'
      and lo.cefr_level=p_cefr_level and lo.skill_code in ('RDG','LNG')
    group by lo.lo_code,lcr.required_per_form
  loop
    if r.available < r.required_per_form*v_fe then
      return query select 'PF031','BLOCKER',r.lo_code,(r.required_per_form*v_fe)::numeric,r.available::numeric,
        format('Primary LO %s cannot cover all six forms',r.lo_code);
    else
      return query select 'PF031','INFO',r.lo_code,(r.required_per_form*v_fe)::numeric,r.available::numeric,
        format('Primary LO %s six-form capacity is sufficient',r.lo_code);
    end if;
  end loop;

  for r in
    select bpr.required_stimulus_families_per_form,
           count(distinct p.stimulus_id)::integer available_families
    from assessment.form_blueprint_requirements bpr
    left join assessment.phase06_item_pool(p_bank_id,p_pool_gate) p
      on p.cefr_level=bpr.cefr_level and p.skill_code='RDG'
    where bpr.bank_id=p_bank_id and bpr.cefr_level=p_cefr_level and bpr.skill_code='RDG'
    group by bpr.required_stimulus_families_per_form
  loop
    if r.required_stimulus_families_per_form is not null
       and r.available_families < r.required_stimulus_families_per_form*v_fe then
      return query select 'PF040','BLOCKER','RDG_STIMULUS_FAMILIES',
        (r.required_stimulus_families_per_form*v_fe)::numeric,r.available_families::numeric,
        format('%s Reading needs at least %s independent stimulus families across six forms; available %s',
          p_cefr_level,r.required_stimulus_families_per_form*v_fe,r.available_families);
    else
      return query select 'PF040','INFO','RDG_STIMULUS_FAMILIES',
        coalesce((r.required_stimulus_families_per_form*v_fe)::numeric,0),r.available_families::numeric,
        'Reading stimulus-family capacity is sufficient for zero-overlap partitioning';
    end if;
  end loop;
end
$function$;
