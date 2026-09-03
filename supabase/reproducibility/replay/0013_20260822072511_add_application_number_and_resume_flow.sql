create sequence if not exists public.application_number_seq start 1;

alter table public.aviation_interest_leads add column if not exists application_number text;

create or replace function public.make_application_number()
returns text
language plpgsql
security definer
set search_path=public
as $$
declare
  v_seq bigint;
begin
  v_seq := nextval('public.application_number_seq');
  return 'AM-A-' || to_char(current_date,'YYYY') || '-' || lpad(v_seq::text,6,'0');
end;
$$;

update public.aviation_interest_leads
set application_number = public.make_application_number()
where application_number is null;

alter table public.aviation_interest_leads alter column application_number set default public.make_application_number();
alter table public.aviation_interest_leads alter column application_number set not null;
create unique index if not exists uq_aviation_interest_leads_application_number on public.aviation_interest_leads(application_number);

create or replace function public.public_resume_application(
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
  v_fit public.career_fit_results%rowtype;
begin
  select * into v_lead
  from public.aviation_interest_leads
  where application_number = upper(trim(p_application_number))
    and lower(trim(email)) = lower(trim(p_email))
    and date_of_birth = p_date_of_birth
  limit 1;

  if not found then
    raise exception 'APPLICATION_NOT_FOUND';
  end if;

  select * into v_profile
  from public.candidate_profiles
  where lead_id = v_lead.id
  limit 1;

  if v_profile.id is not null then
    select * into v_attempt
    from public.assessment_attempts
    where candidate_id = v_profile.id
    order by started_at desc
    limit 1;
  end if;

  if v_attempt.id is not null then
    select * into v_fit
    from public.career_fit_results
    where attempt_id = v_attempt.id
    order by created_at desc
    limit 1;
  end if;

  return jsonb_build_object(
    'application_number', v_lead.application_number,
    'full_name', v_lead.full_name,
    'mobile', v_lead.mobile,
    'email', v_lead.email,
    'date_of_birth', v_lead.date_of_birth,
    'education_stage', v_lead.education_stage,
    'current_city', v_lead.current_city,
    'aviation_interest', v_lead.aviation_interest,
    'preferred_language', v_lead.preferred_language,
    'lead_status', v_lead.status,
    'candidate_id', v_profile.id,
    'profile_status', v_profile.profile_status,
    'assessment_attempt_id', v_attempt.id,
    'assessment_status', v_attempt.status,
    'assessment_result', case when v_fit.id is null then null else jsonb_build_object(
      'current_fit',v_fit.current_fit,
      'future_fit',v_fit.future_fit,
      'readiness_status',v_fit.readiness_status,
      'summary',v_fit.explanation_summary,
      'evidence_payload',v_fit.evidence_payload
    ) end
  );
end;
$$;

grant execute on function public.public_resume_application(text,text,date) to anon, authenticated;

grant select(application_number) on public.aviation_interest_leads to anon, authenticated;
