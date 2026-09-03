create table if not exists am_assessment_stage_registry (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  stage_order integer not null unique,
  assessment_kind text not null,
  description text,
  level_scheme jsonb not null default '{}'::jsonb,
  is_required boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists am_assessment_stage_versions (
  id uuid primary key default gen_random_uuid(),
  stage_id uuid not null references am_assessment_stage_registry(id) on delete cascade,
  version_no integer not null,
  version_label text not null,
  status text not null default 'draft',
  instructions text,
  min_questions integer not null default 0,
  time_limit_minutes integer,
  scoring_rule jsonb not null default '{}'::jsonb,
  level_bands jsonb not null default '[]'::jsonb,
  retake_rule jsonb not null default '{}'::jsonb,
  effective_from timestamptz,
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(stage_id, version_no)
);

create table if not exists am_assessment_stage_version_items (
  id uuid primary key default gen_random_uuid(),
  stage_version_id uuid not null references am_assessment_stage_versions(id) on delete cascade,
  question_id uuid not null references question_bank(id) on delete restrict,
  sequence_no integer not null default 999,
  weight numeric not null default 1,
  is_required boolean not null default true,
  created_at timestamptz not null default now(),
  unique(stage_version_id, question_id)
);

create table if not exists am_candidate_assessment_journeys (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null unique references am_candidate_records(id) on delete cascade,
  status text not null default 'not_started',
  current_stage_code text,
  started_at timestamptz,
  completed_at timestamptz,
  last_activity_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists am_candidate_stage_attempts (
  id uuid primary key default gen_random_uuid(),
  journey_id uuid not null references am_candidate_assessment_journeys(id) on delete cascade,
  candidate_id uuid not null references am_candidate_records(id) on delete cascade,
  stage_code text not null references am_assessment_stage_registry(code) on update cascade,
  stage_version_id uuid references am_assessment_stage_versions(id) on delete restrict,
  attempt_no integer not null,
  status text not null default 'in_progress',
  access_token uuid not null default gen_random_uuid(),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  completed_at timestamptz,
  overall_score numeric,
  level_code text,
  outcome_code text,
  result_json jsonb not null default '{}'::jsonb,
  integrity_flags jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(candidate_id, stage_code, attempt_no)
);

create table if not exists am_candidate_stage_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references am_candidate_stage_attempts(id) on delete cascade,
  question_id uuid not null references question_bank(id) on delete restrict,
  option_id uuid references question_options(id) on delete restrict,
  answer_payload jsonb not null default '{}'::jsonb,
  response_time_seconds integer,
  answered_at timestamptz not null default now(),
  unique(attempt_id, question_id)
);

create table if not exists am_candidate_stage_dimension_results (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references am_candidate_stage_attempts(id) on delete cascade,
  dimension_code text not null,
  dimension_name text,
  raw_score numeric,
  normalized_score numeric,
  level_code text,
  evidence_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(attempt_id, dimension_code)
);

create table if not exists am_candidate_career_recommendations (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references am_candidate_stage_attempts(id) on delete cascade,
  candidate_id uuid not null references am_candidate_records(id) on delete cascade,
  career_code text not null,
  career_name text,
  rank_no integer not null,
  fit_score numeric not null,
  decision_code text,
  gaps jsonb not null default '[]'::jsonb,
  explanation jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(attempt_id, career_code)
);

create index if not exists idx_stage_attempts_candidate on am_candidate_stage_attempts(candidate_id, stage_code, attempt_no desc);
create index if not exists idx_stage_answers_attempt on am_candidate_stage_answers(attempt_id);
create index if not exists idx_stage_dimension_attempt on am_candidate_stage_dimension_results(attempt_id);
create index if not exists idx_career_recommendations_candidate on am_candidate_career_recommendations(candidate_id, fit_score desc);

insert into am_assessment_stage_registry(code,name,stage_order,assessment_kind,description,level_scheme,is_required,is_active)
values
('ENGLISH','English Assessment',1,'foundation','English readiness and level assessment.','{"labels":["A1","A2","B1","B2","C1"],"thresholds":"admin_configured"}'::jsonb,true,true),
('COMPUTER','Computer Assessment',2,'foundation','Digital and computer readiness assessment.','{"labels":["Basic","Intermediate","Advanced"],"thresholds":"admin_configured"}'::jsonb,true,true),
('TRAITS','Traits & Behavioral Assessment',3,'behavioral','Work-style, behavioral and trait dimensions.','{"type":"dimension_profile","thresholds":"admin_configured"}'::jsonb,true,true),
('CAREER','Career Aptitude Assessment',4,'career_fit','Career suitability and pathway recommendation stage.','{"type":"ranked_career_fit","thresholds":"admin_configured"}'::jsonb,true,true)
on conflict(code) do update set name=excluded.name,stage_order=excluded.stage_order,assessment_kind=excluded.assessment_kind,description=excluded.description,level_scheme=excluded.level_scheme,is_required=excluded.is_required,is_active=excluded.is_active,updated_at=now();

insert into am_assessment_stage_versions(stage_id,version_no,version_label,status,instructions,min_questions,time_limit_minutes,scoring_rule,level_bands,retake_rule)
select id,1,'v1.0','draft',
  case code
    when 'ENGLISH' then 'Complete the configured English assessment. Final thresholds are controlled by the approved stage version.'
    when 'COMPUTER' then 'Complete the configured computer assessment. Final thresholds are controlled by the approved stage version.'
    when 'TRAITS' then 'Complete the configured behavioral assessment. Results are a profile, not a simple pass/fail.'
    when 'CAREER' then 'Complete the configured career aptitude assessment. Results produce ranked career fit and gap evidence.'
  end,
  0,null,'{"method":"question_option_dimension_aggregation","normalization":"configured_by_stage_version"}'::jsonb,'[]'::jsonb,
  '{"max_attempts":null,"cooldown_hours":0,"approval_required_for_retake":false}'::jsonb
from am_assessment_stage_registry s
where not exists(select 1 from am_assessment_stage_versions v where v.stage_id=s.id and v.version_no=1);

create or replace view am_candidate_assessment_journey_summary as
select j.id as journey_id,j.candidate_id,c.candidate_number,p.full_name,j.status,j.current_stage_code,j.started_at,j.completed_at,j.last_activity_at,
       coalesce((select count(*) from am_candidate_stage_attempts a where a.journey_id=j.id),0) attempts_total,
       coalesce((select count(*) from am_candidate_stage_attempts a where a.journey_id=j.id and a.status='completed'),0) attempts_completed,
       coalesce((select count(*) from am_candidate_stage_attempts a where a.journey_id=j.id and a.status='in_progress'),0) attempts_in_progress
from am_candidate_assessment_journeys j
join am_candidate_records c on c.id=j.candidate_id
join am_persons p on p.id=c.person_id;

alter table am_assessment_stage_registry enable row level security;
alter table am_assessment_stage_versions enable row level security;
alter table am_assessment_stage_version_items enable row level security;
alter table am_candidate_assessment_journeys enable row level security;
alter table am_candidate_stage_attempts enable row level security;
alter table am_candidate_stage_answers enable row level security;
alter table am_candidate_stage_dimension_results enable row level security;
alter table am_candidate_career_recommendations enable row level security;

create or replace function am_refresh_candidate_assessment_state(p_candidate_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_journey am_candidate_assessment_journeys%rowtype;
  v_next text;
  v_all_done boolean;
  v_eng text;
  v_comp text;
  v_career text;
  v_fit numeric;
begin
  select * into v_journey from am_candidate_assessment_journeys where candidate_id=p_candidate_id;
  if v_journey.id is null then return; end if;

  select s.code into v_next
  from am_assessment_stage_registry s
  where s.is_active and s.is_required
    and not exists(
      select 1 from am_candidate_stage_attempts a
      where a.candidate_id=p_candidate_id and a.stage_code=s.code and a.status='completed'
    )
  order by s.stage_order
  limit 1;

  v_all_done := v_next is null;

  select level_code into v_eng from am_candidate_stage_attempts where candidate_id=p_candidate_id and stage_code='ENGLISH' and status='completed' order by attempt_no desc limit 1;
  select level_code into v_comp from am_candidate_stage_attempts where candidate_id=p_candidate_id and stage_code='COMPUTER' and status='completed' order by attempt_no desc limit 1;
  select r.career_code,r.fit_score into v_career,v_fit
  from am_candidate_career_recommendations r
  join am_candidate_stage_attempts a on a.id=r.attempt_id
  where r.candidate_id=p_candidate_id and a.status='completed'
  order by a.completed_at desc nulls last,r.rank_no asc
  limit 1;

  update am_candidate_assessment_journeys
  set status=case when v_all_done then 'completed' when started_at is null then 'not_started' else 'in_progress' end,
      current_stage_code=v_next,
      completed_at=case when v_all_done then coalesce(completed_at,now()) else null end,
      last_activity_at=now(),updated_at=now()
  where candidate_id=p_candidate_id;

  update am_candidate_current_state
  set english_level=coalesce(v_eng,english_level),
      computer_level=coalesce(v_comp,computer_level),
      current_career_code=coalesce(v_career,current_career_code),
      current_career_fit=coalesce(v_fit,current_career_fit),
      latest_assessment_at=now(),
      qualification_status=case when v_all_done then 'assessment_complete' else 'assessment_in_progress' end,
      recalculated_at=now(),updated_at=now()
  where candidate_id=p_candidate_id;
end;
$$;
