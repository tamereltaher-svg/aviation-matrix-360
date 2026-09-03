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
