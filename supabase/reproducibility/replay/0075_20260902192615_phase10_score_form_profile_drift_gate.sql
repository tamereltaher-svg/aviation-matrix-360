create or replace function assessment.phase10_score_form_from_raw(p_form_code text,p_sections jsonb)
returns jsonb
language plpgsql
stable
set search_path=''
as $fn$
declare
  v_form_id uuid;
  v_form_version_id uuid;
  v_profile_id uuid;
  v_level text;
  v_family text;
  v_total numeric:=0;
  v_result jsonb:='{}'::jsonb;
  v_section jsonb;
  v_earned numeric;
  v_weighted numeric;
  v_unknown_count integer;
  v_validation jsonb;
  r record;
begin
  if p_sections is null or jsonb_typeof(p_sections)<>'object' then
    raise exception 'sections must be a JSON object' using errcode='22023';
  end if;

  select f.id,f.current_version_id,f.cefr_level,f.form_family
    into v_form_id,v_form_version_id,v_level,v_family
  from assessment.forms f
  where f.form_code=p_form_code;

  if v_form_id is null or v_form_version_id is null then
    raise exception 'Unknown or unversioned form %',p_form_code using errcode='22023';
  end if;

  select p.id into v_profile_id
  from assessment.exam_form_scoring_profiles p
  where p.form_version_id=v_form_version_id and p.profile_status in ('DRAFT_VERIFIED','QA_VERIFIED','LOCKED');

  if v_profile_id is null then
    raise exception 'No usable scoring profile for form %',p_form_code using errcode='22023';
  end if;

  v_validation:=assessment.phase10_validate_form_scoring_profile(v_form_version_id);
  if not coalesce((v_validation->>'passes')::boolean,false) then
    raise exception 'Scoring profile drift detected for form %',p_form_code using errcode='22023';
  end if;

  select count(*) into v_unknown_count
  from jsonb_object_keys(p_sections) k
  where not exists(
    select 1 from assessment.exam_form_section_scoring_profiles s
    where s.profile_id=v_profile_id and s.skill_code=k
  );
  if v_unknown_count>0 then
    raise exception 'Unknown section key supplied for form %',p_form_code using errcode='22023';
  end if;

  for r in
    select s.skill_code,s.raw_available,s.weight_percent,s.reported_max_score,s.display_order
    from assessment.exam_form_section_scoring_profiles s
    where s.profile_id=v_profile_id
    order by s.display_order
  loop
    v_section:=p_sections->r.skill_code;
    if v_section is null then
      raise exception 'Missing required section % for form %',r.skill_code,p_form_code using errcode='22023';
    end if;
    v_earned:=nullif(v_section->>'earned','')::numeric;
    v_weighted:=assessment.phase10_normalize_section_score(v_earned,r.raw_available,r.weight_percent);
    v_total:=v_total+v_weighted;
    v_result:=v_result||jsonb_build_object(r.skill_code,jsonb_build_object(
      'raw_earned',v_earned,
      'raw_available',r.raw_available,
      'weight_percent',r.weight_percent,
      'reported_max_score',r.reported_max_score,
      'weighted_score',v_weighted
    ));
  end loop;

  return jsonb_build_object(
    'form_code',p_form_code,
    'form_version_id',v_form_version_id,
    'cefr_level',v_level,
    'form_family',v_family,
    'profile_validation','PASS',
    'sections',v_result,
    'total_score',v_total,
    'classification_status','PENDING_STANDARD_SETTING',
    'rounding_status','PENDING_STANDARD_SETTING'
  );
end $fn$;
