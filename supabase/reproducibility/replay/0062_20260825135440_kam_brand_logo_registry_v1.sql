begin;

create extension if not exists pgcrypto;

create table if not exists public.kids_brand_profiles (
  id uuid primary key default gen_random_uuid(),
  brand_code text not null unique,
  brand_name text not null,
  tagline text,
  design_direction text,
  status text not null default 'active' check (status in ('draft','active','inactive','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_brand_logo_assets (
  id uuid primary key default gen_random_uuid(),
  brand_profile_id uuid not null references public.kids_brand_profiles(id) on delete cascade,
  product_code text not null,
  product_name text not null,
  variant_code text not null,
  asset_role text not null default 'supporting' check (asset_role in ('canonical','supporting','placeholder','draft','superseded')),
  asset_path text not null,
  asset_url text,
  mime_type text,
  pixel_width integer,
  pixel_height integer,
  dpi integer,
  background_mode text,
  color_mode text,
  is_canonical boolean not null default false,
  approval_status text not null default 'draft' check (approval_status in ('draft','review','approved','locked','rejected','superseded')),
  approved_at timestamptz,
  locked_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_profile_id, product_code, variant_code, asset_path)
);

create table if not exists public.kids_brand_logo_rules (
  id uuid primary key default gen_random_uuid(),
  brand_profile_id uuid not null references public.kids_brand_profiles(id) on delete cascade,
  product_code text not null,
  rule_code text not null,
  rule_type text not null check (rule_type in ('required','forbidden','allowed','placement','quality')),
  rule_text text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_profile_id, product_code, rule_code)
);

create table if not exists public.kids_brand_placement_rules (
  id uuid primary key default gen_random_uuid(),
  brand_profile_id uuid not null references public.kids_brand_profiles(id) on delete cascade,
  product_code text not null,
  placement_code text not null,
  placement_name text not null,
  is_required boolean not null default false,
  min_width_px integer,
  min_width_mm numeric(10,2),
  clear_space_factor numeric(10,2),
  safe_area_rule text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_profile_id, product_code, placement_code)
);

create table if not exists public.kids_brand_versions (
  id uuid primary key default gen_random_uuid(),
  brand_profile_id uuid not null references public.kids_brand_profiles(id) on delete cascade,
  product_code text not null,
  version_label text not null,
  lifecycle_status text not null default 'draft' check (lifecycle_status in ('draft','review','approved','locked','superseded','archived')),
  change_summary text,
  effective_from timestamptz,
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  unique (brand_profile_id, product_code, version_label)
);

create or replace function public.kids_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_kids_brand_profiles_updated_at on public.kids_brand_profiles;
create trigger trg_kids_brand_profiles_updated_at before update on public.kids_brand_profiles for each row execute function public.kids_touch_updated_at();

drop trigger if exists trg_kids_brand_logo_assets_updated_at on public.kids_brand_logo_assets;
create trigger trg_kids_brand_logo_assets_updated_at before update on public.kids_brand_logo_assets for each row execute function public.kids_touch_updated_at();

drop trigger if exists trg_kids_brand_logo_rules_updated_at on public.kids_brand_logo_rules;
create trigger trg_kids_brand_logo_rules_updated_at before update on public.kids_brand_logo_rules for each row execute function public.kids_touch_updated_at();

drop trigger if exists trg_kids_brand_placement_rules_updated_at on public.kids_brand_placement_rules;
create trigger trg_kids_brand_placement_rules_updated_at before update on public.kids_brand_placement_rules for each row execute function public.kids_touch_updated_at();

insert into public.kids_brand_profiles (brand_code, brand_name, tagline, design_direction, status)
values ('KAM360','Kids Aviation Matrix 360°','Discover. Learn. Explore. Fly.','Aviation Badge + Cartoon Premium','active')
on conflict (brand_code) do update set
  brand_name = excluded.brand_name,
  tagline = excluded.tagline,
  design_direction = excluded.design_direction,
  status = excluded.status,
  updated_at = now();

with b as (select id from public.kids_brand_profiles where brand_code='KAM360')
insert into public.kids_brand_logo_assets (
  brand_profile_id, product_code, product_name, variant_code, asset_role, asset_path, asset_url,
  mime_type, pixel_width, pixel_height, dpi, background_mode, color_mode, is_canonical,
  approval_status, approved_at, locked_at, notes
)
select b.id, v.product_code, v.product_name, v.variant_code, v.asset_role, v.asset_path, v.asset_url,
       v.mime_type, v.pixel_width, v.pixel_height, v.dpi, v.background_mode, v.color_mode, v.is_canonical,
       v.approval_status, case when v.approval_status in ('approved','locked') then now() end,
       case when v.approval_status='locked' then now() end, v.notes
from b
cross join (values
  ('STORY_BOOK','Story Book','PRIMARY_MASTER','canonical','assets/kam-brand/story-book/01_MASTER/KAM_STORY_BOOK_LOGO_PRIMARY_MASTER.png','https://tamereltaher-svg.github.io/aviation-matrix-360/assets/kam-brand/story-book/01_MASTER/KAM_STORY_BOOK_LOGO_PRIMARY_MASTER.png','image/png',1536,1536,null,'transparent_or_light','full_color',true,'locked','Canonical locked Story Book logo master'),
  ('STORY_BOOK','Story Book','PRINT_3000','supporting','assets/kam-brand/story-book/02_PRINT/KAM_STORY_BOOK_LOGO_PRINT_3000PX_300DPI.png','https://tamereltaher-svg.github.io/aviation-matrix-360/assets/kam-brand/story-book/02_PRINT/KAM_STORY_BOOK_LOGO_PRINT_3000PX_300DPI.png','image/png',3000,3000,300,'transparent_or_light','full_color',false,'approved','Print derivative'),
  ('STORY_BOOK','Story Book','WEB_1024','supporting','assets/kam-brand/story-book/03_WEB/KAM_STORY_BOOK_LOGO_WEB_1024.png','https://tamereltaher-svg.github.io/aviation-matrix-360/assets/kam-brand/story-book/03_WEB/KAM_STORY_BOOK_LOGO_WEB_1024.png','image/png',1024,1024,null,'transparent_or_light','full_color',false,'approved','Web derivative'),
  ('STORY_BOOK','Story Book','WEB_768','supporting','assets/kam-brand/story-book/03_WEB/KAM_STORY_BOOK_LOGO_WEB_768.png','https://tamereltaher-svg.github.io/aviation-matrix-360/assets/kam-brand/story-book/03_WEB/KAM_STORY_BOOK_LOGO_WEB_768.png','image/png',768,768,null,'transparent_or_light','full_color',false,'approved','Web derivative'),
  ('STORY_BOOK','Story Book','WEB_512','supporting','assets/kam-brand/story-book/03_WEB/KAM_STORY_BOOK_LOGO_WEB_512.png','https://tamereltaher-svg.github.io/aviation-matrix-360/assets/kam-brand/story-book/03_WEB/KAM_STORY_BOOK_LOGO_WEB_512.png','image/png',512,512,null,'transparent_or_light','full_color',false,'approved','Web derivative'),
  ('STORY_BOOK','Story Book','WEB_256','supporting','assets/kam-brand/story-book/03_WEB/KAM_STORY_BOOK_LOGO_WEB_256.png','https://tamereltaher-svg.github.io/aviation-matrix-360/assets/kam-brand/story-book/03_WEB/KAM_STORY_BOOK_LOGO_WEB_256.png','image/png',256,256,null,'transparent_or_light','full_color',false,'approved','Web derivative'),
  ('COLORING_BOOK','Coloring Book','PRIMARY_MASTER','placeholder','assets/kam-brand/coloring-book/01_MASTER/KAM_COLORING_BOOK_LOGO_PRIMARY_MASTER.png',null,'image/png',null,null,null,'transparent_or_light','full_color',false,'draft','Design required; not yet approved'),
  ('ACTIVITY_BOOK','Activity Book','PRIMARY_MASTER','placeholder','assets/kam-brand/activity-book/01_MASTER/KAM_ACTIVITY_BOOK_LOGO_PRIMARY_MASTER.png',null,'image/png',null,null,null,'transparent_or_light','full_color',false,'draft','Design required; not yet approved')
) as v(product_code,product_name,variant_code,asset_role,asset_path,asset_url,mime_type,pixel_width,pixel_height,dpi,background_mode,color_mode,is_canonical,approval_status,notes)
on conflict (brand_profile_id, product_code, variant_code, asset_path) do update set
  asset_role = excluded.asset_role,
  asset_url = excluded.asset_url,
  mime_type = excluded.mime_type,
  pixel_width = excluded.pixel_width,
  pixel_height = excluded.pixel_height,
  dpi = excluded.dpi,
  background_mode = excluded.background_mode,
  color_mode = excluded.color_mode,
  is_canonical = excluded.is_canonical,
  approval_status = excluded.approval_status,
  notes = excluded.notes,
  updated_at = now();

with b as (select id from public.kids_brand_profiles where brand_code='KAM360')
insert into public.kids_brand_logo_rules (brand_profile_id, product_code, rule_code, rule_type, rule_text)
select b.id, r.product_code, r.rule_code, r.rule_type, r.rule_text
from b
cross join (values
  ('STORY_BOOK','LOCK_CANONICAL_ASSET','required','Use the canonical locked logo asset; do not regenerate the logo inside AI artwork.'),
  ('STORY_BOOK','NO_CHARACTER_REDRAW','forbidden','Do not redraw, replace, or reinterpret Ava or Ben inside the approved Story Book logo.'),
  ('STORY_BOOK','NO_DISTORTION','forbidden','Do not stretch, skew, crop through, or distort the logo badge.'),
  ('STORY_BOOK','UNIFORM_SCALE_ONLY','allowed','Uniform scaling is allowed while preserving proportions.'),
  ('STORY_BOOK','NO_RANDOM_RECOLOR','forbidden','Do not recolor individual logo elements outside approved variants.'),
  ('COLORING_BOOK','DESIGN_ONCE_LOCK_AFTER_APPROVAL','required','Design once, approve, register canonical asset, then lock and reuse everywhere.'),
  ('COLORING_BOOK','USE_CHARACTER_LOCK','required','If Ava or Ben appear, use their approved canonical identity references during design and preserve locked identity.'),
  ('ACTIVITY_BOOK','DESIGN_ONCE_LOCK_AFTER_APPROVAL','required','Design once, approve, register canonical asset, then lock and reuse everywhere.'),
  ('ACTIVITY_BOOK','USE_CHARACTER_LOCK','required','If Ava or Ben appear, use their approved canonical identity references during design and preserve locked identity.')
) as r(product_code,rule_code,rule_type,rule_text)
on conflict (brand_profile_id, product_code, rule_code) do update set
  rule_type = excluded.rule_type,
  rule_text = excluded.rule_text,
  is_active = true,
  updated_at = now();

with b as (select id from public.kids_brand_profiles where brand_code='KAM360')
insert into public.kids_brand_placement_rules (brand_profile_id, product_code, placement_code, placement_name, is_required, safe_area_rule, notes)
select b.id, p.product_code, p.placement_code, p.placement_name, p.is_required, p.safe_area_rule, p.notes
from b
cross join (values
  ('STORY_BOOK','FRONT_COVER','Front Cover',true,'Use top-center or upper third with clear space around full badge.','Primary book-cover placement.'),
  ('STORY_BOOK','BACK_COVER','Back Cover',false,'Use as smaller series/brand mark; keep clear of barcode and legal blocks.','Secondary placement.'),
  ('STORY_BOOK','INTERIOR_TITLE','Interior Title/Copyright',false,'Optional small mark only; avoid repeating on every page.','Interior placement.'),
  ('STORY_BOOK','STORE_THUMBNAIL','Store Thumbnail',false,'Prefer 512px or 768px approved derivative.','Digital commerce placement.')
) as p(product_code,placement_code,placement_name,is_required,safe_area_rule,notes)
on conflict (brand_profile_id, product_code, placement_code) do update set
  placement_name=excluded.placement_name,
  is_required=excluded.is_required,
  safe_area_rule=excluded.safe_area_rule,
  notes=excluded.notes,
  updated_at=now();

with b as (select id from public.kids_brand_profiles where brand_code='KAM360')
insert into public.kids_brand_versions (brand_profile_id, product_code, version_label, lifecycle_status, change_summary, effective_from)
select b.id, v.product_code, v.version_label, v.lifecycle_status, v.change_summary,
       case when v.lifecycle_status in ('approved','locked') then now() end
from b
cross join (values
  ('STORY_BOOK','v1.0','locked','Initial Story Book logo family lock and registry entry.'),
  ('COLORING_BOOK','v1.0','draft','Initial Coloring Book logo placeholder; design required.'),
  ('ACTIVITY_BOOK','v1.0','draft','Initial Activity Book logo placeholder; design required.')
) as v(product_code,version_label,lifecycle_status,change_summary)
on conflict (brand_profile_id, product_code, version_label) do update set
  lifecycle_status=excluded.lifecycle_status,
  change_summary=excluded.change_summary;

create or replace view public.kids_brand_logo_readiness as
select
  bp.brand_code,
  bp.brand_name,
  la.product_code,
  max(la.product_name) as product_name,
  count(*) filter (where la.approval_status='locked' and la.is_canonical) as locked_canonical_count,
  count(*) filter (where la.approval_status in ('approved','locked')) as approved_asset_count,
  count(*) filter (where la.approval_status='draft') as draft_asset_count,
  case
    when count(*) filter (where la.approval_status='locked' and la.is_canonical) > 0 then 'LOCKED_READY'
    when count(*) filter (where la.approval_status='approved' and la.is_canonical) > 0 then 'APPROVED_NOT_LOCKED'
    else 'DESIGN_REQUIRED'
  end as readiness_status
from public.kids_brand_profiles bp
join public.kids_brand_logo_assets la on la.brand_profile_id=bp.id
group by bp.brand_code,bp.brand_name,la.product_code;

create or replace function public.kids_get_brand_logo_bundle(p_product_code text)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'brand', jsonb_build_object(
      'brand_code', bp.brand_code,
      'brand_name', bp.brand_name,
      'tagline', bp.tagline,
      'design_direction', bp.design_direction
    ),
    'product_code', p_product_code,
    'assets', coalesce((
      select jsonb_agg(to_jsonb(a) order by a.is_canonical desc, a.variant_code)
      from public.kids_brand_logo_assets a
      where a.brand_profile_id=bp.id and a.product_code=p_product_code
    ), '[]'::jsonb),
    'rules', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.rule_code)
      from public.kids_brand_logo_rules r
      where r.brand_profile_id=bp.id and r.product_code=p_product_code and r.is_active
    ), '[]'::jsonb),
    'placements', coalesce((
      select jsonb_agg(to_jsonb(p) order by p.placement_code)
      from public.kids_brand_placement_rules p
      where p.brand_profile_id=bp.id and p.product_code=p_product_code
    ), '[]'::jsonb),
    'readiness', (
      select to_jsonb(rr)
      from public.kids_brand_logo_readiness rr
      where rr.brand_code=bp.brand_code and rr.product_code=p_product_code
    )
  )
  from public.kids_brand_profiles bp
  where bp.brand_code='KAM360';
$$;

commit;
