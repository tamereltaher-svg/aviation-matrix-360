drop view if exists public.kids_production_dashboard;
create view public.kids_production_dashboard with (security_invoker=true) as
select
  (select count(*) from public.kids_missions) as total_missions,
  (select count(*) from public.kids_content_tracker where blueprint_status='Approved') as blueprint_approved,
  (select count(*) from public.kids_content_tracker where script_status='Approved') as script_approved,
  (select count(*) from public.kids_content_tracker where artwork_status='Approved') as artwork_approved,
  (select count(*) from public.kids_content_tracker where final_qa_status='Approved') as final_approved,
  (select count(*) from public.kids_script_pages) as script_pages,
  (select count(*) from public.kids_artwork_pages) as artwork_pages,
  (select count(*) from public.kids_illustration_assets) as illustration_assets,
  (select count(*) from public.kids_location_library) as locations;
