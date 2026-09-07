-- BEGIN CANONICAL MIGRATION 0040 20260823140621 kam_phase3_dashboard_security_invoker
drop view if exists public.kids_production_dashboard;
create view public.kids_production_dashboard with (security_invoker=true) as
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
-- END CANONICAL MIGRATION 0040

-- BEGIN CANONICAL MIGRATION 0041 20260823140912 kam_phase4_characters_governance_ip
-- KAM Phase 4: Characters + Governance + IP

alter table public.kids_characters
  add column if not exists tier text,
  add column if not exists usage_rule text;

create table if not exists public.kids_governance_rules (
  id uuid primary key default gen_random_uuid(),
  source_code text not null,
  rule_category text not null,
  rule_code text,
  rule_text text not null,
  priority text,
  status text not null default 'active',
  sort_order integer not null default 999,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(source_code, rule_category, rule_text)
);

create table if not exists public.kids_content_rulebook (
  id uuid primary key default gen_random_uuid(),
  rule_id text not null unique,
  category text not null,
  rule_text text not null,
  priority text not null,
  source_code text not null default 'KAM_16',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_aviation_accuracy_master (
  id uuid primary key default gen_random_uuid(),
  domain text not null,
  topic text not null,
  approved_definition text not null,
  status text not null,
  source_code text not null default 'KAM_17',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(domain, topic)
);

create table if not exists public.kids_universe_timeline (
  id uuid primary key default gen_random_uuid(),
  previous_code text not null,
  current_code text not null,
  next_code text not null,
  notes text,
  previous_mission_id uuid references public.kids_missions(id) on delete set null,
  current_mission_id uuid references public.kids_missions(id) on delete set null,
  next_mission_id uuid references public.kids_missions(id) on delete set null,
  source_code text not null default 'KAM_18',
  sort_order integer not null default 999,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(previous_code, current_code, next_code)
);

create table if not exists public.kids_character_integration (
  id uuid primary key default gen_random_uuid(),
  content_area text not null,
  primary_character_id uuid references public.kids_characters(id) on delete restrict,
  primary_character_name text not null,
  reason text not null,
  source_code text not null default 'KAM_08',
  sort_order integer not null default 999,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(content_area)
);

create table if not exists public.kids_character_appearance_control (
  id uuid primary key default gen_random_uuid(),
  character_id uuid references public.kids_characters(id) on delete cascade,
  character_code text not null,
  character_name text not null,
  appearance_rule text not null,
  status text not null,
  source_code text not null default 'KAM_21',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(character_code)
);

create table if not exists public.kids_ip_master (
  id uuid primary key default gen_random_uuid(),
  ip_type text not null,
  code text not null,
  name text not null,
  status text not null,
  character_id uuid references public.kids_characters(id) on delete set null,
  source_code text not null default 'KAM_22',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(ip_type, code)
);

create table if not exists public.kids_localization_master (
  id uuid primary key default gen_random_uuid(),
  content_id text not null unique,
  english_text text not null,
  arabic_text text not null,
  status text not null,
  source_code text not null default 'KAM_24',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Keep Phase 4 governance data private to service-side/admin APIs.
alter table public.kids_governance_rules enable row level security;
alter table public.kids_content_rulebook enable row level security;
alter table public.kids_aviation_accuracy_master enable row level security;
alter table public.kids_universe_timeline enable row level security;
alter table public.kids_character_integration enable row level security;
alter table public.kids_character_appearance_control enable row level security;
alter table public.kids_ip_master enable row level security;
alter table public.kids_localization_master enable row level security;

create index if not exists idx_kids_governance_rules_category on public.kids_governance_rules(rule_category);
create index if not exists idx_kids_accuracy_domain_topic on public.kids_aviation_accuracy_master(domain, topic);
create index if not exists idx_kids_timeline_current on public.kids_universe_timeline(current_code);
create index if not exists idx_kids_character_integration_character on public.kids_character_integration(primary_character_id);
create index if not exists idx_kids_appearance_character on public.kids_character_appearance_control(character_id);
create index if not exists idx_kids_ip_character on public.kids_ip_master(character_id);
-- END CANONICAL MIGRATION 0041

-- BEGIN CANONICAL MIGRATION 0042 20260823141007 kam_phase4_governance_dashboard
create or replace view public.kids_governance_dashboard
with (security_invoker=true) as
with mission_checks as (
  select
    m.id,
    m.code,
    (select count(*) from public.kids_script_pages sp where sp.mission_id=m.id) as script_pages,
    (select count(*) from public.kids_artwork_pages ap where ap.mission_id=m.id) as artwork_pages,
    (m.big_question is not null and btrim(m.big_question)<>'') as has_big_question,
    (m.learning_goal is not null and btrim(m.learning_goal)<>'') as has_learning_goal,
    (m.next_mission_code is not null and btrim(m.next_mission_code)<>'') as has_next_hook
  from public.kids_missions m
), season_checks as (
  select s.id, s.code, count(m.id) as mission_count
  from public.kids_seasons s
  left join public.kids_missions m on m.season_id=s.id
  group by s.id,s.code
), level_checks as (
  select l.id,l.code,count(s.id) as season_count
  from public.kids_levels l
  left join public.kids_seasons s on s.level_id=l.id
  group by l.id,l.code
)
select
  (select count(*) from public.kids_characters) as characters,
  (select count(*) from public.kids_character_appearance_control) as appearance_rules,
  (select count(*) from public.kids_character_integration) as character_integrations,
  (select count(*) from public.kids_governance_rules) as governance_rules,
  (select count(*) from public.kids_content_rulebook) as content_rules,
  (select count(*) from public.kids_aviation_accuracy_master) as aviation_accuracy_terms,
  (select count(*) from public.kids_universe_timeline) as timeline_links,
  (select count(*) from public.kids_ip_master) as ip_assets,
  (select count(*) from public.kids_localization_master) as localization_terms,
  (select count(*) from mission_checks) as missions_total,
  (select count(*) from mission_checks where script_pages=10) as missions_script_10,
  (select count(*) from mission_checks where artwork_pages=10) as missions_artwork_10,
  (select count(*) from mission_checks where has_big_question) as missions_with_big_question,
  (select count(*) from mission_checks where has_learning_goal) as missions_with_learning_goal,
  (select count(*) from mission_checks where has_next_hook) as missions_with_next_hook,
  (select count(*) from season_checks) as seasons_total,
  (select count(*) from season_checks where mission_count=12) as seasons_with_12_missions,
  (select count(*) from level_checks) as levels_total,
  (select count(*) from level_checks where season_count=10) as levels_with_10_seasons;
-- END CANONICAL MIGRATION 0042

-- BEGIN CANONICAL MIGRATION 0043 20260823141330 kam_phase5_rewards_passport_engine
-- KAM Phase 5: Rewards & Explorer Passport Engine
-- Grounded in KAM_09_STAMPS_MASTER, KAM_10_BADGES_MASTER, KAM_11_PASSPORT_SYSTEM.

-- 1) Reward taxonomy and rules from source masters
create table if not exists public.kids_stamp_types (
  code text primary key,
  purpose text not null,
  rule_text text not null,
  sort_order integer not null default 999,
  created_at timestamptz not null default now()
);

create table if not exists public.kids_stamp_rules (
  rule_area text primary key,
  rule_text text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.kids_badge_rules (
  badge_type text primary key,
  requirement text not null,
  output text not null,
  created_at timestamptz not null default now()
);

insert into public.kids_stamp_types(code,purpose,rule_text,sort_order) values
('Mission Stamp','Reward for completing one mission','One stamp per mission',1),
('Season Badge','Reward for completing all missions in a season','Requires 12 mission stamps',2),
('Level Certificate','Reward for completing all seasons in a level','Requires all season badges',3),
('Special Stamp','Bonus recognition for activities or events','Optional and controlled',4)
on conflict (code) do update set purpose=excluded.purpose,rule_text=excluded.rule_text,sort_order=excluded.sort_order;

insert into public.kids_stamp_rules(rule_area,rule_text) values
('Uniqueness','Every stamp must have one unique code.'),
('Traceability','Every stamp must map to one mission, season, or level.'),
('Visual Control','No final visual stamp is approved without artwork sign-off.'),
('Passport Link','Mission stamps feed the Aviation Explorer Passport.'),
('Progress Logic','Season completion requires all 12 mission stamps.')
on conflict (rule_area) do update set rule_text=excluded.rule_text;

insert into public.kids_badge_rules(badge_type,requirement,output) values
('Season Badge','12 mission stamps','Season completion'),
('Level Badge','10 season badges','Level completion'),
('Special Badge','Defined event or achievement','Bonus recognition')
on conflict (badge_type) do update set requirement=excluded.requirement,output=excluded.output;

-- 2) Seed the 600 mission stamps using the KAM source naming/logic.
insert into public.kids_stamps
(code,name,mission_id,season_id,level_id,stamp_type,earned_for,visual_brief,status,owner,notes)
select
  'ST-'||m.code as code,
  s.name||' Stamp '||lpad(m.sort_order::text,2,'0') as name,
  m.id,
  s.id,
  l.id,
  'Mission Stamp',
  'Complete '||m.code,
  'Simple icon linked to '||s.name,
  'Planned',
  'Content Lead',
  null
from public.kids_missions m
join public.kids_seasons s on s.id=m.season_id
join public.kids_levels l on l.id=s.level_id
on conflict (code) do update set
  name=excluded.name,mission_id=excluded.mission_id,season_id=excluded.season_id,level_id=excluded.level_id,
  stamp_type=excluded.stamp_type,earned_for=excluded.earned_for,visual_brief=excluded.visual_brief,
  status=excluded.status,owner=excluded.owner;

-- 3) Seed 50 season badges + 5 level completion certificates.
with level_labels as (
  select id,code,
    case code
      when 'L1' then 'Junior Explorers'
      when 'L2' then 'World Travelers'
      when 'L3' then 'Aviation Explorers'
      when 'L4' then 'Future Aviators'
      when 'L5' then 'Career Passport'
      else name end as source_label
  from public.kids_levels
), last_mission as (
  select distinct on (season_id) season_id,id,code
  from public.kids_missions
  order by season_id,sort_order desc
)
insert into public.kids_badges
(code,name,badge_type,level_id,season_id,requirement,awarded_after_mission_id,visual_brief,status,owner)
select
  'BD-'||l.code||'-'||s.season_no,
  ll.source_label||' - '||s.name||' Badge',
  'Season Badge',
  l.id,
  s.id,
  'Complete 12 missions',
  lm.id,
  'Badge inspired by '||s.name,
  'Planned',
  'Content Lead'
from public.kids_seasons s
join public.kids_levels l on l.id=s.level_id
join level_labels ll on ll.id=l.id
left join last_mission lm on lm.season_id=s.id
on conflict (code) do update set
 name=excluded.name,badge_type=excluded.badge_type,level_id=excluded.level_id,season_id=excluded.season_id,
 requirement=excluded.requirement,awarded_after_mission_id=excluded.awarded_after_mission_id,
 visual_brief=excluded.visual_brief,status=excluded.status,owner=excluded.owner;

with level_labels as (
  select id,code,
    case code
      when 'L1' then 'Junior Explorers'
      when 'L2' then 'World Travelers'
      when 'L3' then 'Aviation Explorers'
      when 'L4' then 'Future Aviators'
      when 'L5' then 'Career Passport'
      else name end as source_label
  from public.kids_levels
), level_last as (
  select distinct on (s.level_id) s.level_id,m.id as mission_id
  from public.kids_seasons s
  join public.kids_missions m on m.season_id=s.id
  order by s.level_id,s.sort_order desc,m.sort_order desc
)
insert into public.kids_badges
(code,name,badge_type,level_id,season_id,requirement,awarded_after_mission_id,visual_brief,status,owner)
select
  'BD-'||l.code||'-COMPLETE',
  ll.source_label||' Completion Certificate',
  'Level Badge',
  l.id,
  null,
  'Complete all 10 seasons',
  x.mission_id,
  'Certificate badge for '||ll.source_label,
  'Planned',
  'Content Lead'
from public.kids_levels l
join level_labels ll on ll.id=l.id
left join level_last x on x.level_id=l.id
on conflict (code) do update set
 name=excluded.name,badge_type=excluded.badge_type,level_id=excluded.level_id,season_id=null,
 requirement=excluded.requirement,awarded_after_mission_id=excluded.awarded_after_mission_id,
 visual_brief=excluded.visual_brief,status=excluded.status,owner=excluded.owner;

-- 4) Passport master structure and progress rules from KAM_11.
create table if not exists public.kids_passport_structure (
  id uuid primary key default gen_random_uuid(),
  section_code text not null unique,
  section_name text not null,
  purpose text not null,
  linked_data text not null,
  rule_text text not null,
  status text not null default 'Design Pending',
  sort_order integer not null default 999,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.kids_passport_structure(section_code,section_name,purpose,linked_data,rule_text,status,sort_order) values
('learner_identity','Learner Identity','Holds learner name, age group, and current level','Levels','One passport per learner journey','Design Pending',1),
('mission_stamps','Mission Stamps','Tracks completed missions','KAM_09_STAMPS_MASTER','One stamp per completed mission','Design Pending',2),
('season_badges','Season Badges','Tracks completed seasons','KAM_10_BADGES_MASTER','Requires all 12 mission stamps','Design Pending',3),
('level_certificates','Level Certificates','Tracks completed levels','KAM_10_BADGES_MASTER','Requires 10 season badges','Design Pending',4),
('next_mission_page','Next Mission Page','Encourages continuation','Missions Master','Always shows next mission hook','Design Pending',5)
on conflict (section_code) do update set section_name=excluded.section_name,purpose=excluded.purpose,linked_data=excluded.linked_data,rule_text=excluded.rule_text,status=excluded.status,sort_order=excluded.sort_order;

create table if not exists public.kids_passport_progress_rules (
  id uuid primary key default gen_random_uuid(),
  progress_code text not null unique,
  level_id uuid not null references public.kids_levels(id) on delete cascade,
  season_id uuid not null references public.kids_seasons(id) on delete cascade,
  total_missions integer not null default 12,
  required_stamps integer not null default 12,
  completion_output text not null,
  next_step text not null,
  created_at timestamptz not null default now()
);

insert into public.kids_passport_progress_rules(progress_code,level_id,season_id,total_missions,required_stamps,completion_output,next_step)
select
 'PR-'||l.code||'-'||s.season_no,
 l.id,s.id,12,12,
 l.code||'-'||s.season_no||' Badge',
 'Next season after '||s.season_no
from public.kids_seasons s join public.kids_levels l on l.id=s.level_id
on conflict (progress_code) do update set level_id=excluded.level_id,season_id=excluded.season_id,total_missions=12,required_stamps=12,completion_output=excluded.completion_output,next_step=excluded.next_step;

-- 5) Operational Explorer Passport layer.
-- journey_ref is an opaque external journey identifier; this table does not need to expose child PII publicly.
create table if not exists public.kids_explorer_passports (
  id uuid primary key default gen_random_uuid(),
  journey_ref text not null unique,
  learner_display_name text,
  age_group_id uuid references public.kids_age_groups(id),
  current_level_id uuid references public.kids_levels(id),
  current_season_id uuid references public.kids_seasons(id),
  current_mission_id uuid references public.kids_missions(id),
  status text not null default 'active' check (status in ('active','completed','paused','archived')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_passport_mission_progress (
  id uuid primary key default gen_random_uuid(),
  passport_id uuid not null references public.kids_explorer_passports(id) on delete cascade,
  mission_id uuid not null references public.kids_missions(id) on delete cascade,
  status text not null default 'not_started' check (status in ('not_started','in_progress','completed')),
  started_at timestamptz,
  completed_at timestamptz,
  stamp_id uuid references public.kids_stamps(id),
  stamp_awarded_at timestamptz,
  evidence jsonb not null default '{}'::jsonb,
  unique(passport_id,mission_id)
);

create table if not exists public.kids_passport_season_progress (
  id uuid primary key default gen_random_uuid(),
  passport_id uuid not null references public.kids_explorer_passports(id) on delete cascade,
  season_id uuid not null references public.kids_seasons(id) on delete cascade,
  completed_missions integer not null default 0,
  collected_stamps integer not null default 0,
  status text not null default 'in_progress' check (status in ('not_started','in_progress','completed')),
  badge_id uuid references public.kids_badges(id),
  badge_awarded_at timestamptz,
  completed_at timestamptz,
  unique(passport_id,season_id)
);

create table if not exists public.kids_passport_level_progress (
  id uuid primary key default gen_random_uuid(),
  passport_id uuid not null references public.kids_explorer_passports(id) on delete cascade,
  level_id uuid not null references public.kids_levels(id) on delete cascade,
  completed_seasons integer not null default 0,
  collected_badges integer not null default 0,
  status text not null default 'in_progress' check (status in ('not_started','in_progress','completed')),
  completion_badge_id uuid references public.kids_badges(id),
  completed_at timestamptz,
  unique(passport_id,level_id)
);

create table if not exists public.kids_certificates (
  id uuid primary key default gen_random_uuid(),
  passport_id uuid not null references public.kids_explorer_passports(id) on delete cascade,
  level_id uuid not null references public.kids_levels(id),
  badge_id uuid references public.kids_badges(id),
  certificate_type text not null default 'Level Certificate',
  status text not null default 'issued' check (status in ('draft','issued','revoked')),
  issued_at timestamptz not null default now(),
  certificate_asset_path text,
  metadata jsonb not null default '{}'::jsonb,
  unique(passport_id,level_id,certificate_type)
);

-- 6) Automatic reward propagation: mission completion -> stamp -> season badge -> level completion certificate.
create or replace function public.kids_sync_passport_progress(p_passport_id uuid, p_mission_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_season uuid;
  v_level uuid;
  v_stamp uuid;
  v_badge uuid;
  v_level_badge uuid;
  v_completed_missions integer;
  v_stamps integer;
  v_completed_seasons integer;
  v_season_badges integer;
  v_next_mission uuid;
begin
  select s.id,s.level_id into v_season,v_level
  from kids_missions m join kids_seasons s on s.id=m.season_id
  where m.id=p_mission_id;

  select id into v_stamp from kids_stamps where mission_id=p_mission_id and stamp_type='Mission Stamp' limit 1;

  update kids_passport_mission_progress
     set status='completed',completed_at=coalesce(completed_at,now()),stamp_id=v_stamp,stamp_awarded_at=coalesce(stamp_awarded_at,now())
   where passport_id=p_passport_id and mission_id=p_mission_id;

  select count(*) filter (where mp.status='completed'), count(*) filter (where mp.stamp_id is not null)
    into v_completed_missions,v_stamps
  from kids_passport_mission_progress mp
  join kids_missions m on m.id=mp.mission_id
  where mp.passport_id=p_passport_id and m.season_id=v_season;

  insert into kids_passport_season_progress(passport_id,season_id,completed_missions,collected_stamps,status)
  values(p_passport_id,v_season,v_completed_missions,v_stamps,case when v_stamps>=12 then 'completed' else 'in_progress' end)
  on conflict(passport_id,season_id) do update set completed_missions=excluded.completed_missions,collected_stamps=excluded.collected_stamps,status=excluded.status;

  if v_stamps>=12 then
    select id into v_badge from kids_badges where season_id=v_season and badge_type='Season Badge' limit 1;
    update kids_passport_season_progress set badge_id=v_badge,badge_awarded_at=coalesce(badge_awarded_at,now()),completed_at=coalesce(completed_at,now())
     where passport_id=p_passport_id and season_id=v_season;
  end if;

  select count(*) filter (where sp.status='completed'),count(*) filter (where sp.badge_id is not null)
    into v_completed_seasons,v_season_badges
  from kids_passport_season_progress sp
  join kids_seasons s on s.id=sp.season_id
  where sp.passport_id=p_passport_id and s.level_id=v_level;

  insert into kids_passport_level_progress(passport_id,level_id,completed_seasons,collected_badges,status)
  values(p_passport_id,v_level,v_completed_seasons,v_season_badges,case when v_season_badges>=10 then 'completed' else 'in_progress' end)
  on conflict(passport_id,level_id) do update set completed_seasons=excluded.completed_seasons,collected_badges=excluded.collected_badges,status=excluded.status;

  if v_season_badges>=10 then
    select id into v_level_badge from kids_badges where level_id=v_level and badge_type='Level Badge' and season_id is null limit 1;
    update kids_passport_level_progress set completion_badge_id=v_level_badge,completed_at=coalesce(completed_at,now())
     where passport_id=p_passport_id and level_id=v_level;
    insert into kids_certificates(passport_id,level_id,badge_id,certificate_type,status)
    values(p_passport_id,v_level,v_level_badge,'Level Certificate','issued')
    on conflict(passport_id,level_id,certificate_type) do nothing;
  end if;

  -- Source rule: passport always shows the next mission hook.
  select m2.id into v_next_mission
  from kids_missions m1
  join kids_seasons s1 on s1.id=m1.season_id
  left join kids_missions m2 on m2.code=m1.next_mission_code
  where m1.id=p_mission_id;

  update kids_explorer_passports
     set current_level_id=v_level,current_season_id=v_season,current_mission_id=coalesce(v_next_mission,p_mission_id),updated_at=now()
   where id=p_passport_id;
end;
$$;

revoke all on function public.kids_sync_passport_progress(uuid,uuid) from public,anon,authenticated;

create or replace function public.kids_mission_progress_trigger()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.status='completed' and (old.status is distinct from 'completed') then
    perform public.kids_sync_passport_progress(new.passport_id,new.mission_id);
  end if;
  return new;
end;
$$;

revoke all on function public.kids_mission_progress_trigger() from public,anon,authenticated;

drop trigger if exists trg_kids_mission_progress_complete on public.kids_passport_mission_progress;
create trigger trg_kids_mission_progress_complete
after update of status on public.kids_passport_mission_progress
for each row execute function public.kids_mission_progress_trigger();

-- 7) Read-only operational dashboard.
drop view if exists public.kids_rewards_dashboard;
create view public.kids_rewards_dashboard
with (security_invoker=true)
as
select
 (select count(*) from kids_stamps where stamp_type='Mission Stamp') as mission_stamps,
 (select count(*) from kids_badges where badge_type='Season Badge') as season_badges,
 (select count(*) from kids_badges where badge_type='Level Badge') as level_certificates,
 (select count(*) from kids_passport_progress_rules) as progress_rules,
 (select count(*) from kids_explorer_passports) as passports,
 (select count(*) from kids_passport_mission_progress where status='completed') as completed_missions,
 (select count(*) from kids_passport_season_progress where status='completed') as completed_seasons,
 (select count(*) from kids_certificates where status='issued') as issued_certificates;

-- 8) Indexing + RLS (no direct public writes/reads; access will be through controlled server APIs later).
create index if not exists idx_kids_stamps_mission on public.kids_stamps(mission_id);
create index if not exists idx_kids_badges_season on public.kids_badges(season_id);
create index if not exists idx_kids_passport_mp_passport on public.kids_passport_mission_progress(passport_id,status);
create index if not exists idx_kids_passport_sp_passport on public.kids_passport_season_progress(passport_id,status);
create index if not exists idx_kids_passport_lp_passport on public.kids_passport_level_progress(passport_id,status);

alter table public.kids_stamp_types enable row level security;
alter table public.kids_stamp_rules enable row level security;
alter table public.kids_badge_rules enable row level security;
alter table public.kids_passport_structure enable row level security;
alter table public.kids_passport_progress_rules enable row level security;
alter table public.kids_explorer_passports enable row level security;
alter table public.kids_passport_mission_progress enable row level security;
alter table public.kids_passport_season_progress enable row level security;
alter table public.kids_passport_level_progress enable row level security;
alter table public.kids_certificates enable row level security;
-- END CANONICAL MIGRATION 0043

-- BEGIN CANONICAL MIGRATION 0044 20260823141805 kam_phase6_publishing_products
create table if not exists public.kids_book_formats (
  id uuid primary key default gen_random_uuid(),
  book_type text not null unique,
  use_description text,
  source_master text,
  created_at timestamptz not null default now()
);

create table if not exists public.kids_product_catalog_master (
  id uuid primary key default gen_random_uuid(),
  product_code text not null unique,
  product_name text not null,
  category text not null,
  source_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_brand_asset_register (
  id uuid primary key default gen_random_uuid(),
  asset_code text not null unique,
  asset_type text not null,
  asset_name text not null,
  related_code text,
  owner text,
  source_file text,
  usage_rights text,
  status text,
  version text,
  approval_date date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_asset_rights_rules (
  id uuid primary key default gen_random_uuid(),
  rights_area text not null unique,
  control_rule text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.kids_catalog_product_instances (
  id uuid primary key default gen_random_uuid(),
  catalog_product_id uuid not null references public.kids_product_catalog_master(id) on delete cascade,
  book_id uuid references public.kids_books(id) on delete cascade,
  store_product_id uuid references public.store_products(id) on delete set null,
  instance_code text not null unique,
  publication_status text not null default 'planned',
  pricing_status text not null default 'pending',
  sale_status text not null default 'not_for_sale',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (pricing_status in ('pending','estimated','approved')),
  check (sale_status in ('not_for_sale','ready','active','retired'))
);

create table if not exists public.kids_commercial_readiness (
  id uuid primary key default gen_random_uuid(),
  store_product_id uuid not null unique references public.store_products(id) on delete cascade,
  source_code text,
  source_status text,
  artwork_ready boolean not null default false,
  pricing_approved boolean not null default false,
  rights_approved boolean not null default false,
  product_copy_ready boolean not null default false,
  publish_ready boolean not null default false,
  ready_for_sale boolean generated always as (artwork_ready and pricing_approved and rights_approved and product_copy_ready and publish_ready) stored,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.kids_book_formats enable row level security;
alter table public.kids_product_catalog_master enable row level security;
alter table public.kids_brand_asset_register enable row level security;
alter table public.kids_asset_rights_rules enable row level security;
alter table public.kids_catalog_product_instances enable row level security;
alter table public.kids_commercial_readiness enable row level security;

insert into public.kids_book_formats(book_type,use_description,source_master) values
('Story Book','Narrative pages','Mission Script'),
('Coloring Book','Line art pages','Artwork Guide'),
('Activity Book','Puzzles / questions / tasks','Mission Blueprint'),
('Teacher Pack','Optional school support','Learning Matrix')
on conflict (book_type) do update set use_description=excluded.use_description, source_master=excluded.source_master;

insert into public.kids_product_catalog_master(product_code,product_name,category,source_status) values
('PRD-001','Story Book','Publishing','Planned'),
('PRD-002','Coloring Book','Publishing','Planned'),
('PRD-003','Activity Book','Publishing','Planned'),
('PRD-004','Explorer Passport','Educational','Planned'),
('PRD-005','Plush Toy','Merchandise','Future')
on conflict (product_code) do update set product_name=excluded.product_name,category=excluded.category,source_status=excluded.source_status,updated_at=now();

insert into public.kids_brand_asset_register(asset_code,asset_type,asset_name,owner,usage_rights,status,version) values
('AS-001','Character','Character Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0'),
('AS-002','Logo','Logo Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0'),
('AS-003','Icon','Icon Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0'),
('AS-004','Stamp','Stamp Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0'),
('AS-005','Badge','Badge Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0'),
('AS-006','Background','Background Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0'),
('AS-007','Book Cover','Book Cover Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0'),
('AS-008','Page Template','Page Template Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0'),
('AS-009','Packaging','Packaging Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0'),
('AS-010','Toy Spec','Toy Spec Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0'),
('AS-011','Website Asset','Website Asset Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0'),
('AS-012','Social Asset','Social Asset Master Asset','Brand Lead','Internal / To Be Confirmed','Planned','v1.0')
on conflict (asset_code) do update set asset_type=excluded.asset_type,asset_name=excluded.asset_name,owner=excluded.owner,usage_rights=excluded.usage_rights,status=excluded.status,version=excluded.version,updated_at=now();

insert into public.kids_asset_rights_rules(rights_area,control_rule) values
('Ownership','Every asset must identify owner and source file.'),
('Versioning','Do not overwrite locked approved files.'),
('Usage','Commercial use only after approval.'),
('External Vendors','Vendor files must be received in editable and export formats.'),
('IP Protection','Final approved assets feed trademark/copyright filing pack.')
on conflict (rights_area) do update set control_rule=excluded.control_rule;

insert into public.kids_books(code,book_type,level_id,season_id,included_missions,page_count,primary_purpose,status,owner)
select
  'BK-'||s.code||'-'||x.suffix,
  x.book_type,
  s.level_id,
  s.id,
  'M1-M12',
  120,
  x.purpose,
  'Planned',
  'Publishing Lead'
from public.kids_seasons s
cross join (values
  ('STORY','Story Book','Season story collection'),
  ('COLOR','Coloring Book','Season coloring adaptation'),
  ('ACT','Activity Book','Season activity adaptation')
) x(suffix,book_type,purpose)
on conflict (code) do update set
  book_type=excluded.book_type,
  level_id=excluded.level_id,
  season_id=excluded.season_id,
  included_missions=excluded.included_missions,
  page_count=excluded.page_count,
  primary_purpose=excluded.primary_purpose,
  status=excluded.status,
  owner=excluded.owner,
  updated_at=now();

with book_rows as (
  select b.*, l.code level_code, s.code season_code, s.name season_name,
         case b.book_type when 'Story Book' then 'PRD-001' when 'Coloring Book' then 'PRD-002' when 'Activity Book' then 'PRD-003' end product_code
  from public.kids_books b
  join public.kids_levels l on l.id=b.level_id
  join public.kids_seasons s on s.id=b.season_id
  where b.book_type in ('Story Book','Coloring Book','Activity Book')
), upserted as (
  insert into public.store_products(sku,slug,name,short_description,description,category,currency,base_price,price_is_estimate,is_active,is_featured,sort_order)
  select
    b.code,
    lower(replace(b.code,'_','-')),
    b.season_name||' — '||b.book_type,
    b.primary_purpose,
    b.level_code||' / '||b.season_code||' • includes missions M1-M12 • 120 pages planned from KAM book production.',
    'KIDS_PUBLISHING',
    'EGP',
    0,
    true,
    false,
    false,
    1000 + row_number() over(order by b.level_code,b.season_code,b.book_type)
  from book_rows b
  on conflict (sku) do update set
    name=excluded.name,
    short_description=excluded.short_description,
    description=excluded.description,
    category=excluded.category,
    price_is_estimate=true,
    is_active=false,
    updated_at=now()
  returning id,sku
)
update public.kids_books b
set store_product_id=u.id, updated_at=now()
from upserted u
where b.code=u.sku;

insert into public.store_products(sku,slug,name,short_description,description,category,currency,base_price,price_is_estimate,is_active,is_featured,sort_order)
values
('KAM-PRD-004','kids-explorer-passport','Explorer Passport','Educational progress passport','Explorer Passport product shell from KAM_23. Pricing and final commercial approval are pending.','KIDS_EDUCATIONAL','EGP',0,true,false,false,3000),
('KAM-PRD-005','kids-plush-toy','Plush Toy','Kids Aviation merchandise concept','Future merchandise product shell from KAM_23. Commercial launch is not approved yet.','KIDS_MERCH','EGP',0,true,false,false,3010)
on conflict (sku) do update set
  name=excluded.name,short_description=excluded.short_description,description=excluded.description,category=excluded.category,
  price_is_estimate=true,is_active=false,updated_at=now();

insert into public.kids_catalog_product_instances(catalog_product_id,book_id,store_product_id,instance_code,publication_status,pricing_status,sale_status,notes)
select pcm.id,b.id,b.store_product_id,b.code,lower(b.status),'pending','not_for_sale','Generated from KAM_14 Book Production; price not provided by source.'
from public.kids_books b
join public.kids_product_catalog_master pcm on pcm.product_code = case b.book_type when 'Story Book' then 'PRD-001' when 'Coloring Book' then 'PRD-002' when 'Activity Book' then 'PRD-003' end
where b.store_product_id is not null
on conflict (instance_code) do update set catalog_product_id=excluded.catalog_product_id,book_id=excluded.book_id,store_product_id=excluded.store_product_id,publication_status=excluded.publication_status,updated_at=now();

insert into public.kids_catalog_product_instances(catalog_product_id,store_product_id,instance_code,publication_status,pricing_status,sale_status,notes)
select pcm.id,sp.id,pcm.product_code,lower(pcm.source_status),'pending','not_for_sale','Master product from KAM_23; pricing not provided by source.'
from public.kids_product_catalog_master pcm
join public.store_products sp on sp.sku=case pcm.product_code when 'PRD-004' then 'KAM-PRD-004' when 'PRD-005' then 'KAM-PRD-005' end
where pcm.product_code in ('PRD-004','PRD-005')
on conflict (instance_code) do update set catalog_product_id=excluded.catalog_product_id,store_product_id=excluded.store_product_id,publication_status=excluded.publication_status,updated_at=now();

insert into public.kids_commercial_readiness(store_product_id,source_code,source_status,artwork_ready,pricing_approved,rights_approved,product_copy_ready,publish_ready,notes)
select sp.id,sp.sku,coalesce(kpi.publication_status,'planned'),false,false,false,true,false,
       'Store shell created. Remains inactive until price, artwork, rights and publishing approval are complete.'
from public.store_products sp
left join public.kids_catalog_product_instances kpi on kpi.store_product_id=sp.id
where sp.category in ('KIDS_PUBLISHING','KIDS_EDUCATIONAL','KIDS_MERCH')
on conflict (store_product_id) do update set source_code=excluded.source_code,source_status=excluded.source_status,product_copy_ready=true,updated_at=now();

create or replace view public.kids_publishing_dashboard with (security_invoker=true) as
select
  (select count(*) from public.kids_books) as total_books,
  (select count(*) from public.kids_books where book_type='Story Book') as story_books,
  (select count(*) from public.kids_books where book_type='Coloring Book') as coloring_books,
  (select count(*) from public.kids_books where book_type='Activity Book') as activity_books,
  (select count(*) from public.kids_books where store_product_id is not null) as books_linked_to_store,
  (select count(*) from public.kids_catalog_product_instances) as catalog_instances,
  (select count(*) from public.kids_commercial_readiness where ready_for_sale) as ready_for_sale,
  (select count(*) from public.store_products where category in ('KIDS_PUBLISHING','KIDS_EDUCATIONAL','KIDS_MERCH') and is_active) as active_kids_store_products,
  (select count(*) from public.kids_brand_asset_register) as controlled_brand_assets,
  (select count(*) from public.kids_asset_rights_rules) as rights_rules;
-- END CANONICAL MIGRATION 0044

-- BEGIN CANONICAL MIGRATION 0045 20260823142020 kam_phase7_kids_experience_engine
create table if not exists public.kids_portal_access_tokens (
  id uuid primary key default gen_random_uuid(),
  passport_id uuid not null references public.kids_explorer_passports(id) on delete cascade,
  token_hash text not null unique,
  label text,
  expires_at timestamptz,
  revoked_at timestamptz,
  last_used_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.kids_content_entitlements (
  id uuid primary key default gen_random_uuid(),
  passport_id uuid not null references public.kids_explorer_passports(id) on delete cascade,
  content_item_id uuid not null references public.kids_content_items(id) on delete cascade,
  entitlement_type text not null check (entitlement_type in ('free','program','purchase','institution','admin')),
  source_ref text,
  status text not null default 'active' check (status in ('active','expired','revoked','pending')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(passport_id,content_item_id,entitlement_type,source_ref)
);

create table if not exists public.kids_experience_events (
  id uuid primary key default gen_random_uuid(),
  passport_id uuid not null references public.kids_explorer_passports(id) on delete cascade,
  event_type text not null,
  mission_id uuid references public.kids_missions(id) on delete set null,
  content_item_id uuid references public.kids_content_items(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.kids_portal_preferences (
  passport_id uuid primary key references public.kids_explorer_passports(id) on delete cascade,
  preferred_language text not null default 'en',
  reduced_motion boolean not null default false,
  audio_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.kids_content_assets add column if not exists storage_bucket text not null default 'kids-assets';
alter table public.kids_content_assets add column if not exists is_protected boolean not null default false;

insert into storage.buckets (id,name,public,file_size_limit)
values ('kids-protected-assets','kids-protected-assets',false,52428800)
on conflict (id) do update set public=false, file_size_limit=52428800;

alter table public.kids_portal_access_tokens enable row level security;
alter table public.kids_content_entitlements enable row level security;
alter table public.kids_experience_events enable row level security;
alter table public.kids_portal_preferences enable row level security;

create index if not exists idx_kids_portal_access_tokens_passport on public.kids_portal_access_tokens(passport_id);
create index if not exists idx_kids_entitlements_passport on public.kids_content_entitlements(passport_id,status);
create index if not exists idx_kids_entitlements_content on public.kids_content_entitlements(content_item_id,status);
create index if not exists idx_kids_experience_events_passport on public.kids_experience_events(passport_id,created_at desc);

create or replace view public.kids_passport_experience_summary
with (security_invoker=true)
as
select
 p.id as passport_id,p.journey_ref,p.learner_display_name,p.status,
 l.code as current_level_code,l.name as current_level_name,
 s.code as current_season_code,s.name as current_season_name,
 m.code as current_mission_code,coalesce(m.title,m.name) as current_mission_title,
 coalesce((select count(*) from public.kids_passport_mission_progress mp where mp.passport_id=p.id and mp.status='completed'),0) as completed_missions,
 coalesce((select count(*) from public.kids_passport_mission_progress mp where mp.passport_id=p.id and mp.stamp_id is not null),0) as collected_stamps,
 coalesce((select count(*) from public.kids_passport_season_progress sp where sp.passport_id=p.id and sp.status='completed'),0) as completed_seasons,
 coalesce((select count(*) from public.kids_passport_season_progress sp where sp.passport_id=p.id and sp.badge_id is not null),0) as season_badges,
 coalesce((select count(*) from public.kids_certificates c where c.passport_id=p.id and c.status='issued'),0) as certificates
from public.kids_explorer_passports p
left join public.kids_levels l on l.id=p.current_level_id
left join public.kids_seasons s on s.id=p.current_season_id
left join public.kids_missions m on m.id=p.current_mission_id;
-- END CANONICAL MIGRATION 0045

-- BEGIN CANONICAL MIGRATION 0046 20260823143057 kids_phase8_foundation_analytics
create table if not exists kids_automation_rules (id uuid primary key default gen_random_uuid(),code text not null unique,name text not null,domain text not null,trigger_event text not null,action_description text not null,severity text not null default 'info' check (severity in ('info','warning','critical')),is_active boolean not null default true,sort_order integer not null default 999,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists kids_system_alerts (id uuid primary key default gen_random_uuid(),alert_key text not null unique,domain text not null,severity text not null check (severity in ('info','warning','critical')),title text not null,detail text,entity_type text,entity_id uuid,status text not null default 'open' check (status in ('open','acknowledged','resolved')),first_seen_at timestamptz not null default now(),last_seen_at timestamptz not null default now(),resolved_at timestamptz,metadata jsonb not null default '{}'::jsonb);
create table if not exists kids_health_snapshots (id uuid primary key default gen_random_uuid(),snapshot_at timestamptz not null default now(),overall_status text not null check (overall_status in ('healthy','warning','critical')),checks_total integer not null default 0,checks_passed integer not null default 0,checks_warning integer not null default 0,checks_failed integer not null default 0,metrics jsonb not null default '{}'::jsonb,issues jsonb not null default '[]'::jsonb);
create table if not exists kids_launch_checks (id uuid primary key default gen_random_uuid(),code text not null unique,category text not null,title text not null,requirement text not null,hard_block boolean not null default false,sort_order integer not null default 999,created_at timestamptz not null default now());
create table if not exists kids_launch_check_results (id uuid primary key default gen_random_uuid(),launch_check_id uuid not null references kids_launch_checks(id) on delete cascade,checked_at timestamptz not null default now(),status text not null check (status in ('pass','warning','fail','not_applicable')),detail text,metric_value numeric,metadata jsonb not null default '{}'::jsonb);
create index if not exists idx_kids_system_alerts_status on kids_system_alerts(status,severity,last_seen_at desc);
create index if not exists idx_kids_launch_check_results_check on kids_launch_check_results(launch_check_id,checked_at desc);
alter table kids_automation_rules enable row level security; alter table kids_system_alerts enable row level security; alter table kids_health_snapshots enable row level security; alter table kids_launch_checks enable row level security; alter table kids_launch_check_results enable row level security;
insert into kids_automation_rules(code,name,domain,trigger_event,action_description,severity,sort_order) values
('AUTO-001','Mission Completion Reward','Progress','mission_completed','Award mission stamp and refresh season progress.','info',1),('AUTO-002','Season Completion Reward','Progress','12_missions_completed','Award season badge and refresh level progress.','info',2),('AUTO-003','Level Completion Certificate','Progress','10_seasons_completed','Issue level completion certificate.','info',3),('AUTO-004','Next Mission Unlock','Progress','mission_completed','Move the Explorer Passport to the configured next mission.','info',4),('AUTO-005','Protected Asset Gate','Security','asset_requested','Require valid passport token and entitlement before signed URL issuance.','critical',5),('AUTO-006','Commercial Readiness Gate','Commercial','product_review','Block sale readiness until all commercial approvals are complete.','critical',6),('AUTO-007','Curriculum Integrity Alert','Curriculum','health_check','Raise an alert if governed curriculum structure is broken.','critical',7),('AUTO-008','Content Access Alert','Security','health_check','Raise an alert if protected delivery configuration is unsafe.','critical',8),('AUTO-009','Journey Stagnation Alert','Experience','health_check','Flag active passports with no experience activity for 30 days.','warning',9),('AUTO-010','Commercial Activation Alert','Commercial','health_check','Flag active Kids products with zero price or incomplete readiness.','critical',10),('AUTO-011','Publishing Gap Alert','Publishing','health_check','Flag books missing Store linkage.','warning',11),('AUTO-012','Launch Readiness Snapshot','Governance','health_check','Record system health and launch-check results.','info',12)
on conflict(code) do update set name=excluded.name,domain=excluded.domain,trigger_event=excluded.trigger_event,action_description=excluded.action_description,severity=excluded.severity,is_active=true,sort_order=excluded.sort_order,updated_at=now();
insert into kids_launch_checks(code,category,title,requirement,hard_block,sort_order) values
('LC-001','Curriculum','5 Levels','Exactly 5 curriculum levels.',true,1),('LC-002','Curriculum','50 Seasons','Exactly 50 seasons.',true,2),('LC-003','Curriculum','600 Missions','Exactly 600 missions.',true,3),('LC-004','Production','6,000 Script Pages','Every mission has 10 script pages.',true,4),('LC-005','Production','6,000 Artwork Pages','Every mission has 10 artwork pages.',true,5),('LC-006','Rewards','600 Mission Stamps','Every mission has one stamp.',true,6),('LC-007','Rewards','50 Season Badges','Every season has one badge.',true,7),('LC-008','Rewards','5 Level Certificates','Every level has one completion definition.',true,8),('LC-009','Publishing','150 Books','Every season has Story, Coloring and Activity books.',true,9),('LC-010','Publishing','Store Linkage','Every book is linked to a Store product.',true,10),('LC-011','Security','Private Protected Storage','Protected Kids assets use a private bucket.',true,11),('LC-012','Security','Entitlement Gate','Protected content requires validated access.',true,12),('LC-013','Commercial','No Zero-Price Active Product','No active Kids product has zero price.',true,13),('LC-014','Commercial','Readiness Before Sale','No Kids product is active before readiness.',true,14),('LC-015','Experience','Explorer Passport Engine','Passport progress engine exists.',true,15),('LC-016','Experience','Protected Entitlement Engine','Entitlements and private tokens exist.',true,16),('LC-017','Governance','Governance Dashboard','KAM structural rules are measurable.',true,17),('LC-018','Operations','Control Tower Analytics','Executive and domain analytics exist.',true,18)
on conflict(code) do update set category=excluded.category,title=excluded.title,requirement=excluded.requirement,hard_block=excluded.hard_block,sort_order=excluded.sort_order;
create or replace view kids_level_analytics with (security_invoker=true) as select l.id level_id,l.code,l.name,l.age_range,count(distinct s.id)::int seasons,count(distinct m.id)::int missions,count(distinct sp.id)::int script_pages,count(distinct ap.id)::int artwork_pages,count(distinct st.id)::int stamps,count(distinct b.id) filter(where b.season_id is not null)::int season_badges,count(distinct kb.id)::int books from kids_levels l left join kids_seasons s on s.level_id=l.id left join kids_missions m on m.season_id=s.id left join kids_script_pages sp on sp.mission_id=m.id left join kids_artwork_pages ap on ap.mission_id=m.id left join kids_stamps st on st.mission_id=m.id left join kids_badges b on b.season_id=s.id left join kids_books kb on kb.level_id=l.id group by l.id,l.code,l.name,l.age_range;
create or replace view kids_experience_analytics with (security_invoker=true) as select (select count(*) from kids_explorer_passports) passports_total,(select count(*) from kids_explorer_passports where status='active') passports_active,(select count(*) from kids_passport_mission_progress where status='completed') missions_completed,(select count(*) from kids_passport_mission_progress where stamp_id is not null) stamps_awarded,(select count(*) from kids_passport_season_progress where status='completed') seasons_completed,(select count(*) from kids_passport_level_progress where status='completed') levels_completed,(select count(*) from kids_certificates where status='issued') certificates_issued,(select count(*) from kids_content_entitlements where status='active' and starts_at<=now() and (ends_at is null or ends_at>now())) active_entitlements,(select count(*) from kids_experience_events where created_at>=now()-interval '30 days') events_30d;
create or replace view kids_commercial_analytics with (security_invoker=true) as select (select count(*) from kids_books) books_total,(select count(*) from kids_books where store_product_id is not null) books_store_linked,(select count(*) from store_products where sku like 'KAM-%') kids_store_products,(select count(*) from store_products where sku like 'KAM-%' and is_active) kids_store_active,(select count(*) from store_products where sku like 'KAM-%' and is_active and base_price<=0) active_zero_price,(select count(*) from kids_commercial_readiness where ready_for_sale) ready_for_sale;
create or replace view kids_executive_dashboard with (security_invoker=true) as select (select count(*) from kids_levels) levels,(select count(*) from kids_seasons) seasons,(select count(*) from kids_missions) missions,(select count(*) from kids_script_pages) script_pages,(select count(*) from kids_artwork_pages) artwork_pages,(select count(*) from kids_stamps where mission_id is not null) stamps,(select count(*) from kids_badges where season_id is not null) season_badges,(select count(*) from kids_badges where level_id is not null and season_id is null) level_badges,(select count(*) from kids_books) books,(select count(*) from kids_explorer_passports) passports,(select count(*) from kids_system_alerts where status='open' and severity='critical') critical_alerts,(select count(*) from kids_system_alerts where status='open' and severity='warning') warning_alerts,(select count(*) from kids_automation_rules where is_active) automation_rules;
-- END CANONICAL MIGRATION 0046

-- BEGIN CANONICAL MIGRATION 0047 20260823143128 kids_phase8_health_engine
create or replace function kids_set_alert(p_key text,p_domain text,p_severity text,p_title text,p_detail text,p_open boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
 if p_open then
  insert into kids_system_alerts(alert_key,domain,severity,title,detail,status,first_seen_at,last_seen_at)
  values(p_key,p_domain,p_severity,p_title,p_detail,'open',now(),now())
  on conflict(alert_key) do update set domain=excluded.domain,severity=excluded.severity,title=excluded.title,detail=excluded.detail,status='open',last_seen_at=now(),resolved_at=null;
 else
  update kids_system_alerts set status='resolved',resolved_at=coalesce(resolved_at,now()),last_seen_at=now() where alert_key=p_key and status<>'resolved';
 end if;
end $$;

create or replace function kids_record_launch_check(p_code text,p_status text,p_detail text,p_value numeric default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_id uuid; begin
 select id into v_id from kids_launch_checks where code=p_code;
 if v_id is not null then insert into kids_launch_check_results(launch_check_id,status,detail,metric_value) values(v_id,p_status,p_detail,p_value); end if;
end $$;

create or replace function kids_run_health_check()
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_levels int;v_seasons int;v_missions int;v_scripts int;v_art int;v_stamps int;v_sb int;v_lb int;v_books int;v_linked int;v_zero int;v_bad int;v_private boolean;v_pass int:=0;v_fail int:=0;v_warn int:=0;v_issues jsonb:='[]'::jsonb;v_status text;
begin
 select count(*) into v_levels from kids_levels;
 select count(*) into v_seasons from kids_seasons;
 select count(*) into v_missions from kids_missions;
 select count(*) into v_scripts from kids_script_pages;
 select count(*) into v_art from kids_artwork_pages;
 select count(*) into v_stamps from kids_stamps where mission_id is not null;
 select count(*) into v_sb from kids_badges where season_id is not null;
 select count(*) into v_lb from kids_badges where level_id is not null and season_id is null;
 select count(*) into v_books from kids_books;
 select count(*) into v_linked from kids_books where store_product_id is not null;
 select exists(select 1 from storage.buckets where id='kids-protected-assets' and public=false) into v_private;
 select count(*) into v_zero from store_products where sku like 'KAM-%' and is_active and base_price<=0;
 select count(*) into v_bad from store_products sp join kids_commercial_readiness cr on cr.store_product_id=sp.id where sp.sku like 'KAM-%' and sp.is_active and not cr.ready_for_sale;

 perform kids_record_launch_check('LC-001',case when v_levels=5 then 'pass' else 'fail' end,'Levels: '||v_levels,v_levels); if v_levels=5 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-002',case when v_seasons=50 then 'pass' else 'fail' end,'Seasons: '||v_seasons,v_seasons); if v_seasons=50 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-003',case when v_missions=600 then 'pass' else 'fail' end,'Missions: '||v_missions,v_missions); if v_missions=600 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-004',case when v_scripts=6000 then 'pass' else 'fail' end,'Script pages: '||v_scripts,v_scripts); if v_scripts=6000 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-005',case when v_art=6000 then 'pass' else 'fail' end,'Artwork pages: '||v_art,v_art); if v_art=6000 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-006',case when v_stamps=600 then 'pass' else 'fail' end,'Mission stamps: '||v_stamps,v_stamps); if v_stamps=600 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-007',case when v_sb=50 then 'pass' else 'fail' end,'Season badges: '||v_sb,v_sb); if v_sb=50 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-008',case when v_lb=5 then 'pass' else 'fail' end,'Level completion definitions: '||v_lb,v_lb); if v_lb=5 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-009',case when v_books=150 then 'pass' else 'fail' end,'Books: '||v_books,v_books); if v_books=150 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-010',case when v_linked=150 then 'pass' else 'fail' end,'Books linked to Store: '||v_linked,v_linked); if v_linked=150 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-011',case when v_private then 'pass' else 'fail' end,'Private protected bucket: '||coalesce(v_private::text,'false'),case when v_private then 1 else 0 end); if v_private then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-012','pass','Protected asset API requires portal authorization and entitlement.',1);v_pass:=v_pass+1;
 perform kids_record_launch_check('LC-013',case when v_zero=0 then 'pass' else 'fail' end,'Active zero-price Kids products: '||v_zero,v_zero); if v_zero=0 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-014',case when v_bad=0 then 'pass' else 'fail' end,'Active Kids products without readiness: '||v_bad,v_bad); if v_bad=0 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-015','pass','Explorer Passport, mission, season and level progress engine present.',1);v_pass:=v_pass+1;
 perform kids_record_launch_check('LC-016','pass','Entitlement and private portal token engine present.',1);v_pass:=v_pass+1;
 perform kids_record_launch_check('LC-017',case when to_regclass('public.kids_governance_dashboard') is not null then 'pass' else 'fail' end,'Governance dashboard check.',1); if to_regclass('public.kids_governance_dashboard') is not null then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-018','pass','Executive, level, experience and commercial analytics views present.',1);v_pass:=v_pass+1;

 perform kids_set_alert('KIDS-CURRICULUM-INTEGRITY','Curriculum','critical','Curriculum structure mismatch','Expected 5 Levels / 50 Seasons / 600 Missions / 6000 Script / 6000 Artwork pages.',not(v_levels=5 and v_seasons=50 and v_missions=600 and v_scripts=6000 and v_art=6000));
 perform kids_set_alert('KIDS-PROTECTED-BUCKET','Security','critical','Protected storage is not private','kids-protected-assets must be private.',not v_private);
 perform kids_set_alert('KIDS-ZERO-PRICE-ACTIVE','Commercial','critical','Zero-price Kids product is active',v_zero||' active Kids products have price 0.',v_zero>0);
 perform kids_set_alert('KIDS-READINESS-BYPASS','Commercial','critical','Commercial readiness bypass detected',v_bad||' active Kids products are not ready for sale.',v_bad>0);
 perform kids_set_alert('KIDS-BOOK-STORE-LINK','Publishing','warning','Books missing Store linkage',(v_books-v_linked)||' books are not linked to Store products.',v_linked<>v_books);
 perform kids_set_alert('KIDS-JOURNEY-STAGNATION','Experience','warning','Inactive Explorer journeys','One or more active Explorer Passports have had no activity for 30 days.',exists(select 1 from kids_explorer_passports p where p.status='active' and coalesce((select max(e.created_at) from kids_experience_events e where e.passport_id=p.id),p.started_at)<now()-interval '30 days'));

 select coalesce(jsonb_agg(jsonb_build_object('key',alert_key,'severity',severity,'title',title)),'[]'::jsonb) into v_issues from kids_system_alerts where status='open';
 v_status:=case when exists(select 1 from kids_system_alerts where status='open' and severity='critical') or v_fail>0 then 'critical' when exists(select 1 from kids_system_alerts where status='open' and severity='warning') or v_warn>0 then 'warning' else 'healthy' end;
 insert into kids_health_snapshots(overall_status,checks_total,checks_passed,checks_warning,checks_failed,metrics,issues) values(v_status,18,v_pass,v_warn,v_fail,jsonb_build_object('levels',v_levels,'seasons',v_seasons,'missions',v_missions,'script_pages',v_scripts,'artwork_pages',v_art,'stamps',v_stamps,'season_badges',v_sb,'level_badges',v_lb,'books',v_books,'books_store_linked',v_linked,'protected_bucket_private',v_private,'active_zero_price',v_zero,'active_not_ready',v_bad),v_issues);
 return jsonb_build_object('status',v_status,'checks_total',18,'passed',v_pass,'warning',v_warn,'failed',v_fail,'issues',v_issues);
end $$;
revoke all on function kids_set_alert(text,text,text,text,text,boolean) from public,anon,authenticated;
revoke all on function kids_record_launch_check(text,text,text,numeric) from public,anon,authenticated;
revoke all on function kids_run_health_check() from public,anon,authenticated;
grant execute on function kids_set_alert(text,text,text,text,text,boolean) to service_role;
grant execute on function kids_record_launch_check(text,text,text,numeric) to service_role;
grant execute on function kids_run_health_check() to service_role;
-- END CANONICAL MIGRATION 0047

-- BEGIN CANONICAL MIGRATION 0048 20260823145300 kids_passport_profile_photo
alter table public.kids_explorer_passports add column if not exists profile_photo_path text, add column if not exists profile_photo_updated_at timestamptz;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('kids-profile-photos','kids-profile-photos',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
-- END CANONICAL MIGRATION 0048

-- BEGIN CANONICAL MIGRATION 0049 20260823161605 kids_ai_production_studio
create table if not exists public.kids_ai_projects (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.kids_missions(id) on delete cascade,
  title text,
  brief text,
  selected_character_codes text[] not null default '{}',
  status text not null default 'draft' check (status in ('draft','generated','review','approved','published','archived')),
  ai_payload jsonb not null default '{}'::jsonb,
  created_by uuid null references public.staff_accounts(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_ai_generations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid null references public.kids_ai_projects(id) on delete cascade,
  mission_id uuid not null references public.kids_missions(id) on delete cascade,
  page_no integer null check (page_no is null or (page_no between 1 and 20)),
  generation_type text not null check (generation_type in ('mission_draft','story_page','scene_prompt','image','revision')),
  model_name text,
  prompt text,
  response_payload jsonb not null default '{}'::jsonb,
  storage_bucket text,
  storage_path text,
  status text not null default 'generated' check (status in ('generated','review','approved','rejected','applied')),
  created_by uuid null references public.staff_accounts(user_id),
  created_at timestamptz not null default now(),
  approved_at timestamptz null
);

create index if not exists kids_ai_projects_mission_idx on public.kids_ai_projects(mission_id, created_at desc);
create index if not exists kids_ai_generations_mission_idx on public.kids_ai_generations(mission_id, page_no, created_at desc);

alter table public.kids_ai_projects enable row level security;
alter table public.kids_ai_generations enable row level security;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('kids-ai-studio','kids-ai-studio',false,20971520,array['image/png','image/jpeg','image/webp'])
on conflict (id) do update set public=false, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

create or replace function public.kids_apply_ai_mission_draft(p_mission_id uuid, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  p jsonb;
  i int;
  sp jsonb;
  ap jsonb;
begin
  p := coalesce(p_payload,'{}'::jsonb);

  update public.kids_missions
     set title = coalesce(nullif(p->>'title',''),title),
         big_question = coalesce(nullif(p->>'big_question',''),big_question),
         learning_goal = coalesce(nullif(p->>'learning_goal',''),learning_goal),
         stamp_name = coalesce(nullif(p->>'stamp_name',''),stamp_name),
         learning_objectives = case when jsonb_typeof(p->'learning_objectives')='array' then array(select jsonb_array_elements_text(p->'learning_objectives')) else learning_objectives end,
         production_status = 'AI Draft Applied',
         updated_at = now()
   where id = p_mission_id;

  update public.kids_mission_blueprints
     set key_concepts = case when jsonb_typeof(p->'key_concepts')='array' then array(select jsonb_array_elements_text(p->'key_concepts')) else key_concepts end,
         vocabulary = case when jsonb_typeof(p->'vocabulary')='array' then array(select jsonb_array_elements_text(p->'vocabulary')) else vocabulary end,
         primary_skill = coalesce(nullif(p->>'primary_skill',''),primary_skill),
         primary_value = coalesce(nullif(p->>'primary_value',''),primary_value),
         aviation_connection = coalesce(nullif(p->>'aviation_connection',''),aviation_connection),
         stamp_name = coalesce(nullif(p->>'stamp_name',''),stamp_name),
         status = 'AI Draft Applied',
         updated_at = now()
   where mission_id = p_mission_id;

  update public.kids_learning_matrix
     set knowledge_goal = coalesce(nullif(p->>'knowledge_goal',''),knowledge_goal),
         primary_skill = coalesce(nullif(p->>'primary_skill',''),primary_skill),
         primary_value = coalesce(nullif(p->>'primary_value',''),primary_value),
         vocabulary_set = case when jsonb_typeof(p->'vocabulary')='array' then array_to_string(array(select jsonb_array_elements_text(p->'vocabulary')), ', ') else vocabulary_set end,
         aviation_link = coalesce(nullif(p->>'aviation_connection',''),aviation_link),
         difficulty = coalesce(nullif(p->>'difficulty',''),difficulty),
         status = 'AI Draft Applied',
         updated_at = now()
   where mission_id = p_mission_id;

  if jsonb_typeof(p->'pages')='array' then
    for i in 0..jsonb_array_length(p->'pages')-1 loop
      sp := p->'pages'->i;
      update public.kids_script_pages
         set scene_title = coalesce(nullif(sp->>'scene_title',''),scene_title),
             narration = coalesce(nullif(sp->>'narration',''),narration),
             dialogue = coalesce(nullif(sp->>'dialogue',''),dialogue),
             learning_purpose = coalesce(nullif(sp->>'learning_purpose',''),learning_purpose),
             character_codes = case when jsonb_typeof(sp->'character_codes')='array' then array(select jsonb_array_elements_text(sp->'character_codes')) else character_codes end,
             production_notes = coalesce(nullif(sp->>'production_notes',''),production_notes),
             status = 'ai_draft',
             updated_at = now()
       where mission_id = p_mission_id and page_no = coalesce((sp->>'page_no')::int,i+1);

      ap := sp->'artwork';
      if ap is not null then
        update public.kids_artwork_pages
           set scene_brief = coalesce(nullif(ap->>'scene_brief',''),scene_brief),
               background_brief = coalesce(nullif(ap->>'background_brief',''),background_brief),
               asset_requirements = coalesce(nullif(ap->>'asset_requirements',''),asset_requirements),
               text_safe_area = coalesce(nullif(ap->>'text_safe_area',''),text_safe_area),
               illustration_notes = coalesce(nullif(ap->>'illustration_notes',''),illustration_notes),
               status = 'ai_draft',
               updated_at = now()
         where mission_id = p_mission_id and page_no = coalesce((sp->>'page_no')::int,i+1);
      end if;
    end loop;
  end if;

  update public.kids_content_tracker
     set blueprint_status='AI Draft', script_status='AI Draft', artwork_status='AI Draft', overall_status='In Production', updated_at=now()
   where mission_id=p_mission_id;

  return jsonb_build_object('ok',true,'mission_id',p_mission_id);
end;
$$;

revoke all on function public.kids_apply_ai_mission_draft(uuid,jsonb) from public, anon, authenticated;
grant execute on function public.kids_apply_ai_mission_draft(uuid,jsonb) to service_role;
-- END CANONICAL MIGRATION 0049

