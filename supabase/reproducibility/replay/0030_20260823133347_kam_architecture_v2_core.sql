-- KAM Architecture v2: source-governed curriculum operating system

create table if not exists public.kids_source_registry (
  id uuid primary key default gen_random_uuid(),
  source_code text not null unique,
  file_name text not null,
  folder_name text,
  department text,
  purpose text,
  primary_owner text,
  used_by text,
  depends_on text,
  feeds_into text,
  update_frequency text,
  source_status text default 'Active',
  sort_order integer default 999,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.kids_source_registry enable row level security;

create table if not exists public.kids_source_dependencies (
  id uuid primary key default gen_random_uuid(),
  step_no integer,
  source_code text not null,
  role_in_workflow text,
  next_source_code text,
  created_at timestamptz not null default now(),
  unique(source_code, next_source_code)
);
alter table public.kids_source_dependencies enable row level security;

alter table public.kids_levels
  add column if not exists age_range text,
  add column if not exists min_age integer,
  add column if not exists max_age integer,
  add column if not exists learning_stage text,
  add column if not exists primary_goal text,
  add column if not exists learner_outcome text;

alter table public.kids_seasons
  add column if not exists season_no text,
  add column if not exists learning_stage text,
  add column if not exists base_goal text,
  add column if not exists depth_goal text,
  add column if not exists mission_count integer default 12,
  add column if not exists page_count integer default 120,
  add column if not exists transition_rule text;

alter table public.kids_missions
  add column if not exists mission_no text,
  add column if not exists title text,
  add column if not exists big_question text,
  add column if not exists learning_goal text,
  add column if not exists stamp_name text,
  add column if not exists next_mission_code text,
  add column if not exists production_status text default 'Not Started';

create table if not exists public.kids_mission_blueprints (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null unique references public.kids_missions(id) on delete cascade,
  key_concepts text[] not null default '{}',
  vocabulary text[] not null default '{}',
  primary_skill text,
  primary_value text,
  aviation_connection text,
  stamp_name text,
  next_mission_code text,
  status text default 'Not Started',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.kids_mission_blueprints enable row level security;

create table if not exists public.kids_learning_matrix (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null unique references public.kids_missions(id) on delete cascade,
  knowledge_goal text,
  primary_skill text,
  primary_value text,
  vocabulary_set text,
  aviation_link text,
  difficulty text,
  status text default 'Planned',
  review_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.kids_learning_matrix enable row level security;

create table if not exists public.kids_script_pages (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.kids_missions(id) on delete cascade,
  page_no integer not null check (page_no between 1 and 20),
  scene_title text,
  narration text,
  dialogue text,
  learning_purpose text,
  character_codes text[] not null default '{}',
  production_notes text,
  status text default 'planned',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(mission_id, page_no)
);
alter table public.kids_script_pages enable row level security;

create table if not exists public.kids_artwork_pages (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.kids_missions(id) on delete cascade,
  page_no integer not null,
  scene_brief text,
  background_brief text,
  asset_requirements text,
  text_safe_area text,
  illustration_notes text,
  status text default 'planned',
  asset_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(mission_id, page_no)
);
alter table public.kids_artwork_pages enable row level security;

create table if not exists public.kids_stamps (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  mission_id uuid references public.kids_missions(id) on delete cascade,
  season_id uuid references public.kids_seasons(id) on delete cascade,
  level_id uuid references public.kids_levels(id) on delete cascade,
  stamp_type text default 'Mission Stamp',
  earned_for text,
  visual_brief text,
  status text default 'Planned',
  owner text,
  notes text,
  image_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.kids_stamps enable row level security;

create table if not exists public.kids_badges (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  badge_type text not null,
  level_id uuid references public.kids_levels(id) on delete cascade,
  season_id uuid references public.kids_seasons(id) on delete cascade,
  requirement text,
  awarded_after_mission_id uuid references public.kids_missions(id) on delete set null,
  visual_brief text,
  status text default 'Planned',
  owner text,
  image_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.kids_badges enable row level security;

create table if not exists public.kids_books (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  book_type text not null,
  level_id uuid references public.kids_levels(id) on delete cascade,
  season_id uuid references public.kids_seasons(id) on delete cascade,
  included_missions text,
  page_count integer,
  primary_purpose text,
  status text default 'Planned',
  owner text,
  notes text,
  store_product_id uuid references public.store_products(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.kids_books enable row level security;

create index if not exists idx_kids_seasons_level on public.kids_seasons(level_id, sort_order);
create index if not exists idx_kids_missions_season on public.kids_missions(season_id, sort_order);
create index if not exists idx_kids_script_pages_mission on public.kids_script_pages(mission_id, page_no);
create index if not exists idx_kids_artwork_pages_mission on public.kids_artwork_pages(mission_id, page_no);
create index if not exists idx_kids_stamps_mission on public.kids_stamps(mission_id);
create index if not exists idx_kids_badges_season on public.kids_badges(season_id);
create index if not exists idx_kids_books_season on public.kids_books(season_id);

-- Public read is deliberately limited to published/active curriculum elements.
drop policy if exists kids_levels_public_read on public.kids_levels;
create policy kids_levels_public_read on public.kids_levels for select to anon, authenticated using (is_active = true);
drop policy if exists kids_seasons_public_read on public.kids_seasons;
create policy kids_seasons_public_read on public.kids_seasons for select to anon, authenticated using (is_active = true);
drop policy if exists kids_missions_public_read on public.kids_missions;
create policy kids_missions_public_read on public.kids_missions for select to anon, authenticated using (is_active = true);
