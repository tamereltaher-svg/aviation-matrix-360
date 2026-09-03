create table if not exists public.store_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'store_admin' check (role in ('store_admin','store_manager')),
  created_at timestamptz not null default now()
);

alter table public.store_admins enable row level security;

create or replace function public.is_store_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.store_admins a where a.user_id = auth.uid()
  );
$$;

revoke all on function public.is_store_admin() from public;
grant execute on function public.is_store_admin() to authenticated;

-- Sanitized: production store-admin identity seed omitted.

drop policy if exists store_admin_self_read on public.store_admins;
create policy store_admin_self_read on public.store_admins
for select to authenticated
using (user_id = auth.uid());

-- Admin write policies for product tables
create policy store_products_admin_insert on public.store_products for insert to authenticated with check (public.is_store_admin());
create policy store_products_admin_update on public.store_products for update to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy store_products_admin_delete on public.store_products for delete to authenticated using (public.is_store_admin());

create policy store_images_admin_insert on public.store_product_images for insert to authenticated with check (public.is_store_admin());
create policy store_images_admin_update on public.store_product_images for update to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy store_images_admin_delete on public.store_product_images for delete to authenticated using (public.is_store_admin());

create policy store_variants_admin_insert on public.store_product_variants for insert to authenticated with check (public.is_store_admin());
create policy store_variants_admin_update on public.store_product_variants for update to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy store_variants_admin_delete on public.store_product_variants for delete to authenticated using (public.is_store_admin());

create policy store_personalization_admin_insert on public.store_personalization_options for insert to authenticated with check (public.is_store_admin());
create policy store_personalization_admin_update on public.store_personalization_options for update to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy store_personalization_admin_delete on public.store_personalization_options for delete to authenticated using (public.is_store_admin());

create policy store_audiences_admin_insert on public.store_product_audiences for insert to authenticated with check (public.is_store_admin());
create policy store_audiences_admin_update on public.store_product_audiences for update to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy store_audiences_admin_delete on public.store_product_audiences for delete to authenticated using (public.is_store_admin());

-- Authenticated store admins can upload/update/delete product images in the product-images bucket
create policy product_images_admin_insert on storage.objects for insert to authenticated with check (bucket_id='product-images' and public.is_store_admin());
create policy product_images_admin_update on storage.objects for update to authenticated using (bucket_id='product-images' and public.is_store_admin()) with check (bucket_id='product-images' and public.is_store_admin());
create policy product_images_admin_delete on storage.objects for delete to authenticated using (bucket_id='product-images' and public.is_store_admin());
