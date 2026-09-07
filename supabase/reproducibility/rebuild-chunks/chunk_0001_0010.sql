-- BEGIN CANONICAL MIGRATION 0001 20260821003413 create_aviation_interest_leads
create table if not exists public.aviation_interest_leads (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  mobile text not null,
  email text not null,
  date_of_birth date not null,
  education_stage text not null check (education_stage in ('school','secondary','university','graduate','other')),
  current_city text not null,
  aviation_interest text not null check (aviation_interest in ('cabin_crew','passenger_services','cargo','ground_operations','flight_ops','not_sure')),
  preferred_language text not null check (preferred_language in ('ar','en','ar_en')),
  consent boolean not null default false check (consent = true),
  source text not null default 'landing_pilot',
  status text not null default 'new' check (status in ('new','contacted','screening','qualified','closed')),
  created_at timestamptz not null default now()
);

alter table public.aviation_interest_leads enable row level security;

revoke all on table public.aviation_interest_leads from anon, authenticated;
grant insert on table public.aviation_interest_leads to anon, authenticated;

create policy "public_can_submit_aviation_interest"
on public.aviation_interest_leads
for insert
to anon, authenticated
with check (consent = true and source = 'landing_pilot');

create index if not exists aviation_interest_leads_created_at_idx
on public.aviation_interest_leads (created_at desc);

create index if not exists aviation_interest_leads_status_idx
on public.aviation_interest_leads (status);
-- END CANONICAL MIGRATION 0001

-- BEGIN CANONICAL MIGRATION 0002 20260821005702 add_candidate_onboarding_pilot
create table if not exists public.candidate_profiles (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid unique references public.aviation_interest_leads(id) on delete set null,
  full_name text not null,
  mobile text,
  email text,
  date_of_birth date,
  education_stage text,
  current_city text,
  aviation_interest text,
  preferred_language text,
  profile_status text not null default 'started' check (profile_status in ('started','confirmed','assessment_in_progress','assessment_completed','journey_ready')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.initial_assessment_attempts (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  status text not null default 'in_progress' check (status in ('in_progress','completed')),
  communication numeric(5,2),
  customer_service numeric(5,2),
  teamwork numeric(5,2),
  attention_to_detail numeric(5,2),
  digital_readiness numeric(5,2),
  professional_judgment numeric(5,2),
  english_readiness numeric(5,2),
  current_fit numeric(5,2),
  future_fit numeric(5,2),
  suggested_path text,
  development_gaps jsonb not null default '[]'::jsonb,
  result_payload jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.initial_assessment_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.initial_assessment_attempts(id) on delete cascade,
  question_code text not null,
  selected_option_code text not null,
  dimension_scores jsonb not null default '{}'::jsonb,
  response_time_seconds integer,
  created_at timestamptz not null default now(),
  unique(attempt_id, question_code)
);

alter table public.candidate_profiles enable row level security;
alter table public.initial_assessment_attempts enable row level security;
alter table public.initial_assessment_answers enable row level security;

revoke all on public.candidate_profiles from anon, authenticated;
revoke all on public.initial_assessment_attempts from anon, authenticated;
revoke all on public.initial_assessment_answers from anon, authenticated;

create index if not exists candidate_profiles_lead_id_idx on public.candidate_profiles(lead_id);
create index if not exists initial_assessment_attempts_candidate_id_idx on public.initial_assessment_attempts(candidate_id);
create index if not exists initial_assessment_answers_attempt_id_idx on public.initial_assessment_answers(attempt_id);
-- END CANONICAL MIGRATION 0002

-- BEGIN CANONICAL MIGRATION 0003 20260821233139 create_generic_assessment_architecture
create extension if not exists pgcrypto;

create table if not exists public.career_tracks (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.assessment_frameworks (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  purpose text not null,
  scope text not null default 'career_fit',
  status text not null default 'draft' check (status in ('draft','review','published','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.assessment_versions (
  id uuid primary key default gen_random_uuid(),
  framework_id uuid not null references public.assessment_frameworks(id) on delete cascade,
  version_no integer not null,
  version_label text not null,
  status text not null default 'draft' check (status in ('draft','review','published','retired')),
  effective_from timestamptz,
  effective_to timestamptz,
  methodology_notes text,
  created_at timestamptz not null default now(),
  unique(framework_id, version_no)
);

create table if not exists public.assessment_dimensions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text not null,
  dimension_type text not null default 'competency' check (dimension_type in ('competency','readiness','behavior','knowledge','eligibility')),
  is_critical boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.career_dimension_weights (
  id uuid primary key default gen_random_uuid(),
  assessment_version_id uuid not null references public.assessment_versions(id) on delete cascade,
  career_track_id uuid not null references public.career_tracks(id) on delete cascade,
  dimension_id uuid not null references public.assessment_dimensions(id) on delete cascade,
  weight numeric(6,3) not null check (weight >= 0 and weight <= 1),
  minimum_score numeric(5,2) check (minimum_score is null or (minimum_score >= 0 and minimum_score <= 100)),
  is_hard_gate boolean not null default false,
  rationale text,
  created_at timestamptz not null default now(),
  unique(assessment_version_id, career_track_id, dimension_id)
);

create table if not exists public.assessment_reference_sources (
  id uuid primary key default gen_random_uuid(),
  source_type text not null check (source_type in ('regulatory','official_guidance','industry','research','internal_methodology')),
  authority text not null,
  document_code text,
  title text not null,
  section_ref text,
  version_or_edition text,
  effective_date date,
  source_url text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.dimension_references (
  id uuid primary key default gen_random_uuid(),
  dimension_id uuid not null references public.assessment_dimensions(id) on delete cascade,
  reference_source_id uuid not null references public.assessment_reference_sources(id) on delete cascade,
  relevance_note text not null,
  created_at timestamptz not null default now(),
  unique(dimension_id, reference_source_id)
);

create table if not exists public.question_bank (
  id uuid primary key default gen_random_uuid(),
  assessment_version_id uuid not null references public.assessment_versions(id) on delete cascade,
  code text not null,
  question_type text not null default 'situational_judgment' check (question_type in ('situational_judgment','scenario','prioritization','consistency','knowledge','self_report')),
  prompt text not null,
  scenario_context text,
  difficulty integer not null default 1 check (difficulty between 1 and 5),
  criticality text not null default 'normal' check (criticality in ('normal','important','critical')),
  explanation_policy text not null default 'show_dimension_not_answer' check (explanation_policy in ('show_dimension_not_answer','show_full_rationale','hidden_until_review')),
  status text not null default 'draft' check (status in ('draft','review','published','retired')),
  randomization_group text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(assessment_version_id, code)
);

create table if not exists public.question_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.question_bank(id) on delete cascade,
  option_code text not null,
  option_text text not null,
  sequence_no integer not null,
  scoring_rationale text not null,
  candidate_feedback text,
  created_at timestamptz not null default now(),
  unique(question_id, option_code),
  unique(question_id, sequence_no)
);

create table if not exists public.question_dimension_scores (
  id uuid primary key default gen_random_uuid(),
  option_id uuid not null references public.question_options(id) on delete cascade,
  dimension_id uuid not null references public.assessment_dimensions(id) on delete cascade,
  score numeric(5,2) not null check (score >= 0 and score <= 100),
  evidence_note text,
  created_at timestamptz not null default now(),
  unique(option_id, dimension_id)
);

create table if not exists public.assessment_attempts (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid references public.candidate_profiles(id) on delete set null,
  assessment_version_id uuid not null references public.assessment_versions(id),
  target_career_track_id uuid references public.career_tracks(id),
  status text not null default 'in_progress' check (status in ('in_progress','completed','abandoned','invalidated')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  overall_score numeric(5,2),
  result_payload jsonb not null default '{}'::jsonb
);

create table if not exists public.assessment_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.assessment_attempts(id) on delete cascade,
  question_id uuid not null references public.question_bank(id),
  option_id uuid not null references public.question_options(id),
  response_time_seconds integer,
  answered_at timestamptz not null default now(),
  unique(attempt_id, question_id)
);

create table if not exists public.career_fit_results (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.assessment_attempts(id) on delete cascade,
  career_track_id uuid not null references public.career_tracks(id),
  current_fit numeric(5,2) not null check (current_fit between 0 and 100),
  future_fit numeric(5,2) check (future_fit is null or future_fit between 0 and 100),
  rank_no integer,
  readiness_status text check (readiness_status in ('ready_now','ready_with_development','development_required','alternative_path','future_eligible')),
  explanation_summary text,
  evidence_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(attempt_id, career_track_id)
);

create table if not exists public.development_gaps (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.assessment_attempts(id) on delete cascade,
  career_track_id uuid references public.career_tracks(id),
  dimension_id uuid not null references public.assessment_dimensions(id),
  observed_score numeric(5,2) not null,
  target_score numeric(5,2) not null,
  gap_severity text not null check (gap_severity in ('low','medium','high','critical')),
  development_recommendation text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.preparatory_paths (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.career_preparatory_rules (
  id uuid primary key default gen_random_uuid(),
  career_track_id uuid not null references public.career_tracks(id) on delete cascade,
  dimension_id uuid not null references public.assessment_dimensions(id) on delete cascade,
  threshold_below numeric(5,2) not null check (threshold_below between 0 and 100),
  preparatory_path_id uuid not null references public.preparatory_paths(id),
  rationale text not null,
  is_active boolean not null default true,
  unique(career_track_id, dimension_id, preparatory_path_id)
);

alter table public.career_tracks enable row level security;
alter table public.assessment_frameworks enable row level security;
alter table public.assessment_versions enable row level security;
alter table public.assessment_dimensions enable row level security;
alter table public.career_dimension_weights enable row level security;
alter table public.assessment_reference_sources enable row level security;
alter table public.dimension_references enable row level security;
alter table public.question_bank enable row level security;
alter table public.question_options enable row level security;
alter table public.question_dimension_scores enable row level security;
alter table public.assessment_attempts enable row level security;
alter table public.assessment_answers enable row level security;
alter table public.career_fit_results enable row level security;
alter table public.development_gaps enable row level security;
alter table public.preparatory_paths enable row level security;
alter table public.career_preparatory_rules enable row level security;

create policy "public_read_active_career_tracks" on public.career_tracks for select to anon, authenticated using (is_active = true);
create policy "public_read_active_dimensions" on public.assessment_dimensions for select to anon, authenticated using (is_active = true);
create policy "public_read_published_frameworks" on public.assessment_frameworks for select to anon, authenticated using (status = 'published');
create policy "public_read_published_versions" on public.assessment_versions for select to anon, authenticated using (status = 'published');
create policy "public_read_published_questions" on public.question_bank for select to anon, authenticated using (status = 'published');
create policy "public_read_question_options" on public.question_options for select to anon, authenticated using (exists (select 1 from public.question_bank q where q.id = question_id and q.status = 'published'));
create policy "public_read_question_scores" on public.question_dimension_scores for select to anon, authenticated using (exists (select 1 from public.question_options qo join public.question_bank q on q.id = qo.question_id where qo.id = option_id and q.status = 'published'));
-- END CANONICAL MIGRATION 0003

-- BEGIN CANONICAL MIGRATION 0004 20260821233752 extend_assessment_question_traceability
create table if not exists public.question_career_tracks (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.question_bank(id) on delete cascade,
  career_track_id uuid not null references public.career_tracks(id) on delete cascade,
  relevance_weight numeric not null default 1 check (relevance_weight >= 0 and relevance_weight <= 1),
  rationale text,
  created_at timestamptz not null default now(),
  unique(question_id, career_track_id)
);

create table if not exists public.question_references (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.question_bank(id) on delete cascade,
  reference_source_id uuid not null references public.assessment_reference_sources(id) on delete cascade,
  relevance_note text not null,
  created_at timestamptz not null default now(),
  unique(question_id, reference_source_id)
);

alter table public.question_career_tracks enable row level security;
alter table public.question_references enable row level security;
-- END CANONICAL MIGRATION 0004

-- BEGIN CANONICAL MIGRATION 0005 20260821233830 assessment_question_uniqueness_guards
alter table public.question_bank add constraint question_bank_version_code_key unique (assessment_version_id, code);
alter table public.question_options add constraint question_options_question_code_key unique (question_id, option_code);
alter table public.question_dimension_scores add constraint question_dimension_scores_option_dimension_key unique (option_id, dimension_id);
-- END CANONICAL MIGRATION 0005

-- BEGIN CANONICAL MIGRATION 0006 20260821234849 add_explainable_assessment_scoring_engine
create table if not exists public.assessment_scoring_models (
  id uuid primary key default gen_random_uuid(),
  assessment_version_id uuid not null references public.assessment_versions(id) on delete cascade,
  career_track_id uuid not null references public.career_tracks(id) on delete cascade,
  model_code text not null,
  model_name text not null,
  methodology_notes text not null,
  current_fit_formula text not null,
  future_fit_formula text not null,
  status text not null default 'draft' check (status in ('draft','review','published','retired')),
  created_at timestamptz not null default now(),
  unique (assessment_version_id, career_track_id, model_code)
);

create table if not exists public.assessment_dimension_results (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.assessment_attempts(id) on delete cascade,
  career_track_id uuid not null references public.career_tracks(id) on delete cascade,
  dimension_id uuid not null references public.assessment_dimensions(id) on delete cascade,
  raw_score numeric not null check (raw_score between 0 and 100),
  weighted_contribution numeric not null default 0,
  weight_used numeric not null check (weight_used between 0 and 1),
  minimum_score numeric null,
  meets_minimum boolean null,
  evidence_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (attempt_id, career_track_id, dimension_id)
);

create table if not exists public.assessment_explanation_rules (
  id uuid primary key default gen_random_uuid(),
  assessment_version_id uuid not null references public.assessment_versions(id) on delete cascade,
  career_track_id uuid not null references public.career_tracks(id) on delete cascade,
  rule_type text not null check (rule_type in ('strength','gap','status','future_fit','minimum_gate')),
  dimension_id uuid null references public.assessment_dimensions(id) on delete cascade,
  min_score numeric null,
  max_score numeric null,
  explanation_template text not null,
  development_action text null,
  priority integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.assessment_scoring_models enable row level security;
alter table public.assessment_dimension_results enable row level security;
alter table public.assessment_explanation_rules enable row level security;

insert into public.assessment_scoring_models (
  assessment_version_id, career_track_id, model_code, model_name,
  methodology_notes, current_fit_formula, future_fit_formula, status
)
select v.id,c.id,'weighted_dimension_fit_v1','Weighted Dimension Fit v1',
'AVIATION MATRIX DRAFT METHODOLOGY. Current Fit is a weighted combination of observed dimension scores. Weights are internal methodology informed by role relevance and reference-backed competencies; the percentages are not prescribed by ICAO. Future Fit is a transparent development-potential estimate and must not be presented as guaranteed future performance.',
'Current Fit = sum(observed dimension score × career dimension weight), normalized over answered dimensions.',
'Future Fit = Current Fit + remaining gap × (0.15 + 0.25 × Learning Agility/100), capped at 95. This is a draft development-potential estimate, not a regulatory or airline standard.',
'draft'
from public.assessment_versions v
join public.assessment_frameworks f on f.id=v.framework_id and f.code='career_fit'
join public.career_tracks c on c.code='cabin_crew'
where v.version_no=1
on conflict (assessment_version_id, career_track_id, model_code) do nothing;

insert into public.preparatory_paths(code,name,description)
values
('prep_aviation_english','Aviation English Foundation','Development path for aviation English comprehension, terminology and communication readiness.'),
('prep_safety_judgment','Safety & Professional Judgment Foundation','Development path for safety-first thinking, procedural judgment, escalation and prioritization.'),
('prep_crm_communication','CRM & Communication Foundation','Development path for teamwork, clear communication, coordination and passenger interaction.'),
('prep_attention_procedures','Attention & Procedures Foundation','Development path for detail orientation, checking discipline and procedural accuracy.'),
('prep_professional_readiness','Professional Readiness Foundation','Development path for professional presence, service conduct, resilience and learning habits.')
on conflict (code) do nothing;

insert into public.career_preparatory_rules(career_track_id,dimension_id,threshold_below,preparatory_path_id,rationale,is_active)
select c.id,d.id,x.threshold,p.id,x.rationale,true
from public.career_tracks c
join (values
 ('english_readiness',65::numeric,'prep_aviation_english','Below this draft threshold, targeted aviation-English preparation is recommended before full career readiness.'),
 ('safety_mindset',70::numeric,'prep_safety_judgment','Safety mindset is a high-priority cabin-crew dimension; a low score triggers targeted preparation rather than silent rejection.'),
 ('professional_judgment',60::numeric,'prep_safety_judgment','Judgment below the draft threshold indicates a need for scenario-based decision development.'),
 ('teamwork_crm',60::numeric,'prep_crm_communication','CRM/teamwork below the draft threshold indicates targeted coordination and communication development.'),
 ('communication',60::numeric,'prep_crm_communication','Communication below the draft threshold indicates targeted communication development.'),
 ('attention_to_detail',60::numeric,'prep_attention_procedures','Attention below the draft threshold indicates targeted procedural and checking practice.'),
 ('professional_presence',55::numeric,'prep_professional_readiness','Professional presence is developable and should lead to coaching, not rejection.'),
 ('learning_agility',55::numeric,'prep_professional_readiness','Low learning-agility evidence indicates the need for structured learning support.')
) as x(dim_code,threshold,path_code,rationale) on true
join public.assessment_dimensions d on d.code=x.dim_code
join public.preparatory_paths p on p.code=x.path_code
where c.code='cabin_crew'
and not exists (
 select 1 from public.career_preparatory_rules r
 where r.career_track_id=c.id and r.dimension_id=d.id and r.preparatory_path_id=p.id
);

create or replace function public.calculate_assessment_career_fit(p_attempt_id uuid, p_career_code text default 'cabin_crew')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt public.assessment_attempts%rowtype;
  v_career_id uuid;
  v_learning numeric := 50;
  v_current numeric := 0;
  v_future numeric := 0;
  v_weight_sum numeric := 0;
  v_status text;
  v_summary text;
  v_strengths jsonb := '[]'::jsonb;
  v_gaps jsonb := '[]'::jsonb;
  v_dimensions jsonb := '{}'::jsonb;
  v_failed_minimums integer := 0;
begin
  select * into v_attempt from public.assessment_attempts where id=p_attempt_id;
  if not found then raise exception 'Assessment attempt not found'; end if;

  select id into v_career_id from public.career_tracks where code=p_career_code and is_active=true;
  if v_career_id is null then raise exception 'Career track not found'; end if;

  delete from public.assessment_dimension_results where attempt_id=p_attempt_id and career_track_id=v_career_id;

  insert into public.assessment_dimension_results(
    attempt_id,career_track_id,dimension_id,raw_score,weighted_contribution,weight_used,minimum_score,meets_minimum,evidence_payload
  )
  select
    p_attempt_id,
    v_career_id,
    w.dimension_id,
    round(avg(qds.score),2) as raw_score,
    round(avg(qds.score) * w.weight,4) as weighted_contribution,
    w.weight,
    w.minimum_score,
    case when w.minimum_score is null then null else avg(qds.score) >= w.minimum_score end,
    jsonb_build_object(
      'answered_items',count(distinct a.question_id),
      'scoring_basis','Mean option evidence score for this dimension',
      'weight_rationale',w.rationale
    )
  from public.assessment_answers a
  join public.question_dimension_scores qds on qds.option_id=a.option_id
  join public.career_dimension_weights w on w.dimension_id=qds.dimension_id
    and w.assessment_version_id=v_attempt.assessment_version_id
    and w.career_track_id=v_career_id
  where a.attempt_id=p_attempt_id
  group by w.dimension_id,w.weight,w.minimum_score,w.rationale;

  select coalesce(sum(weight_used),0),
         coalesce(sum(weighted_contribution),0)
    into v_weight_sum,v_current
  from public.assessment_dimension_results
  where attempt_id=p_attempt_id and career_track_id=v_career_id;

  if v_weight_sum > 0 then
    v_current := round(v_current / v_weight_sum,2);
  else
    raise exception 'No scorable answers found for this attempt';
  end if;

  select coalesce(raw_score,50) into v_learning
  from public.assessment_dimension_results dr
  join public.assessment_dimensions d on d.id=dr.dimension_id
  where dr.attempt_id=p_attempt_id and dr.career_track_id=v_career_id and d.code='learning_agility';

  v_future := round(least(95, v_current + (100-v_current) * (0.15 + 0.25*(v_learning/100))),2);

  select count(*) into v_failed_minimums
  from public.assessment_dimension_results
  where attempt_id=p_attempt_id and career_track_id=v_career_id and meets_minimum=false;

  if v_current >= 80 and v_failed_minimums=0 then v_status:='ready_now';
  elsif v_current >= 65 and v_failed_minimums<=1 then v_status:='ready_with_development';
  elsif v_current >= 45 then v_status:='development_required';
  else v_status:='future_eligible';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('code',code,'name',name,'score',raw_score,'weight',weight_used,'meets_minimum',meets_minimum) order by raw_score desc),'[]'::jsonb)
    into v_strengths
  from (
    select d.code,d.name,dr.raw_score,dr.weight_used,dr.meets_minimum
    from public.assessment_dimension_results dr join public.assessment_dimensions d on d.id=dr.dimension_id
    where dr.attempt_id=p_attempt_id and dr.career_track_id=v_career_id
    order by dr.raw_score desc limit 3
  ) s;

  select coalesce(jsonb_agg(jsonb_build_object('code',code,'name',name,'score',raw_score,'target',target_score,'reason',reason,'recommended_path',path_name) order by raw_score asc),'[]'::jsonb)
    into v_gaps
  from (
    select d.code,d.name,dr.raw_score,
           coalesce(w.minimum_score,r.threshold_below,65) as target_score,
           case when dr.meets_minimum=false then 'Below the career draft minimum' else 'One of the lower observed dimensions' end as reason,
           p.name as path_name
    from public.assessment_dimension_results dr
    join public.assessment_dimensions d on d.id=dr.dimension_id
    join public.career_dimension_weights w on w.dimension_id=dr.dimension_id and w.assessment_version_id=v_attempt.assessment_version_id and w.career_track_id=v_career_id
    left join public.career_preparatory_rules r on r.career_track_id=v_career_id and r.dimension_id=dr.dimension_id and dr.raw_score < r.threshold_below and r.is_active=true
    left join public.preparatory_paths p on p.id=r.preparatory_path_id
    where dr.attempt_id=p_attempt_id and dr.career_track_id=v_career_id
      and (dr.meets_minimum=false or dr.raw_score < 65)
    order by dr.raw_score asc limit 4
  ) g;

  select coalesce(jsonb_object_agg(d.code,jsonb_build_object('name',d.name,'score',dr.raw_score,'weight',dr.weight_used,'weighted_contribution',dr.weighted_contribution,'minimum',dr.minimum_score,'meets_minimum',dr.meets_minimum)),'{}'::jsonb)
    into v_dimensions
  from public.assessment_dimension_results dr join public.assessment_dimensions d on d.id=dr.dimension_id
  where dr.attempt_id=p_attempt_id and dr.career_track_id=v_career_id;

  v_summary := case v_status
    when 'ready_now' then 'Your current evidence shows a strong Cabin Crew fit across the weighted dimensions, with no draft minimum-score gaps.'
    when 'ready_with_development' then 'Your current evidence shows a good Cabin Crew fit, with targeted development recommended before full readiness.'
    when 'development_required' then 'Cabin Crew remains a possible path, but the current evidence shows development priorities that should be addressed first.'
    else 'The current evidence does not yet support immediate Cabin Crew readiness. This is not a permanent rejection; the result identifies areas to develop and reassess.'
  end;

  insert into public.career_fit_results(attempt_id,career_track_id,current_fit,future_fit,rank_no,readiness_status,explanation_summary,evidence_payload)
  values(p_attempt_id,v_career_id,v_current,v_future,1,v_status,v_summary,
    jsonb_build_object(
      'methodology','Weighted Dimension Fit v1',
      'methodology_status','draft',
      'transparency_note','Weights and thresholds are Aviation Matrix methodology informed by role competencies; they are not ICAO-prescribed percentages.',
      'dimension_results',v_dimensions,
      'strengths',v_strengths,
      'development_gaps',v_gaps,
      'failed_minimum_count',v_failed_minimums,
      'future_fit_explanation','Future Fit is a development-potential estimate using Current Fit and Learning Agility; it is not guaranteed future performance.'
    )
  )
  on conflict (attempt_id,career_track_id) do update set
    current_fit=excluded.current_fit,
    future_fit=excluded.future_fit,
    rank_no=excluded.rank_no,
    readiness_status=excluded.readiness_status,
    explanation_summary=excluded.explanation_summary,
    evidence_payload=excluded.evidence_payload;

  delete from public.development_gaps where attempt_id=p_attempt_id and career_track_id=v_career_id;
  insert into public.development_gaps(attempt_id,career_track_id,dimension_id,observed_score,target_score,gap_severity,development_recommendation)
  select p_attempt_id,v_career_id,dr.dimension_id,dr.raw_score,
         coalesce(w.minimum_score,r.threshold_below,65),
         case
           when dr.raw_score < 40 then 'critical'
           when dr.raw_score < 55 then 'high'
           when dr.raw_score < 65 then 'medium'
           else 'low'
         end,
         coalesce('Recommended preparation: '||p.name,'Targeted practice and reassessment are recommended for this dimension.')
  from public.assessment_dimension_results dr
  join public.career_dimension_weights w on w.dimension_id=dr.dimension_id and w.assessment_version_id=v_attempt.assessment_version_id and w.career_track_id=v_career_id
  left join public.career_preparatory_rules r on r.career_track_id=v_career_id and r.dimension_id=dr.dimension_id and dr.raw_score < r.threshold_below and r.is_active=true
  left join public.preparatory_paths p on p.id=r.preparatory_path_id
  where dr.attempt_id=p_attempt_id and dr.career_track_id=v_career_id and (dr.meets_minimum=false or dr.raw_score < 65);

  update public.assessment_attempts set overall_score=v_current,result_payload=jsonb_build_object('career_code',p_career_code,'current_fit',v_current,'future_fit',v_future,'readiness_status',v_status,'strengths',v_strengths,'development_gaps',v_gaps) where id=p_attempt_id;

  return jsonb_build_object('career_code',p_career_code,'current_fit',v_current,'future_fit',v_future,'readiness_status',v_status,'summary',v_summary,'strengths',v_strengths,'development_gaps',v_gaps,'dimensions',v_dimensions);
end;
$$;
-- END CANONICAL MIGRATION 0006

-- BEGIN CANONICAL MIGRATION 0007 20260821235127 connect_public_assessment_engine
alter table public.assessment_attempts add column if not exists lead_id uuid references public.aviation_interest_leads(id);

create index if not exists assessment_attempts_lead_id_idx on public.assessment_attempts(lead_id);

update public.question_bank set status='published' where code like 'CFV1_CC_%';

create or replace function public.start_public_career_assessment(p_lead_id uuid, p_career_code text default 'cabin_crew')
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_version_id uuid;
  v_career_id uuid;
  v_attempt_id uuid;
begin
  if not exists(select 1 from public.aviation_interest_leads where id=p_lead_id) then
    raise exception 'Lead not found';
  end if;
  select av.id into v_version_id
  from public.assessment_versions av
  join public.assessment_frameworks af on af.id=av.framework_id
  where af.code='career_fit' and av.version_no=1
  order by av.created_at desc limit 1;
  if v_version_id is null then raise exception 'Assessment version not found'; end if;
  select id into v_career_id from public.career_tracks where code=p_career_code and is_active=true;
  if v_career_id is null then raise exception 'Career track not found'; end if;
  select id into v_attempt_id from public.assessment_attempts
   where lead_id=p_lead_id and assessment_version_id=v_version_id and target_career_track_id=v_career_id and status='in_progress'
   order by started_at desc limit 1;
  if v_attempt_id is null then
    insert into public.assessment_attempts(lead_id,assessment_version_id,target_career_track_id,status)
    values(p_lead_id,v_version_id,v_career_id,'in_progress') returning id into v_attempt_id;
  end if;
  return jsonb_build_object('attempt_id',v_attempt_id,'assessment_version_id',v_version_id,'career_code',p_career_code);
end;
$$;

create or replace function public.submit_public_assessment_answer(p_attempt_id uuid, p_question_id uuid, p_option_id uuid, p_response_time_seconds integer default null)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
begin
  if not exists(select 1 from public.assessment_attempts where id=p_attempt_id and status='in_progress') then
    raise exception 'Assessment attempt is not active';
  end if;
  if not exists(select 1 from public.question_options qo join public.question_bank q on q.id=qo.question_id where qo.id=p_option_id and qo.question_id=p_question_id and q.status='published') then
    raise exception 'Question option mismatch';
  end if;
  delete from public.assessment_answers where attempt_id=p_attempt_id and question_id=p_question_id;
  insert into public.assessment_answers(attempt_id,question_id,option_id,response_time_seconds)
  values(p_attempt_id,p_question_id,p_option_id,p_response_time_seconds);
  return jsonb_build_object('saved',true);
end;
$$;

create or replace function public.finish_public_career_assessment(p_attempt_id uuid, p_career_code text default 'cabin_crew')
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_count integer;
  v_result jsonb;
begin
  select count(*) into v_count from public.assessment_answers where attempt_id=p_attempt_id;
  if v_count < 10 then raise exception 'Assessment incomplete'; end if;
  v_result := public.calculate_assessment_career_fit(p_attempt_id,p_career_code);
  update public.assessment_attempts set status='completed',completed_at=now() where id=p_attempt_id;
  return v_result;
end;
$$;

grant execute on function public.start_public_career_assessment(uuid,text) to anon, authenticated;
grant execute on function public.submit_public_assessment_answer(uuid,uuid,uuid,integer) to anon, authenticated;
grant execute on function public.finish_public_career_assessment(uuid,text) to anon, authenticated;
-- END CANONICAL MIGRATION 0007

-- BEGIN CANONICAL MIGRATION 0008 20260821235206 public_registration_and_duplicate_guard
create or replace function public.normalize_public_mobile(p_mobile text)
returns text language sql immutable as $$ select regexp_replace(coalesce(p_mobile,''),'\D','','g') $$;

create or replace function public.guard_public_lead_duplicates()
returns trigger language plpgsql set search_path=public as $$
begin
  if exists(select 1 from public.aviation_interest_leads l where lower(trim(l.email))=lower(trim(new.email))) then
    raise exception 'EMAIL_ALREADY_REGISTERED';
  end if;
  if exists(select 1 from public.aviation_interest_leads l where public.normalize_public_mobile(l.mobile)=public.normalize_public_mobile(new.mobile)) then
    raise exception 'MOBILE_ALREADY_REGISTERED';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_public_lead_duplicates on public.aviation_interest_leads;
create trigger trg_guard_public_lead_duplicates before insert on public.aviation_interest_leads for each row execute function public.guard_public_lead_duplicates();

create or replace function public.register_public_aviation_lead(
  p_full_name text,
  p_mobile text,
  p_email text,
  p_date_of_birth date,
  p_education_stage text,
  p_current_city text,
  p_aviation_interest text,
  p_preferred_language text,
  p_consent boolean
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id uuid;
begin
  if coalesce(p_consent,false) is not true then raise exception 'CONSENT_REQUIRED'; end if;
  if exists(select 1 from public.aviation_interest_leads where lower(trim(email))=lower(trim(p_email))) then
    return jsonb_build_object('created',false,'existing_profile',true,'reason','email');
  end if;
  if exists(select 1 from public.aviation_interest_leads where public.normalize_public_mobile(mobile)=public.normalize_public_mobile(p_mobile)) then
    return jsonb_build_object('created',false,'existing_profile',true,'reason','mobile');
  end if;
  insert into public.aviation_interest_leads(full_name,mobile,email,date_of_birth,education_stage,current_city,aviation_interest,preferred_language,consent,source,status)
  values(trim(p_full_name),trim(p_mobile),lower(trim(p_email)),p_date_of_birth,p_education_stage,trim(p_current_city),p_aviation_interest,p_preferred_language,true,'landing_pilot','new')
  returning id into v_id;
  return jsonb_build_object('created',true,'existing_profile',false,'lead_id',v_id);
end;
$$;

grant execute on function public.register_public_aviation_lead(text,text,text,date,text,text,text,text,boolean) to anon, authenticated;
-- END CANONICAL MIGRATION 0008

-- BEGIN CANONICAL MIGRATION 0009 20260821235249 resume_existing_public_profile
create or replace function public.register_public_aviation_lead(
  p_full_name text,
  p_mobile text,
  p_email text,
  p_date_of_birth date,
  p_education_stage text,
  p_current_city text,
  p_aviation_interest text,
  p_preferred_language text,
  p_consent boolean
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id uuid;
  v_exact_id uuid;
begin
  if coalesce(p_consent,false) is not true then raise exception 'CONSENT_REQUIRED'; end if;

  select id into v_exact_id
  from public.aviation_interest_leads
  where lower(trim(email))=lower(trim(p_email))
    and public.normalize_public_mobile(mobile)=public.normalize_public_mobile(p_mobile)
    and date_of_birth=p_date_of_birth
  order by created_at asc
  limit 1;

  if v_exact_id is not null then
    return jsonb_build_object('created',false,'existing_profile',true,'resume_allowed',true,'lead_id',v_exact_id,'reason','exact_match');
  end if;

  if exists(select 1 from public.aviation_interest_leads where lower(trim(email))=lower(trim(p_email))) then
    return jsonb_build_object('created',false,'existing_profile',true,'resume_allowed',false,'reason','email');
  end if;
  if exists(select 1 from public.aviation_interest_leads where public.normalize_public_mobile(mobile)=public.normalize_public_mobile(p_mobile)) then
    return jsonb_build_object('created',false,'existing_profile',true,'resume_allowed',false,'reason','mobile');
  end if;

  insert into public.aviation_interest_leads(full_name,mobile,email,date_of_birth,education_stage,current_city,aviation_interest,preferred_language,consent,source,status)
  values(trim(p_full_name),trim(p_mobile),lower(trim(p_email)),p_date_of_birth,p_education_stage,trim(p_current_city),p_aviation_interest,p_preferred_language,true,'landing_pilot','new')
  returning id into v_id;

  return jsonb_build_object('created',true,'existing_profile',false,'resume_allowed',true,'lead_id',v_id);
end;
$$;
-- END CANONICAL MIGRATION 0009

-- BEGIN CANONICAL MIGRATION 0010 20260822070220 fix_public_lead_duplicate_trigger_permissions
create or replace function public.guard_public_lead_duplicates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists(
    select 1
    from public.aviation_interest_leads l
    where lower(trim(l.email)) = lower(trim(new.email))
  ) then
    raise exception 'EMAIL_ALREADY_REGISTERED';
  end if;

  if exists(
    select 1
    from public.aviation_interest_leads l
    where public.normalize_public_mobile(l.mobile) = public.normalize_public_mobile(new.mobile)
  ) then
    raise exception 'MOBILE_ALREADY_REGISTERED';
  end if;

  return new;
end;
$$;
-- END CANONICAL MIGRATION 0010

