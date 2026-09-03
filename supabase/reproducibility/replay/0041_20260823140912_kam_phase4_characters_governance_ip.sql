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
