-- BEGIN CANONICAL MIGRATION 0050 20260824121426 master_platform_architecture_v1
create table if not exists public.am_platform_architecture_versions (
  id uuid primary key default gen_random_uuid(),
  version_code text not null unique,
  version_name text not null,
  status text not null default 'frozen' check (status in ('draft','review','frozen','retired')),
  principles jsonb not null default '[]'::jsonb,
  notes text,
  created_at timestamptz not null default now(),
  frozen_at timestamptz
);
create table if not exists public.am_platform_domains (
  id uuid primary key default gen_random_uuid(),
  architecture_version_id uuid not null references public.am_platform_architecture_versions(id) on delete cascade,
  code text not null,
  name text not null,
  purpose text not null,
  sort_order int not null default 999,
  lifecycle_scope text,
  primary_output text,
  is_active boolean not null default true,
  unique(architecture_version_id, code)
);
create table if not exists public.am_platform_modules (
  id uuid primary key default gen_random_uuid(),
  domain_id uuid not null references public.am_platform_domains(id) on delete cascade,
  code text not null,
  name text not null,
  purpose text not null,
  module_type text not null default 'operational' check (module_type in ('operational','builder','engine','monitoring','governance','experience','reporting')),
  input_summary text,
  process_summary text,
  evidence_summary text,
  decision_summary text,
  output_summary text,
  sort_order int not null default 999,
  status text not null default 'planned' check (status in ('existing','partial','planned','future','retired')),
  unique(domain_id, code)
);
create table if not exists public.am_platform_screens (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references public.am_platform_modules(id) on delete cascade,
  code text not null,
  name text not null,
  screen_type text not null default 'workspace' check (screen_type in ('hub','workspace','dashboard','builder','register','viewer','report','portal','settings')),
  route_hint text,
  audience text[] not null default '{}',
  purpose text not null,
  sort_order int not null default 999,
  status text not null default 'planned' check (status in ('existing','partial','planned','future','retired')),
  unique(module_id, code)
);
create table if not exists public.am_platform_flows (
  id uuid primary key default gen_random_uuid(),
  architecture_version_id uuid not null references public.am_platform_architecture_versions(id) on delete cascade,
  code text not null,
  name text not null,
  trigger_text text not null,
  stages jsonb not null default '[]'::jsonb,
  final_output text,
  owner_domain_code text,
  unique(architecture_version_id, code)
);
create table if not exists public.am_platform_roles (
  id uuid primary key default gen_random_uuid(),
  architecture_version_id uuid not null references public.am_platform_architecture_versions(id) on delete cascade,
  code text not null,
  name text not null,
  portal_name text not null,
  scope_summary text not null,
  unique(architecture_version_id, code)
);
alter table public.am_platform_architecture_versions enable row level security;
alter table public.am_platform_domains enable row level security;
alter table public.am_platform_modules enable row level security;
alter table public.am_platform_screens enable row level security;
alter table public.am_platform_flows enable row level security;
alter table public.am_platform_roles enable row level security;
-- END CANONICAL MIGRATION 0050

-- BEGIN CANONICAL MIGRATION 0051 20260824123541 kids_aviation_reorganization_v3
create table if not exists public.kids_navigation_groups (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  purpose text not null,
  sort_order integer not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.kids_navigation_items (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.kids_navigation_groups(id) on delete cascade,
  code text not null unique,
  name text not null,
  description text not null,
  route_hint text,
  implementation_status text not null check (implementation_status in ('existing','partial','planned')),
  source_tables text[] not null default '{}',
  sort_order integer not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.kids_navigation_groups enable row level security;
alter table public.kids_navigation_items enable row level security;

insert into public.kids_navigation_groups(code,name,purpose,sort_order) values
('KOP','Operations & Learners','Operate the Kids system, learner access, progress and control tower.',10),
('KJP','Journey & Production','Design and produce levels, seasons, missions, scripts and artwork.',20),
('KCM','Content & Media','Manage stories, songs, audio, video and reusable media content.',30),
('KCA','Creative Activities','Manage coloring, worksheets, quizzes, activities and printables.',40),
('KCU','Characters & Universe','Govern characters, appearance, locations, timeline, aviation accuracy, IP and localization.',50),
('KRP','Rewards & Passport','Manage passports, stamps, badges, level completion and certificates.',60),
('KBP','Books & Publishing','Manage story, coloring and activity books plus publishing readiness.',70),
('KPS','Products & Store','Manage Kids commercial products, product instances, readiness and store links.',80)
on conflict (code) do update set name=excluded.name,purpose=excluded.purpose,sort_order=excluded.sort_order,is_active=true;

with g as (select id,code from public.kids_navigation_groups)
insert into public.kids_navigation_items(group_id,code,name,description,route_hint,implementation_status,source_tables,sort_order)
select g.id,x.code,x.name,x.description,x.route_hint,x.status,x.tables,x.sort_order
from g join (values
('KOP','KOP-CT','Kids Control Tower','System health, launch checks, alerts and operational oversight.','kids_control_tower.html','existing',array['kids_health_snapshots','kids_launch_checks','kids_launch_check_results','kids_system_alerts'],10),
('KOP','KOP-PM','Passport Manager','Create and manage Explorer Passports, profile photos and access keys.','kids_passports_admin.html','existing',array['kids_explorer_passports','kids_portal_access_tokens'],20),
('KOP','KOP-LE','Learner Experience','Private learner-facing Passport and mission experience.','kids_experience.html','existing',array['kids_explorer_passports','kids_portal_preferences','kids_experience_events'],30),
('KOP','KOP-LP','Learner Progress','Mission, season, level and certificate progression.','', 'existing',array['kids_passport_mission_progress','kids_passport_season_progress','kids_passport_level_progress','kids_certificates'],40),
('KJP','KJP-JM','Journey & Missions','Levels, seasons, missions, mission blueprints and learning matrix.','', 'existing',array['kids_levels','kids_seasons','kids_missions','kids_mission_blueprints','kids_learning_matrix'],10),
('KJP','KJP-AI','AI Production Studio','Generate and review mission drafts, scripts, artwork briefs and images.','kids_ai_studio.html','existing',array['kids_ai_projects','kids_ai_generations'],20),
('KJP','KJP-SA','Scripts & Artwork','Ten-page scripts, artwork pages, trackers and illustration assets.','', 'existing',array['kids_script_pages','kids_artwork_pages','kids_content_tracker','kids_illustration_assets'],30),
('KCM','KCM-ST','Stories','Narrative content library linked to missions and programs.','story_hangar.html','partial',array['kids_content_items','kids_content_assets'],10),
('KCM','KCM-MU','Music & Audio','Songs, audio and music assets for the Kids universe.','music_cabin.html','partial',array['kids_content_items','kids_content_assets'],20),
('KCM','KCM-VD','Video & Media','Video and reusable media experiences.','', 'planned',array['kids_content_items','kids_content_assets'],30),
('KCA','KCA-CO','Coloring','Coloring content and printable artwork.','coloring_corner.html','partial',array['kids_content_items','kids_content_assets'],10),
('KCA','KCA-ACT','Activities & Worksheets','Activities, worksheets, quizzes and printables.','activities.html','partial',array['kids_content_items','kids_content_assets'],20),
('KCU','KCU-CH','Characters','Approved characters, integration and appearance control.','', 'existing',array['kids_characters','kids_character_integration','kids_character_appearance_control'],10),
('KCU','KCU-WD','World & Locations','Universe locations and narrative timeline.','kids_world.html','existing',array['kids_location_library','kids_universe_timeline'],20),
('KCU','KCU-GV','Governance & Accuracy','Rulebook, governance rules and aviation accuracy.','', 'existing',array['kids_content_rulebook','kids_governance_rules','kids_aviation_accuracy_master'],30),
('KCU','KCU-IP','IP & Localization','IP master, brand assets, rights and localization.','', 'existing',array['kids_ip_master','kids_brand_asset_register','kids_asset_rights_rules','kids_localization_master'],40),
('KRP','KRP-PS','Explorer Passport','Passport structure, experience and progression rules.','kids_experience.html','existing',array['kids_explorer_passports','kids_passport_structure','kids_passport_progress_rules'],10),
('KRP','KRP-ST','Mission Stamps','Mission stamp types, rules and earned stamps.','', 'existing',array['kids_stamp_types','kids_stamp_rules','kids_stamps'],20),
('KRP','KRP-BD','Badges','Season and level reward rules and badge definitions.','badges.html','existing',array['kids_badges','kids_badge_rules'],30),
('KRP','KRP-CR','Certificates','Level completion and learner certificates.','', 'existing',array['kids_certificates'],40),
('KBP','KBP-BK','Books Library','Story, coloring and activity book catalog.','', 'existing',array['kids_books','kids_book_formats'],10),
('KBP','KBP-PR','Publishing Readiness','Rights, artwork, copy and publication readiness.','', 'existing',array['kids_publishing_dashboard','kids_commercial_readiness'],20),
('KPS','KPS-PC','Product Catalog','Kids product catalog separated from educational content.','wings_shop.html','existing',array['kids_product_catalog_master','kids_catalog_product_instances'],10),
('KPS','KPS-SL','Store Links','Commercial links between Kids products and the existing Store.','wings_shop.html','existing',array['kids_product_links','kids_catalog_product_instances'],20),
('KPS','KPS-CA','Commercial Readiness','Pricing, rights, copy and product sale readiness.','', 'existing',array['kids_commercial_readiness','kids_commercial_analytics'],30)
) as x(group_code,code,name,description,route_hint,status,tables,sort_order) on x.group_code=g.code
on conflict (code) do update set group_id=excluded.group_id,name=excluded.name,description=excluded.description,route_hint=excluded.route_hint,implementation_status=excluded.implementation_status,source_tables=excluded.source_tables,sort_order=excluded.sort_order,is_active=true;
-- END CANONICAL MIGRATION 0051

-- BEGIN CANONICAL MIGRATION 0052 20260824123847 phase4_talent_candidate_architecture
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
-- END CANONICAL MIGRATION 0052

-- BEGIN CANONICAL MIGRATION 0053 20260824124159 phase5_learning_exam_assessment_architecture
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
-- END CANONICAL MIGRATION 0053

-- BEGIN CANONICAL MIGRATION 0054 20260824124630 phase6_airline_employer_architecture_v2
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
-- END CANONICAL MIGRATION 0054

-- BEGIN CANONICAL MIGRATION 0055 20260824125151 am_phase7_core_intelligence_engines
create table if not exists public.am_evidence_type_registry (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  default_validity_days integer,
  verification_required boolean not null default true,
  status text not null default 'active' check (status in ('active','inactive','archived')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.am_evidence_type_registry(code,name,verification_required) values
('assessment_result','Assessment Result',true),('exam_result','Exam Result',true),('training_completion','Training Completion',true),('certificate','Certificate',true),('document','Document',true),('interview','Interview Evidence',true),('attendance','Attendance Evidence',true),('instructor_feedback','Instructor Feedback',true),('video','Video Evidence',true),('reference','Reference Evidence',true),('system_result','System Result',true)
on conflict (code) do nothing;

create table if not exists public.am_evidence_verifications (
  id uuid primary key default gen_random_uuid(),
  evidence_id uuid not null references public.am_candidate_evidence(id) on delete cascade,
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected','expired','revoked')),
  verification_method text,
  verified_by uuid,
  verified_at timestamptz,
  notes text,
  evidence_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists am_evidence_verifications_evidence_idx on public.am_evidence_verifications(evidence_id,created_at desc);

create table if not exists public.am_candidate_facts (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  fact_code text not null,
  fact_category text,
  value_json jsonb not null,
  source_type text not null default 'manual' check (source_type in ('manual','evidence','assessment','exam','document','system','import')),
  source_evidence_id uuid references public.am_candidate_evidence(id) on delete set null,
  verification_status text not null default 'unverified' check (verification_status in ('unverified','verified','rejected','expired','revoked')),
  valid_from timestamptz,
  valid_until timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists am_candidate_facts_candidate_code_idx on public.am_candidate_facts(candidate_id,fact_code,created_at desc);

create table if not exists public.am_competency_frameworks (
  id uuid primary key default gen_random_uuid(),
  framework_code text not null unique,
  name text not null,
  description text,
  version_no integer not null default 1,
  status text not null default 'draft' check (status in ('draft','active','retired','archived')),
  effective_from timestamptz,
  effective_to timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_competencies (
  id uuid primary key default gen_random_uuid(),
  framework_id uuid not null references public.am_competency_frameworks(id) on delete cascade,
  competency_code text not null,
  name text not null,
  description text,
  category text,
  parent_competency_id uuid references public.am_competencies(id) on delete set null,
  scale_min numeric not null default 0,
  scale_max numeric not null default 100,
  sort_order integer not null default 0,
  status text not null default 'active' check (status in ('active','inactive','archived')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(framework_id,competency_code)
);

create table if not exists public.am_candidate_competency_ratings (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  competency_id uuid not null references public.am_competencies(id) on delete cascade,
  rating numeric not null,
  rating_status text not null default 'provisional' check (rating_status in ('provisional','verified','superseded','revoked')),
  source_method text not null default 'manual',
  calculated_at timestamptz not null default now(),
  valid_until timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists am_candidate_competency_candidate_idx on public.am_candidate_competency_ratings(candidate_id,competency_id,calculated_at desc);

create table if not exists public.am_competency_evidence_links (
  id uuid primary key default gen_random_uuid(),
  rating_id uuid not null references public.am_candidate_competency_ratings(id) on delete cascade,
  evidence_id uuid not null references public.am_candidate_evidence(id) on delete cascade,
  contribution_weight numeric,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(rating_id,evidence_id)
);

create table if not exists public.am_requirement_evaluation_runs (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  requirement_set_id uuid not null references public.am_requirement_sets(id) on delete cascade,
  campaign_id uuid references public.am_recruitment_campaigns(id) on delete set null,
  candidate_match_id uuid references public.am_candidate_matches(id) on delete set null,
  run_status text not null default 'running' check (run_status in ('running','completed','failed','cancelled')),
  mandatory_met boolean,
  overall_score numeric,
  matched_count integer not null default 0,
  gap_count integer not null default 0,
  manual_review_count integer not null default 0,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  engine_version text not null default 'REQ-1.0',
  input_snapshot jsonb not null default '{}'::jsonb,
  result_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists am_req_eval_candidate_idx on public.am_requirement_evaluation_runs(candidate_id,created_at desc);

create table if not exists public.am_requirement_evaluation_results (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.am_requirement_evaluation_runs(id) on delete cascade,
  requirement_item_id uuid not null references public.am_requirement_items(id) on delete cascade,
  evaluation_status text not null check (evaluation_status in ('met','gap','manual_review','not_applicable')),
  mandatory boolean not null default false,
  weight numeric,
  actual_value jsonb,
  expected_value jsonb,
  evidence_id uuid references public.am_candidate_evidence(id) on delete set null,
  fact_id uuid references public.am_candidate_facts(id) on delete set null,
  explanation text,
  evaluated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique(run_id,requirement_item_id)
);

create table if not exists public.am_decision_records (
  id uuid primary key default gen_random_uuid(),
  decision_code text not null,
  subject_type text not null,
  subject_id uuid,
  candidate_id uuid references public.am_candidate_records(id) on delete set null,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  decision_type text not null,
  decision_value text not null,
  decision_status text not null default 'proposed' check (decision_status in ('proposed','approved','rejected','superseded','revoked','final')),
  decision_source text not null default 'human' check (decision_source in ('human','rule','system','ai','hybrid')),
  rule_version text,
  rationale text,
  decided_by uuid,
  decided_at timestamptz not null default now(),
  input_snapshot jsonb not null default '{}'::jsonb,
  output_snapshot jsonb not null default '{}'::jsonb,
  supersedes_decision_id uuid references public.am_decision_records(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists am_decision_candidate_idx on public.am_decision_records(candidate_id,decided_at desc);

create table if not exists public.am_decision_evidence_links (
  id uuid primary key default gen_random_uuid(),
  decision_id uuid not null references public.am_decision_records(id) on delete cascade,
  evidence_id uuid not null references public.am_candidate_evidence(id) on delete cascade,
  role text not null default 'supporting' check (role in ('supporting','contradicting','required','context')),
  created_at timestamptz not null default now(),
  unique(decision_id,evidence_id)
);

create table if not exists public.am_workflow_templates (
  id uuid primary key default gen_random_uuid(),
  workflow_code text not null unique,
  name text not null,
  domain_code text,
  description text,
  version_no integer not null default 1,
  status text not null default 'draft' check (status in ('draft','active','retired','archived')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_workflow_steps (
  id uuid primary key default gen_random_uuid(),
  workflow_template_id uuid not null references public.am_workflow_templates(id) on delete cascade,
  step_code text not null,
  name text not null,
  step_type text not null default 'task' check (step_type in ('task','review','approval','decision','notification','system')),
  sort_order integer not null default 0,
  required boolean not null default true,
  role_code text,
  sla_hours numeric,
  entry_rule jsonb not null default '{}'::jsonb,
  completion_rule jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  unique(workflow_template_id,step_code)
);

create table if not exists public.am_workflow_instances (
  id uuid primary key default gen_random_uuid(),
  workflow_template_id uuid not null references public.am_workflow_templates(id) on delete restrict,
  subject_type text not null,
  subject_id uuid,
  candidate_id uuid references public.am_candidate_records(id) on delete set null,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  status text not null default 'active' check (status in ('active','paused','completed','cancelled','failed')),
  current_step_code text,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  context jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.am_workflow_tasks (
  id uuid primary key default gen_random_uuid(),
  workflow_instance_id uuid not null references public.am_workflow_instances(id) on delete cascade,
  workflow_step_id uuid references public.am_workflow_steps(id) on delete set null,
  task_code text not null,
  title text not null,
  assigned_to uuid,
  assigned_role text,
  status text not null default 'pending' check (status in ('pending','in_progress','waiting','completed','cancelled','failed')),
  priority text not null default 'normal' check (priority in ('low','normal','high','critical')),
  due_at timestamptz,
  completed_at timestamptz,
  outcome jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists am_workflow_tasks_instance_idx on public.am_workflow_tasks(workflow_instance_id,status);

create table if not exists public.am_approval_records (
  id uuid primary key default gen_random_uuid(),
  workflow_instance_id uuid references public.am_workflow_instances(id) on delete cascade,
  task_id uuid references public.am_workflow_tasks(id) on delete set null,
  subject_type text not null,
  subject_id uuid,
  approval_type text not null,
  approval_status text not null default 'pending' check (approval_status in ('pending','approved','rejected','cancelled','expired')),
  requested_by uuid,
  requested_at timestamptz not null default now(),
  decided_by uuid,
  decided_at timestamptz,
  comments text,
  evidence_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.am_communications (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid references public.am_candidate_records(id) on delete set null,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  employer_id uuid references public.am_employer_organizations(id) on delete set null,
  campaign_id uuid references public.am_recruitment_campaigns(id) on delete set null,
  channel text not null check (channel in ('email','whatsapp','sms','phone','meeting','interview','notification','portal','other')),
  direction text not null default 'internal' check (direction in ('inbound','outbound','internal')),
  subject text,
  summary text not null,
  communication_status text not null default 'recorded' check (communication_status in ('draft','scheduled','sent','delivered','failed','received','recorded','cancelled')),
  occurred_at timestamptz not null default now(),
  created_by uuid,
  external_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists am_communications_candidate_idx on public.am_communications(candidate_id,occurred_at desc);

create table if not exists public.am_communication_participants (
  id uuid primary key default gen_random_uuid(),
  communication_id uuid not null references public.am_communications(id) on delete cascade,
  participant_type text not null check (participant_type in ('candidate','guardian','staff','employer_contact','institution','external')),
  participant_id uuid,
  display_name text,
  address text,
  participant_role text,
  created_at timestamptz not null default now()
);

create table if not exists public.am_intelligence_events (
  id uuid primary key default gen_random_uuid(),
  event_code text not null,
  event_type text not null,
  domain_code text,
  candidate_id uuid references public.am_candidate_records(id) on delete set null,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  subject_type text,
  subject_id uuid,
  source_system text not null default 'aviation_matrix',
  source_table text,
  source_id uuid,
  event_at timestamptz not null default now(),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists am_intelligence_events_candidate_idx on public.am_intelligence_events(candidate_id,event_at desc);

create or replace function public.am_evaluate_candidate_requirements(p_candidate_id uuid,p_requirement_set_id uuid,p_campaign_id uuid default null,p_candidate_match_id uuid default null)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_run uuid;
  r record;
  v_evidence public.am_candidate_evidence%rowtype;
  v_fact public.am_candidate_facts%rowtype;
  v_status text;
  v_actual jsonb;
  v_met int := 0;
  v_gap int := 0;
  v_manual int := 0;
  v_total_weight numeric := 0;
  v_met_weight numeric := 0;
  v_mandatory_met boolean := true;
  v_operator text;
  v_expected_text text;
  v_actual_text text;
begin
  insert into public.am_requirement_evaluation_runs(candidate_id,requirement_set_id,campaign_id,candidate_match_id,input_snapshot)
  values(p_candidate_id,p_requirement_set_id,p_campaign_id,p_candidate_match_id,jsonb_build_object('candidate_id',p_candidate_id,'requirement_set_id',p_requirement_set_id,'campaign_id',p_campaign_id)) returning id into v_run;

  for r in select * from public.am_requirement_items where requirement_set_id=p_requirement_set_id and status='active' order by sort_order,id loop
    v_evidence := null; v_fact := null; v_status := 'manual_review'; v_actual := null; v_operator := coalesce(r.operator,'exists');

    if nullif(r.metadata->>'fact_code','') is not null then
      select * into v_fact from public.am_candidate_facts f
      where f.candidate_id=p_candidate_id and f.fact_code=(r.metadata->>'fact_code')
        and f.verification_status in ('verified','unverified')
        and (f.valid_until is null or f.valid_until>=now())
      order by (f.verification_status='verified') desc,f.created_at desc limit 1;
      if found then
        v_actual := v_fact.value_json;
        v_expected_text := coalesce(r.expected_value->>'value',trim(both '"' from coalesce(r.expected_value::text,'')));
        v_actual_text := coalesce(v_actual->>'value',trim(both '"' from v_actual::text));
        if v_operator in ('exists','present') then v_status:='met';
        elsif v_operator in ('eq','=') then v_status:=case when v_actual_text=v_expected_text then 'met' else 'gap' end;
        elsif v_operator in ('neq','!=') then v_status:=case when v_actual_text<>v_expected_text then 'met' else 'gap' end;
        elsif v_operator in ('gte','>=','lte','<=','gt','>','lt','<') and v_actual_text ~ '^-?[0-9]+([.][0-9]+)?$' and v_expected_text ~ '^-?[0-9]+([.][0-9]+)?$' then
          if v_operator in ('gte','>=') then v_status:=case when v_actual_text::numeric>=v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('lte','<=') then v_status:=case when v_actual_text::numeric<=v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('gt','>') then v_status:=case when v_actual_text::numeric>v_expected_text::numeric then 'met' else 'gap' end;
          else v_status:=case when v_actual_text::numeric<v_expected_text::numeric then 'met' else 'gap' end; end if;
        else v_status:='manual_review'; end if;
      else
        v_status:=case when r.is_mandatory then 'gap' else 'manual_review' end;
      end if;
    elsif r.evidence_type is not null then
      select * into v_evidence from public.am_candidate_evidence e
      where e.candidate_id=p_candidate_id and e.evidence_type=r.evidence_type
        and e.status in ('verified','accepted','valid','final')
        and (e.valid_until is null or e.valid_until>=now())
      order by e.verified_at desc nulls last,e.issued_at desc nulls last,e.created_at desc limit 1;
      if found then
        v_actual:=jsonb_build_object('evidence_id',v_evidence.id,'score',v_evidence.score,'status',v_evidence.status,'valid_until',v_evidence.valid_until);
        if v_operator in ('exists','present') then v_status:='met';
        elsif v_evidence.score is not null and r.expected_value is not null and coalesce(r.expected_value->>'value','') ~ '^-?[0-9]+([.][0-9]+)?$' then
          v_expected_text:=r.expected_value->>'value';
          if v_operator in ('gte','>=') then v_status:=case when v_evidence.score>=v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('lte','<=') then v_status:=case when v_evidence.score<=v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('gt','>') then v_status:=case when v_evidence.score>v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('lt','<') then v_status:=case when v_evidence.score<v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('eq','=') then v_status:=case when v_evidence.score=v_expected_text::numeric then 'met' else 'gap' end;
          else v_status:='manual_review'; end if;
        else v_status:='manual_review'; end if;
      else
        v_status:=case when r.is_mandatory then 'gap' else 'manual_review' end;
      end if;
    else
      v_status:='manual_review';
    end if;

    insert into public.am_requirement_evaluation_results(run_id,requirement_item_id,evaluation_status,mandatory,weight,actual_value,expected_value,evidence_id,fact_id,explanation)
    values(v_run,r.id,v_status,r.is_mandatory,coalesce(r.weight,1),v_actual,r.expected_value,v_evidence.id,v_fact.id,
      case v_status when 'met' then 'Requirement satisfied by current candidate fact/evidence.' when 'gap' then 'Requirement not satisfied or required evidence is missing.' else 'Automatic evaluation is insufficient; human review required.' end);

    v_total_weight:=v_total_weight+coalesce(r.weight,1);
    if v_status='met' then v_met:=v_met+1; v_met_weight:=v_met_weight+coalesce(r.weight,1); end if;
    if v_status='gap' then v_gap:=v_gap+1; end if;
    if v_status='manual_review' then v_manual:=v_manual+1; end if;
    if r.is_mandatory and v_status<>'met' then v_mandatory_met:=false; end if;
  end loop;

  update public.am_requirement_evaluation_runs set run_status='completed',mandatory_met=v_mandatory_met,
    overall_score=case when v_total_weight=0 then null else round((v_met_weight/v_total_weight)*100,2) end,
    matched_count=v_met,gap_count=v_gap,manual_review_count=v_manual,completed_at=now(),
    result_snapshot=jsonb_build_object('matched',v_met,'gaps',v_gap,'manual_review',v_manual,'mandatory_met',v_mandatory_met)
  where id=v_run;

  if p_candidate_match_id is not null then
    update public.am_candidate_matches m set match_status=case when v_mandatory_met and v_gap=0 and v_manual=0 then 'qualified' when not v_mandatory_met then 'gap' else 'manual_review' end,
      overall_score=(select overall_score from public.am_requirement_evaluation_runs where id=v_run),mandatory_met=v_mandatory_met,matched_count=v_met,gap_count=v_gap,evaluated_at=now(),
      evaluation_snapshot=jsonb_build_object('requirement_run_id',v_run,'manual_review_count',v_manual)
    where m.id=p_candidate_match_id;
  end if;

  insert into public.am_intelligence_events(event_code,event_type,domain_code,candidate_id,subject_type,subject_id,source_table,source_id,payload)
  values('REQUIREMENT_EVALUATED','requirement_evaluation','AIR',p_candidate_id,'requirement_set',p_requirement_set_id,'am_requirement_evaluation_runs',v_run,jsonb_build_object('matched',v_met,'gaps',v_gap,'manual_review',v_manual,'mandatory_met',v_mandatory_met));
  return v_run;
exception when others then
  if v_run is not null then update public.am_requirement_evaluation_runs set run_status='failed',completed_at=now(),result_snapshot=jsonb_build_object('error',sqlerrm) where id=v_run; end if;
  raise;
end;
$$;
revoke all on function public.am_evaluate_candidate_requirements(uuid,uuid,uuid,uuid) from public,anon,authenticated;

create or replace view public.am_core_intelligence_summary with (security_invoker=true) as
select
 (select count(*) from public.am_evidence_type_registry) evidence_types,
 (select count(*) from public.am_candidate_facts) candidate_facts,
 (select count(*) from public.am_competency_frameworks) competency_frameworks,
 (select count(*) from public.am_competencies) competencies,
 (select count(*) from public.am_candidate_competency_ratings) competency_ratings,
 (select count(*) from public.am_requirement_evaluation_runs) requirement_runs,
 (select count(*) from public.am_decision_records) decisions,
 (select count(*) from public.am_workflow_templates) workflow_templates,
 (select count(*) from public.am_workflow_instances) workflow_instances,
 (select count(*) from public.am_workflow_tasks) workflow_tasks,
 (select count(*) from public.am_approval_records) approvals,
 (select count(*) from public.am_communications) communications,
 (select count(*) from public.am_intelligence_events) intelligence_events;
revoke all on public.am_core_intelligence_summary from anon,authenticated;

alter table public.am_evidence_type_registry enable row level security;
alter table public.am_evidence_verifications enable row level security;
alter table public.am_candidate_facts enable row level security;
alter table public.am_competency_frameworks enable row level security;
alter table public.am_competencies enable row level security;
alter table public.am_candidate_competency_ratings enable row level security;
alter table public.am_competency_evidence_links enable row level security;
alter table public.am_requirement_evaluation_runs enable row level security;
alter table public.am_requirement_evaluation_results enable row level security;
alter table public.am_decision_records enable row level security;
alter table public.am_decision_evidence_links enable row level security;
alter table public.am_workflow_templates enable row level security;
alter table public.am_workflow_steps enable row level security;
alter table public.am_workflow_instances enable row level security;
alter table public.am_workflow_tasks enable row level security;
alter table public.am_approval_records enable row level security;
alter table public.am_communications enable row level security;
alter table public.am_communication_participants enable row level security;
alter table public.am_intelligence_events enable row level security;

update public.am_platform_modules set status='partial' where code in ('PLT-CMP','PLT-WF','PLT-DEC','PLT-COM','AIR-REQ','TAL-EVD');
-- END CANONICAL MIGRATION 0055

-- BEGIN CANONICAL MIGRATION 0056 20260824130248 phase8_dashboards_reports_final_integration_v3
create table if not exists public.am_report_templates (id uuid primary key default gen_random_uuid(),template_code text not null unique,name text not null,report_type text not null,subject_type text not null,version_no integer not null default 1,status text not null default 'draft',sections jsonb not null default '[]'::jsonb,output_formats text[] not null default array['html']::text[],metadata jsonb not null default '{}'::jsonb,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.am_report_snapshots (id uuid primary key default gen_random_uuid(),report_code text not null unique,template_id uuid references public.am_report_templates(id) on delete set null,subject_type text not null,subject_id uuid not null,candidate_id uuid references public.am_candidate_records(id) on delete set null,case_id uuid references public.am_candidate_cases(id) on delete set null,report_type text not null,status text not null default 'draft',title text not null,data_snapshot jsonb not null default '{}'::jsonb,verification_code text unique,generated_at timestamptz not null default now(),approved_at timestamptz,approved_by uuid,supersedes_report_id uuid references public.am_report_snapshots(id) on delete set null,metadata jsonb not null default '{}'::jsonb,created_at timestamptz not null default now());
create table if not exists public.am_report_exports (id uuid primary key default gen_random_uuid(),report_snapshot_id uuid not null references public.am_report_snapshots(id) on delete cascade,export_format text not null,storage_bucket text,storage_path text,export_status text not null default 'pending',file_hash text,generated_at timestamptz,expires_at timestamptz,metadata jsonb not null default '{}'::jsonb,created_at timestamptz not null default now());
create table if not exists public.am_dashboard_definitions (id uuid primary key default gen_random_uuid(),dashboard_code text not null unique,name text not null,audience_role text not null,domain_code text,status text not null default 'active',widget_config jsonb not null default '[]'::jsonb,metadata jsonb not null default '{}'::jsonb,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.am_dashboard_snapshots (id uuid primary key default gen_random_uuid(),dashboard_id uuid references public.am_dashboard_definitions(id) on delete cascade,subject_type text,subject_id uuid,candidate_id uuid references public.am_candidate_records(id) on delete cascade,snapshot_data jsonb not null default '{}'::jsonb,snapshot_at timestamptz not null default now(),metadata jsonb not null default '{}'::jsonb);
create table if not exists public.am_portal_navigation_registry (id uuid primary key default gen_random_uuid(),portal_code text not null,hub_code text,item_code text not null unique,label text not null,route text,item_type text not null default 'tool',status text not null default 'planned',sort_order integer not null default 999,role_visibility text[] not null default array['staff']::text[],metadata jsonb not null default '{}'::jsonb,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
alter table public.am_report_templates enable row level security;alter table public.am_report_snapshots enable row level security;alter table public.am_report_exports enable row level security;alter table public.am_dashboard_definitions enable row level security;alter table public.am_dashboard_snapshots enable row level security;alter table public.am_portal_navigation_registry enable row level security;
revoke all on public.am_report_templates,public.am_report_snapshots,public.am_report_exports,public.am_dashboard_definitions,public.am_dashboard_snapshots,public.am_portal_navigation_registry from anon,authenticated;
create or replace view public.am_candidate_360_dashboard with (security_invoker=true) as select cr.id candidate_id,cr.candidate_number,p.full_name,cr.lifecycle_stage,cr.activation_status,cr.activated_at,cr.completed_at,(select count(*) from public.am_candidate_cases c where c.candidate_id=cr.id) case_count,(select count(*) from public.am_candidate_evidence e where e.candidate_id=cr.id) evidence_count,(select count(*) from public.am_candidate_evidence e where e.candidate_id=cr.id and e.status='verified') verified_evidence_count,(select count(*) from public.am_candidate_documents d where d.candidate_id=cr.id) document_count,(select count(*) from public.am_candidate_documents d where d.candidate_id=cr.id and d.verification_status='verified') verified_document_count,(select count(*) from public.am_exam_results er where er.candidate_id=cr.id and er.result_status='final') final_exam_count,(select avg(er.overall_score) from public.am_exam_results er where er.candidate_id=cr.id and er.result_status='final') avg_exam_score,(select count(*) from public.am_learning_credentials lc where lc.candidate_id=cr.id and lc.status in ('issued','active','valid')) active_credential_count,(select count(*) from public.am_candidate_development_plans dp where dp.candidate_id=cr.id and dp.status not in ('completed','cancelled')) open_development_plans,(select count(*) from public.am_candidate_matches m where m.candidate_id=cr.id) match_count,(select max(m.overall_score) from public.am_candidate_matches m where m.candidate_id=cr.id) best_match_score,(select count(*) from public.am_decision_records dr where dr.candidate_id=cr.id and dr.decision_status='final') final_decision_count,greatest(coalesce((select max(e.created_at) from public.am_candidate_evidence e where e.candidate_id=cr.id),cr.updated_at),coalesce((select max(c.updated_at) from public.am_candidate_cases c where c.candidate_id=cr.id),cr.updated_at),cr.updated_at) last_activity_at from public.am_candidate_records cr join public.am_persons p on p.id=cr.person_id;
create or replace view public.am_candidate_exam_transcript with (security_invoker=true) as select er.candidate_id,cr.candidate_number,p.full_name,ed.code exam_code,ed.name exam_name,ed.exam_type,ea.attempt_no,ea.integrity_status,er.overall_score,er.pass_status,er.result_status,er.finalized_at,er.strengths,er.gaps from public.am_exam_results er join public.am_exam_attempts ea on ea.id=er.attempt_id join public.am_exam_versions ev on ev.id=ea.exam_version_id join public.am_exam_definitions ed on ed.id=ev.exam_id join public.am_candidate_records cr on cr.id=er.candidate_id join public.am_persons p on p.id=cr.person_id;
create or replace view public.am_candidate_readiness_summary with (security_invoker=true) as select r.candidate_id,cr.candidate_number,p.full_name,r.requirement_set_id,rs.name requirement_set_name,jr.role_name,eo.organization_name employer_name,r.run_status,r.mandatory_met,r.overall_score,r.matched_count,r.gap_count,r.manual_review_count,r.completed_at,r.engine_version from public.am_requirement_evaluation_runs r join public.am_candidate_records cr on cr.id=r.candidate_id join public.am_persons p on p.id=cr.person_id join public.am_requirement_sets rs on rs.id=r.requirement_set_id left join public.am_job_roles jr on jr.id=rs.role_id left join public.am_employer_organizations eo on eo.id=rs.employer_id;
create or replace view public.am_employer_recruitment_dashboard with (security_invoker=true) as select eo.id employer_id,eo.organization_code,eo.organization_name,count(distinct rc.id) campaign_count,count(distinct ca.id) application_count,count(distinct cm.id) match_count,count(distinct s.id) filter (where s.shortlist_status in ('approved','released')) shortlist_count,count(distinct i.id) interview_count,count(distinct ho.id) filter (where ho.outcome='hired') hired_count from public.am_employer_organizations eo left join public.am_recruitment_campaigns rc on rc.employer_id=eo.id left join public.am_candidate_applications ca on ca.campaign_id=rc.id left join public.am_candidate_matches cm on cm.campaign_id=rc.id left join public.am_shortlists s on s.campaign_id=rc.id left join public.am_interviews i on i.campaign_id=rc.id left join public.am_hiring_outcomes ho on ho.campaign_id=rc.id group by eo.id,eo.organization_code,eo.organization_name;
create or replace view public.am_management_overview with (security_invoker=true) as select (select count(*) from public.am_candidate_records) candidates,(select count(*) from public.am_candidate_records where lifecycle_stage in ('enrolled_learner','active_learner')) active_learners,(select count(*) from public.am_exam_results where result_status='final') final_exam_results,(select count(*) from public.am_learning_credentials where status in ('issued','active','valid')) active_credentials,(select count(*) from public.am_employer_organizations where status='active') active_employers,(select count(*) from public.am_recruitment_campaigns where status in ('open','active')) active_campaigns,(select count(*) from public.am_candidate_matches where match_status in ('qualified','conditional')) positive_matches,(select count(*) from public.am_hiring_outcomes where outcome='hired') hired_candidates,(select count(*) from public.am_workflow_tasks where status in ('open','assigned','in_progress')) open_workflow_tasks,(select count(*) from public.am_approval_records where approval_status='pending') pending_approvals;
revoke all on public.am_candidate_360_dashboard,public.am_candidate_exam_transcript,public.am_candidate_readiness_summary,public.am_employer_recruitment_dashboard,public.am_management_overview from anon,authenticated;
insert into public.am_report_templates(template_code,name,report_type,subject_type,status,sections,output_formats) values ('RPT-C360-ENTRY','Candidate Entry Profile','entry_profile','candidate','active','["Identity","Entry Assessment","Career Fit","Initial Gaps","Recommended Path"]'::jsonb,array['html','pdf']::text[]),('RPT-C360-LIVE','Candidate 360 Live Profile','live_profile','candidate','active','["Identity","Journey","Learning","Exams","Evidence","Credentials","Competencies","Development","Readiness","Timeline"]'::jsonb,array['html','pdf']::text[]),('RPT-C360-FINAL','Final Aviation Talent Dossier','final_dossier','candidate','active','["Executive Summary","Verified Identity","Education","Training","Exam History","Competencies","Behavioral","Language","Credentials","Evidence","Career Fit","Airline Matching","Readiness","Development History"]'::jsonb,array['html','pdf']::text[]),('RPT-READY','Airline Readiness Report','readiness_report','candidate','active','["Target Employer","Target Role","Requirement Summary","Mandatory Gates","Matched Requirements","Gaps","Manual Review","Evidence"]'::jsonb,array['html','pdf']::text[]),('RPT-GAP','Candidate Gap Report','gap_report','candidate','active','["Target Role","Current State","Missing Requirements","Expiring Evidence","Development Actions","Priority"]'::jsonb,array['html','pdf']::text[]),('RPT-EXAM','Exam Transcript','exam_transcript','candidate','active','["Candidate","Exam History","Attempts","Scores","Integrity","Strengths","Gaps","Credentials"]'::jsonb,array['html','pdf']::text[]) on conflict (template_code) do update set name=excluded.name,report_type=excluded.report_type,subject_type=excluded.subject_type,status=excluded.status,sections=excluded.sections,output_formats=excluded.output_formats,updated_at=now();
insert into public.am_dashboard_definitions(dashboard_code,name,audience_role,domain_code,status,widget_config) values ('DB-CAND-360','Candidate 360 Dashboard','staff','TALENT','active','["identity","lifecycle","journey","exams","evidence","documents","credentials","development","readiness","timeline"]'::jsonb),('DB-EMP-REC','Employer Recruitment Dashboard','staff','AIR','active','["campaigns","applications","matches","shortlists","interviews","hiring"]'::jsonb),('DB-MGMT','Management Overview','admin','PLAT','active','["candidates","learners","exams","credentials","employers","campaigns","matches","hiring","workflow","approvals"]'::jsonb) on conflict (dashboard_code) do update set name=excluded.name,audience_role=excluded.audience_role,domain_code=excluded.domain_code,status=excluded.status,widget_config=excluded.widget_config,updated_at=now();
insert into public.am_portal_navigation_registry(portal_code,hub_code,item_code,label,route,item_type,status,sort_order,role_visibility) values ('AM','TALENT','TAL-C360','Candidate 360 Dashboard','candidate_360_dashboard.html','dashboard','ready',10,array['staff','admin']::text[]),('AM','TALENT','TAL-DOSSIER','Candidate Dossier','candidate_dossier.html','report','ready',20,array['staff','admin']::text[]),('AM','LEARN','LRN-TRANSCRIPT','Exam Transcript','exam_transcript.html','report','ready',30,array['staff','admin']::text[]),('AM','AIR','AIR-READY','Airline Readiness','airline_readiness.html','report','ready',40,array['staff','admin']::text[]),('AM','AIR','AIR-DASH','Employer Dashboard','employer_dashboard.html','dashboard','ready',50,array['staff','admin']::text[]),('AM','PLAT','PLT-MGMT','Management Overview','management_dashboard.html','dashboard','ready',60,array['admin']::text[]) on conflict (item_code) do update set label=excluded.label,route=excluded.route,item_type=excluded.item_type,status=excluded.status,sort_order=excluded.sort_order,role_visibility=excluded.role_visibility,updated_at=now();
update public.am_platform_modules set status='partial' where code in ('TAL-CAN','TAL-DOS','PLT-RPT','AIR-MAT','LRN-SCR','LRN-CRD');
-- END CANONICAL MIGRATION 0056

-- BEGIN CANONICAL MIGRATION 0057 20260824130320 phase8_reporting_permission
insert into public.staff_permissions(user_id,permission_code,is_allowed)
select user_id,'platform.reporting',true from public.staff_permissions where permission_code='store.manage' and is_allowed=true
on conflict (user_id,permission_code) do update set is_allowed=true;
-- END CANONICAL MIGRATION 0057

-- BEGIN CANONICAL MIGRATION 0058 20260824170836 kam_character_identity_foundation_v1
create table if not exists public.kids_character_identity_profiles (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null unique references public.kids_characters(id) on delete cascade,
  character_code text not null,
  character_name text not null,
  identity_version text not null default '1.0',
  identity_status text not null default 'foundation_pending' check (identity_status in ('foundation_pending','draft','review','approved','superseded')),
  face_shape text,
  skin_tone text,
  eye_shape text,
  eye_color text,
  hair_style text,
  hair_color text,
  body_proportions text,
  age_appearance text,
  default_outfit text,
  signature_accessories text,
  silhouette_notes text,
  color_palette jsonb not null default '{}'::jsonb,
  immutable_traits jsonb not null default '[]'::jsonb,
  flexible_traits jsonb not null default '[]'::jsonb,
  do_not_change jsonb not null default '[]'::jsonb,
  source_code text,
  notes text,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_character_visual_rules (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.kids_characters(id) on delete cascade,
  character_code text not null,
  rule_category text not null,
  rule_text text not null,
  strictness text not null default 'hard_lock' check (strictness in ('hard_lock','soft_lock','guidance')),
  source_type text not null default 'source_derived' check (source_type in ('source_derived','production_rule','approved_art_reference')),
  source_code text,
  is_active boolean not null default true,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists kids_character_visual_rules_uq
on public.kids_character_visual_rules(character_id, rule_category, rule_text);

create table if not exists public.kids_character_reference_requirements (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.kids_characters(id) on delete cascade,
  character_code text not null,
  reference_type text not null check (reference_type in ('master_front','master_three_quarter','master_side','full_body','face_closeup','expressions_sheet','poses_sheet','outfit_sheet','accessories_sheet','color_palette')),
  required boolean not null default true,
  minimum_count integer not null default 1 check (minimum_count >= 1),
  status text not null default 'missing' check (status in ('missing','in_production','review','approved')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(character_id, reference_type)
);

create table if not exists public.kids_character_identity_versions (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.kids_characters(id) on delete cascade,
  identity_version text not null,
  snapshot jsonb not null,
  status text not null default 'draft' check (status in ('draft','approved','superseded')),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique(character_id, identity_version)
);

alter table public.kids_character_identity_profiles enable row level security;
alter table public.kids_character_visual_rules enable row level security;
alter table public.kids_character_reference_requirements enable row level security;
alter table public.kids_character_identity_versions enable row level security;

insert into public.kids_character_identity_profiles(character_id,character_code,character_name,source_code,notes)
select id,code,name,'KAM_08_CHARACTERS_MASTER','Visual DNA fields intentionally left undefined until approved master references are produced.'
from public.kids_characters
where code in ('AW-001','BJ-001','MC-001','CM-001','MX-001','DS-001','DM-001')
on conflict (character_id) do update set
 character_code=excluded.character_code,
 character_name=excluded.character_name,
 source_code=excluded.source_code,
 updated_at=now();

insert into public.kids_character_visual_rules(character_id,character_code,rule_category,rule_text,strictness,source_type,source_code,sort_order)
select kc.id,kc.code,'appearance',x.rule,'hard_lock','source_derived','KAM_21_CHARACTER_APPEARANCE_CONTROL',10
from (values
 ('AW-001','Consistent hairstyle and explorer outfit'),
 ('BJ-001','Consistent travel outfit'),
 ('MC-001','Professional mentor appearance'),
 ('CM-001','Pilot uniform standards'),
 ('MX-001','Engineering attire standards')
) as x(code,rule)
join public.kids_characters kc on kc.code=x.code
on conflict do nothing;

insert into public.kids_character_visual_rules(character_id,character_code,rule_category,rule_text,strictness,source_type,source_code,sort_order)
select kc.id,kc.code,'continuity','Character identity must remain visually consistent across missions and production assets.','hard_lock','production_rule','Character Identity Foundation v1',20
from public.kids_characters kc
where kc.code in ('AW-001','BJ-001','MC-001','CM-001','MX-001','DS-001','DM-001')
on conflict do nothing;

insert into public.kids_character_reference_requirements(character_id,character_code,reference_type,required,minimum_count,notes)
select kc.id,kc.code,r.reference_type,true,r.minimum_count,r.notes
from public.kids_characters kc
cross join (values
 ('master_front',1,'Primary canonical identity reference'),
 ('master_three_quarter',1,'Canonical three-quarter identity reference'),
 ('master_side',1,'Canonical side-profile reference'),
 ('full_body',1,'Canonical full-body proportions and outfit reference'),
 ('face_closeup',1,'Face identity and feature reference'),
 ('expressions_sheet',1,'Approved core expression set'),
 ('poses_sheet',1,'Approved core pose set'),
 ('outfit_sheet',1,'Approved standard outfit construction'),
 ('accessories_sheet',1,'Approved signature accessories'),
 ('color_palette',1,'Approved character color palette')
) as r(reference_type,minimum_count,notes)
where kc.code in ('AW-001','BJ-001','MC-001','CM-001','MX-001','DS-001','DM-001')
on conflict (character_id,reference_type) do nothing;
-- END CANONICAL MIGRATION 0058

-- BEGIN CANONICAL MIGRATION 0059 20260824171814 kam_character_reference_assets_phase2
create table if not exists public.kids_character_reference_assets (
  id uuid primary key default gen_random_uuid(),
  character_id uuid references public.kids_characters(id) on delete cascade,
  character_code text not null,
  character_name text not null,
  asset_type text not null,
  asset_role text not null,
  source_file_name text,
  storage_path text,
  source_status text not null default 'prepared_local',
  approval_status text not null default 'source_locked_phase2',
  is_canonical boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.kids_character_reference_assets enable row level security;
revoke all on public.kids_character_reference_assets from anon, authenticated;

create unique index if not exists kids_character_reference_assets_uq
on public.kids_character_reference_assets(character_code, asset_type, asset_role);

insert into public.kids_character_reference_assets(character_id,character_code,character_name,asset_type,asset_role,source_file_name,source_status,approval_status,is_canonical,metadata)
select c.id,c.code,c.name,'master_source','identity_anchor',
  case c.code
    when 'AW-001' then '1000413299.png'
    when 'BJ-001' then '1000413327.png'
    when 'CM-001' then '1000413300.png'
    when 'DS-001' then '1000413301.png'
    when 'MX-001' then '1000413302.png'
    when 'TC-001' then '1000413304.png'
    when 'DM-001' then '1000413303.png'
  end,
  'prepared_local','source_locked_phase2',true,
  jsonb_build_object('phase',2,'policy','exact source reference; no generative alteration')
from public.kids_characters c
where c.code in ('AW-001','BJ-001','CM-001','DS-001','MX-001','TC-001','DM-001')
on conflict (character_code, asset_type, asset_role) do update set
  source_file_name=excluded.source_file_name,
  source_status='prepared_local',
  approval_status='source_locked_phase2',
  is_canonical=true,
  updated_at=now();

insert into public.kids_character_reference_assets(character_id,character_code,character_name,asset_type,asset_role,source_file_name,source_status,approval_status,is_canonical,metadata)
select c.id,c.code,c.name,x.asset_type,x.asset_role,
  case c.code
    when 'AW-001' then '1000413299.png'
    when 'BJ-001' then '1000413327.png'
    when 'CM-001' then '1000413300.png'
    when 'DS-001' then '1000413301.png'
    when 'MX-001' then '1000413302.png'
    when 'TC-001' then '1000413304.png'
    when 'DM-001' then '1000413303.png'
  end,
  'prepared_local','source_locked_phase2',true,
  jsonb_build_object('phase',2,'derived_from_exact_source_crop',true)
from public.kids_characters c
cross join (values ('full_body','canonical_crop'),('face_closeup','canonical_crop')) as x(asset_type,asset_role)
where c.code in ('AW-001','BJ-001','CM-001','DS-001','MX-001','TC-001','DM-001')
on conflict (character_code, asset_type, asset_role) do update set
  source_file_name=excluded.source_file_name,
  source_status='prepared_local',
  approval_status='source_locked_phase2',
  is_canonical=true,
  updated_at=now();
-- END CANONICAL MIGRATION 0059

