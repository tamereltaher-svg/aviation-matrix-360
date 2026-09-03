create sequence if not exists am_candidate_number_seq start 1001;

create table if not exists public.am_persons (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  date_of_birth date,
  email text,
  mobile text,
  current_city text,
  preferred_language text,
  person_status text not null default 'active' check (person_status in ('active','inactive','merged','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists am_persons_email_norm_uq on public.am_persons (lower(trim(email))) where email is not null and trim(email)<>'';
create unique index if not exists am_persons_mobile_norm_uq on public.am_persons ((regexp_replace(mobile,'\D','','g'))) where mobile is not null and trim(mobile)<>'';

create table if not exists public.am_candidate_records (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.am_persons(id) on delete restrict,
  candidate_number text not null unique default ('AM-C-'||lpad(nextval('am_candidate_number_seq')::text,7,'0')),
  legacy_candidate_profile_id uuid unique references public.candidate_profiles(id) on delete set null,
  legacy_lead_id uuid references public.aviation_interest_leads(id) on delete set null,
  lifecycle_stage text not null default 'applicant' check (lifecycle_stage in ('visitor','applicant','candidate','enrolled_learner','active_learner','completed','alumni','employed','inactive')),
  activation_status text not null default 'not_activated' check (activation_status in ('not_activated','pending_review','active','suspended','closed')),
  activated_at timestamptz,
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists am_candidate_records_person_active_uq on public.am_candidate_records(person_id) where activation_status <> 'closed';

create table if not exists public.am_candidate_cases (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_type text not null check (case_type in ('application','learning_journey','development','airline_application','recruitment_campaign','assessment','other')),
  case_ref text not null unique,
  title text not null,
  status text not null default 'open' check (status in ('draft','open','in_progress','on_hold','completed','cancelled','closed')),
  started_at timestamptz default now(),
  ended_at timestamptz,
  source_ref text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_candidate_timeline_events (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  event_type text not null,
  title text not null,
  detail text,
  actor_type text not null default 'system' check (actor_type in ('system','staff','candidate','guardian','instructor','examiner','employer','institution')),
  actor_ref uuid,
  visibility text not null default 'internal' check (visibility in ('internal','candidate','employer','shared')),
  evidence_ref uuid,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists am_candidate_timeline_candidate_idx on public.am_candidate_timeline_events(candidate_id,occurred_at desc);

create table if not exists public.am_candidate_evidence (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  evidence_type text not null check (evidence_type in ('assessment','exam','certificate','document','instructor_feedback','interview','attendance','training','video','reference','system_result','other')),
  source_system text not null default 'aviation_matrix',
  source_table text,
  source_id uuid,
  title text not null,
  summary text,
  status text not null default 'unverified' check (status in ('unverified','verified','expired','revoked','rejected')),
  issued_at timestamptz,
  valid_until timestamptz,
  verified_at timestamptz,
  verified_by uuid,
  score numeric,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists am_candidate_evidence_candidate_idx on public.am_candidate_evidence(candidate_id,created_at desc);

create table if not exists public.am_candidate_documents (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  evidence_id uuid references public.am_candidate_evidence(id) on delete set null,
  document_type text not null,
  document_number text,
  issuing_country text,
  issued_at date,
  expires_at date,
  storage_bucket text,
  storage_path text,
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected','expired','revoked')),
  verified_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists am_candidate_documents_candidate_idx on public.am_candidate_documents(candidate_id,document_type);

create table if not exists public.am_candidate_development_plans (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  plan_name text not null,
  status text not null default 'draft' check (status in ('draft','active','completed','cancelled','superseded')),
  objective text,
  target_role_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.am_candidate_development_actions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.am_candidate_development_plans(id) on delete cascade,
  competency_code text,
  title text not null,
  action_type text not null default 'development' check (action_type in ('training','assessment','practice','document','coaching','experience','development','other')),
  status text not null default 'planned' check (status in ('planned','booked','in_progress','completed','waived','cancelled')),
  target_date date,
  completed_at timestamptz,
  evidence_id uuid references public.am_candidate_evidence(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_candidate_dossier_snapshots (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  dossier_type text not null check (dossier_type in ('entry_profile','live_profile','final_dossier','employer_release','readiness_report','gap_report')),
  version_no integer not null default 1,
  status text not null default 'draft' check (status in ('draft','review','approved','released','superseded','archived')),
  payload jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  approved_at timestamptz,
  released_at timestamptz,
  created_by uuid,
  notes text,
  unique(candidate_id,dossier_type,version_no)
);

alter table public.am_persons enable row level security;
alter table public.am_candidate_records enable row level security;
alter table public.am_candidate_cases enable row level security;
alter table public.am_candidate_timeline_events enable row level security;
alter table public.am_candidate_evidence enable row level security;
alter table public.am_candidate_documents enable row level security;
alter table public.am_candidate_development_plans enable row level security;
alter table public.am_candidate_development_actions enable row level security;
alter table public.am_candidate_dossier_snapshots enable row level security;

-- Migrate existing candidate profiles into the canonical person/candidate layer without changing legacy tables.
insert into public.am_persons(full_name,date_of_birth,email,mobile,current_city,preferred_language)
select cp.full_name, cp.date_of_birth, cp.email, cp.mobile, cp.current_city, cp.preferred_language
from public.candidate_profiles cp
where not exists (
  select 1 from public.am_persons p
  where (cp.email is not null and trim(cp.email)<>'' and lower(trim(p.email))=lower(trim(cp.email)))
     or (cp.mobile is not null and trim(cp.mobile)<>'' and regexp_replace(p.mobile,'\D','','g')=regexp_replace(cp.mobile,'\D','','g'))
);

insert into public.am_candidate_records(person_id,legacy_candidate_profile_id,legacy_lead_id,lifecycle_stage,activation_status,metadata)
select p.id, cp.id, cp.lead_id,
  case when cp.profile_status in ('journey_ready') then 'candidate' else 'applicant' end,
  case when cp.profile_status in ('journey_ready') then 'active' else 'pending_review' end,
  jsonb_build_object('legacy_profile_status',cp.profile_status)
from public.candidate_profiles cp
join public.am_persons p on (
 (cp.email is not null and trim(cp.email)<>'' and lower(trim(p.email))=lower(trim(cp.email)))
 or (cp.mobile is not null and trim(cp.mobile)<>'' and regexp_replace(p.mobile,'\D','','g')=regexp_replace(cp.mobile,'\D','','g'))
)
where not exists (select 1 from public.am_candidate_records c where c.legacy_candidate_profile_id=cp.id)
on conflict do nothing;

insert into public.am_candidate_timeline_events(candidate_id,event_type,title,detail,actor_type,metadata,occurred_at)
select c.id,'legacy_profile_imported','Legacy candidate profile linked','Existing candidate profile linked into Talent Architecture Phase 4.','system',jsonb_build_object('legacy_candidate_profile_id',cp.id,'legacy_status',cp.profile_status),cp.created_at
from public.am_candidate_records c
join public.candidate_profiles cp on cp.id=c.legacy_candidate_profile_id
where not exists (select 1 from public.am_candidate_timeline_events e where e.candidate_id=c.id and e.event_type='legacy_profile_imported');

create or replace view public.am_candidate_360_summary with (security_invoker=true) as
select c.id as candidate_id,c.candidate_number,c.lifecycle_stage,c.activation_status,
       p.id as person_id,p.full_name,p.date_of_birth,p.email,p.mobile,p.current_city,p.preferred_language,
       (select count(*) from public.am_candidate_cases x where x.candidate_id=c.id) as case_count,
       (select count(*) from public.am_candidate_evidence x where x.candidate_id=c.id) as evidence_count,
       (select count(*) from public.am_candidate_documents x where x.candidate_id=c.id) as document_count,
       (select count(*) from public.am_candidate_timeline_events x where x.candidate_id=c.id) as timeline_event_count,
       (select max(x.occurred_at) from public.am_candidate_timeline_events x where x.candidate_id=c.id) as last_activity_at,
       c.created_at,c.updated_at
from public.am_candidate_records c join public.am_persons p on p.id=c.person_id;
