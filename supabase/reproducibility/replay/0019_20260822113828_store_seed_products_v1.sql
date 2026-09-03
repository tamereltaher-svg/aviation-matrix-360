insert into public.store_products (sku,slug,name,short_description,description,category,currency,base_price,price_is_estimate,is_active,sort_order)
values
('AM-NB-001','aviation-matrix-notebook','Aviation Matrix Notebook','Premium aviation-themed notebook for students and institutional programs.','Hard cover notebook suitable for student kits, school programs, events, and personalization.','STATIONERY','EGP',220,true,true,10),
('AM-MG-001','aviation-matrix-mug','Aviation Matrix Mug','Branded aviation mug for gifts, staff packs, and events.','Ceramic mug with branding and personalization options.','MERCH','EGP',180,true,true,20),
('AM-ID-001','student-id-lanyard','Student ID + Lanyard','Student identity card and lanyard for programs and clubs.','Printed student ID card with lanyard for aviation programs, clubs, and institutional events.','IDENTITY','EGP',150,true,true,30),
('AM-KIT-001','student-aviation-kit','Student Aviation Kit','Bundled student kit for Aviation Matrix learning experiences.','Student kit combining selected learning and branded materials.','KIT','EGP',650,true,true,40),
('AM-TS-001','aviation-tshirt','Aviation T-Shirt','Aviation-themed T-shirt for students, teams, and school clubs.','Comfort apparel with branding and personalization options.','APPAREL','EGP',450,true,true,50),
('AM-CAP-001','aviation-cap','Aviation Cap','Aviation Matrix cap for activities and student kits.','Adjustable cap suitable for school programs, clubs, field days, and events.','APPAREL','EGP',280,true,true,60),
('AM-UNI-001','full-aviation-uniform','Full Aviation Uniform','Full aviation-inspired uniform for programs and institutional packages.','Uniform package with apparel components and personalization options.','UNIFORM','EGP',1850,true,true,70),
('AM-BAG-001','aviation-backpack','Aviation Backpack','Aviation-themed backpack for student bundles and programs.','Multi-pocket backpack suitable for student use and institutional branding.','BAG','EGP',760,true,true,80),
('AM-BDG-001','personalized-name-badge','Personalized Name Badge','Individual name badge for students, uniforms, clubs, and events.','Printed or engraved student name badge with Aviation Matrix identity.','IDENTITY','EGP',120,true,true,90)
on conflict (slug) do update set
 name=excluded.name, short_description=excluded.short_description, description=excluded.description,
 category=excluded.category, base_price=excluded.base_price, price_is_estimate=excluded.price_is_estimate,
 is_active=excluded.is_active, sort_order=excluded.sort_order, updated_at=now();

insert into public.store_product_audiences(product_id,audience_code)
select p.id,a.audience_code
from public.store_products p
cross join (values ('nursery'),('school'),('university'),('institution'),('government')) a(audience_code)
where p.slug in ('aviation-matrix-notebook','aviation-matrix-mug','student-id-lanyard','student-aviation-kit','aviation-tshirt','aviation-cap','full-aviation-uniform','aviation-backpack','personalized-name-badge')
on conflict do nothing;

insert into public.store_product_variants(product_id,variant_type,variant_value,sort_order)
select p.id,'size',v.val,v.ord
from public.store_products p
join lateral (values
 ('6Y',10),('8Y',20),('10Y',30),('12Y',40),('14Y',50),('XS',60),('S',70),('M',80),('L',90),('XL',100)
) v(val,ord) on true
where p.slug in ('aviation-tshirt','full-aviation-uniform')
on conflict do nothing;

insert into public.store_product_variants(product_id,variant_type,variant_value,sort_order)
select p.id,'size',v.val,v.ord
from public.store_products p
join lateral (values ('Kids',10),('Adult',20)) v(val,ord) on true
where p.slug='aviation-cap'
on conflict do nothing;

insert into public.store_personalization_options(product_id,code,label,input_type,is_required,price_delta,sort_order)
select p.id,x.code,x.label,x.input_type,x.required,x.price_delta,x.sort_order
from public.store_products p
join lateral (values
 ('student_name','Student Name','text',false,0::numeric,10),
 ('institution_name','Institution Name','text',false,0::numeric,20),
 ('logo','Institution Logo','image',false,0::numeric,30)
) x(code,label,input_type,required,price_delta,sort_order) on true
where p.slug in ('aviation-matrix-notebook','aviation-matrix-mug','student-id-lanyard','student-aviation-kit','aviation-tshirt','aviation-cap','aviation-backpack','personalized-name-badge','full-aviation-uniform')
on conflict do nothing;

insert into public.store_personalization_options(product_id,code,label,input_type,is_required,price_delta,sort_order,config)
select p.id,'uniform_notes','Uniform Notes','textarea',false,0,40,'{"placeholder":"Badge text, trousers/skirt, jacket notes, sizing notes"}'::jsonb
from public.store_products p where p.slug='full-aviation-uniform'
on conflict do nothing;
