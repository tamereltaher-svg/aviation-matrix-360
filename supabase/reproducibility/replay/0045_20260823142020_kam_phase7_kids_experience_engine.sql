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
