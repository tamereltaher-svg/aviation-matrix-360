create table if not exists public.am_employer_organizations (
  id uuid primary key default gen_random_uuid(), organization_code text not null unique, organization_name text not null,
  organization_type text not null check (organization_type in ('airline','airport','ground_handler','cargo_operator','mro','aviation_service','other')),
  country_code text, website text, status text not null default 'active' check (status in ('active','inactive','prospect','archived')),
  profile_data jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.am_employer_contacts (
  id uuid primary key default gen_random_uuid(), employer_id uuid not null references public.am_employer_organizations(id) on delete cascade,
  full_name text not null, job_title text, email text, mobile text,
  contact_type text not null default 'recruitment' check (contact_type in ('recruitment','hr','operations','training','management','other')),
  is_primary boolean not null default false, status text not null default 'active' check (status in ('active','inactive')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.am_job_roles (
  id uuid primary key default gen_random_uuid(), role_code text not null unique, employer_id uuid references public.am_employer_organizations(id) on delete cascade,
  role_name text not null, role_family text, employment_type text, seniority_level text, role_description text,
  status text not null default 'draft' check (status in ('draft','active','inactive','archived')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.am_requirement_sets (
  id uuid primary key default gen_random_uuid(), requirement_set_code text not null unique,
  employer_id uuid references public.am_employer_organizations(id) on delete cascade, role_id uuid references public.am_job_roles(id) on delete cascade,
  name text not null, version_no integer not null default 1,
  status text not null default 'draft' check (status in ('draft','active','inactive','superseded','archived')),
  effective_from timestamptz, effective_to timestamptz, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(role_id, version_no)
);
create table if not exists public.am_requirement_items (
  id uuid primary key default gen_random_uuid(), requirement_set_id uuid not null references public.am_requirement_sets(id) on delete cascade,
  requirement_code text not null, category text not null, title text not null,
  requirement_type text not null default 'minimum' check (requirement_type in ('minimum','preferred','informational','hard_gate')),
  operator text, expected_value jsonb, weight numeric, is_mandatory boolean not null default false, evidence_type text,
  validity_rule jsonb, sort_order integer not null default 0, status text not null default 'active' check (status in ('active','inactive')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(requirement_set_id, requirement_code)
);
create table if not exists public.am_recruitment_campaigns (
  id uuid primary key default gen_random_uuid(), campaign_code text not null unique,
  employer_id uuid not null references public.am_employer_organizations(id) on delete cascade,
  role_id uuid not null references public.am_job_roles(id), requirement_set_id uuid references public.am_requirement_sets(id),
  title text not null, description text, openings integer, location_text text, opens_at timestamptz, closes_at timestamptz,
  status text not null default 'draft' check (status in ('draft','open','paused','closed','cancelled','completed')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.am_candidate_applications (
  id uuid primary key default gen_random_uuid(), candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  campaign_id uuid not null references public.am_recruitment_campaigns(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null, application_ref text not null unique, source text,
  status text not null default 'submitted' check (status in ('draft','submitted','screening','matched','shortlisted','interview','offer','hired','rejected','withdrawn','closed')),
  submitted_at timestamptz, closed_at timestamptz, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(candidate_id, campaign_id)
);
create table if not exists public.am_candidate_matches (
  id uuid primary key default gen_random_uuid(), candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  campaign_id uuid references public.am_recruitment_campaigns(id) on delete cascade, role_id uuid not null references public.am_job_roles(id),
  requirement_set_id uuid references public.am_requirement_sets(id), application_id uuid references public.am_candidate_applications(id) on delete set null,
  match_status text not null default 'pending' check (match_status in ('pending','qualified','conditional','gap','not_eligible','manual_review')),
  overall_score numeric, mandatory_met boolean, matched_count integer not null default 0, gap_count integer not null default 0,
  evaluated_at timestamptz, evaluation_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.am_shortlists (
  id uuid primary key default gen_random_uuid(), campaign_id uuid not null references public.am_recruitment_campaigns(id) on delete cascade,
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  application_id uuid references public.am_candidate_applications(id) on delete set null, match_id uuid references public.am_candidate_matches(id) on delete set null,
  shortlist_status text not null default 'proposed' check (shortlist_status in ('proposed','approved','released','held','removed')),
  rank_no integer, decision_note text, approved_at timestamptz, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(campaign_id, candidate_id)
);
create table if not exists public.am_interviews (
  id uuid primary key default gen_random_uuid(), campaign_id uuid not null references public.am_recruitment_campaigns(id) on delete cascade,
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  application_id uuid references public.am_candidate_applications(id) on delete set null,
  interview_type text not null default 'employer' check (interview_type in ('screening','technical','behavioral','language','panel','employer','final','other')),
  scheduled_at timestamptz, completed_at timestamptz, location_or_link text,
  status text not null default 'scheduled' check (status in ('scheduled','confirmed','completed','no_show','cancelled','rescheduled')),
  outcome text check (outcome is null or outcome in ('pass','fail','hold','next_round','offer_recommended','pending')),
  overall_score numeric, notes text, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.am_interview_scores (
  id uuid primary key default gen_random_uuid(), interview_id uuid not null references public.am_interviews(id) on delete cascade,
  criterion_code text not null, criterion_name text not null, score numeric, max_score numeric, evaluator_ref text, comments text,
  evidence_payload jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), unique(interview_id, criterion_code, evaluator_ref)
);
create table if not exists public.am_hiring_outcomes (
  id uuid primary key default gen_random_uuid(), campaign_id uuid not null references public.am_recruitment_campaigns(id) on delete cascade,
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  application_id uuid references public.am_candidate_applications(id) on delete set null,
  outcome text not null check (outcome in ('offer','hired','rejected','withdrawn','reserve','not_selected')),
  decided_at timestamptz not null default now(), start_date date, employer_reference text, decision_reason text,
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(campaign_id, candidate_id)
);
create index if not exists idx_am_job_roles_employer on public.am_job_roles(employer_id);
create index if not exists idx_am_requirement_sets_role on public.am_requirement_sets(role_id);
create index if not exists idx_am_requirement_items_set on public.am_requirement_items(requirement_set_id);
create index if not exists idx_am_recruitment_campaigns_employer_role on public.am_recruitment_campaigns(employer_id, role_id);
create index if not exists idx_am_candidate_applications_candidate on public.am_candidate_applications(candidate_id);
create index if not exists idx_am_candidate_applications_campaign on public.am_candidate_applications(campaign_id);
create index if not exists idx_am_candidate_matches_candidate_role on public.am_candidate_matches(candidate_id, role_id);
create index if not exists idx_am_candidate_matches_campaign on public.am_candidate_matches(campaign_id);
create index if not exists idx_am_shortlists_campaign on public.am_shortlists(campaign_id);
create index if not exists idx_am_interviews_campaign_candidate on public.am_interviews(campaign_id, candidate_id);
create index if not exists idx_am_hiring_outcomes_candidate on public.am_hiring_outcomes(candidate_id);
alter table public.am_employer_organizations enable row level security;
alter table public.am_employer_contacts enable row level security;
alter table public.am_job_roles enable row level security;
alter table public.am_requirement_sets enable row level security;
alter table public.am_requirement_items enable row level security;
alter table public.am_recruitment_campaigns enable row level security;
alter table public.am_candidate_applications enable row level security;
alter table public.am_candidate_matches enable row level security;
alter table public.am_shortlists enable row level security;
alter table public.am_interviews enable row level security;
alter table public.am_interview_scores enable row level security;
alter table public.am_hiring_outcomes enable row level security;
create or replace view public.am_airline_employer_architecture_summary with (security_invoker = true) as
select (select count(*) from public.am_employer_organizations) employers,
(select count(*) from public.am_job_roles) roles,
(select count(*) from public.am_requirement_sets) requirement_sets,
(select count(*) from public.am_requirement_items) requirement_items,
(select count(*) from public.am_recruitment_campaigns) campaigns,
(select count(*) from public.am_candidate_applications) applications,
(select count(*) from public.am_candidate_matches) matches,
(select count(*) from public.am_shortlists) shortlisted,
(select count(*) from public.am_interviews) interviews,
(select count(*) from public.am_hiring_outcomes) outcomes;
update public.am_platform_modules set status='partial' where code in ('AIR-ORG','AIR-ROLE','AIR-REQ','AIR-CMP','AIR-MAT','AIR-SHL','AIR-HIR');
