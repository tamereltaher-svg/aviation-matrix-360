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
