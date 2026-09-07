-- BEGIN CANONICAL MIGRATION 0113 20260903133953 cleanup_public_edge_runtime_fixtures
alter table public.am_registration_events disable trigger trg_registration_events_append_only;

do $$
declare aid uuid;
begin
  select id into aid from public.am_registration_applications where email='security-registration-20260903@example.invalid' order by created_at desc limit 1;
  if aid is not null then
    delete from public.am_registration_sessions where application_id=aid;
    delete from public.am_registration_activation_codes where application_id=aid;
    delete from public.am_registration_payment_refs where application_id=aid;
    delete from public.am_application_consents where application_id=aid;
    delete from public.am_application_documents where application_id=aid;
    delete from public.am_registration_events where application_id=aid;
    delete from public.am_registration_applications where id=aid;
  end if;
end $$;

alter table public.am_registration_events enable trigger trg_registration_events_append_only;

drop extension if exists http;
-- END CANONICAL MIGRATION 0113

-- BEGIN CANONICAL MIGRATION 0114 20260903134423 temp_enable_http_for_kids_entitlement_runtime
create extension if not exists http with schema extensions;
-- END CANONICAL MIGRATION 0114

-- BEGIN CANONICAL MIGRATION 0115 20260903134635 temp_disable_http_after_kids_entitlement_runtime
drop extension if exists http;
-- END CANONICAL MIGRATION 0115

-- BEGIN CANONICAL MIGRATION 0116 20260903141131 p1_harden_public_application_login_resume_boundary
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
-- END CANONICAL MIGRATION 0116

-- BEGIN CANONICAL MIGRATION 0117 20260903141158 p1_application_resume_token_atomic_rotation
create or replace function public.am_consume_application_resume_token(
  p_token_hash text,
  p_application_number text,
  p_new_token_hash text,
  p_new_expires_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_catalog'
as $function$
declare
  v_old_id uuid;
  v_lead_id uuid;
  v_new_id uuid;
begin
  if p_token_hash is null or length(p_token_hash) < 32 or p_new_token_hash is null or length(p_new_token_hash) < 32 then
    raise exception 'INVALID_RESUME_TOKEN';
  end if;
  if p_new_expires_at <= clock_timestamp() or p_new_expires_at > clock_timestamp() + interval '31 days' then
    raise exception 'INVALID_RESUME_TOKEN_EXPIRY';
  end if;

  update public.am_application_resume_tokens t
     set consumed_at=clock_timestamp()
    from public.aviation_interest_leads l
   where t.token_hash=p_token_hash
     and t.lead_id=l.id
     and l.application_number=upper(trim(p_application_number))
     and t.consumed_at is null
     and t.expires_at > clock_timestamp()
  returning t.id,t.lead_id into v_old_id,v_lead_id;

  if v_old_id is null then
    return jsonb_build_object('ok',false);
  end if;

  insert into public.am_application_resume_tokens(lead_id,token_hash,expires_at,rotated_from_id)
  values(v_lead_id,p_new_token_hash,p_new_expires_at,v_old_id)
  returning id into v_new_id;

  return jsonb_build_object('ok',true,'lead_id',v_lead_id,'token_id',v_new_id);
end;
$function$;
revoke execute on function public.am_consume_application_resume_token(text,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.am_consume_application_resume_token(text,text,text,timestamptz) to service_role;
-- END CANONICAL MIGRATION 0117

-- BEGIN CANONICAL MIGRATION 0118 20260903141455 p1_harden_direct_public_application_registration
create or replace function public.public_register_application(p_full_name text, p_mobile text, p_email text, p_date_of_birth date, p_education_stage text, p_current_city text, p_aviation_interest text, p_preferred_language text, p_consent boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions','pg_catalog'
as $function$
declare
  v_row public.aviation_interest_leads%rowtype;
  v_headers jsonb := '{}'::jsonb;
  v_ip text := 'unknown';
  v_email text := lower(trim(coalesce(p_email,'')));
  v_mobile text := regexp_replace(trim(coalesce(p_mobile,'')),'\s+','','g');
  v_rate jsonb;
  v_resume_token text;
  v_resume_hash text;
  v_expires timestamptz := clock_timestamp() + interval '30 days';
begin
  if coalesce(p_consent,false) is not true then raise exception 'CONSENT_REQUIRED'; end if;
  if length(trim(coalesce(p_full_name,''))) < 2 or length(trim(coalesce(p_full_name,''))) > 220 then raise exception 'INVALID_APPLICATION_INPUT'; end if;
  if length(v_email) > 220 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'INVALID_APPLICATION_INPUT'; end if;
  if length(v_mobile) < 5 or length(v_mobile) > 80 then raise exception 'INVALID_APPLICATION_INPUT'; end if;
  if p_date_of_birth is null or p_date_of_birth > current_date then raise exception 'INVALID_APPLICATION_INPUT'; end if;

  begin
    v_headers := nullif(current_setting('request.headers',true),'')::jsonb;
  exception when others then v_headers := '{}'::jsonb;
  end;
  v_ip := left(coalesce(nullif(v_headers->>'cf-connecting-ip',''),nullif(split_part(coalesce(v_headers->>'x-forwarded-for',''),',',1),''),'unknown'),120);

  select public.am_check_public_api_rate_limit(encode(extensions.digest('application-register-ip|'||v_ip,'sha256'),'hex'),'application_register_rpc_ip',3600,10) into v_rate;
  if not coalesce((v_rate->>'ok')::boolean,false) then raise exception 'RATE_LIMITED'; end if;
  select public.am_check_public_api_rate_limit(encode(extensions.digest('application-register-email|'||v_email,'sha256'),'hex'),'application_register_rpc_contact',3600,3) into v_rate;
  if not coalesce((v_rate->>'ok')::boolean,false) then raise exception 'RATE_LIMITED'; end if;
  select public.am_check_public_api_rate_limit(encode(extensions.digest('application-register-mobile|'||v_mobile,'sha256'),'hex'),'application_register_rpc_mobile',3600,3) into v_rate;
  if not coalesce((v_rate->>'ok')::boolean,false) then raise exception 'RATE_LIMITED'; end if;

  insert into public.aviation_interest_leads(full_name,mobile,email,date_of_birth,education_stage,current_city,aviation_interest,preferred_language,consent,source,status)
  values(trim(p_full_name),v_mobile,v_email,p_date_of_birth,left(trim(p_education_stage),80),left(trim(p_current_city),120),left(trim(p_aviation_interest),100),left(trim(p_preferred_language),20),true,'landing_pilot','new')
  returning * into v_row;

  v_resume_token := encode(extensions.gen_random_bytes(32),'hex');
  v_resume_hash := encode(extensions.digest(v_resume_token,'sha256'),'hex');
  insert into public.am_application_resume_tokens(lead_id,token_hash,expires_at)
  values(v_row.id,v_resume_hash,v_expires);

  return jsonb_build_object(
    'application_number',v_row.application_number,
    'full_name',v_row.full_name,
    'email',v_row.email,
    'mobile',v_row.mobile,
    'date_of_birth',v_row.date_of_birth,
    'education_stage',v_row.education_stage,
    'current_city',v_row.current_city,
    'aviation_interest',v_row.aviation_interest,
    'preferred_language',v_row.preferred_language,
    'lead_status',v_row.status,
    'resume_token',v_resume_token,
    'resume_token_expires_at',v_expires
  );
end;
$function$;
revoke execute on function public.public_register_application(text,text,text,date,text,text,text,text,boolean) from public;
grant execute on function public.public_register_application(text,text,text,date,text,text,text,text,boolean) to anon,authenticated,service_role;

revoke execute on function public.register_public_aviation_lead(text,text,text,date,text,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.register_public_aviation_lead(text,text,text,date,text,text,text,text,boolean) to service_role;
-- END CANONICAL MIGRATION 0118

-- BEGIN CANONICAL MIGRATION 0119 20260903144840 runtime_gate_remove_temporary_http_extension
drop extension if exists http;
-- END CANONICAL MIGRATION 0119

