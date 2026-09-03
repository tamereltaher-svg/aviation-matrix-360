alter table public.am_programs
  add column if not exists cover_image_path text,
  add column if not exists cover_image_alt text,
  add column if not exists card_theme text not null default 'aviation_blue',
  add column if not exists overlay_strength integer not null default 42;

alter table public.am_programs
  drop constraint if exists am_programs_card_theme_check;
alter table public.am_programs
  add constraint am_programs_card_theme_check
  check (card_theme in ('aviation_blue','light','dark','kids_colorful'));

alter table public.am_programs
  drop constraint if exists am_programs_overlay_strength_check;
alter table public.am_programs
  add constraint am_programs_overlay_strength_check
  check (overlay_strength between 0 and 85);

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('program-images','program-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public=true,
  file_size_limit=5242880,
  allowed_mime_types=array['image/jpeg','image/png','image/webp'];
