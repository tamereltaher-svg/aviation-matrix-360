create table if not exists public.am_learning_curricula (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  version_label text not null default '1.0',
  status text not null default 'draft' check (status in ('draft','review','approved','active','retired')),
  purpose text,
  audience_code text,
  effective_from date,
  effective_to date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_learning_courses (
  id uuid primary key default gen_random_uuid(),
  curriculum_id uuid references public.am_learning_curricula(id) on delete set null,
  code text not null unique,
  name text not null,
  course_type text not null default 'training' check (course_type in ('training','orientation','workshop','e_learning','practical','assessment_only')),
  status text not null default 'draft' check (status in ('draft','review','approved','active','retired')),
  duration_minutes integer check (duration_minutes is null or duration_minutes >= 0),
  delivery_modes text[] not null default '{}',
  prerequisites jsonb not null default '[]'::jsonb,
  completion_rule jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_learning_paths (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  target_role_code text,
  status text not null default 'draft' check (status in ('draft','review','approved','active','retired')),
  purpose text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_learning_path_courses (
  id uuid primary key default gen_random_uuid(),
  learning_path_id uuid not null references public.am_learning_paths(id) on delete cascade,
  course_id uuid not null references public.am_learning_courses(id) on delete cascade,
  sequence_no integer not null default 1,
  is_required boolean not null default true,
  unlock_rule jsonb not null default '{}'::jsonb,
  unique(learning_path_id, course_id)
);

create table if not exists public.am_course_learning_outcomes (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.am_learning_courses(id) on delete cascade,
  code text not null,
  outcome_text text not null,
  outcome_type text not null default 'knowledge' check (outcome_type in ('knowledge','skill','behavior','competency','compliance')),
  competency_code text,
  target_level text,
  sort_order integer not null default 999,
  unique(course_id, code)
);

create table if not exists public.am_candidate_learning_enrollments (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  learning_path_id uuid references public.am_learning_paths(id) on delete set null,
  course_id uuid references public.am_learning_courses(id) on delete set null,
  status text not null default 'enrolled' check (status in ('enrolled','not_started','in_progress','completed','failed','withdrawn','cancelled')),
  enrolled_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  completion_score numeric check (completion_score is null or (completion_score >= 0 and completion_score <= 100)),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_assessment_blueprints (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  purpose text not null,
  assessment_type text not null check (assessment_type in ('diagnostic','formative','summative','exam','practical','interview','career_fit','compliance')),
  stakes text not null default 'medium' check (stakes in ('low','medium','high','critical')),
  status text not null default 'draft' check (status in ('draft','review','approved','published','retired')),
  passing_rule jsonb not null default '{}'::jsonb,
  integrity_rule jsonb not null default '{}'::jsonb,
  attempt_rule jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_assessment_blueprint_components (
  id uuid primary key default gen_random_uuid(),
  blueprint_id uuid not null references public.am_assessment_blueprints(id) on delete cascade,
  component_code text not null,
  component_name text not null,
  competency_code text,
  dimension_id uuid references public.assessment_dimensions(id) on delete set null,
  weight numeric not null default 1 check (weight >= 0),
  minimum_score numeric check (minimum_score is null or (minimum_score >= 0 and minimum_score <= 100)),
  question_count integer check (question_count is null or question_count >= 0),
  is_hard_gate boolean not null default false,
  sort_order integer not null default 999,
  unique(blueprint_id, component_code)
);

create table if not exists public.am_exam_definitions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  course_id uuid references public.am_learning_courses(id) on delete set null,
  blueprint_id uuid not null references public.am_assessment_blueprints(id) on delete restrict,
  exam_type text not null default 'knowledge' check (exam_type in ('knowledge','practical','mixed','oral','interview','simulation')),
  status text not null default 'draft' check (status in ('draft','review','approved','active','retired')),
  duration_minutes integer check (duration_minutes is null or duration_minutes > 0),
  max_attempts integer not null default 1 check (max_attempts >= 1),
  pass_score numeric check (pass_score is null or (pass_score >= 0 and pass_score <= 100)),
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_exam_versions (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.am_exam_definitions(id) on delete cascade,
  version_no integer not null,
  version_label text not null,
  status text not null default 'draft' check (status in ('draft','review','approved','published','retired')),
  effective_from timestamptz,
  effective_to timestamptz,
  randomization_rule jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(exam_id, version_no)
);

create table if not exists public.am_exam_version_questions (
  id uuid primary key default gen_random_uuid(),
  exam_version_id uuid not null references public.am_exam_versions(id) on delete cascade,
  question_id uuid not null references public.question_bank(id) on delete restrict,
  blueprint_component_id uuid references public.am_assessment_blueprint_components(id) on delete set null,
  sequence_no integer,
  points numeric not null default 1 check (points >= 0),
  is_required boolean not null default true,
  unique(exam_version_id, question_id)
);

create table if not exists public.am_exam_sessions (
  id uuid primary key default gen_random_uuid(),
  session_ref text not null unique,
  exam_version_id uuid not null references public.am_exam_versions(id) on delete restrict,
  status text not null default 'scheduled' check (status in ('scheduled','open','in_progress','closed','cancelled')),
  delivery_mode text not null default 'online' check (delivery_mode in ('online','classroom','practical','hybrid')),
  scheduled_start timestamptz,
  scheduled_end timestamptz,
  venue text,
  invigilation_mode text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_exam_attempts (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  session_id uuid references public.am_exam_sessions(id) on delete set null,
  exam_version_id uuid not null references public.am_exam_versions(id) on delete restrict,
  attempt_no integer not null default 1 check (attempt_no >= 1),
  status text not null default 'not_started' check (status in ('not_started','in_progress','submitted','scored','passed','failed','invalidated','abandoned')),
  started_at timestamptz,
  submitted_at timestamptz,
  scored_at timestamptz,
  integrity_status text not null default 'not_reviewed' check (integrity_status in ('not_reviewed','clear','flagged','invalidated')),
  access_context jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(candidate_id, exam_version_id, attempt_no)
);

create table if not exists public.am_exam_attempt_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.am_exam_attempts(id) on delete cascade,
  question_id uuid not null references public.question_bank(id) on delete restrict,
  option_id uuid references public.question_options(id) on delete set null,
  answer_payload jsonb not null default '{}'::jsonb,
  awarded_points numeric,
  is_correct boolean,
  answered_at timestamptz not null default now(),
  response_time_seconds integer check (response_time_seconds is null or response_time_seconds >= 0),
  unique(attempt_id, question_id)
);

create table if not exists public.am_exam_results (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null unique references public.am_exam_attempts(id) on delete cascade,
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  overall_score numeric not null check (overall_score >= 0 and overall_score <= 100),
  pass_status text not null check (pass_status in ('pass','fail','conditional','pending_review','invalidated')),
  result_status text not null default 'provisional' check (result_status in ('provisional','reviewed','final','appealed','superseded')),
  strengths jsonb not null default '[]'::jsonb,
  gaps jsonb not null default '[]'::jsonb,
  scoring_payload jsonb not null default '{}'::jsonb,
  finalized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_exam_result_components (
  id uuid primary key default gen_random_uuid(),
  exam_result_id uuid not null references public.am_exam_results(id) on delete cascade,
  blueprint_component_id uuid references public.am_assessment_blueprint_components(id) on delete set null,
  component_code text not null,
  raw_score numeric check (raw_score is null or (raw_score >= 0 and raw_score <= 100)),
  weighted_score numeric,
  meets_minimum boolean,
  evidence_payload jsonb not null default '{}'::jsonb,
  unique(exam_result_id, component_code)
);

create table if not exists public.am_exam_retakes (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  original_attempt_id uuid not null references public.am_exam_attempts(id) on delete cascade,
  approved_attempt_no integer not null,
  status text not null default 'requested' check (status in ('requested','approved','rejected','scheduled','completed','cancelled')),
  reason text,
  approved_by uuid references public.staff_accounts(user_id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.am_learning_credentials (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  course_id uuid references public.am_learning_courses(id) on delete set null,
  exam_result_id uuid references public.am_exam_results(id) on delete set null,
  credential_type text not null check (credential_type in ('certificate','completion_record','exam_transcript','competency_record','attendance_record')),
  credential_number text not null unique,
  title text not null,
  status text not null default 'issued' check (status in ('draft','issued','revoked','expired','superseded')),
  issued_at timestamptz not null default now(),
  valid_until timestamptz,
  verification_code text unique,
  asset_path text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists am_candidate_learning_enrollments_candidate_idx on public.am_candidate_learning_enrollments(candidate_id);
create index if not exists am_exam_attempts_candidate_idx on public.am_exam_attempts(candidate_id);
create index if not exists am_exam_attempts_session_idx on public.am_exam_attempts(session_id);
create index if not exists am_exam_results_candidate_idx on public.am_exam_results(candidate_id);
create index if not exists am_learning_credentials_candidate_idx on public.am_learning_credentials(candidate_id);

alter table public.am_learning_curricula enable row level security;
alter table public.am_learning_courses enable row level security;
alter table public.am_learning_paths enable row level security;
alter table public.am_learning_path_courses enable row level security;
alter table public.am_course_learning_outcomes enable row level security;
alter table public.am_candidate_learning_enrollments enable row level security;
alter table public.am_assessment_blueprints enable row level security;
alter table public.am_assessment_blueprint_components enable row level security;
alter table public.am_exam_definitions enable row level security;
alter table public.am_exam_versions enable row level security;
alter table public.am_exam_version_questions enable row level security;
alter table public.am_exam_sessions enable row level security;
alter table public.am_exam_attempts enable row level security;
alter table public.am_exam_attempt_answers enable row level security;
alter table public.am_exam_results enable row level security;
alter table public.am_exam_result_components enable row level security;
alter table public.am_exam_retakes enable row level security;
alter table public.am_learning_credentials enable row level security;

create or replace view public.am_learning_exam_architecture_summary
with (security_invoker=true) as
select
  (select count(*) from public.am_learning_curricula) as curricula,
  (select count(*) from public.am_learning_courses) as courses,
  (select count(*) from public.am_learning_paths) as learning_paths,
  (select count(*) from public.am_assessment_blueprints) as assessment_blueprints,
  (select count(*) from public.question_bank) as existing_question_bank_items,
  (select count(*) from public.am_exam_definitions) as exams,
  (select count(*) from public.am_exam_sessions) as exam_sessions,
  (select count(*) from public.am_exam_attempts) as exam_attempts,
  (select count(*) from public.am_exam_results) as exam_results,
  (select count(*) from public.am_learning_credentials) as credentials;

create or replace function public.am_exam_result_to_candidate_evidence()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.result_status = 'final' and (tg_op = 'INSERT' or old.result_status is distinct from new.result_status) then
    insert into public.am_candidate_evidence(candidate_id, case_id, evidence_type, source_system, source_table, source_id, title, summary, status, issued_at, score, metadata)
    select new.candidate_id, new.case_id, 'exam_result', 'aviation_matrix', 'am_exam_results', new.id,
           'Final Exam Result', 'Finalized examination result', 'verified', coalesce(new.finalized_at, now()), new.overall_score,
           jsonb_build_object('pass_status',new.pass_status,'attempt_id',new.attempt_id)
    where not exists (select 1 from public.am_candidate_evidence e where e.source_table='am_exam_results' and e.source_id=new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_am_exam_result_to_candidate_evidence on public.am_exam_results;
create trigger trg_am_exam_result_to_candidate_evidence
after insert or update of result_status on public.am_exam_results
for each row execute function public.am_exam_result_to_candidate_evidence();
