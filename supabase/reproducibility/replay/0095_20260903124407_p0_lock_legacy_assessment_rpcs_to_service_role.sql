revoke execute on function public.start_public_career_assessment(uuid, text) from public, anon, authenticated;
revoke execute on function public.submit_public_assessment_answer(uuid, uuid, uuid, integer) from public, anon, authenticated;
revoke execute on function public.finish_public_career_assessment(uuid, text) from public, anon, authenticated;

grant execute on function public.start_public_career_assessment(uuid, text) to service_role;
grant execute on function public.submit_public_assessment_answer(uuid, uuid, uuid, integer) to service_role;
grant execute on function public.finish_public_career_assessment(uuid, text) to service_role;
