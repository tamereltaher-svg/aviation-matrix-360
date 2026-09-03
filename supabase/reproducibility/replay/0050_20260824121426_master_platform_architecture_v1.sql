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
