revoke execute on function public.public_start_assessment(text,text,date,text) from public, anon, authenticated;
revoke execute on function public.public_submit_assessment_answer(uuid,uuid,uuid,uuid,integer) from public, anon, authenticated;
revoke execute on function public.public_finish_assessment(uuid,uuid,text) from public, anon, authenticated;

grant execute on function public.public_start_assessment(text,text,date,text) to service_role;
grant execute on function public.public_submit_assessment_answer(uuid,uuid,uuid,uuid,integer) to service_role;
grant execute on function public.public_finish_assessment(uuid,uuid,text) to service_role;