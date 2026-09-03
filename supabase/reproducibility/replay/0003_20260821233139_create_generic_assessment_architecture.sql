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
