create or replace function public.public_resume_application_auth(p_application_number text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_email text;
  v_lead public.aviation_interest_leads%rowtype;
  v_profile public.candidate_profiles%rowtype;
  v_attempt public.assessment_attempts%rowtype;
  v_fit public.career_fit_results%rowtype;
begin
  v_email := lower(trim(coalesce(auth.jwt()->>'email','')));
  if v_email='' then raise exception 'AUTH_REQUIRED'; end if;

  select * into v_lead
  from public.aviation_interest_leads
  where application_number=upper(trim(p_application_number))
    and lower(trim(email))=v_email
  limit 1;
  if not found then raise exception 'APPLICATION_NOT_FOUND'; end if;

  select * into v_profile from public.candidate_profiles where lead_id=v_lead.id limit 1;
  if v_profile.id is not null then
    select * into v_attempt from public.assessment_attempts where candidate_id=v_profile.id order by started_at desc limit 1;
  end if;
  if v_attempt.id is not null then
    select * into v_fit from public.career_fit_results where attempt_id=v_attempt.id order by created_at desc limit 1;
  end if;

  return jsonb_build_object(
    'application_number',v_lead.application_number,
    'full_name',v_lead.full_name,
    'mobile',v_lead.mobile,
    'email',v_lead.email,
    'date_of_birth',v_lead.date_of_birth,
    'education_stage',v_lead.education_stage,
    'current_city',v_lead.current_city,
    'aviation_interest',v_lead.aviation_interest,
    'preferred_language',v_lead.preferred_language,
    'lead_status',v_lead.status,
    'candidate_id',v_profile.id,
    'profile_status',v_profile.profile_status,
    'assessment_attempt_id',v_attempt.id,
    'assessment_status',v_attempt.status,
    'assessment_result',case when v_fit.id is null then null else jsonb_build_object(
      'current_fit',v_fit.current_fit,
      'future_fit',v_fit.future_fit,
      'readiness_status',v_fit.readiness_status,
      'summary',v_fit.explanation_summary,
      'evidence_payload',v_fit.evidence_payload
    ) end
  );
end;
$$;

create or replace function public.public_resume_assessment_auth(p_application_number text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_email text;
  v_lead public.aviation_interest_leads%rowtype;
  v_profile public.candidate_profiles%rowtype;
  v_attempt public.assessment_attempts%rowtype;
  v_answered int:=0;
begin
  v_email := lower(trim(coalesce(auth.jwt()->>'email','')));
  if v_email='' then raise exception 'AUTH_REQUIRED'; end if;

  select * into v_lead
  from public.aviation_interest_leads
  where application_number=upper(trim(p_application_number))
    and lower(trim(email))=v_email
  limit 1;
  if not found then raise exception 'APPLICATION_NOT_FOUND'; end if;

  select * into v_profile from public.candidate_profiles where lead_id=v_lead.id limit 1;
  if v_profile.id is null then
    return jsonb_build_object('status','registered','application_number',v_lead.application_number);
  end if;

  select * into v_attempt from public.assessment_attempts where candidate_id=v_profile.id order by started_at desc limit 1;
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

grant execute on function public.public_resume_application_auth(text) to authenticated;
grant execute on function public.public_resume_assessment_auth(text) to authenticated;
revoke all on function public.public_resume_application_auth(text) from anon;
revoke all on function public.public_resume_assessment_auth(text) from anon;
