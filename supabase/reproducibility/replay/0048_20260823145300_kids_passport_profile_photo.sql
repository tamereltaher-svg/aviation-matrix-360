alter table public.kids_explorer_passports add column if not exists profile_photo_path text, add column if not exists profile_photo_updated_at timestamptz;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('kids-profile-photos','kids-profile-photos',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
