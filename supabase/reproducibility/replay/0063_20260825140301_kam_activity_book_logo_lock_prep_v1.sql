with bp as (
  select id from kids_brand_profiles where brand_code='KAM360' limit 1
)
insert into kids_brand_logo_rules (brand_profile_id, product_code, rule_code, rule_type, rule_text, is_active)
select bp.id, 'ACTIVITY_BOOK', v.rule_code, v.rule_type, v.rule_text, true
from bp
cross join (values
  ('LOCK_CANONICAL_ASSET','required','Use the approved canonical Activity Book logo asset; do not regenerate the logo inside AI artwork.'),
  ('NO_CHARACTER_REDRAW','forbidden','If Ava or Ben appear in the approved Activity Book logo, do not redraw, replace, or reinterpret them.'),
  ('NO_DISTORTION','forbidden','Do not stretch, skew, crop through, or distort the Activity Book logo badge.'),
  ('NO_RANDOM_RECOLOR','forbidden','Do not recolor individual Activity Book logo elements outside approved variants.'),
  ('UNIFORM_SCALE_ONLY','allowed','Uniform scaling is allowed while preserving proportions.')
) as v(rule_code, rule_type, rule_text)
where not exists (
  select 1 from kids_brand_logo_rules r
  where r.brand_profile_id=bp.id and r.product_code='ACTIVITY_BOOK' and r.rule_code=v.rule_code
);

with bp as (
  select id from kids_brand_profiles where brand_code='KAM360' limit 1
)
insert into kids_brand_placement_rules (
  brand_profile_id, product_code, placement_code, placement_name,
  is_required, safe_area_rule, notes
)
select bp.id, 'ACTIVITY_BOOK', v.placement_code, v.placement_name,
       v.is_required, v.safe_area_rule, v.notes
from bp
cross join (values
  ('FRONT_COVER','Front Cover',true,'Use top-center or upper third with clear space around full badge.','Primary Activity Book cover placement.'),
  ('BACK_COVER','Back Cover',false,'Use as a smaller series/brand mark; keep clear of barcode and legal blocks.','Secondary placement.'),
  ('INTERIOR_TITLE','Interior Title/Copyright',false,'Optional small mark only; avoid repeating on every page.','Interior placement.'),
  ('STORE_THUMBNAIL','Store Thumbnail',false,'Prefer 512px or 768px approved derivative.','Digital commerce placement.')
) as v(placement_code, placement_name, is_required, safe_area_rule, notes)
where not exists (
  select 1 from kids_brand_placement_rules p
  where p.brand_profile_id=bp.id and p.product_code='ACTIVITY_BOOK' and p.placement_code=v.placement_code
);
