create table if not exists public.kids_character_lock_policies (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.kids_characters(id) on delete cascade,
  character_code text not null,
  rule_key text not null,
  lock_scope text not null,
  expected_value jsonb not null default '{}'::jsonb,
  enforcement_mode text not null default 'hard' check (enforcement_mode in ('hard','soft')),
  severity text not null default 'critical' check (severity in ('critical','major','minor')),
  tolerance jsonb not null default '{}'::jsonb,
  source_type text not null default 'official_reference',
  source_ref text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(character_id, rule_key)
);

alter table public.kids_character_lock_policies enable row level security;
revoke all on public.kids_character_lock_policies from anon, authenticated;

create or replace function public.kids_get_character_lock_bundle(p_character_id uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'character', to_jsonb(c),
    'identity_profile', coalesce((select to_jsonb(p) from public.kids_character_identity_profiles p where p.character_id=c.id limit 1),'{}'::jsonb),
    'canonical_references', coalesce((select jsonb_agg(to_jsonb(a) order by a.asset_type) from public.kids_character_reference_assets a where a.character_id=c.id and a.is_canonical=true),'[]'::jsonb),
    'visual_rules', coalesce((select jsonb_agg(to_jsonb(r) order by r.sort_order,r.rule_category) from public.kids_character_visual_rules r where r.character_id=c.id and r.is_active=true),'[]'::jsonb),
    'lock_policies', coalesce((select jsonb_agg(to_jsonb(l) order by l.lock_scope,l.rule_key) from public.kids_character_lock_policies l where l.character_id=c.id and l.is_active=true),'[]'::jsonb)
  )
  from public.kids_characters c
  where c.id=p_character_id;
$$;
revoke all on function public.kids_get_character_lock_bundle(uuid) from public;

create or replace view public.kids_character_lock_readiness as
select c.id as character_id,c.code as character_code,c.name as character_name,
       count(distinct l.id) filter (where l.is_active) as active_lock_rules,
       count(distinct a.id) filter (where a.is_canonical) as canonical_reference_count,
       case when count(distinct l.id) filter (where l.is_active)>=8 and count(distinct a.id) filter (where a.is_canonical)>=3 then 'LOCK_READY' else 'NOT_READY' end as lock_status
from public.kids_characters c
left join public.kids_character_lock_policies l on l.character_id=c.id
left join public.kids_character_reference_assets a on a.character_id=c.id
group by c.id,c.code,c.name;
revoke all on public.kids_character_lock_readiness from anon, authenticated;

update public.kids_characters set code='TC-001', name='Tara Control', short_name='Tara', role_title='Navigation Guide', updated_at=now() where code='MC-001';
update public.kids_character_identity_profiles set character_code='TC-001', character_name='Tara Control', updated_at=now() where character_code='MC-001';
update public.kids_character_visual_rules set character_code='TC-001', updated_at=now() where character_code='MC-001';
update public.kids_character_reference_requirements set character_code='TC-001', updated_at=now() where character_code='MC-001';
update public.kids_character_appearance_control set character_code='TC-001', character_name='Tara Control', updated_at=now() where character_code='MC-001';

update public.kids_character_identity_profiles p set
  identity_version='1.0', identity_status='review',
  face_shape='rounded child face',
  eye_shape='large rounded cartoon eyes',
  eye_color='brown',
  hair_style=case p.character_code when 'AW-001' then 'long wavy brown hair under navy explorer cap' when 'BJ-001' then 'short tousled brown hair' when 'CM-001' then 'short brown hair under captain cap' when 'DS-001' then 'brown hair in low side bun under cabin-crew hat' when 'MX-001' then 'short tousled brown hair under navy mechanic cap' when 'TC-001' then 'brown hair tied back in low ponytail with headset' when 'DM-001' then 'neatly styled swept brown hair with glasses' end,
  hair_color='brown',
  body_proportions='kid-friendly premium 3D cartoon proportions; preserve canonical head-to-body ratio',
  age_appearance=case p.character_code when 'AW-001' then '8–10 years visual age' when 'BJ-001' then '8–10 years visual age' when 'CM-001' then '10–12 years visual age' when 'DS-001' then '8–10 years visual age' when 'MX-001' then '9–12 years visual age' when 'TC-001' then '9–12 years visual age' when 'DM-001' then '10–12 years visual age' end,
  default_outfit=case p.character_code when 'AW-001' then 'navy cap, denim jacket, white graphic shirt, denim jeans, pink high-top sneakers, pink backpack' when 'BJ-001' then 'blue casual jacket, light shirt, khaki cargo trousers, blue-and-white sneakers, green backpack' when 'CM-001' then 'navy young-captain uniform with gold trim, white shirt, dark tie, captain cap, black shoes' when 'DS-001' then 'navy cabin-crew dress with pink trim, pink neck scarf and belt, matching hat, black shoes' when 'MX-001' then 'navy mechanic coveralls, navy cap, brown tool belt, brown work boots' when 'TC-001' then 'light-blue aviation shirt, navy trousers, dark tie, headset, ID badge, black shoes' when 'DM-001' then 'navy aviation jacket, white shirt, dark tie, khaki trousers, navy-and-white sneakers, black glasses' end,
  signature_accessories=case p.character_code when 'AW-001' then 'navy explorer cap; pink backpack; passport; pink rolling suitcase' when 'BJ-001' then 'green backpack; travel ticket/card' when 'CM-001' then 'captain cap; gold wings; black rolling case' when 'DS-001' then 'pink scarf; cabin-crew hat; pink rolling case' when 'MX-001' then 'wrench; tool belt; mechanic cap' when 'TC-001' then 'black headset; handheld radio; ID badge' when 'DM-001' then 'black glasses; tablet; clipboard' end,
  immutable_traits=jsonb_build_object('face_identity','reference-image locked','hair_identity','locked','eye_identity','locked','age_look','locked','body_proportions','locked','default_outfit','locked','signature_accessories','locked'),
  flexible_traits=jsonb_build_object('pose','allowed within approved pose logic','expression','allowed if facial identity preserved','camera_angle','allowed','background','allowed','hand_props','only role-appropriate approved props'),
  do_not_change=jsonb_build_object('face_shape',true,'eye_shape',true,'hair_style',true,'hair_color',true,'age_appearance',true,'body_proportions',true,'outfit_design',true,'signature_accessories',true,'character_code',true),
  notes='Character Lock v1: generated artwork must match canonical source references; text description is secondary to image reference.',
  updated_at=now();

insert into public.kids_character_reference_assets(character_id,character_code,character_name,asset_type,asset_role,source_file_name,storage_path,source_status,approval_status,is_canonical,metadata)
select c.id,c.code,c.name,x.asset_type,x.asset_role,'1000413304.png',null,'official_library_source','source_locked',true,jsonb_build_object('phase','2','source','KAM Character Studio official artwork')
from public.kids_characters c
cross join (values ('master_source','master_source'),('full_body','canonical_full_body'),('face_closeup','canonical_face_closeup')) as x(asset_type,asset_role)
where c.code='TC-001'
and not exists (select 1 from public.kids_character_reference_assets a where a.character_id=c.id and a.asset_type=x.asset_type and a.is_canonical=true);

insert into public.kids_character_lock_policies(character_id,character_code,rule_key,lock_scope,expected_value,enforcement_mode,severity,tolerance,source_type,source_ref)
select c.id,c.code,v.rule_key,v.lock_scope,v.expected_value::jsonb,v.enforcement_mode,v.severity,v.tolerance::jsonb,'official_reference','KAM Phase2 Source-Locked Reference Pack'
from public.kids_characters c
cross join lateral (
 values
 ('face_identity','face','{"require":"match canonical face reference"}','hard','critical','{"variation":"none"}'),
 ('eye_identity','face','{"require":"preserve canonical eye shape, size, spacing and brown color"}','hard','critical','{"variation":"none"}'),
 ('hair_identity','hair','{"require":"preserve canonical hairstyle, hairline and brown color"}','hard','critical','{"variation":"none"}'),
 ('age_identity','proportions','{"require":"preserve canonical visual age"}','hard','critical','{"variation":"none"}'),
 ('body_proportions','proportions','{"require":"preserve canonical child proportions and silhouette"}','hard','critical','{"variation":"none"}'),
 ('outfit_identity','outfit','{"require":"preserve canonical outfit design, major colors and role markers"}','hard','critical','{"variation":"none"}'),
 ('signature_accessories','accessories','{"require":"preserve character-defining accessories whenever visible"}','hard','major','{"variation":"only scene-driven visibility"}'),
 ('art_style','style','{"require":"premium bright clean warm child-friendly 3D cartoon KAM style"}','hard','major','{"variation":"lighting and environment only"}'),
 ('pose_flexibility','pose','{"allow":"pose variation without silhouette or anatomy drift"}','soft','minor','{"variation":"approved natural poses"}'),
 ('expression_flexibility','expression','{"allow":"expression variation while preserving face identity"}','soft','minor','{"variation":"happy curious thinking surprised confident calm"}')
) as v(rule_key,lock_scope,expected_value,enforcement_mode,severity,tolerance)
where c.code in ('AW-001','BJ-001','CM-001','DS-001','MX-001','TC-001','DM-001')
on conflict(character_id,rule_key) do update set expected_value=excluded.expected_value,enforcement_mode=excluded.enforcement_mode,severity=excluded.severity,tolerance=excluded.tolerance,source_ref=excluded.source_ref,is_active=true,updated_at=now();
