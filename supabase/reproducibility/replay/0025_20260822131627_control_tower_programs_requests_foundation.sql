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
