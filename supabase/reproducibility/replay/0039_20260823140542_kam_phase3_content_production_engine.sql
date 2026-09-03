begin;

-- Preserve the exact KAM_06 source fields on script pages.
alter table public.kids_script_pages add column if not exists page_code text;
alter table public.kids_script_pages add column if not exists page_role text;
alter table public.kids_script_pages add column if not exists page_objective text;
alter table public.kids_script_pages add column if not exists mission_title text;
alter table public.kids_script_pages add column if not exists big_question text;

-- Preserve the exact KAM_07 source fields on artwork pages.
alter table public.kids_artwork_pages add column if not exists page_code text;
alter table public.kids_artwork_pages add column if not exists page_role text;
alter table public.kids_artwork_pages add column if not exists artwork_objective text;
alter table public.kids_artwork_pages add column if not exists character_rule text;
alter table public.kids_artwork_pages add column if not exists background text;
alter table public.kids_artwork_pages add column if not exists text_area text;

create table if not exists public.kids_content_tracker (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null unique references public.kids_missions(id) on delete cascade,
  mission_code text not null unique,
  level_code text not null,
  season_code text not null,
  mission_code_short text not null,
  blueprint_status text not null default 'Not Started',
  script_status text not null default 'Not Started',
  artwork_status text not null default 'Not Started',
  coloring_status text not null default 'Not Started',
  activity_status text not null default 'Not Started',
  final_qa_status text not null default 'Not Started',
  overall_status text not null default 'Not Started',
  owner text,
  priority text not null default 'Medium',
  target_date date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_illustration_assets (
  id uuid primary key default gen_random_uuid(),
  asset_id text not null unique,
  category text not null,
  asset_name text not null,
  status text not null,
  storage_path text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_location_library (
  id uuid primary key default gen_random_uuid(),
  location_id text not null unique,
  location_name text not null,
  country text not null,
  usage text not null,
  reference_path text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- RLS: production-management tables are not directly writable/readable by public roles.
alter table public.kids_content_tracker enable row level security;
alter table public.kids_illustration_assets enable row level security;
alter table public.kids_location_library enable row level security;

-- Exact 10-page KAM_06 script template sourced from KAM_06_SCRIPT_PRODUCTION.xlsx.
with page_template(page_no,page_code,page_role,page_objective) as (
  values
    (1,'P01','Mission Start','Open curiosity and introduce the situation.'),
    (2,'P02','Big Question','Ask the main learning question.'),
    (3,'P03','Discovery 1','Show the first discovery.'),
    (4,'P04','Discovery 2','Add a second simple discovery.'),
    (5,'P05','Learning Moment','Explain the core learning point.'),
    (6,'P06','Adventure','Move the mission forward through action.'),
    (7,'P07','Challenge','Introduce a small problem or choice.'),
    (8,'P08','Solution','Solve the challenge with the learning goal.'),
    (9,'P09','Mission Success','Confirm the mission has been achieved.'),
    (10,'P10','Mission Complete','Summarize learning, stamp, and next mission hook.')
)
insert into public.kids_script_pages (
  mission_id,page_no,page_code,page_role,page_objective,mission_title,big_question,
  scene_title,narration,dialogue,learning_purpose,character_codes,production_notes,status
)
select
  m.id,t.page_no,t.page_code,t.page_role,t.page_objective,
  coalesce(m.title,m.name),m.big_question,
  t.page_role,
  'Narration to be written from blueprint.',
  'Dialogue to be mapped to selected characters.',
  t.page_objective,
  '{}'::text[],
  null,
  'Draft'
from public.kids_missions m
cross join page_template t
on conflict (mission_id,page_no) do update set
  page_code=excluded.page_code,
  page_role=excluded.page_role,
  page_objective=excluded.page_objective,
  mission_title=excluded.mission_title,
  big_question=excluded.big_question,
  scene_title=excluded.scene_title,
  narration=excluded.narration,
  dialogue=excluded.dialogue,
  learning_purpose=excluded.learning_purpose;

-- Exact KAM_07 production defaults sourced from KAM_07_ARTWORK_PRODUCTION.xlsx.
with page_template(page_no,page_code,page_role) as (
  values
    (1,'P01','Mission Start'),(2,'P02','Big Question'),(3,'P03','Discovery 1'),(4,'P04','Discovery 2'),
    (5,'P05','Learning Moment'),(6,'P06','Adventure'),(7,'P07','Challenge'),(8,'P08','Solution'),
    (9,'P09','Mission Success'),(10,'P10','Mission Complete')
)
insert into public.kids_artwork_pages (
  mission_id,page_no,page_code,page_role,artwork_objective,character_rule,background,text_area,
  scene_brief,background_brief,asset_requirements,text_safe_area,illustration_notes,status
)
select
  m.id,t.page_no,t.page_code,t.page_role,
  'Illustrate ' || lower(t.page_role) || ' for ' || coalesce(m.title,m.name) || '.',
  'No logo; no characters unless content team assigns them.',
  'Clean educational aviation setting.',
  'Leave safe text area.',
  'Illustrate ' || lower(t.page_role) || ' for ' || coalesce(m.title,m.name) || '.',
  'Clean educational aviation setting.',
  'No logo; no characters unless content team assigns them.',
  'Leave safe text area.',
  'Use approved style guide and character references when available.',
  'Draft'
from public.kids_missions m
cross join page_template t
on conflict (mission_id,page_no) do update set
  page_code=excluded.page_code,
  page_role=excluded.page_role,
  artwork_objective=excluded.artwork_objective,
  character_rule=excluded.character_rule,
  background=excluded.background,
  text_area=excluded.text_area,
  scene_brief=excluded.scene_brief,
  background_brief=excluded.background_brief,
  asset_requirements=excluded.asset_requirements,
  text_safe_area=excluded.text_safe_area,
  illustration_notes=excluded.illustration_notes;

-- KAM_13 Content Tracker: one production-control row for every mission.
insert into public.kids_content_tracker (
  mission_id,mission_code,level_code,season_code,mission_code_short,
  blueprint_status,script_status,artwork_status,coloring_status,activity_status,final_qa_status,overall_status,
  owner,priority,target_date,notes
)
select
  m.id,m.code,l.code,s.season_no,coalesce(m.mission_no,'M'||m.sort_order::text),
  'Not Started','Not Started','Not Started','Not Started','Not Started','Not Started','Not Started',
  null,'Medium',null,null
from public.kids_missions m
join public.kids_seasons s on s.id=m.season_id
join public.kids_levels l on l.id=s.level_id
on conflict (mission_id) do update set
  mission_code=excluded.mission_code,
  level_code=excluded.level_code,
  season_code=excluded.season_code,
  mission_code_short=excluded.mission_code_short;

-- KAM_19 Illustration Library exact seed.
insert into public.kids_illustration_assets(asset_id,category,asset_name,status) values
('AST-0001','Airport','Airport Terminal','Approved'),
('AST-0002','Airport','Check-In Counter','Approved'),
('AST-0003','Airport','Boarding Gate','Approved'),
('AST-0004','Travel','Passport','Approved'),
('AST-0005','Travel','Suitcase','Approved'),
('AST-0006','Aircraft','Aircraft Cabin','Approved'),
('AST-0007','Aircraft','Cockpit','Approved'),
('AST-0008','Airport','Control Tower','Approved'),
('AST-0009','Airport','Runway','Approved'),
('AST-0010','Airport','Baggage Claim','Approved')
on conflict (asset_id) do update set category=excluded.category,asset_name=excluded.asset_name,status=excluded.status;

-- KAM_20 Location Library exact seed.
insert into public.kids_location_library(location_id,location_name,country,usage) values
('LOC-0001','Home Bedroom','Generic','Story Start'),
('LOC-0002','Airport Entrance','Global','Travel'),
('LOC-0003','Check-In Area','Global','Airport'),
('LOC-0004','Security Checkpoint','Global','Airport'),
('LOC-0005','Boarding Gate','Global','Airport'),
('LOC-0006','Aircraft Cabin','Global','Flight'),
('LOC-0007','Cockpit','Global','Flight'),
('LOC-0008','Control Tower','Global','Operations'),
('LOC-0009','Baggage Claim','Global','Arrival')
on conflict (location_id) do update set location_name=excluded.location_name,country=excluded.country,usage=excluded.usage;

create or replace view public.kids_production_dashboard as
select
  (select count(*) from public.kids_missions) as total_missions,
  (select count(*) from public.kids_content_tracker where blueprint_status='Approved') as blueprint_approved,
  (select count(*) from public.kids_content_tracker where script_status='Approved') as script_approved,
  (select count(*) from public.kids_content_tracker where artwork_status='Approved') as artwork_approved,
  (select count(*) from public.kids_content_tracker where final_qa_status='Approved') as final_approved,
  (select count(*) from public.kids_script_pages) as script_pages,
  (select count(*) from public.kids_artwork_pages) as artwork_pages,
  (select count(*) from public.kids_illustration_assets) as illustration_assets,
  (select count(*) from public.kids_location_library) as locations;

commit;
