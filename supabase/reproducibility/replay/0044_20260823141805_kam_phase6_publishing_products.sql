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
