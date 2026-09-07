-- BEGIN CANONICAL MIGRATION 0073 20260902185930 phase10_integrated_exam_model_and_scoring_engine
do $do$
declare r record;
begin
  for r in
    select conname
    from pg_constraint con
    join pg_class c on con.conrelid=c.oid
    join pg_namespace n on c.relnamespace=n.oid
    where n.nspname='assessment' and c.relname='form_items' and con.contype='c'
      and pg_get_constraintdef(con.oid) ilike '%scoring_mode_snapshot%'
  loop
    execute format('alter table assessment.form_items drop constraint %I', r.conname);
  end loop;
end $do$;

alter table assessment.form_items
  add constraint form_items_scoring_mode_snapshot_ck
  check (scoring_mode_snapshot in ('OPTION_KEY','EXACT_KEY','FINITE_KEYSET','BOOLEAN_KEY','MATCH_KEY','ORDER_KEY','ANALYTIC_RUBRIC'));

create table if not exists assessment.exam_models (
  id uuid primary key default gen_random_uuid(),
  control_bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  model_code text not null unique,
  model_name text not null,
  framework_code text not null,
  model_version text not null,
  model_status text not null check (model_status in ('AUTHORING','DRAFT_ASSEMBLY','QA','PILOT','ACTIVE','RETIRED')),
  total_weight_percent numeric(8,4) not null check (total_weight_percent=100),
  total_reported_score numeric(8,4) not null check (total_reported_score=100),
  source_status text not null,
  external_certification_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists assessment.exam_model_components (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references assessment.exam_models(id) on delete restrict,
  skill_code text not null check (skill_code in ('RDG','LST','WRT','SPK','LNG')),
  source_bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  display_order smallint not null check (display_order>0),
  weight_percent numeric(8,4) not null check (weight_percent>0 and weight_percent<=100),
  reported_max_score numeric(8,4) not null check (reported_max_score>0),
  aggregation_method text not null check (aggregation_method in ('NORMALIZE_RAW_TO_WEIGHT')),
  required_for_total boolean not null default true,
  source_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(model_id,skill_code),
  unique(model_id,display_order)
);

create table if not exists assessment.exam_model_level_blueprints (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references assessment.exam_models(id) on delete restrict,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  form_family_count smallint not null check (form_family_count=6),
  total_reported_score numeric(8,4) not null check (total_reported_score=100),
  assembly_method text not null,
  composition_status text not null,
  equivalence_status text not null,
  human_review_gate text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(model_id,cefr_level)
);

create table if not exists assessment.exam_model_section_requirements (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references assessment.exam_models(id) on delete restrict,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  skill_code text not null check (skill_code in ('RDG','LST','WRT','SPK','LNG')),
  source_bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  required_item_count integer not null check (required_item_count>0),
  expected_raw_max numeric(10,4) not null check (expected_raw_max>0),
  reported_max_score numeric(8,4) not null check (reported_max_score>0),
  assembly_rule text not null,
  source_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(model_id,cefr_level,skill_code)
);

create table if not exists assessment.exam_model_forms (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references assessment.exam_models(id) on delete restrict,
  form_id uuid not null references assessment.forms(id) on delete restrict,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  form_family text not null check (form_family in ('A','B','C','R1','R2','PILOT')),
  family_ordinal smallint not null check (family_ordinal between 1 and 6),
  composition_status text not null,
  equivalence_status text not null,
  assembly_method text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(model_id,form_id),
  unique(model_id,cefr_level,form_family),
  unique(model_id,cefr_level,family_ordinal)
);

create table if not exists assessment.exam_scoring_policies (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references assessment.exam_models(id) on delete restrict,
  scoring_version text not null,
  section_formula text not null,
  total_formula text not null,
  no_early_rounding boolean not null,
  final_rounding_scale smallint null check (final_rounding_scale is null or final_rounding_scale between 0 and 6),
  final_rounding_status text not null,
  missing_section_policy text not null,
  classification_status text not null,
  cut_score_status text not null,
  external_certification_status text not null,
  source_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(model_id,scoring_version)
);

create table if not exists assessment.exam_cut_score_policies (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references assessment.exam_models(id) on delete restrict,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  overall_cut_score numeric(8,4) null check (overall_cut_score is null or (overall_cut_score>=0 and overall_cut_score<=100)),
  section_minimums jsonb null,
  standard_setting_method text null,
  policy_status text not null,
  source_status text not null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(model_id,cefr_level)
);

create index if not exists idx_exam_model_components_model on assessment.exam_model_components(model_id,display_order);
create index if not exists idx_exam_model_sections_level on assessment.exam_model_section_requirements(model_id,cefr_level,skill_code);
create index if not exists idx_exam_model_forms_model on assessment.exam_model_forms(model_id,cefr_level,family_ordinal);

create or replace function assessment.phase10_normalize_section_score(
  p_raw_earned numeric,
  p_raw_available numeric,
  p_weight_percent numeric
) returns numeric
language plpgsql immutable
set search_path=''
as $fn$
begin
  if p_raw_available is null or p_raw_available <= 0 then
    raise exception 'raw_available must be > 0' using errcode='22023';
  end if;
  if p_raw_earned is null or p_raw_earned < 0 or p_raw_earned > p_raw_available then
    raise exception 'raw_earned must be between 0 and raw_available' using errcode='22023';
  end if;
  if p_weight_percent is null or p_weight_percent <= 0 or p_weight_percent > 100 then
    raise exception 'weight_percent must be between 0 and 100' using errcode='22023';
  end if;
  return (p_raw_earned / p_raw_available) * p_weight_percent;
end $fn$;

create or replace function assessment.phase10_score_from_raw(
  p_model_code text,
  p_sections jsonb
) returns jsonb
language plpgsql stable
set search_path=''
as $fn$
declare
  v_model_id uuid;
  v_total numeric := 0;
  v_result jsonb := '{}'::jsonb;
  r record;
  v_section jsonb;
  v_earned numeric;
  v_available numeric;
  v_weighted numeric;
begin
  select id into v_model_id from assessment.exam_models where model_code=p_model_code;
  if v_model_id is null then
    raise exception 'Unknown exam model %', p_model_code using errcode='22023';
  end if;

  for r in
    select skill_code,weight_percent,reported_max_score,required_for_total
    from assessment.exam_model_components
    where model_id=v_model_id
    order by display_order
  loop
    v_section := p_sections -> r.skill_code;
    if v_section is null then
      if r.required_for_total then
        raise exception 'Missing required section %', r.skill_code using errcode='22023';
      else
        continue;
      end if;
    end if;
    v_earned := nullif(v_section->>'earned','')::numeric;
    v_available := nullif(v_section->>'available','')::numeric;
    v_weighted := assessment.phase10_normalize_section_score(v_earned,v_available,r.weight_percent);
    v_total := v_total + v_weighted;
    v_result := v_result || jsonb_build_object(r.skill_code,jsonb_build_object(
      'raw_earned',v_earned,
      'raw_available',v_available,
      'weight_percent',r.weight_percent,
      'weighted_score',v_weighted
    ));
  end loop;

  return jsonb_build_object(
    'model_code',p_model_code,
    'sections',v_result,
    'total_score',v_total,
    'classification_status','PENDING_STANDARD_SETTING'
  );
end $fn$;
-- END CANONICAL MIGRATION 0073

-- BEGIN CANONICAL MIGRATION 0074 20260902192452 phase10_form_specific_scoring_profiles_hardening
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
-- END CANONICAL MIGRATION 0074

-- BEGIN CANONICAL MIGRATION 0075 20260902192615 phase10_score_form_profile_drift_gate
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
-- END CANONICAL MIGRATION 0075

-- BEGIN CANONICAL MIGRATION 0076 20260902193137 phase11_extend_item_scoring_validation_for_analytic
create or replace function assessment.item_version_scoring_valid(p_item_version_id uuid)
returns boolean
language plpgsql
stable
set search_path=''
as $function$
declare
  v_item_type text;
  v_mode text;
  v_objective boolean;
  v_human boolean;
  v_partial boolean;
  v_score numeric;
  v_option_count integer;
  v_correct_count integer;
  v_distinct_option_count integer;
  v_answer_count integer;
  v_key jsonb;
begin
  select iv.item_type_code, iv.scoring_mode, iv.objective_eligible,
         iv.human_judgment_required, iv.partial_credit_allowed, iv.max_raw_score
    into v_item_type, v_mode, v_objective, v_human, v_partial, v_score
  from assessment.item_versions iv
  where iv.id = p_item_version_id;

  if v_item_type is null or v_score is null or v_score <= 0 then return false; end if;

  if v_mode = 'ANALYTIC_RUBRIC' then
    if v_item_type not in ('ER-WRT','OR-SPK') then return false; end if;
    if v_objective or not v_human or not v_partial then return false; end if;
    if exists(select 1 from assessment.item_options io where io.item_version_id=p_item_version_id) then return false; end if;
    if exists(select 1 from assessment.accepted_answers aa where aa.item_version_id=p_item_version_id) then return false; end if;
    if exists(select 1 from assessment.item_scoring_keys sk where sk.item_version_id=p_item_version_id) then return false; end if;
    return true;
  end if;

  if not v_objective or v_human or v_partial or v_score <> 1 then return false; end if;

  if v_item_type = 'SR-MCQ' and v_mode <> 'OPTION_KEY' then return false; end if;
  if v_item_type = 'SR-TF' and v_mode not in ('BOOLEAN_KEY','OPTION_KEY') then return false; end if;
  if v_item_type = 'SR-MATCH' and v_mode <> 'MATCH_KEY' then return false; end if;
  if v_item_type = 'SR-SEQ' and v_mode <> 'ORDER_KEY' then return false; end if;
  if v_item_type in ('CR-GAP','CR-SA','CR-EDIT') and v_mode not in ('EXACT_KEY','FINITE_KEYSET') then return false; end if;

  if v_mode = 'OPTION_KEY' then
    select count(*),
           count(*) filter (where io.is_correct),
           count(distinct lower(regexp_replace(trim(io.option_text), '[[:space:]]+', ' ', 'g')))
      into v_option_count, v_correct_count, v_distinct_option_count
    from assessment.item_options io
    where io.item_version_id = p_item_version_id and io.status = 'ACTIVE';

    if v_option_count < 2 or v_correct_count <> 1 or v_distinct_option_count <> v_option_count then return false; end if;
  elsif v_mode in ('EXACT_KEY','FINITE_KEYSET') then
    select count(*) into v_answer_count
    from assessment.accepted_answers aa
    where aa.item_version_id = p_item_version_id and aa.status = 'ACTIVE';
    if v_answer_count < 1 then return false; end if;
  elsif v_mode in ('BOOLEAN_KEY','MATCH_KEY','ORDER_KEY') then
    select sk.key_payload into v_key
    from assessment.item_scoring_keys sk
    where sk.item_version_id = p_item_version_id;
    if v_key is null then return false; end if;
    if v_mode = 'BOOLEAN_KEY' and jsonb_typeof(v_key) <> 'boolean' then return false; end if;
    if v_mode in ('MATCH_KEY','ORDER_KEY') and (jsonb_typeof(v_key) not in ('array','object') or v_key in ('[]'::jsonb,'{}'::jsonb)) then return false; end if;
  else
    return false;
  end if;

  return true;
end $function$;

create or replace function assessment.assert_item_version_scoring_integrity(p_item_version_id uuid)
returns void
language plpgsql
stable
set search_path=''
as $function$
begin
  if not assessment.item_version_scoring_valid(p_item_version_id) then
    raise exception 'Item version % does not satisfy governed scoring integrity', p_item_version_id using errcode='23514';
  end if;
end $function$;
-- END CANONICAL MIGRATION 0076

-- BEGIN CANONICAL MIGRATION 0077 20260902193446 phase11_secure_new_assessment_objects
do $do$
declare r record;
begin
  for r in
    select n.nspname,c.relname
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('assessment','assessment_staging')
      and c.relkind in ('r','p')
      and not c.relrowsecurity
  loop
    execute format('alter table %I.%I enable row level security',r.nspname,r.relname);
  end loop;
end $do$;

revoke all privileges on all functions in schema assessment from public, anon, authenticated;
revoke all privileges on all functions in schema assessment_staging from public, anon, authenticated;

alter default privileges in schema assessment revoke execute on functions from public;
alter default privileges in schema assessment revoke execute on functions from anon;
alter default privileges in schema assessment revoke execute on functions from authenticated;
alter default privileges in schema assessment_staging revoke execute on functions from public;
alter default privileges in schema assessment_staging revoke execute on functions from anon;
alter default privileges in schema assessment_staging revoke execute on functions from authenticated;
-- END CANONICAL MIGRATION 0077

-- BEGIN CANONICAL MIGRATION 0078 20260902193715 phase11_integrated_validation_gate_v2
alter table assessment.deployment_gate_runs drop constraint deployment_gate_runs_gate_scope_check;
alter table assessment.deployment_gate_runs add constraint deployment_gate_runs_gate_scope_check
check (gate_scope in ('FOUNDATION_DEPLOYMENT','PHASE06_LAUNCH','PHASE11_INTEGRATED'));

alter table assessment.ref_deployment_gate_checks drop constraint ref_deployment_gate_checks_gate_scope_check;
alter table assessment.ref_deployment_gate_checks add constraint ref_deployment_gate_checks_gate_scope_check
check (gate_scope in ('FOUNDATION_DEPLOYMENT','PHASE06_LAUNCH','PHASE11_INTEGRATED'));

insert into assessment.ref_deployment_gate_checks(check_code,gate_scope,category,fail_severity,description,sort_order,is_active)
values
('P11I001','PHASE11_INTEGRATED','SECURITY','BLOCKER','Latest foundation security/deployment gate is GO.',2000,true),
('P11I002','PHASE11_INTEGRATED','FORMS','BLOCKER','All 36 integrated form scoring profiles are current and structurally valid.',2010,true),
('P11I003','PHASE11_INTEGRATED','CONFIGURATION','BLOCKER','Integrated form snapshots contain exactly 2,382 unique governed item versions with expected objective/analytic scoring modes.',2020,true),
('P11I004','PHASE11_INTEGRATED','SECURITY','BLOCKER','All integrated items are unexposed, uncompromised and remain in controlled draft QA state.',2030,true),
('P11I005','PHASE11_INTEGRATED','CONTENT','BLOCKER','Authoritative P06 Primary-LO capacity has zero deficits across six form equivalents.',2040,true),
('P11I006','PHASE11_INTEGRATED','SOURCE','BLOCKER','All governed P07 listening audio assets used by forms are READY with stored media and duration.',2050,true),
('P11I007','PHASE11_INTEGRATED','QA','BLOCKER','All integrated current item versions have completed human review and approval.',2060,true),
('P11I008','PHASE11_INTEGRATED','CONFIGURATION','MAJOR','All integrated current item versions have governed domain and construct metadata.',2070,true),
('P11I009','PHASE11_INTEGRATED','BALANCE','BLOCKER','All 36 integrated forms have validated parallel-form equivalence.',2080,true),
('P11I010','PHASE11_INTEGRATED','CONFIGURATION','BLOCKER','All six CEFR levels have governed cut scores and completed standard-setting status.',2090,true),
('P11I011','PHASE11_INTEGRATED','QA','BLOCKER','Each CEFR level has at least one closed pilot cohort with usable responses.',2100,true),
('P11I012','PHASE11_INTEGRATED','PSYCHOMETRIC','BLOCKER','Every objective item version in the integrated forms has an acceptable psychometric decision.',2110,true),
('P11I013','PHASE11_INTEGRATED','QA','BLOCKER','Writing and Speaking human-scoring governance policies and rater controls are present.',2120,true),
('P11I014','PHASE11_INTEGRATED','CONFIGURATION','BLOCKER','Integrated model retains internal-source and NOT_CLAIMED external certification governance.',2130,true)
on conflict (check_code) do update set
 gate_scope=excluded.gate_scope,category=excluded.category,fail_severity=excluded.fail_severity,
 description=excluded.description,sort_order=excluded.sort_order,is_active=true;

create or replace function assessment.run_phase11_integrated_gate()
returns uuid
language plpgsql
set search_path=''
as $function$
declare
  v_run uuid;
  v_bank uuid;
  v_model uuid;
  v_count integer;
  v_bad integer;
  v_total integer;
  v_obj integer;
  v_analytic integer;
  v_foundation_status text;
  r record;
begin
  select id into v_bank from assessment.assessment_banks where bank_code='ENG-GENERAL-P06';
  select id into v_model from assessment.exam_models where model_code='ENG-GENERAL-INTEGRATED-v1.0';
  if v_bank is null or v_model is null then raise exception 'Integrated model/control bank missing' using errcode='23503'; end if;

  insert into assessment.deployment_gate_runs(gate_scope,bank_id,status,report_version,notes)
  values('PHASE11_INTEGRATED',v_bank,'RUNNING','P11-INTEGRATED-v1.0','Integrated QA / Validation / Security readiness gate; NO_GO is expected until human review, media, equivalence, standard setting and pilot evidence are complete.')
  returning id into v_run;

  select status into v_foundation_status from assessment.deployment_gate_runs
  where gate_scope='FOUNDATION_DEPLOYMENT' and finished_at is not null order by finished_at desc limit 1;
  perform assessment.add_deployment_gate_result(v_run,'P11I001',coalesce(v_foundation_status,'')='GO',coalesce(v_foundation_status,'NONE'),'GO','Foundation security gate status.');

  v_bad:=0; v_count:=0;
  for r in select p.form_version_id from assessment.exam_form_scoring_profiles p where p.model_id=v_model loop
    v_count:=v_count+1;
    begin perform assessment.phase10_validate_form_scoring_profile(r.form_version_id); exception when others then v_bad:=v_bad+1; end;
  end loop;
  perform assessment.add_deployment_gate_result(v_run,'P11I002',v_count=36 and v_bad=0,format('profiles=%s; invalid=%s',v_count,v_bad),'profiles=36; invalid=0','Integrated form scoring-profile validation.');

  select count(*),count(distinct fi.item_version_id),
         count(*) filter(where fi.scoring_mode_snapshot='OPTION_KEY'),
         count(*) filter(where fi.scoring_mode_snapshot='ANALYTIC_RUBRIC')
    into v_total,v_count,v_obj,v_analytic
  from assessment.form_items fi
  join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id
  join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model;
  perform assessment.add_deployment_gate_result(v_run,'P11I003',v_total=2382 and v_count=2382 and v_obj=2202 and v_analytic=180,
    format('rows=%s; distinct=%s; objective=%s; analytic=%s',v_total,v_count,v_obj,v_analytic),'rows=2382; distinct=2382; objective=2202; analytic=180','Integrated item snapshot reconciliation.');

  select count(*) into v_bad
  from assessment.form_items fi
  join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id
  join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
  join assessment.item_versions iv on iv.id=fi.item_version_id
  join assessment.items i on i.id=iv.item_id
  where i.security_level<>'SEC-1' or i.exposure_status<>'UNUSED' or i.compromise_status or i.lifecycle_status<>'DRAFT_QA';
  perform assessment.add_deployment_gate_result(v_run,'P11I004',v_bad=0,v_bad::text,'0','Integrated items outside controlled draft security state.');

  select count(*) into v_bad
  from assessment.lo_capacity_requirements r
  join assessment.assessment_banks b on b.id=r.bank_id
  where r.bank_id=v_bank and (
    select count(distinct i.id)
    from assessment.items i
    join assessment.item_versions iv on iv.id=i.current_version_id
    join assessment.item_lo_mappings m on m.item_version_id=iv.id and m.lo_id=r.lo_id and m.mapping_role='PRIMARY' and m.mapping_status<>'REJECTED'
    where i.bank_id=r.bank_id and i.lifecycle_status not in ('RETIRED','COMPROMISED') and not i.compromise_status
  ) < r.required_per_form*b.launch_form_equivalents;
  perform assessment.add_deployment_gate_result(v_run,'P11I005',v_bad=0,v_bad::text,'0','P06 authoritative Primary-LO capacity deficits.');

  select count(*) into v_total from assessment.listening_stimulus_audio;
  select count(*) into v_count from assessment.listening_stimulus_audio
    where audio_status='READY' and storage_bucket is not null and storage_object_path is not null and duration_seconds is not null and duration_seconds>0;
  perform assessment.add_deployment_gate_result(v_run,'P11I006',v_total=374 and v_count=374,format('ready=%s; total=%s',v_count,v_total),'ready=374; total=374','P07 listening audio production readiness.');

  select count(distinct fi.item_version_id) into v_total
  from assessment.form_items fi join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model;
  select count(distinct iv.id) into v_count
  from assessment.form_items fi join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
  join assessment.item_versions iv on iv.id=fi.item_version_id
  where iv.review_status in ('PASS','PASS_WITH_EDIT') and iv.approval_status='APPROVED';
  perform assessment.add_deployment_gate_result(v_run,'P11I007',v_total=2382 and v_count=2382,format('approved_reviewed=%s; total=%s',v_count,v_total),'approved_reviewed=2382; total=2382','Integrated human-review and approval completion.');

  select count(distinct iv.id) into v_bad
  from assessment.form_items fi join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
  join assessment.item_versions iv on iv.id=fi.item_version_id where iv.domain_code is null or iv.construct_code is null;
  perform assessment.add_deployment_gate_result(v_run,'P11I008',v_bad=0,v_bad::text,'0','Integrated items missing domain and/or construct metadata.');

  select count(*) into v_count from assessment.exam_model_forms where model_id=v_model
    and equivalence_status not in ('NOT_YET_VALIDATED','PENDING','PENDING_HUMAN_REVIEW');
  perform assessment.add_deployment_gate_result(v_run,'P11I009',v_count=36,v_count::text,'36','Forms with validated equivalence status.');

  select count(*) into v_count from assessment.exam_cut_score_policies where model_id=v_model
    and overall_cut_score is not null and policy_status<>'PENDING_STANDARD_SETTING';
  perform assessment.add_deployment_gate_result(v_run,'P11I010',v_count=6,v_count::text,'6','CEFR levels with completed standard setting and cut score.');

  select count(distinct cefr_level) into v_count from assessment.pilot_cohorts where cohort_status='CLOSED' and usable_response_count>0;
  perform assessment.add_deployment_gate_result(v_run,'P11I011',v_count=6,v_count::text,'6','CEFR levels with closed usable pilot cohorts.');

  with objective_items as (
    select distinct fi.item_version_id from assessment.form_items fi
    join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
    join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
    where fi.scoring_mode_snapshot='OPTION_KEY'
  ), acceptable as (
    select distinct ps.item_version_id from assessment.psychometric_stats ps join objective_items oi on oi.item_version_id=ps.item_version_id
    where ps.psychometric_decision in ('KEEP','KEEP_MONITOR')
  ) select (select count(*) from objective_items),(select count(*) from acceptable) into v_total,v_count;
  perform assessment.add_deployment_gate_result(v_run,'P11I012',v_total=2202 and v_count=2202,format('acceptable=%s; objective=%s',v_count,v_total),'acceptable=2202; objective=2202','Objective item psychometric coverage.');

  select count(*) into v_count from assessment.writing_scoring_policy wsp join assessment.assessment_banks b on b.id=wsp.bank_id
    where b.bank_code='ENG-GENERAL-P08' and wsp.external_certification_status='NOT_CLAIMED';
  select count(*) into v_total from assessment.speaking_scoring_policy ssp join assessment.assessment_banks b on b.id=ssp.bank_id
    where b.bank_code='ENG-GENERAL-P09' and ssp.external_certification_status='NOT_CLAIMED';
  select count(*) into v_bad from assessment.writing_rater_policy wrp join assessment.assessment_banks b on b.id=wrp.bank_id where b.bank_code='ENG-GENERAL-P08' and wrp.is_active;
  select count(*) into v_obj from assessment.speaking_rater_policy srp join assessment.assessment_banks b on b.id=srp.bank_id where b.bank_code='ENG-GENERAL-P09' and srp.is_active;
  perform assessment.add_deployment_gate_result(v_run,'P11I013',v_count>=1 and v_total>=1 and v_bad>=1 and v_obj>=1,
    format('writing_policy=%s; speaking_policy=%s; writing_rater_rules=%s; speaking_rater_rules=%s',v_count,v_total,v_bad,v_obj),'all present','Writing/Speaking human-scoring governance presence.');

  select count(*) into v_count from assessment.exam_models where id=v_model and external_certification_status='NOT_CLAIMED' and source_status='AVIATION_MATRIX_INTERNAL_OPERATIONAL_BASELINE';
  perform assessment.add_deployment_gate_result(v_run,'P11I014',v_count=1,v_count::text,'1','Integrated model internal-governance / no external-certification claim.');

  perform assessment.finish_deployment_gate_run(v_run);
  return v_run;
exception when others then
  if v_run is not null then update assessment.deployment_gate_runs set status='ERROR',finished_at=now(),notes=coalesce(notes,'')||' ERROR: '||sqlerrm where id=v_run; end if;
  raise;
end $function$;

revoke all privileges on function assessment.run_phase11_integrated_gate() from public, anon, authenticated;
-- END CANONICAL MIGRATION 0078

-- BEGIN CANONICAL MIGRATION 0079 20260902193804 phase11_fix_integrated_gate_alias
create or replace function assessment.run_phase11_integrated_gate()
returns uuid
language plpgsql
set search_path=''
as $function$
declare
  v_run uuid;
  v_bank uuid;
  v_model uuid;
  v_count integer;
  v_bad integer;
  v_total integer;
  v_obj integer;
  v_analytic integer;
  v_foundation_status text;
  v_rec record;
begin
  select id into v_bank from assessment.assessment_banks where bank_code='ENG-GENERAL-P06';
  select id into v_model from assessment.exam_models where model_code='ENG-GENERAL-INTEGRATED-v1.0';
  if v_bank is null or v_model is null then raise exception 'Integrated model/control bank missing' using errcode='23503'; end if;

  insert into assessment.deployment_gate_runs(gate_scope,bank_id,status,report_version,notes)
  values('PHASE11_INTEGRATED',v_bank,'RUNNING','P11-INTEGRATED-v1.0','Integrated QA / Validation / Security readiness gate; NO_GO is expected until human review, media, equivalence, standard setting and pilot evidence are complete.')
  returning id into v_run;

  select status into v_foundation_status from assessment.deployment_gate_runs
  where gate_scope='FOUNDATION_DEPLOYMENT' and finished_at is not null order by finished_at desc limit 1;
  perform assessment.add_deployment_gate_result(v_run,'P11I001',coalesce(v_foundation_status,'')='GO',coalesce(v_foundation_status,'NONE'),'GO','Foundation security gate status.');

  v_bad:=0; v_count:=0;
  for v_rec in select p.form_version_id from assessment.exam_form_scoring_profiles p where p.model_id=v_model loop
    v_count:=v_count+1;
    begin perform assessment.phase10_validate_form_scoring_profile(v_rec.form_version_id); exception when others then v_bad:=v_bad+1; end;
  end loop;
  perform assessment.add_deployment_gate_result(v_run,'P11I002',v_count=36 and v_bad=0,format('profiles=%s; invalid=%s',v_count,v_bad),'profiles=36; invalid=0','Integrated form scoring-profile validation.');

  select count(*),count(distinct fi.item_version_id),
         count(*) filter(where fi.scoring_mode_snapshot='OPTION_KEY'),
         count(*) filter(where fi.scoring_mode_snapshot='ANALYTIC_RUBRIC')
    into v_total,v_count,v_obj,v_analytic
  from assessment.form_items fi
  join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id
  join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model;
  perform assessment.add_deployment_gate_result(v_run,'P11I003',v_total=2382 and v_count=2382 and v_obj=2202 and v_analytic=180,
    format('rows=%s; distinct=%s; objective=%s; analytic=%s',v_total,v_count,v_obj,v_analytic),'rows=2382; distinct=2382; objective=2202; analytic=180','Integrated item snapshot reconciliation.');

  select count(*) into v_bad
  from assessment.form_items fi
  join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id
  join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
  join assessment.item_versions iv on iv.id=fi.item_version_id
  join assessment.items i on i.id=iv.item_id
  where i.security_level<>'SEC-1' or i.exposure_status<>'UNUSED' or i.compromise_status or i.lifecycle_status<>'DRAFT_QA';
  perform assessment.add_deployment_gate_result(v_run,'P11I004',v_bad=0,v_bad::text,'0','Integrated items outside controlled draft security state.');

  select count(*) into v_bad
  from assessment.lo_capacity_requirements lcr
  join assessment.assessment_banks b on b.id=lcr.bank_id
  where lcr.bank_id=v_bank and (
    select count(distinct i.id)
    from assessment.items i
    join assessment.item_versions iv on iv.id=i.current_version_id
    join assessment.item_lo_mappings m on m.item_version_id=iv.id and m.lo_id=lcr.lo_id and m.mapping_role='PRIMARY' and m.mapping_status<>'REJECTED'
    where i.bank_id=lcr.bank_id and i.lifecycle_status not in ('RETIRED','COMPROMISED') and not i.compromise_status
  ) < lcr.required_per_form*b.launch_form_equivalents;
  perform assessment.add_deployment_gate_result(v_run,'P11I005',v_bad=0,v_bad::text,'0','P06 authoritative Primary-LO capacity deficits.');

  select count(*) into v_total from assessment.listening_stimulus_audio;
  select count(*) into v_count from assessment.listening_stimulus_audio
    where audio_status='READY' and storage_bucket is not null and storage_object_path is not null and duration_seconds is not null and duration_seconds>0;
  perform assessment.add_deployment_gate_result(v_run,'P11I006',v_total=374 and v_count=374,format('ready=%s; total=%s',v_count,v_total),'ready=374; total=374','P07 listening audio production readiness.');

  select count(distinct fi.item_version_id) into v_total
  from assessment.form_items fi join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model;
  select count(distinct iv.id) into v_count
  from assessment.form_items fi join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
  join assessment.item_versions iv on iv.id=fi.item_version_id
  where iv.review_status in ('PASS','PASS_WITH_EDIT') and iv.approval_status='APPROVED';
  perform assessment.add_deployment_gate_result(v_run,'P11I007',v_total=2382 and v_count=2382,format('approved_reviewed=%s; total=%s',v_count,v_total),'approved_reviewed=2382; total=2382','Integrated human-review and approval completion.');

  select count(distinct iv.id) into v_bad
  from assessment.form_items fi join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
  join assessment.item_versions iv on iv.id=fi.item_version_id where iv.domain_code is null or iv.construct_code is null;
  perform assessment.add_deployment_gate_result(v_run,'P11I008',v_bad=0,v_bad::text,'0','Integrated items missing domain and/or construct metadata.');

  select count(*) into v_count from assessment.exam_model_forms where model_id=v_model
    and equivalence_status not in ('NOT_YET_VALIDATED','PENDING','PENDING_HUMAN_REVIEW');
  perform assessment.add_deployment_gate_result(v_run,'P11I009',v_count=36,v_count::text,'36','Forms with validated equivalence status.');

  select count(*) into v_count from assessment.exam_cut_score_policies where model_id=v_model
    and overall_cut_score is not null and policy_status<>'PENDING_STANDARD_SETTING';
  perform assessment.add_deployment_gate_result(v_run,'P11I010',v_count=6,v_count::text,'6','CEFR levels with completed standard setting and cut score.');

  select count(distinct cefr_level) into v_count from assessment.pilot_cohorts where cohort_status='CLOSED' and usable_response_count>0;
  perform assessment.add_deployment_gate_result(v_run,'P11I011',v_count=6,v_count::text,'6','CEFR levels with closed usable pilot cohorts.');

  with objective_items as (
    select distinct fi.item_version_id from assessment.form_items fi
    join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
    join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
    where fi.scoring_mode_snapshot='OPTION_KEY'
  ), acceptable as (
    select distinct ps.item_version_id from assessment.psychometric_stats ps join objective_items oi on oi.item_version_id=ps.item_version_id
    where ps.psychometric_decision in ('KEEP','KEEP_MONITOR')
  ) select (select count(*) from objective_items),(select count(*) from acceptable) into v_total,v_count;
  perform assessment.add_deployment_gate_result(v_run,'P11I012',v_total=2202 and v_count=2202,format('acceptable=%s; objective=%s',v_count,v_total),'acceptable=2202; objective=2202','Objective item psychometric coverage.');

  select count(*) into v_count from assessment.writing_scoring_policy wsp join assessment.assessment_banks b on b.id=wsp.bank_id
    where b.bank_code='ENG-GENERAL-P08' and wsp.external_certification_status='NOT_CLAIMED';
  select count(*) into v_total from assessment.speaking_scoring_policy ssp join assessment.assessment_banks b on b.id=ssp.bank_id
    where b.bank_code='ENG-GENERAL-P09' and ssp.external_certification_status='NOT_CLAIMED';
  select count(*) into v_bad from assessment.writing_rater_policy wrp join assessment.assessment_banks b on b.id=wrp.bank_id where b.bank_code='ENG-GENERAL-P08' and wrp.is_active;
  select count(*) into v_obj from assessment.speaking_rater_policy srp join assessment.assessment_banks b on b.id=srp.bank_id where b.bank_code='ENG-GENERAL-P09' and srp.is_active;
  perform assessment.add_deployment_gate_result(v_run,'P11I013',v_count>=1 and v_total>=1 and v_bad>=1 and v_obj>=1,
    format('writing_policy=%s; speaking_policy=%s; writing_rater_rules=%s; speaking_rater_rules=%s',v_count,v_total,v_bad,v_obj),'all present','Writing/Speaking human-scoring governance presence.');

  select count(*) into v_count from assessment.exam_models where id=v_model and external_certification_status='NOT_CLAIMED' and source_status='AVIATION_MATRIX_INTERNAL_OPERATIONAL_BASELINE';
  perform assessment.add_deployment_gate_result(v_run,'P11I014',v_count=1,v_count::text,'1','Integrated model internal-governance / no external-certification claim.');

  perform assessment.finish_deployment_gate_run(v_run);
  return v_run;
exception when others then
  if v_run is not null then update assessment.deployment_gate_runs set status='ERROR',finished_at=now(),notes=coalesce(notes,'')||' ERROR: '||sqlerrm where id=v_run; end if;
  raise;
end $function$;

revoke all privileges on function assessment.run_phase11_integrated_gate() from public, anon, authenticated;
-- END CANONICAL MIGRATION 0079

-- BEGIN CANONICAL MIGRATION 0080 20260902213103 fix_phase06_form_assembly_preflight_alias
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
-- END CANONICAL MIGRATION 0080

-- BEGIN CANONICAL MIGRATION 0081 20260902213413 phase11_integrated_form_prevalidation_evidence
create table if not exists assessment.integrated_form_prevalidation_runs (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references assessment.exam_models(id),
  run_version text not null default 'P11-FORM-PREVALIDATION-v1.0',
  status text not null default 'RUNNING' check (status in ('RUNNING','PREVALIDATION_BLOCKED','REVIEW_REQUIRED','PREVALIDATION_PASS')),
  blocker_count integer not null default 0,
  major_count integer not null default 0,
  review_count integer not null default 0,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  notes text
);

create table if not exists assessment.integrated_form_prevalidation_findings (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references assessment.integrated_form_prevalidation_runs(id) on delete cascade,
  check_code text not null,
  severity text not null check (severity in ('BLOCKER','MAJOR','REVIEW','INFO')),
  cefr_level text,
  form_id uuid references assessment.forms(id),
  form_family text,
  skill_code text,
  dimension_code text not null,
  actual_value numeric,
  expected_value numeric,
  message text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists ix_integrated_form_prevalidation_findings_run on assessment.integrated_form_prevalidation_findings(run_id,severity,check_code);
create index if not exists ix_integrated_form_prevalidation_findings_form on assessment.integrated_form_prevalidation_findings(form_id,skill_code);

alter table assessment.integrated_form_prevalidation_runs enable row level security;
alter table assessment.integrated_form_prevalidation_findings enable row level security;
revoke all on assessment.integrated_form_prevalidation_runs from public, anon, authenticated;
revoke all on assessment.integrated_form_prevalidation_findings from public, anon, authenticated;

create or replace function assessment.run_phase11_form_prevalidation()
returns uuid
language plpgsql
set search_path to ''
as $function$
declare
  v_model_id uuid;
  v_run_id uuid;
  v_blockers integer;
  v_majors integer;
  v_reviews integer;
begin
  select id into v_model_id from assessment.exam_models where model_code='ENG-GENERAL-INTEGRATED-v1.0' limit 1;
  if v_model_id is null then raise exception 'Integrated exam model not found' using errcode='23503'; end if;

  insert into assessment.integrated_form_prevalidation_runs(model_id,status,notes)
  values(v_model_id,'RUNNING','Automated structural and balance pre-validation only. Does not establish psychometric or operational equivalence.')
  returning id into v_run_id;

  -- Scoring profile integrity: hard prerequisite.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,dimension_code,actual_value,expected_value,message,details)
  select v_run_id,'P11FP001',case when bad=0 and total=36 then 'INFO' else 'BLOCKER' end,'FORM_PROFILE',
         total-bad,36,'Integrated form scoring profiles valid.',jsonb_build_object('forms_total',total,'invalid_profiles',bad)
  from (
    select count(*)::integer total,
           count(*) filter(where coalesce((assessment.phase10_validate_form_scoring_profile(p.form_version_id)->>'passes')::boolean,false)=false)::integer bad
    from assessment.exam_form_scoring_profiles p where p.model_id=v_model_id
  ) x;

  -- Exact section counts/raw maxima across six families per level.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,skill_code,dimension_code,actual_value,expected_value,message,details)
  with s as (
    select emf.cefr_level,fi.section_code skill_code,emf.form_family,
           count(*)::numeric item_count,sum(fi.max_raw_score_snapshot)::numeric raw_max
    from assessment.exam_model_forms emf
    join assessment.forms f on f.id=emf.form_id
    join assessment.form_items fi on fi.form_version_id=f.current_version_id
    where emf.model_id=v_model_id
    group by 1,2,3
  ), g as (
    select cefr_level,skill_code,min(item_count) min_items,max(item_count) max_items,min(raw_max) min_raw,max(raw_max) max_raw
    from s group by 1,2
  )
  select v_run_id,'P11FP002',case when min_items=max_items and min_raw=max_raw then 'INFO' else 'BLOCKER' end,
         cefr_level,skill_code,'SECTION_PARITY',max_items-min_items,0,'Six-family section count/raw parity.',
         jsonb_build_object('min_items',min_items,'max_items',max_items,'min_raw',min_raw,'max_raw',max_raw)
  from g;

  -- P06 exact authoritative Primary-LO vector per form.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with req as (
    select lo.cefr_level,lo.skill_code,lcr.lo_id,lo.lo_code,lcr.required_per_form
    from assessment.lo_capacity_requirements lcr
    join assessment.learning_outcomes lo on lo.id=lcr.lo_id
    join assessment.assessment_banks b on b.id=lcr.bank_id and b.bank_code='ENG-GENERAL-P06'
    where lcr.source_status='AUTHORITATIVE_CONFIRMED' and lo.skill_code in ('RDG','LNG')
  ), forms as (
    select emf.cefr_level,emf.form_family,emf.form_id,f.current_version_id
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id
    where emf.model_id=v_model_id
  ), actual as (
    select fm.cefr_level,fm.form_id,fm.form_family,r.skill_code,r.lo_id,r.lo_code,r.required_per_form,
           count(fi.id)::integer actual_count
    from forms fm join req r on r.cefr_level=fm.cefr_level
    left join assessment.item_lo_mappings lm on lm.lo_id=r.lo_id and lm.mapping_role='PRIMARY'
    left join assessment.form_items fi on fi.form_version_id=fm.current_version_id and fi.item_version_id=lm.item_version_id and fi.section_code=r.skill_code
    group by 1,2,3,4,5,6,7
  )
  select v_run_id,'P11FP003','BLOCKER',cefr_level,form_id,form_family,skill_code,'PRIMARY_LO',actual_count,required_per_form,
         'P06 authoritative Primary-LO count does not match per-form requirement.',jsonb_build_object('lo_code',lo_code)
  from actual where actual_count<>required_per_form;

  -- Reading independent stimulus-family capacity across six forms.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,skill_code,dimension_code,actual_value,expected_value,message,details)
  with b as (select id from assessment.assessment_banks where bank_code='ENG-GENERAL-P06'),
  req as (
    select fbr.cefr_level,fbr.required_stimulus_families_per_form,ab.launch_form_equivalents
    from assessment.form_blueprint_requirements fbr join assessment.assessment_banks ab on ab.id=fbr.bank_id
    where fbr.bank_id=(select id from b) and fbr.skill_code='RDG'
  ), avail as (
    select i.cefr_level,count(distinct sv.stimulus_id)::integer available
    from assessment.items i join assessment.item_versions iv on iv.id=i.current_version_id
    join assessment.stimulus_versions sv on sv.id=iv.stimulus_version_id
    where i.bank_id=(select id from b) and i.skill_code='RDG'
    group by i.cefr_level
  )
  select v_run_id,'P11FP004',case when a.available>=r.required_stimulus_families_per_form*r.launch_form_equivalents then 'INFO' else 'BLOCKER' end,
         r.cefr_level,'RDG','STIMULUS_FAMILY_CAPACITY',a.available,
         r.required_stimulus_families_per_form*r.launch_form_equivalents,
         'Independent Reading stimulus-family capacity for zero-overlap six-form partition.',
         jsonb_build_object('required_per_form',r.required_stimulus_families_per_form,'form_equivalents',r.launch_form_equivalents)
  from req r join avail a using(cefr_level);

  -- Current cross-form Reading stimulus overlap.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,skill_code,dimension_code,actual_value,expected_value,message,details)
  with x as (
    select emf.cefr_level,sv.stimulus_id,count(distinct emf.form_id)::integer form_count
    from assessment.exam_model_forms emf
    join assessment.forms f on f.id=emf.form_id
    join assessment.form_items fi on fi.form_version_id=f.current_version_id and fi.section_code='RDG'
    join assessment.item_versions iv on iv.id=fi.item_version_id
    join assessment.stimulus_versions sv on sv.id=iv.stimulus_version_id
    where emf.model_id=v_model_id
    group by 1,2 having count(distinct emf.form_id)>1
  )
  select v_run_id,'P11FP005','BLOCKER',cefr_level,'RDG','CROSS_FORM_STIMULUS_OVERLAP',count(*)::numeric,0,
         'Reading stimulus identities currently appear in more than one parallel form.',
         jsonb_build_object('max_forms_for_one_stimulus',max(form_count))
  from x group by cefr_level;

  -- P06 difficulty: existing frozen aggregate targets converted to per-form floor/ceiling; soft review only.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with b as (select id,launch_form_equivalents fe from assessment.assessment_banks where bank_code='ENG-GENERAL-P06'),
  forms as (
    select emf.cefr_level,emf.form_family,emf.form_id,f.current_version_id
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id where emf.model_id=v_model_id
  ), t as (
    select d.cefr_level,d.skill_code,d.difficulty_band,d.target_count,(select fe from b) fe
    from assessment.difficulty_distribution_targets d where d.bank_id=(select id from b) and d.skill_code in ('RDG','LNG')
  ), a as (
    select fm.cefr_level,fm.form_id,fm.form_family,t.skill_code,t.difficulty_band,t.target_count,t.fe,count(fi.id)::integer actual_count
    from forms fm join t on t.cefr_level=fm.cefr_level
    left join assessment.form_items fi on fi.form_version_id=fm.current_version_id and fi.section_code=t.skill_code
    left join assessment.item_versions iv on iv.id=fi.item_version_id and iv.author_difficulty=t.difficulty_band
    where fi.id is null or iv.id is not null
    group by 1,2,3,4,5,6,7
  )
  select v_run_id,'P11FP006','REVIEW',cefr_level,form_id,form_family,skill_code,'DIFFICULTY',actual_count,target_count::numeric/fe,
         'P06 difficulty count is outside derived per-form floor/ceiling; soft balance review.',
         jsonb_build_object('difficulty_band',difficulty_band,'derived_floor',floor(target_count::numeric/fe),'derived_ceiling',ceil(target_count::numeric/fe),'aggregate_target_count',target_count)
  from a where actual_count not between floor(target_count::numeric/fe) and ceil(target_count::numeric/fe);

  -- P06 frozen domain concentration thresholds, RDG/LNG only.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with x as (
    select emf.cefr_level,emf.form_id,emf.form_family,fi.section_code skill_code,iv.domain_code,count(*)::numeric n,
           count(*)::numeric/sum(count(*)) over(partition by emf.form_id,fi.section_code) share
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id
    join assessment.form_items fi on fi.form_version_id=f.current_version_id and fi.section_code in ('RDG','LNG')
    join assessment.item_versions iv on iv.id=fi.item_version_id
    where emf.model_id=v_model_id
    group by 1,2,3,4,5
  )
  select v_run_id,'P11FP007',case when share>0.35 then 'MAJOR' else 'REVIEW' end,cefr_level,form_id,form_family,skill_code,'DOMAIN_CONCENTRATION',share,0.25,
         'P06 RDG/LNG domain concentration exceeds frozen review threshold.',
         jsonb_build_object('domain_code',domain_code,'review_share',0.25,'major_share',0.35,'count',n)
  from x where share>0.25;

  -- Reading unique-stimulus word-load tolerance +/-10%; soft review only.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with forms as (
    select emf.cefr_level,emf.form_id,emf.form_family,f.current_version_id
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id where emf.model_id=v_model_id
  ), load as (
    select fm.cefr_level,fm.form_id,fm.form_family,coalesce(sum(x.word_count),0)::numeric word_load
    from forms fm left join lateral (
      select distinct sv.id,sv.word_count
      from assessment.form_items fi join assessment.item_versions iv on iv.id=fi.item_version_id
      join assessment.stimulus_versions sv on sv.id=iv.stimulus_version_id
      where fi.form_version_id=fm.current_version_id and fi.section_code='RDG'
    ) x on true group by 1,2,3
  ), stats as (select cefr_level,avg(word_load)::numeric mean_load from load group by cefr_level)
  select v_run_id,'P11FP008','REVIEW',l.cefr_level,l.form_id,l.form_family,'RDG','READING_WORD_LOAD',l.word_load,s.mean_load,
         'Reading unique-stimulus word load is outside +/-10% of level mean.',
         jsonb_build_object('relative_deviation',(l.word_load-s.mean_load)/nullif(s.mean_load,0),'tolerance_pct',0.10)
  from load l join stats s using(cefr_level)
  where s.mean_load<>0 and abs((l.word_load-s.mean_load)/s.mean_load)>0.10;

  select count(*) filter(where severity='BLOCKER'),count(*) filter(where severity='MAJOR'),count(*) filter(where severity='REVIEW')
    into v_blockers,v_majors,v_reviews
  from assessment.integrated_form_prevalidation_findings where run_id=v_run_id;

  update assessment.integrated_form_prevalidation_runs
  set blocker_count=v_blockers,major_count=v_majors,review_count=v_reviews,
      status=case when v_blockers>0 then 'PREVALIDATION_BLOCKED' when v_majors>0 or v_reviews>0 then 'REVIEW_REQUIRED' else 'PREVALIDATION_PASS' end,
      finished_at=now()
  where id=v_run_id;

  return v_run_id;
end
$function$;

revoke execute on function assessment.run_phase11_form_prevalidation() from public, anon, authenticated;
-- END CANONICAL MIGRATION 0081

-- BEGIN CANONICAL MIGRATION 0082 20260902213554 fix_phase11_prevalidation_difficulty_aggregation
create or replace function assessment.run_phase11_form_prevalidation()
returns uuid
language plpgsql
set search_path to ''
as $function$
declare
  v_model_id uuid;
  v_run_id uuid;
  v_blockers integer;
  v_majors integer;
  v_reviews integer;
begin
  select id into v_model_id from assessment.exam_models where model_code='ENG-GENERAL-INTEGRATED-v1.0' limit 1;
  if v_model_id is null then raise exception 'Integrated exam model not found' using errcode='23503'; end if;

  insert into assessment.integrated_form_prevalidation_runs(model_id,run_version,status,notes)
  values(v_model_id,'P11-FORM-PREVALIDATION-v1.1','RUNNING','Automated structural and balance pre-validation only. Does not establish psychometric or operational equivalence.')
  returning id into v_run_id;

  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,dimension_code,actual_value,expected_value,message,details)
  select v_run_id,'P11FP001',case when bad=0 and total=36 then 'INFO' else 'BLOCKER' end,'FORM_PROFILE',
         total-bad,36,'Integrated form scoring profiles valid.',jsonb_build_object('forms_total',total,'invalid_profiles',bad)
  from (
    select count(*)::integer total,
           count(*) filter(where coalesce((assessment.phase10_validate_form_scoring_profile(p.form_version_id)->>'passes')::boolean,false)=false)::integer bad
    from assessment.exam_form_scoring_profiles p where p.model_id=v_model_id
  ) x;

  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,skill_code,dimension_code,actual_value,expected_value,message,details)
  with s as (
    select emf.cefr_level,fi.section_code skill_code,emf.form_family,
           count(*)::numeric item_count,sum(fi.max_raw_score_snapshot)::numeric raw_max
    from assessment.exam_model_forms emf
    join assessment.forms f on f.id=emf.form_id
    join assessment.form_items fi on fi.form_version_id=f.current_version_id
    where emf.model_id=v_model_id
    group by 1,2,3
  ), g as (
    select cefr_level,skill_code,min(item_count) min_items,max(item_count) max_items,min(raw_max) min_raw,max(raw_max) max_raw
    from s group by 1,2
  )
  select v_run_id,'P11FP002',case when min_items=max_items and min_raw=max_raw then 'INFO' else 'BLOCKER' end,
         cefr_level,skill_code,'SECTION_PARITY',max_items-min_items,0,'Six-family section count/raw parity.',
         jsonb_build_object('min_items',min_items,'max_items',max_items,'min_raw',min_raw,'max_raw',max_raw)
  from g;

  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with req as (
    select lo.cefr_level,lo.skill_code,lcr.lo_id,lo.lo_code,lcr.required_per_form
    from assessment.lo_capacity_requirements lcr
    join assessment.learning_outcomes lo on lo.id=lcr.lo_id
    join assessment.assessment_banks b on b.id=lcr.bank_id and b.bank_code='ENG-GENERAL-P06'
    where lcr.source_status='AUTHORITATIVE_CONFIRMED' and lo.skill_code in ('RDG','LNG')
  ), forms as (
    select emf.cefr_level,emf.form_family,emf.form_id,f.current_version_id
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id
    where emf.model_id=v_model_id
  ), actual as (
    select fm.cefr_level,fm.form_id,fm.form_family,r.skill_code,r.lo_id,r.lo_code,r.required_per_form,
           count(fi.id)::integer actual_count
    from forms fm join req r on r.cefr_level=fm.cefr_level
    left join assessment.item_lo_mappings lm on lm.lo_id=r.lo_id and lm.mapping_role='PRIMARY'
    left join assessment.form_items fi on fi.form_version_id=fm.current_version_id and fi.item_version_id=lm.item_version_id and fi.section_code=r.skill_code
    group by 1,2,3,4,5,6,7
  )
  select v_run_id,'P11FP003','BLOCKER',cefr_level,form_id,form_family,skill_code,'PRIMARY_LO',actual_count,required_per_form,
         'P06 authoritative Primary-LO count does not match per-form requirement.',jsonb_build_object('lo_code',lo_code)
  from actual where actual_count<>required_per_form;

  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,skill_code,dimension_code,actual_value,expected_value,message,details)
  with b as (select id from assessment.assessment_banks where bank_code='ENG-GENERAL-P06'),
  req as (
    select fbr.cefr_level,fbr.required_stimulus_families_per_form,ab.launch_form_equivalents
    from assessment.form_blueprint_requirements fbr join assessment.assessment_banks ab on ab.id=fbr.bank_id
    where fbr.bank_id=(select id from b) and fbr.skill_code='RDG'
  ), avail as (
    select i.cefr_level,count(distinct sv.stimulus_id)::integer available
    from assessment.items i join assessment.item_versions iv on iv.id=i.current_version_id
    join assessment.stimulus_versions sv on sv.id=iv.stimulus_version_id
    where i.bank_id=(select id from b) and i.skill_code='RDG'
    group by i.cefr_level
  )
  select v_run_id,'P11FP004',case when a.available>=r.required_stimulus_families_per_form*r.launch_form_equivalents then 'INFO' else 'BLOCKER' end,
         r.cefr_level,'RDG','STIMULUS_FAMILY_CAPACITY',a.available,
         r.required_stimulus_families_per_form*r.launch_form_equivalents,
         'Independent Reading stimulus-family capacity for zero-overlap six-form partition.',
         jsonb_build_object('required_per_form',r.required_stimulus_families_per_form,'form_equivalents',r.launch_form_equivalents)
  from req r join avail a using(cefr_level);

  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,skill_code,dimension_code,actual_value,expected_value,message,details)
  with x as (
    select emf.cefr_level,sv.stimulus_id,count(distinct emf.form_id)::integer form_count
    from assessment.exam_model_forms emf
    join assessment.forms f on f.id=emf.form_id
    join assessment.form_items fi on fi.form_version_id=f.current_version_id and fi.section_code='RDG'
    join assessment.item_versions iv on iv.id=fi.item_version_id
    join assessment.stimulus_versions sv on sv.id=iv.stimulus_version_id
    where emf.model_id=v_model_id
    group by 1,2 having count(distinct emf.form_id)>1
  )
  select v_run_id,'P11FP005','BLOCKER',cefr_level,'RDG','CROSS_FORM_STIMULUS_OVERLAP',count(*)::numeric,0,
         'Reading stimulus identities currently appear in more than one parallel form.',
         jsonb_build_object('max_forms_for_one_stimulus',max(form_count))
  from x group by cefr_level;

  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with b as (select id,launch_form_equivalents fe from assessment.assessment_banks where bank_code='ENG-GENERAL-P06'),
  forms as (
    select emf.cefr_level,emf.form_family,emf.form_id,f.current_version_id
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id where emf.model_id=v_model_id
  ), t as (
    select d.cefr_level,d.skill_code,d.difficulty_band,d.target_count,(select fe from b) fe
    from assessment.difficulty_distribution_targets d where d.bank_id=(select id from b) and d.skill_code in ('RDG','LNG')
  ), a as (
    select fm.cefr_level,fm.form_id,fm.form_family,t.skill_code,t.difficulty_band,t.target_count,t.fe,
           count(*) filter(where iv.author_difficulty=t.difficulty_band)::integer actual_count
    from forms fm join t on t.cefr_level=fm.cefr_level
    left join assessment.form_items fi on fi.form_version_id=fm.current_version_id and fi.section_code=t.skill_code
    left join assessment.item_versions iv on iv.id=fi.item_version_id
    group by 1,2,3,4,5,6,7
  )
  select v_run_id,'P11FP006','REVIEW',cefr_level,form_id,form_family,skill_code,'DIFFICULTY',actual_count,target_count::numeric/fe,
         'P06 difficulty count is outside derived per-form floor/ceiling; soft balance review.',
         jsonb_build_object('difficulty_band',difficulty_band,'derived_floor',floor(target_count::numeric/fe),'derived_ceiling',ceil(target_count::numeric/fe),'aggregate_target_count',target_count)
  from a where actual_count not between floor(target_count::numeric/fe) and ceil(target_count::numeric/fe);

  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with x as (
    select emf.cefr_level,emf.form_id,emf.form_family,fi.section_code skill_code,iv.domain_code,count(*)::numeric n,
           count(*)::numeric/sum(count(*)) over(partition by emf.form_id,fi.section_code) share
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id
    join assessment.form_items fi on fi.form_version_id=f.current_version_id and fi.section_code in ('RDG','LNG')
    join assessment.item_versions iv on iv.id=fi.item_version_id
    where emf.model_id=v_model_id
    group by 1,2,3,4,5
  )
  select v_run_id,'P11FP007',case when share>0.35 then 'MAJOR' else 'REVIEW' end,cefr_level,form_id,form_family,skill_code,'DOMAIN_CONCENTRATION',share,0.25,
         'P06 RDG/LNG domain concentration exceeds frozen review threshold.',
         jsonb_build_object('domain_code',domain_code,'review_share',0.25,'major_share',0.35,'count',n)
  from x where share>0.25;

  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with forms as (
    select emf.cefr_level,emf.form_id,emf.form_family,f.current_version_id
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id where emf.model_id=v_model_id
  ), load as (
    select fm.cefr_level,fm.form_id,fm.form_family,coalesce(sum(x.word_count),0)::numeric word_load
    from forms fm left join lateral (
      select distinct sv.id,sv.word_count
      from assessment.form_items fi join assessment.item_versions iv on iv.id=fi.item_version_id
      join assessment.stimulus_versions sv on sv.id=iv.stimulus_version_id
      where fi.form_version_id=fm.current_version_id and fi.section_code='RDG'
    ) x on true group by 1,2,3
  ), stats as (select cefr_level,avg(word_load)::numeric mean_load from load group by cefr_level)
  select v_run_id,'P11FP008','REVIEW',l.cefr_level,l.form_id,l.form_family,'RDG','READING_WORD_LOAD',l.word_load,s.mean_load,
         'Reading unique-stimulus word load is outside +/-10% of level mean.',
         jsonb_build_object('relative_deviation',(l.word_load-s.mean_load)/nullif(s.mean_load,0),'tolerance_pct',0.10)
  from load l join stats s using(cefr_level)
  where s.mean_load<>0 and abs((l.word_load-s.mean_load)/s.mean_load)>0.10;

  select count(*) filter(where severity='BLOCKER'),count(*) filter(where severity='MAJOR'),count(*) filter(where severity='REVIEW')
    into v_blockers,v_majors,v_reviews
  from assessment.integrated_form_prevalidation_findings where run_id=v_run_id;

  update assessment.integrated_form_prevalidation_runs
  set blocker_count=v_blockers,major_count=v_majors,review_count=v_reviews,
      status=case when v_blockers>0 then 'PREVALIDATION_BLOCKED' when v_majors>0 or v_reviews>0 then 'REVIEW_REQUIRED' else 'PREVALIDATION_PASS' end,
      finished_at=now()
  where id=v_run_id;

  return v_run_id;
end
$function$;

revoke execute on function assessment.run_phase11_form_prevalidation() from public, anon, authenticated;
-- END CANONICAL MIGRATION 0082

