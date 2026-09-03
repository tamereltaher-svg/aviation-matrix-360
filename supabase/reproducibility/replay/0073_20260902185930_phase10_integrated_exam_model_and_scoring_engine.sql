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
