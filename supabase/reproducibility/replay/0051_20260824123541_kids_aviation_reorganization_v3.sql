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
