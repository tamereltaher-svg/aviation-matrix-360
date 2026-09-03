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
