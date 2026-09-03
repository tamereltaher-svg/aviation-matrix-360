create or replace function public.public_resume_assessment(
  p_application_number text,
  p_email text,
  p_date_of_birth date
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_lead public.aviation_interest_leads%rowtype;
  v_profile public.candidate_profiles%rowtype;
  v_attempt public.assessment_attempts%rowtype;
  v_answered int := 0;
begin
  select * into v_lead
  from public.aviation_interest_leads
  where application_number=upper(trim(p_application_number))
    and lower(trim(email))=lower(trim(p_email))
    and date_of_birth=p_date_of_birth
  limit 1;
  if not found then raise exception 'APPLICATION_NOT_FOUND'; end if;

  select * into v_profile from public.candidate_profiles where lead_id=v_lead.id limit 1;
  if v_profile.id is null then
    return jsonb_build_object('status','registered','application_number',v_lead.application_number);
  end if;

  select * into v_attempt
  from public.assessment_attempts
  where candidate_id=v_profile.id
  order by started_at desc
  limit 1;

  if v_attempt.id is null then
    return jsonb_build_object('status','ready_for_assessment','application_number',v_lead.application_number,'candidate_id',v_profile.id);
  end if;

  select count(*) into v_answered from public.assessment_answers where attempt_id=v_attempt.id;

  return jsonb_build_object(
    'status',v_attempt.status,
    'application_number',v_lead.application_number,
    'candidate_id',v_profile.id,
    'attempt_id',v_attempt.id,
    'access_token',case when v_attempt.status='in_progress' then v_attempt.access_token else null end,
    'answered_count',v_answered,
    'result_payload',v_attempt.result_payload
  );
end;
$$;

grant execute on function public.public_resume_assessment(text,text,date) to anon,authenticated;
