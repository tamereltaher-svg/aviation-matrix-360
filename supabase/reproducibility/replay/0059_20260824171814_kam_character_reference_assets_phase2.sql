create table if not exists public.kids_character_reference_assets (
  id uuid primary key default gen_random_uuid(),
  character_id uuid references public.kids_characters(id) on delete cascade,
  character_code text not null,
  character_name text not null,
  asset_type text not null,
  asset_role text not null,
  source_file_name text,
  storage_path text,
  source_status text not null default 'prepared_local',
  approval_status text not null default 'source_locked_phase2',
  is_canonical boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.kids_character_reference_assets enable row level security;
revoke all on public.kids_character_reference_assets from anon, authenticated;

create unique index if not exists kids_character_reference_assets_uq
on public.kids_character_reference_assets(character_code, asset_type, asset_role);

insert into public.kids_character_reference_assets(character_id,character_code,character_name,asset_type,asset_role,source_file_name,source_status,approval_status,is_canonical,metadata)
select c.id,c.code,c.name,'master_source','identity_anchor',
  case c.code
    when 'AW-001' then '1000413299.png'
    when 'BJ-001' then '1000413327.png'
    when 'CM-001' then '1000413300.png'
    when 'DS-001' then '1000413301.png'
    when 'MX-001' then '1000413302.png'
    when 'TC-001' then '1000413304.png'
    when 'DM-001' then '1000413303.png'
  end,
  'prepared_local','source_locked_phase2',true,
  jsonb_build_object('phase',2,'policy','exact source reference; no generative alteration')
from public.kids_characters c
where c.code in ('AW-001','BJ-001','CM-001','DS-001','MX-001','TC-001','DM-001')
on conflict (character_code, asset_type, asset_role) do update set
  source_file_name=excluded.source_file_name,
  source_status='prepared_local',
  approval_status='source_locked_phase2',
  is_canonical=true,
  updated_at=now();

insert into public.kids_character_reference_assets(character_id,character_code,character_name,asset_type,asset_role,source_file_name,source_status,approval_status,is_canonical,metadata)
select c.id,c.code,c.name,x.asset_type,x.asset_role,
  case c.code
    when 'AW-001' then '1000413299.png'
    when 'BJ-001' then '1000413327.png'
    when 'CM-001' then '1000413300.png'
    when 'DS-001' then '1000413301.png'
    when 'MX-001' then '1000413302.png'
    when 'TC-001' then '1000413304.png'
    when 'DM-001' then '1000413303.png'
  end,
  'prepared_local','source_locked_phase2',true,
  jsonb_build_object('phase',2,'derived_from_exact_source_crop',true)
from public.kids_characters c
cross join (values ('full_body','canonical_crop'),('face_closeup','canonical_crop')) as x(asset_type,asset_role)
where c.code in ('AW-001','BJ-001','CM-001','DS-001','MX-001','TC-001','DM-001')
on conflict (character_code, asset_type, asset_role) do update set
  source_file_name=excluded.source_file_name,
  source_status='prepared_local',
  approval_status='source_locked_phase2',
  is_canonical=true,
  updated_at=now();
