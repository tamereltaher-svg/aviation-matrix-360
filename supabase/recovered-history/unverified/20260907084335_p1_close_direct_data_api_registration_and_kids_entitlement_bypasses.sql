-- Close direct application registration bypass.
revoke insert on table public.aviation_interest_leads from anon, authenticated;
drop policy if exists public_can_submit_aviation_interest on public.aviation_interest_leads;

-- Public Kids Data API is read-only; learner-authorized access stays behind kids-experience-api/service_role.
revoke insert, update, delete, truncate, references, trigger on table public.kids_content_items from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.kids_content_assets from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.kids_content_age_groups from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.kids_content_characters from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.program_content_items from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.kids_product_links from anon, authenticated;

-- Only published free/public_preview items are directly public.
drop policy if exists public_read_published_kids_content on public.kids_content_items;
create policy public_read_published_kids_content
on public.kids_content_items
for select
to anon, authenticated
using (
  status = 'published'
  and access_level in ('free','public_preview')
);

-- Only unprotected assets belonging to directly-public content are directly readable.
drop policy if exists public_read_published_kids_assets on public.kids_content_assets;
create policy public_read_published_kids_assets
on public.kids_content_assets
for select
to anon, authenticated
using (
  is_protected = false
  and storage_bucket = 'kids-assets'
  and exists (
    select 1
    from public.kids_content_items c
    where c.id = kids_content_assets.content_item_id
      and c.status = 'published'
      and c.access_level in ('free','public_preview')
  )
);

-- Child relations follow the exact same public entitlement boundary.
drop policy if exists public_read_kids_content_age_groups on public.kids_content_age_groups;
create policy public_read_kids_content_age_groups
on public.kids_content_age_groups
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.kids_content_items c
    where c.id = kids_content_age_groups.content_item_id
      and c.status = 'published'
      and c.access_level in ('free','public_preview')
  )
);

drop policy if exists public_read_kids_content_characters on public.kids_content_characters;
create policy public_read_kids_content_characters
on public.kids_content_characters
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.kids_content_items c
    where c.id = kids_content_characters.content_item_id
      and c.status = 'published'
      and c.access_level in ('free','public_preview')
  )
);

drop policy if exists public_read_program_content on public.program_content_items;
create policy public_read_program_content
on public.program_content_items
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.kids_content_items c
    where c.id = program_content_items.content_item_id
      and c.status = 'published'
      and c.access_level in ('free','public_preview')
  )
  and exists (
    select 1
    from public.am_programs p
    where p.id = program_content_items.program_id
      and p.is_active = true
  )
);

drop policy if exists public_read_kids_product_links on public.kids_product_links;
create policy public_read_kids_product_links
on public.kids_product_links
for select
to anon, authenticated
using (
  content_item_id is not null
  and exists (
    select 1
    from public.kids_content_items c
    where c.id = kids_product_links.content_item_id
      and c.status = 'published'
      and c.access_level in ('free','public_preview')
  )
  and exists (
    select 1
    from public.store_products sp
    where sp.id = kids_product_links.product_id
      and sp.is_active = true
  )
);