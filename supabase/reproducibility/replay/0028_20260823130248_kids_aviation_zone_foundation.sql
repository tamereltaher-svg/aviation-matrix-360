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
