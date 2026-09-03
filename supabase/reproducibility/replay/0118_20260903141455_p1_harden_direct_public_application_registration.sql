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
