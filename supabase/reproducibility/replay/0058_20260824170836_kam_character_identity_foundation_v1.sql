create table if not exists public.kids_character_identity_profiles (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null unique references public.kids_characters(id) on delete cascade,
  character_code text not null,
  character_name text not null,
  identity_version text not null default '1.0',
  identity_status text not null default 'foundation_pending' check (identity_status in ('foundation_pending','draft','review','approved','superseded')),
  face_shape text,
  skin_tone text,
  eye_shape text,
  eye_color text,
  hair_style text,
  hair_color text,
  body_proportions text,
  age_appearance text,
  default_outfit text,
  signature_accessories text,
  silhouette_notes text,
  color_palette jsonb not null default '{}'::jsonb,
  immutable_traits jsonb not null default '[]'::jsonb,
  flexible_traits jsonb not null default '[]'::jsonb,
  do_not_change jsonb not null default '[]'::jsonb,
  source_code text,
  notes text,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_character_visual_rules (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.kids_characters(id) on delete cascade,
  character_code text not null,
  rule_category text not null,
  rule_text text not null,
  strictness text not null default 'hard_lock' check (strictness in ('hard_lock','soft_lock','guidance')),
  source_type text not null default 'source_derived' check (source_type in ('source_derived','production_rule','approved_art_reference')),
  source_code text,
  is_active boolean not null default true,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists kids_character_visual_rules_uq
on public.kids_character_visual_rules(character_id, rule_category, rule_text);

create table if not exists public.kids_character_reference_requirements (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.kids_characters(id) on delete cascade,
  character_code text not null,
  reference_type text not null check (reference_type in ('master_front','master_three_quarter','master_side','full_body','face_closeup','expressions_sheet','poses_sheet','outfit_sheet','accessories_sheet','color_palette')),
  required boolean not null default true,
  minimum_count integer not null default 1 check (minimum_count >= 1),
  status text not null default 'missing' check (status in ('missing','in_production','review','approved')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(character_id, reference_type)
);

create table if not exists public.kids_character_identity_versions (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.kids_characters(id) on delete cascade,
  identity_version text not null,
  snapshot jsonb not null,
  status text not null default 'draft' check (status in ('draft','approved','superseded')),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique(character_id, identity_version)
);

alter table public.kids_character_identity_profiles enable row level security;
alter table public.kids_character_visual_rules enable row level security;
alter table public.kids_character_reference_requirements enable row level security;
alter table public.kids_character_identity_versions enable row level security;

insert into public.kids_character_identity_profiles(character_id,character_code,character_name,source_code,notes)
select id,code,name,'KAM_08_CHARACTERS_MASTER','Visual DNA fields intentionally left undefined until approved master references are produced.'
from public.kids_characters
where code in ('AW-001','BJ-001','MC-001','CM-001','MX-001','DS-001','DM-001')
on conflict (character_id) do update set
 character_code=excluded.character_code,
 character_name=excluded.character_name,
 source_code=excluded.source_code,
 updated_at=now();

insert into public.kids_character_visual_rules(character_id,character_code,rule_category,rule_text,strictness,source_type,source_code,sort_order)
select kc.id,kc.code,'appearance',x.rule,'hard_lock','source_derived','KAM_21_CHARACTER_APPEARANCE_CONTROL',10
from (values
 ('AW-001','Consistent hairstyle and explorer outfit'),
 ('BJ-001','Consistent travel outfit'),
 ('MC-001','Professional mentor appearance'),
 ('CM-001','Pilot uniform standards'),
 ('MX-001','Engineering attire standards')
) as x(code,rule)
join public.kids_characters kc on kc.code=x.code
on conflict do nothing;

insert into public.kids_character_visual_rules(character_id,character_code,rule_category,rule_text,strictness,source_type,source_code,sort_order)
select kc.id,kc.code,'continuity','Character identity must remain visually consistent across missions and production assets.','hard_lock','production_rule','Character Identity Foundation v1',20
from public.kids_characters kc
where kc.code in ('AW-001','BJ-001','MC-001','CM-001','MX-001','DS-001','DM-001')
on conflict do nothing;

insert into public.kids_character_reference_requirements(character_id,character_code,reference_type,required,minimum_count,notes)
select kc.id,kc.code,r.reference_type,true,r.minimum_count,r.notes
from public.kids_characters kc
cross join (values
 ('master_front',1,'Primary canonical identity reference'),
 ('master_three_quarter',1,'Canonical three-quarter identity reference'),
 ('master_side',1,'Canonical side-profile reference'),
 ('full_body',1,'Canonical full-body proportions and outfit reference'),
 ('face_closeup',1,'Face identity and feature reference'),
 ('expressions_sheet',1,'Approved core expression set'),
 ('poses_sheet',1,'Approved core pose set'),
 ('outfit_sheet',1,'Approved standard outfit construction'),
 ('accessories_sheet',1,'Approved signature accessories'),
 ('color_palette',1,'Approved character color palette')
) as r(reference_type,minimum_count,notes)
where kc.code in ('AW-001','BJ-001','MC-001','CM-001','MX-001','DS-001','DM-001')
on conflict (character_id,reference_type) do nothing;
