-- BEGIN CANONICAL MIGRATION 0021 20260822122643 staff_accounts_and_permissions
create table if not exists public.staff_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  employee_code text unique,
  full_name text,
  email text not null unique,
  department text,
  job_title text,
  role_code text not null default 'staff',
  is_active boolean not null default true,
  must_change_password boolean not null default false,
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.staff_permissions (
  user_id uuid not null references public.staff_accounts(user_id) on delete cascade,
  permission_code text not null,
  is_allowed boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (user_id, permission_code)
);

alter table public.staff_accounts enable row level security;
alter table public.staff_permissions enable row level security;

create or replace function public.is_active_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.staff_accounts s
    where s.user_id = auth.uid()
      and s.is_active = true
  );
$$;

create or replace function public.has_staff_permission(p_permission text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.staff_permissions p
    join public.staff_accounts s on s.user_id = p.user_id
    where p.user_id = auth.uid()
      and s.is_active = true
      and p.permission_code = p_permission
      and p.is_allowed = true
  );
$$;

revoke all on function public.is_active_staff() from public;
revoke all on function public.has_staff_permission(text) from public;
grant execute on function public.is_active_staff() to authenticated;
grant execute on function public.has_staff_permission(text) to authenticated;

create policy staff_can_read_self
on public.staff_accounts
for select
to authenticated
using (user_id = auth.uid());

create policy staff_permissions_read_self
on public.staff_permissions
for select
to authenticated
using (user_id = auth.uid());

-- Sanitized: production staff-account identity seed omitted.

-- Sanitized: production staff-permission identity seed omitted.
-- END CANONICAL MIGRATION 0021

-- BEGIN CANONICAL MIGRATION 0022 20260822125244 staff_password_auth_and_sessions_v2
create extension if not exists pgcrypto with schema extensions;

alter table public.staff_accounts
  add column if not exists password_hash text,
  add column if not exists password_updated_at timestamptz;

create table if not exists public.staff_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.staff_accounts(user_id) on delete cascade,
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  user_agent text,
  ip_hint text
);

alter table public.staff_sessions enable row level security;
revoke all on public.staff_sessions from public, anon, authenticated;

create or replace function public.staff_verify_password(p_email text, p_password text)
returns table(user_id uuid, email text, full_name text, role_code text, is_active boolean)
language sql
security definer
set search_path = public, extensions, pg_temp
as $$
  select s.user_id, s.email, s.full_name, s.role_code, s.is_active
  from public.staff_accounts s
  where lower(s.email)=lower(trim(p_email))
    and s.is_active=true
    and s.password_hash is not null
    and s.password_hash = extensions.crypt(p_password, s.password_hash)
  limit 1;
$$;

revoke all on function public.staff_verify_password(text,text) from public, anon, authenticated;
grant execute on function public.staff_verify_password(text,text) to service_role;

create or replace function public.staff_has_permission(p_user_id uuid, p_permission text)
returns boolean
language sql
security definer
set search_path = public, pg_temp
as $$
  select exists(
    select 1 from public.staff_permissions sp
    join public.staff_accounts sa on sa.user_id=sp.user_id
    where sp.user_id=p_user_id
      and sp.permission_code=p_permission
      and sp.is_allowed=true
      and sa.is_active=true
  );
$$;

revoke all on function public.staff_has_permission(uuid,text) from public, anon, authenticated;
grant execute on function public.staff_has_permission(uuid,text) to service_role;
-- END CANONICAL MIGRATION 0022

-- BEGIN CANONICAL MIGRATION 0023 20260822125444 staff_login_guard
create table if not exists public.staff_login_guard (
  email text primary key,
  failed_count integer not null default 0,
  window_started_at timestamptz not null default now(),
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.staff_login_guard enable row level security;
revoke all on public.staff_login_guard from public, anon, authenticated;
-- END CANONICAL MIGRATION 0023

-- BEGIN CANONICAL MIGRATION 0024 20260822125607 store_writes_edge_only
drop policy if exists store_products_admin_insert on public.store_products;
drop policy if exists store_products_admin_update on public.store_products;
drop policy if exists store_products_admin_delete on public.store_products;

drop policy if exists store_images_admin_insert on public.store_product_images;
drop policy if exists store_images_admin_update on public.store_product_images;
drop policy if exists store_images_admin_delete on public.store_product_images;

drop policy if exists store_variants_admin_insert on public.store_product_variants;
drop policy if exists store_variants_admin_update on public.store_product_variants;
drop policy if exists store_variants_admin_delete on public.store_product_variants;

drop policy if exists store_personalization_admin_insert on public.store_personalization_options;
drop policy if exists store_personalization_admin_update on public.store_personalization_options;
drop policy if exists store_personalization_admin_delete on public.store_personalization_options;

drop policy if exists store_audiences_admin_insert on public.store_product_audiences;
drop policy if exists store_audiences_admin_update on public.store_product_audiences;
drop policy if exists store_audiences_admin_delete on public.store_product_audiences;

drop policy if exists product_images_admin_insert on storage.objects;
drop policy if exists product_images_admin_update on storage.objects;
drop policy if exists product_images_admin_delete on storage.objects;

revoke insert, update, delete on public.store_products from authenticated;
revoke insert, update, delete on public.store_product_images from authenticated;
revoke insert, update, delete on public.store_product_variants from authenticated;
revoke insert, update, delete on public.store_personalization_options from authenticated;
revoke insert, update, delete on public.store_product_audiences from authenticated;
-- END CANONICAL MIGRATION 0024

-- BEGIN CANONICAL MIGRATION 0025 20260822131627 control_tower_programs_requests_foundation
create extension if not exists pgcrypto;

create table if not exists public.am_institutions (
  id uuid primary key default gen_random_uuid(),
  institution_type text not null check (institution_type in ('nursery','school','university','institution','government')),
  name text not null,
  contact_person text,
  email text,
  mobile text,
  city text,
  country text default 'Egypt',
  notes text,
  status text not null default 'active' check (status in ('lead','active','inactive','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_programs (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  audience_code text not null check (audience_code in ('nursery','school','university','individual','institution','government')),
  name text not null,
  short_description text,
  description text,
  base_price numeric(14,2) not null default 0,
  currency text not null default 'EGP',
  pricing_unit text not null default 'per_learner',
  duration_label text,
  delivery_modes text[] not null default array['on_site']::text[],
  is_active boolean not null default true,
  is_featured boolean not null default false,
  sort_order integer not null default 999,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_program_addons (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  description text,
  unit_price numeric(14,2) not null default 0,
  currency text not null default 'EGP',
  pricing_unit text not null default 'per_learner',
  is_active boolean not null default true,
  sort_order integer not null default 999,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create sequence if not exists public.am_request_number_seq start 1;

create table if not exists public.am_requests (
  id uuid primary key default gen_random_uuid(),
  request_number text unique not null default ('AM-RQ-' || to_char(current_date,'YYYY') || '-' || lpad(nextval('public.am_request_number_seq')::text,6,'0')),
  request_type text not null check (request_type in ('program','custom_program','product','meeting','callback','quotation','partnership')),
  audience_code text not null check (audience_code in ('nursery','school','university','individual','institution','government')),
  institution_id uuid references public.am_institutions(id) on delete set null,
  program_id uuid references public.am_programs(id) on delete set null,
  status text not null default 'new' check (status in ('new','reviewing','contacted','quotation_pending','quotation_sent','approved','rejected','closed')),
  contact_person text,
  email text,
  mobile text,
  learner_count integer,
  delivery_mode text,
  preferred_contact_method text,
  preferred_date date,
  preferred_time time,
  estimated_total numeric(14,2),
  currency text not null default 'EGP',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_request_items (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.am_requests(id) on delete cascade,
  item_type text not null check (item_type in ('program','addon','product','custom')),
  ref_id uuid,
  name text not null,
  quantity numeric(14,2) not null default 1,
  unit_price numeric(14,2) not null default 0,
  amount numeric(14,2) generated always as (quantity * unit_price) stored,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.am_meetings (
  id uuid primary key default gen_random_uuid(),
  request_id uuid references public.am_requests(id) on delete set null,
  institution_id uuid references public.am_institutions(id) on delete set null,
  meeting_type text not null check (meeting_type in ('online_meeting','callback')),
  scheduled_at timestamptz,
  status text not null default 'requested' check (status in ('requested','scheduled','completed','cancelled','no_answer')),
  contact_person text,
  mobile text,
  email text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_am_programs_audience on public.am_programs(audience_code,is_active);
create index if not exists idx_am_requests_status on public.am_requests(status,created_at desc);
create index if not exists idx_am_requests_institution on public.am_requests(institution_id);
create index if not exists idx_am_meetings_status on public.am_meetings(status,scheduled_at);

alter table public.am_institutions enable row level security;
alter table public.am_programs enable row level security;
alter table public.am_program_addons enable row level security;
alter table public.am_requests enable row level security;
alter table public.am_request_items enable row level security;
alter table public.am_meetings enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='am_programs' and policyname='am_programs_public_read') then
    create policy am_programs_public_read on public.am_programs for select to anon, authenticated using (is_active = true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='am_program_addons' and policyname='am_program_addons_public_read') then
    create policy am_program_addons_public_read on public.am_program_addons for select to anon, authenticated using (is_active = true);
  end if;
end $$;

grant select on public.am_programs, public.am_program_addons to anon, authenticated;

insert into public.am_programs(code,audience_code,name,short_description,base_price,currency,pricing_unit,duration_label,delivery_modes,is_active,is_featured,sort_order)
values
('NUR-DISCOVERY-DAY','nursery','Aviation Discovery Day','A themed aviation discovery day for young learners.',900,'EGP','per_learner','1 day',array['on_site','aviation_matrix'],true,true,10),
('NUR-WEEKLY','nursery','Weekly Kids Aviation Program','Weekly aviation learning and activity sessions.',650,'EGP','per_learner','Weekly',array['on_site'],true,true,20),
('SCH-CAREER-DAY','school','Aviation Career Discovery Day','Career discovery and aviation awareness for school students.',950,'EGP','per_learner','1 day',array['on_site','aviation_matrix'],true,true,30),
('SCH-WEEKLY-CLUB','school','Weekly Aviation Club','Structured weekly school aviation club.',700,'EGP','per_learner','Weekly',array['on_site'],true,true,40),
('SCH-SECONDARY-PATH','school','Secondary Career Pathway','Career pathway for secondary students.',1100,'EGP','per_learner','Term / Semester',array['on_site','hybrid'],true,true,50),
('UNI-CAREER-READY','university','Aviation Career Readiness Program','Career readiness for university students entering aviation.',1200,'EGP','per_learner','Program',array['on_site','hybrid','online'],true,true,60),
('UNI-ASSESS-MAP','university','Student Assessment & Career Mapping','Assessment and aviation career mapping for student groups.',1350,'EGP','per_learner','Program',array['on_site','online'],true,false,70),
('IND-CAREER-FIT','individual','Career Fit Assessment','Individual aviation career fit assessment.',650,'EGP','per_person','Single assessment',array['online','aviation_matrix'],true,true,80),
('INS-WORKFORCE','institution','Workforce Development Package','Customized aviation workforce development package.',1450,'EGP','per_learner','Custom',array['on_site','hybrid'],true,false,90),
('GOV-YOUTH-PIPELINE','government','Youth Aviation Pipeline','Scalable youth aviation awareness and career pipeline initiative.',1750,'EGP','per_learner','Custom',array['on_site','hybrid'],true,false,100)
on conflict (code) do nothing;

insert into public.am_program_addons(code,name,description,unit_price,currency,pricing_unit,is_active,sort_order)
values
('ASSESSMENT','Assessment','Structured learner assessment',120,'EGP','per_learner',true,10),
('CERTIFICATE','Certificates','Printed or digital certificate',80,'EGP','per_learner',true,20),
('CAREER_REPORT','Career Reports','Individual or group career reporting',160,'EGP','per_learner',true,30),
('PARENT_SESSION','Parent Session','Parent awareness / briefing session',100,'EGP','per_learner',true,40),
('PERSONALIZATION','Personalization','Student names / institution name / logo',70,'EGP','per_learner',true,50),
('MEDIA_PACKAGE','Photo / Media Package','Program photo and media coverage',150,'EGP','per_learner',true,60),
('CUSTOM_BRANDING','Custom Branding','Institution-specific branded materials',90,'EGP','per_learner',true,70)
on conflict (code) do nothing;
-- END CANONICAL MIGRATION 0025

-- BEGIN CANONICAL MIGRATION 0026 20260822152832 commercial_operations_foundation
create sequence if not exists public.am_quotation_number_seq start 1;

-- Extend request lifecycle
alter table public.am_requests drop constraint if exists am_requests_status_check;
alter table public.am_requests add constraint am_requests_status_check check (status in ('new','reviewing','contacted','quotation_pending','quotation_sent','approved','execution','completed','rejected','closed','cancelled'));

create table if not exists public.am_quotations (
  id uuid primary key default gen_random_uuid(),
  quotation_number text unique not null default ('AM-Q-' || to_char(current_date,'YYYY') || '-' || lpad(nextval('public.am_quotation_number_seq')::text,6,'0')),
  request_id uuid not null references public.am_requests(id) on delete cascade,
  version_no integer not null default 1,
  status text not null default 'draft' check (status in ('draft','sent','accepted','rejected','expired','superseded','cancelled')),
  currency text not null default 'EGP',
  subtotal numeric(14,2) not null default 0,
  discount_amount numeric(14,2) not null default 0,
  tax_amount numeric(14,2) not null default 0,
  total_amount numeric(14,2) not null default 0,
  valid_until date,
  terms text,
  notes text,
  sent_at timestamptz,
  accepted_at timestamptz,
  rejected_at timestamptz,
  created_by uuid references public.staff_accounts(user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(request_id, version_no)
);

create table if not exists public.am_quotation_items (
  id uuid primary key default gen_random_uuid(),
  quotation_id uuid not null references public.am_quotations(id) on delete cascade,
  item_type text not null check (item_type in ('program','addon','product','service','custom')),
  ref_id uuid,
  name text not null,
  description text,
  quantity numeric(14,2) not null default 1,
  unit_price numeric(14,2) not null default 0,
  discount_amount numeric(14,2) not null default 0,
  amount numeric(14,2) not null default 0,
  config jsonb not null default '{}'::jsonb,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.am_request_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.am_requests(id) on delete cascade,
  event_type text not null,
  from_status text,
  to_status text,
  title text not null,
  detail text,
  visibility text not null default 'internal' check (visibility in ('internal','customer')),
  actor_type text not null default 'system' check (actor_type in ('system','staff','customer')),
  actor_staff_id uuid references public.staff_accounts(user_id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.am_customer_notifications (
  id uuid primary key default gen_random_uuid(),
  request_id uuid references public.am_requests(id) on delete cascade,
  quotation_id uuid references public.am_quotations(id) on delete cascade,
  channel text not null check (channel in ('email','whatsapp','sms','portal')),
  recipient text,
  template_code text not null,
  subject text,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','sent','failed','skipped')),
  sent_at timestamptz,
  error_message text,
  created_at timestamptz not null default now()
);

create index if not exists idx_am_quotations_request on public.am_quotations(request_id, created_at desc);
create index if not exists idx_am_quotations_status on public.am_quotations(status, created_at desc);
create index if not exists idx_am_request_events_request on public.am_request_events(request_id, created_at desc);
create index if not exists idx_am_notifications_request on public.am_customer_notifications(request_id, created_at desc);

alter table public.am_quotations enable row level security;
alter table public.am_quotation_items enable row level security;
alter table public.am_request_events enable row level security;
alter table public.am_customer_notifications enable row level security;

revoke all on public.am_quotations, public.am_quotation_items, public.am_request_events, public.am_customer_notifications from anon, authenticated;

-- Seed a customer-visible event for existing requests that do not yet have a timeline
insert into public.am_request_events(request_id,event_type,to_status,title,detail,visibility,actor_type)
select r.id,'request_received',r.status,'Request received','Your request has been received by Aviation Matrix.','customer','system'
from public.am_requests r
where not exists (select 1 from public.am_request_events e where e.request_id=r.id);

-- Keep quotation totals consistent.
create or replace function public.am_recalculate_quotation(p_quotation_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare v_sub numeric(14,2); v_discount numeric(14,2); v_tax numeric(14,2); begin
  select coalesce(sum(amount),0) into v_sub from public.am_quotation_items where quotation_id=p_quotation_id;
  select discount_amount, tax_amount into v_discount, v_tax from public.am_quotations where id=p_quotation_id;
  update public.am_quotations set subtotal=v_sub,total_amount=greatest(0,v_sub-coalesce(v_discount,0)+coalesce(v_tax,0)),updated_at=now() where id=p_quotation_id;
end $$;
revoke all on function public.am_recalculate_quotation(uuid) from public, anon, authenticated;
grant execute on function public.am_recalculate_quotation(uuid) to service_role;
-- END CANONICAL MIGRATION 0026

-- BEGIN CANONICAL MIGRATION 0027 20260822160801 program_cover_images_and_card_theme
alter table public.am_programs
  add column if not exists cover_image_path text,
  add column if not exists cover_image_alt text,
  add column if not exists card_theme text not null default 'aviation_blue',
  add column if not exists overlay_strength integer not null default 42;

alter table public.am_programs
  drop constraint if exists am_programs_card_theme_check;
alter table public.am_programs
  add constraint am_programs_card_theme_check
  check (card_theme in ('aviation_blue','light','dark','kids_colorful'));

alter table public.am_programs
  drop constraint if exists am_programs_overlay_strength_check;
alter table public.am_programs
  add constraint am_programs_overlay_strength_check
  check (overlay_strength between 0 and 85);

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('program-images','program-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public=true,
  file_size_limit=5242880,
  allowed_mime_types=array['image/jpeg','image/png','image/webp'];
-- END CANONICAL MIGRATION 0027

-- BEGIN CANONICAL MIGRATION 0028 20260823130248 kids_aviation_zone_foundation
create table if not exists public.kids_characters (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  short_name text,
  role_title text,
  description text,
  personality text,
  values text[] not null default '{}',
  primary_image_path text,
  profile_image_path text,
  is_active boolean not null default true,
  sort_order integer not null default 999,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_age_groups (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label text not null,
  min_age integer not null,
  max_age integer not null,
  sort_order integer not null default 999,
  is_active boolean not null default true,
  constraint kids_age_groups_valid_age check (min_age >= 0 and max_age >= min_age)
);

create table if not exists public.kids_content_categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  icon text,
  sort_order integer not null default 999,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.kids_levels (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  sort_order integer not null default 999,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_seasons (
  id uuid primary key default gen_random_uuid(),
  level_id uuid not null references public.kids_levels(id) on delete cascade,
  code text not null unique,
  name text not null,
  description text,
  sort_order integer not null default 999,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_missions (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.kids_seasons(id) on delete cascade,
  code text not null unique,
  name text not null,
  description text,
  learning_objectives text[] not null default '{}',
  sort_order integer not null default 999,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_scenes (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.kids_missions(id) on delete cascade,
  code text not null unique,
  name text not null,
  description text,
  sort_order integer not null default 999,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_content_items (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  content_type text not null,
  category_id uuid references public.kids_content_categories(id) on delete set null,
  language_code text not null default 'en',
  short_description text,
  description text,
  duration_minutes integer,
  cover_image_path text,
  thumbnail_path text,
  access_level text not null default 'program_only',
  level_id uuid references public.kids_levels(id) on delete set null,
  season_id uuid references public.kids_seasons(id) on delete set null,
  mission_id uuid references public.kids_missions(id) on delete set null,
  scene_id uuid references public.kids_scenes(id) on delete set null,
  status text not null default 'draft',
  is_featured boolean not null default false,
  sort_order integer not null default 999,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint kids_content_type_check check (content_type in ('story','coloring','song','activity','mission','printable','worksheet','quiz','certificate','video','audio','around_the_world','character_activity')),
  constraint kids_access_level_check check (access_level in ('public_preview','free','registered','program_only','purchased','institution_licensed','admin_only')),
  constraint kids_content_status_check check (status in ('draft','review','published','archived')),
  constraint kids_duration_valid check (duration_minutes is null or duration_minutes >= 0)
);

create table if not exists public.kids_content_assets (
  id uuid primary key default gen_random_uuid(),
  content_item_id uuid not null references public.kids_content_items(id) on delete cascade,
  asset_type text not null,
  storage_path text not null,
  file_name text,
  mime_type text,
  language_code text default 'en',
  is_primary boolean not null default false,
  is_downloadable boolean not null default false,
  sort_order integer not null default 999,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint kids_asset_type_check check (asset_type in ('cover','thumbnail','pdf','image','audio','video','worksheet','printable','certificate','other'))
);

create table if not exists public.kids_content_age_groups (
  content_item_id uuid not null references public.kids_content_items(id) on delete cascade,
  age_group_id uuid not null references public.kids_age_groups(id) on delete cascade,
  primary key (content_item_id, age_group_id)
);

create table if not exists public.kids_content_characters (
  content_item_id uuid not null references public.kids_content_items(id) on delete cascade,
  character_id uuid not null references public.kids_characters(id) on delete cascade,
  role_code text default 'featured',
  sort_order integer not null default 999,
  primary key (content_item_id, character_id)
);

create table if not exists public.program_content_items (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.am_programs(id) on delete cascade,
  content_item_id uuid not null references public.kids_content_items(id) on delete cascade,
  sequence_no integer not null default 999,
  is_required boolean not null default true,
  delivery_mode text not null default 'instructor_led',
  learner_visibility text not null default 'during_program',
  instructor_notes text,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(program_id, content_item_id),
  constraint program_content_delivery_check check (delivery_mode in ('instructor_led','self_guided','printable','audio','video','activity','take_home')),
  constraint program_content_visibility_check check (learner_visibility in ('hidden','preview','before_program','during_program','after_program','always'))
);

create table if not exists public.kids_product_links (
  id uuid primary key default gen_random_uuid(),
  content_item_id uuid references public.kids_content_items(id) on delete cascade,
  program_id uuid references public.am_programs(id) on delete cascade,
  product_id uuid not null references public.store_products(id) on delete cascade,
  link_type text not null default 'recommended',
  sort_order integer not null default 999,
  created_at timestamptz not null default now(),
  constraint kids_product_link_owner_check check (content_item_id is not null or program_id is not null),
  constraint kids_product_link_type_check check (link_type in ('recommended','included','optional','required','bundle'))
);

create index if not exists idx_kids_content_status_type on public.kids_content_items(status, content_type);
create index if not exists idx_kids_content_category on public.kids_content_items(category_id);
create index if not exists idx_kids_content_mission on public.kids_content_items(mission_id);
create index if not exists idx_program_content_program on public.program_content_items(program_id, sequence_no);
create index if not exists idx_program_content_content on public.program_content_items(content_item_id);
create index if not exists idx_kids_assets_content on public.kids_content_assets(content_item_id, sort_order);
create index if not exists idx_kids_product_program on public.kids_product_links(program_id);
create index if not exists idx_kids_product_content on public.kids_product_links(content_item_id);

insert into public.kids_age_groups(code,label,min_age,max_age,sort_order) values
 ('AGE-03-04','3–4',3,4,10),
 ('AGE-04-06','4–6',4,6,20),
 ('AGE-06-08','6–8',6,8,30),
 ('AGE-08-10','8–10',8,10,40),
 ('AGE-10-12','10–12',10,12,50),
 ('AGE-12-14','12–14',12,14,60),
 ('AGE-14-16','14–16',14,16,70),
 ('AGE-16-18','16–18',16,18,80)
on conflict (code) do update set label=excluded.label,min_age=excluded.min_age,max_age=excluded.max_age,sort_order=excluded.sort_order;

insert into public.kids_content_categories(code,name,sort_order) values
 ('STORIES','Stories',10),('COLORING','Coloring',20),('SONGS','Songs',30),('ACTIVITIES','Activities',40),
 ('MISSIONS','Missions',50),('AROUND-WORLD','Around The World',60),('PRINTABLES','Printables',70),('CERTIFICATES','Certificates',80)
on conflict (code) do update set name=excluded.name,sort_order=excluded.sort_order;

insert into public.kids_characters(code,name,short_name,role_title,sort_order) values
 ('AW-001','AVA Wings','AVA','Aviation Explorer',10),
 ('BJ-001','Ben Journey','Ben','Young Traveler',20),
 ('CM-001','Captain Matrix','Captain Matrix','Captain',30),
 ('DM-001','Dispatcher Matrix','Dispatcher Matrix','Flight Dispatcher',40),
 ('MC-001','Maria Control','Maria','Air Traffic Control',50),
 ('MX-001','Max Jet','Max','Aviation Adventurer',60),
 ('DS-001','Daisy Sky','Daisy','Aviation Explorer',70)
on conflict (code) do update set name=excluded.name,short_name=excluded.short_name,role_title=excluded.role_title,sort_order=excluded.sort_order;

insert into public.kids_levels(code,name,description,sort_order)
values ('KAM-L1','Level 1','Foundation aviation discovery level',10)
on conflict (code) do nothing;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('kids-assets','kids-assets',true,10485760,array['image/jpeg','image/png','image/webp','application/pdf','audio/mpeg','audio/wav','audio/x-wav','video/mp4'])
on conflict (id) do update set public=true,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;

alter table public.kids_characters enable row level security;
alter table public.kids_age_groups enable row level security;
alter table public.kids_content_categories enable row level security;
alter table public.kids_levels enable row level security;
alter table public.kids_seasons enable row level security;
alter table public.kids_missions enable row level security;
alter table public.kids_scenes enable row level security;
alter table public.kids_content_items enable row level security;
alter table public.kids_content_assets enable row level security;
alter table public.kids_content_age_groups enable row level security;
alter table public.kids_content_characters enable row level security;
alter table public.program_content_items enable row level security;
alter table public.kids_product_links enable row level security;

create policy "public_read_kids_characters" on public.kids_characters for select to anon, authenticated using (is_active = true);
create policy "public_read_kids_age_groups" on public.kids_age_groups for select to anon, authenticated using (is_active = true);
create policy "public_read_kids_categories" on public.kids_content_categories for select to anon, authenticated using (is_active = true);
create policy "public_read_kids_levels" on public.kids_levels for select to anon, authenticated using (is_active = true);
create policy "public_read_kids_seasons" on public.kids_seasons for select to anon, authenticated using (is_active = true);
create policy "public_read_kids_missions" on public.kids_missions for select to anon, authenticated using (is_active = true);
create policy "public_read_kids_scenes" on public.kids_scenes for select to anon, authenticated using (is_active = true);
create policy "public_read_published_kids_content" on public.kids_content_items for select to anon, authenticated using (status = 'published' and access_level in ('public_preview','free','registered','program_only','purchased','institution_licensed'));
create policy "public_read_published_kids_assets" on public.kids_content_assets for select to anon, authenticated using (exists (select 1 from public.kids_content_items c where c.id = content_item_id and c.status='published'));
create policy "public_read_kids_content_age_groups" on public.kids_content_age_groups for select to anon, authenticated using (exists (select 1 from public.kids_content_items c where c.id = content_item_id and c.status='published'));
create policy "public_read_kids_content_characters" on public.kids_content_characters for select to anon, authenticated using (exists (select 1 from public.kids_content_items c where c.id = content_item_id and c.status='published'));
create policy "public_read_program_content" on public.program_content_items for select to anon, authenticated using (
  exists (select 1 from public.kids_content_items c where c.id=content_item_id and c.status='published')
  and exists (select 1 from public.am_programs p where p.id=program_id and p.is_active=true)
);
create policy "public_read_kids_product_links" on public.kids_product_links for select to anon, authenticated using (
  (content_item_id is null or exists (select 1 from public.kids_content_items c where c.id=content_item_id and c.status='published'))
  and exists (select 1 from public.store_products sp where sp.id=product_id and sp.is_active=true)
);

create policy "public_read_kids_assets_bucket" on storage.objects for select to anon, authenticated using (bucket_id = 'kids-assets');
-- END CANONICAL MIGRATION 0028

-- BEGIN CANONICAL MIGRATION 0029 20260823130605 kids_phase2_commercial_content
alter table public.kids_content_items
  add column if not exists commercial_mode text not null default 'included_program'
    check (commercial_mode in ('free','paid','included_program','product_linked','institution_licensed','mixed')),
  add column if not exists base_price numeric not null default 0 check (base_price >= 0),
  add column if not exists currency text not null default 'EGP',
  add column if not exists price_unit text not null default 'per_item'
    check (price_unit in ('per_item','per_download','per_learner','per_group','license')),
  add column if not exists allow_direct_purchase boolean not null default false,
  add column if not exists commercial_notes text null;

create index if not exists idx_kids_content_status_type on public.kids_content_items(status,content_type);
create index if not exists idx_kids_content_commercial on public.kids_content_items(commercial_mode,status);
create index if not exists idx_program_content_program on public.program_content_items(program_id,sequence_no);
create index if not exists idx_kids_product_links_content on public.kids_product_links(content_item_id);
create index if not exists idx_kids_assets_item on public.kids_content_assets(content_item_id,sort_order);

insert into public.staff_permissions(user_id,permission_code,is_allowed)
select user_id,'kids.manage',true from public.staff_accounts where is_active=true
on conflict (user_id,permission_code) do update set is_allowed=excluded.is_allowed;
-- END CANONICAL MIGRATION 0029

-- BEGIN CANONICAL MIGRATION 0030 20260823133347 kam_architecture_v2_core
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
-- END CANONICAL MIGRATION 0030

