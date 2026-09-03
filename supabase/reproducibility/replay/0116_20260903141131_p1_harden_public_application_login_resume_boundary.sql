create table if not exists public.am_application_auth_bindings (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  lead_id uuid not null references public.aviation_interest_leads(id) on delete cascade,
  application_number text not null,
  verified_at timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  unique (auth_user_id, lead_id),
  unique (lead_id)
);
create index if not exists am_application_auth_bindings_application_idx on public.am_application_auth_bindings(application_number) where revoked_at is null;
alter table public.am_application_auth_bindings enable row level security;
revoke all on public.am_application_auth_bindings from public, anon, authenticated;
grant all on public.am_application_auth_bindings to service_role;

create table if not exists public.am_application_resume_tokens (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.aviation_interest_leads(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  rotated_from_id uuid references public.am_application_resume_tokens(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists am_application_resume_tokens_lead_active_idx on public.am_application_resume_tokens(lead_id, expires_at) where consumed_at is null;
alter table public.am_application_resume_tokens enable row level security;
revoke all on public.am_application_resume_tokens from public, anon, authenticated;
grant all on public.am_application_resume_tokens to service_role;

revoke execute on function public.public_register_application(text,text,text,date,text,text,text,text,boolean) from public, anon, authenticated;
grant execute on function public.public_register_application(text,text,text,date,text,text,text,text,boolean) to service_role;
revoke execute on function public.register_public_aviation_lead(text,text,text,date,text,text,text,text,boolean) from public, anon, authenticated;
grant execute on function public.register_public_aviation_lead(text,text,text,date,text,text,text,text,boolean) to service_role;
revoke execute on function public.public_resume_application(text,text,date) from public, anon, authenticated;
grant execute on function public.public_resume_application(text,text,date) to service_role;
revoke execute on function public.public_resume_assessment(text,text,date) from public, anon, authenticated;
grant execute on function public.public_resume_assessment(text,text,date) to service_role;

create or replace function public.public_resume_application_auth(p_application_number text)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_catalog'
as $function$
declare
  v_uid uuid := auth.uid();
  v_lead public.aviation_interest_leads%rowtype;
  v_profile public.candidate_profiles%rowtype;
  v_attempt public.assessment_attempts%rowtype;
  v_fit public.career_fit_results%rowtype;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists (select 1 from auth.users u where u.id=v_uid and u.email_confirmed_at is not null and u.deleted_at is null) then
    raise exception 'VERIFIED_AUTH_REQUIRED';
  end if;

  select l.* into v_lead
  from public.aviation_interest_leads l
  join public.am_application_auth_bindings b on b.lead_id=l.id
  where l.application_number=upper(trim(p_application_number))
    and b.auth_user_id=v_uid
    and b.application_number=l.application_number
    and b.revoked_at is null
  limit 1;
  if not found then raise exception 'APPLICATION_ACCESS_DENIED'; end if;

  update public.am_application_auth_bindings set last_used_at=clock_timestamp()
  where auth_user_id=v_uid and lead_id=v_lead.id and revoked_at is null;

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
$function$;

create or replace function public.public_resume_assessment_auth(p_application_number text)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_catalog'
as $function$
declare
  v_uid uuid := auth.uid();
  v_lead public.aviation_interest_leads%rowtype;
  v_profile public.candidate_profiles%rowtype;
  v_attempt public.assessment_attempts%rowtype;
  v_answered int:=0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists (select 1 from auth.users u where u.id=v_uid and u.email_confirmed_at is not null and u.deleted_at is null) then
    raise exception 'VERIFIED_AUTH_REQUIRED';
  end if;

  select l.* into v_lead
  from public.aviation_interest_leads l
  join public.am_application_auth_bindings b on b.lead_id=l.id
  where l.application_number=upper(trim(p_application_number))
    and b.auth_user_id=v_uid
    and b.application_number=l.application_number
    and b.revoked_at is null
  limit 1;
  if not found then raise exception 'APPLICATION_ACCESS_DENIED'; end if;

  update public.am_application_auth_bindings set last_used_at=clock_timestamp()
  where auth_user_id=v_uid and lead_id=v_lead.id and revoked_at is null;

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
$function$;

revoke execute on function public.public_resume_application_auth(text) from public, anon;
grant execute on function public.public_resume_application_auth(text) to authenticated, service_role;
revoke execute on function public.public_resume_assessment_auth(text) from public, anon;
grant execute on function public.public_resume_assessment_auth(text) to authenticated, service_role;

alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from public, anon, authenticated;
