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
