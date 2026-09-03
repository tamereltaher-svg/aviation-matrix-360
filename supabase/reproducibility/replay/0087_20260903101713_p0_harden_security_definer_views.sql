-- P0: eliminate SECURITY DEFINER view exposure while preserving trusted service-role access.
alter view public.am_candidate_lifetime_summary set (security_invoker = true);
alter view public.am_candidate_assessment_journey_summary set (security_invoker = true);
alter view public.kids_brand_logo_readiness set (security_invoker = true);

revoke all privileges on table public.am_candidate_lifetime_summary from anon, authenticated;
revoke all privileges on table public.am_candidate_assessment_journey_summary from anon, authenticated;
revoke all privileges on table public.kids_brand_logo_readiness from anon, authenticated;

grant select on table public.am_candidate_lifetime_summary to service_role;
grant select on table public.am_candidate_assessment_journey_summary to service_role;
grant select on table public.kids_brand_logo_readiness to service_role;
