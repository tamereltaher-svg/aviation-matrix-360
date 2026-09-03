create table if not exists assessment.exam_form_scoring_profiles (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references assessment.exam_models(id) on delete restrict,
  form_id uuid not null references assessment.forms(id) on delete restrict,
  form_version_id uuid not null references assessment.form_versions(id) on delete restrict,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  form_family text not null check (form_family in ('A','B','C','R1','R2','PILOT')),
  profile_version text not null,
  total_raw_available numeric(10,3) not null check (total_raw_available > 0),
  total_reported_score numeric(10,3) not null check (total_reported_score = 100),
  scoring_version text not null,
  profile_status text not null check (profile_status in ('DRAFT_VERIFIED','QA_VERIFIED','LOCKED','RETIRED')),
  source_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(model_id,form_version_id),
  unique(model_id,form_id,profile_version)
);

create table if not exists assessment.exam_form_section_scoring_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references assessment.exam_form_scoring_profiles(id) on delete restrict,
  skill_code text not null check (skill_code in ('RDG','LST','WRT','SPK','LNG')),
  source_bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  display_order smallint not null check (display_order between 1 and 5),
  item_count integer not null check (item_count > 0),
  objective_item_count integer not null check (objective_item_count >= 0),
  analytic_item_count integer not null check (analytic_item_count >= 0),
  raw_available numeric(10,3) not null check (raw_available > 0),
  weight_percent numeric(8,4) not null check (weight_percent > 0 and weight_percent <= 100),
  reported_max_score numeric(8,4) not null check (reported_max_score > 0 and reported_max_score <= 100),
  scoring_modes jsonb not null,
  source_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(profile_id,skill_code),
  unique(profile_id,display_order),
  check (objective_item_count + analytic_item_count = item_count)
);

create index if not exists idx_exam_form_scoring_profiles_form on assessment.exam_form_scoring_profiles(form_version_id);
create index if not exists idx_exam_form_section_scoring_profiles_profile on assessment.exam_form_section_scoring_profiles(profile_id,display_order);

create or replace function assessment.phase10_validate_form_scoring_profile(p_form_version_id uuid)
returns jsonb
language plpgsql
stable
set search_path=''
as $fn$
declare
  v_profile_id uuid;
  v_model_id uuid;
  v_mismatch_count integer;
  v_missing_count integer;
  v_extra_count integer;
  v_weight_sum numeric;
  v_reported_sum numeric;
  v_raw_sum numeric;
begin
  select id,model_id into v_profile_id,v_model_id
  from assessment.exam_form_scoring_profiles
  where form_version_id=p_form_version_id and profile_status <> 'RETIRED';

  if v_profile_id is null then
    raise exception 'No active scoring profile for form version %',p_form_version_id using errcode='22023';
  end if;

  with actual as (
    select fi.section_code as skill_code,
           count(*)::integer as item_count,
           count(*) filter(where fi.scoring_mode_snapshot='OPTION_KEY')::integer as objective_item_count,
           count(*) filter(where fi.scoring_mode_snapshot='ANALYTIC_RUBRIC')::integer as analytic_item_count,
           sum(fi.max_raw_score_snapshot)::numeric as raw_available,
           jsonb_agg(distinct fi.scoring_mode_snapshot order by fi.scoring_mode_snapshot) as scoring_modes
    from assessment.form_items fi
    where fi.form_version_id=p_form_version_id
    group by fi.section_code
  ), expected as (
    select s.skill_code,s.item_count,s.objective_item_count,s.analytic_item_count,s.raw_available,s.scoring_modes
    from assessment.exam_form_section_scoring_profiles s where s.profile_id=v_profile_id
  )
  select count(*) into v_mismatch_count
  from expected e join actual a using(skill_code)
  where e.item_count<>a.item_count
     or e.objective_item_count<>a.objective_item_count
     or e.analytic_item_count<>a.analytic_item_count
     or e.raw_available<>a.raw_available
     or e.scoring_modes<>a.scoring_modes;

  with actual as (select distinct section_code skill_code from assessment.form_items where form_version_id=p_form_version_id),
       expected as (select skill_code from assessment.exam_form_section_scoring_profiles where profile_id=v_profile_id)
  select count(*) into v_missing_count from expected e where not exists(select 1 from actual a where a.skill_code=e.skill_code);

  with actual as (select distinct section_code skill_code from assessment.form_items where form_version_id=p_form_version_id),
       expected as (select skill_code from assessment.exam_form_section_scoring_profiles where profile_id=v_profile_id)
  select count(*) into v_extra_count from actual a where not exists(select 1 from expected e where e.skill_code=a.skill_code);

  select sum(weight_percent),sum(reported_max_score),sum(raw_available)
  into v_weight_sum,v_reported_sum,v_raw_sum
  from assessment.exam_form_section_scoring_profiles where profile_id=v_profile_id;

  return jsonb_build_object(
    'form_version_id',p_form_version_id,
    'mismatch_count',v_mismatch_count,
    'missing_sections',v_missing_count,
    'extra_sections',v_extra_count,
    'weight_sum',v_weight_sum,
    'reported_score_sum',v_reported_sum,
    'raw_available_sum',v_raw_sum,
    'passes',(v_mismatch_count=0 and v_missing_count=0 and v_extra_count=0 and v_weight_sum=100 and v_reported_sum=100)
  );
end $fn$;

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
    'sections',v_result,
    'total_score',v_total,
    'classification_status','PENDING_STANDARD_SETTING',
    'rounding_status','PENDING_STANDARD_SETTING'
  );
end $fn$;
