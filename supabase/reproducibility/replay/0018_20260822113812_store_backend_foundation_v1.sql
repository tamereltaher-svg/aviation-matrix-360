create extension if not exists pgcrypto;

create table if not exists public.store_products (
  id uuid primary key default gen_random_uuid(),
  sku text unique,
  slug text unique not null,
  name text not null,
  short_description text,
  description text,
  category text not null,
  currency text not null default 'EGP',
  base_price numeric(12,2) not null default 0 check (base_price >= 0),
  price_is_estimate boolean not null default true,
  is_active boolean not null default true,
  is_featured boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.store_products(id) on delete cascade,
  storage_path text not null,
  alt_text text,
  is_primary boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique(product_id, storage_path)
);

create unique index if not exists uq_store_product_primary_image
  on public.store_product_images(product_id)
  where is_primary = true;

create table if not exists public.store_product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.store_products(id) on delete cascade,
  variant_type text not null,
  variant_value text not null,
  price_delta numeric(12,2) not null default 0,
  sku_suffix text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique(product_id, variant_type, variant_value)
);

create table if not exists public.store_personalization_options (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.store_products(id) on delete cascade,
  code text not null,
  label text not null,
  input_type text not null check (input_type in ('text','image','select','boolean','textarea')),
  is_required boolean not null default false,
  price_delta numeric(12,2) not null default 0,
  config jsonb not null default '{}'::jsonb,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(product_id, code)
);

create table if not exists public.store_product_audiences (
  product_id uuid not null references public.store_products(id) on delete cascade,
  audience_code text not null check (audience_code in ('nursery','school','university','individual','institution','government')),
  primary key(product_id, audience_code)
);

create or replace function public.set_store_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_store_products_updated_at on public.store_products;
create trigger trg_store_products_updated_at
before update on public.store_products
for each row execute function public.set_store_updated_at();

alter table public.store_products enable row level security;
alter table public.store_product_images enable row level security;
alter table public.store_product_variants enable row level security;
alter table public.store_personalization_options enable row level security;
alter table public.store_product_audiences enable row level security;

create policy store_products_public_read on public.store_products
for select to anon, authenticated
using (is_active = true);

create policy store_images_public_read on public.store_product_images
for select to anon, authenticated
using (exists (select 1 from public.store_products p where p.id = product_id and p.is_active = true));

create policy store_variants_public_read on public.store_product_variants
for select to anon, authenticated
using (is_active = true and exists (select 1 from public.store_products p where p.id = product_id and p.is_active = true));

create policy store_personalization_public_read on public.store_personalization_options
for select to anon, authenticated
using (is_active = true and exists (select 1 from public.store_products p where p.id = product_id and p.is_active = true));

create policy store_audiences_public_read on public.store_product_audiences
for select to anon, authenticated
using (exists (select 1 from public.store_products p where p.id = product_id and p.is_active = true));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy product_images_public_storage_read on storage.objects
for select to public
using (bucket_id = 'product-images');
