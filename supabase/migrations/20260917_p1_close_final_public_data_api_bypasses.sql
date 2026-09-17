-- Aviation Matrix — Final Security Audit blocker remediation
-- Date: 2026-09-17
-- Purpose: close legacy assessment RPC, direct application insert, and Kids restricted-content Data API bypasses.

-- 1) Legacy public assessment RPCs: preserve server-side compatibility only.
revoke execute on function public.public_start_assessment(text,text,date,text) from public, anon, authenticated;
revoke execute on function public.public_submit_assessment_answer(uuid,uuid,uuid,uuid,integer) from public, anon, authenticated;
revoke execute on function public.public_finish_assessment(uuid,uuid,text) from public, anon, authenticated;

grant execute on function public.public_start_assessment(text,text,date,text) to service_role;
grant execute on function public.public_submit_assessment_answer(uuid,uuid,uuid,uuid,integer) to service_role;
grant execute on function public.public_finish_assessment(uuid,uuid,text) to service_role;

-- 2) Registration must enter through application-login -> service-role RPC -> DB controls.
revoke insert on table public.aviation_interest_leads from anon, authenticated;
drop policy if exists public_can_submit_aviation_interest on public.aviation_interest_leads;

-- 3) Direct Kids Data API must expose only genuinely public tiers.
drop policy if exists public_read_published_kids_content on public.kids_content_items;
create policy public_read_published_kids_content
on public.kids_content_items
for select
to anon, authenticated
using (
  status = 'published'
  and access_level in ('free','public_preview')
);

-- 4) Public Kids asset metadata must exclude protected/restricted assets.
drop policy if exists public_read_published_kids_assets on public.kids_content_assets;
create policy public_read_published_kids_assets
on public.kids_content_assets
for select
to anon, authenticated
using (
  coalesce(is_protected,false) = false
  and coalesce(storage_bucket,'kids-assets') = 'kids-assets'
  and exists (
    select 1
    from public.kids_content_items c
    where c.id = kids_content_assets.content_item_id
      and c.status = 'published'
      and c.access_level in ('free','public_preview')
  )
);
