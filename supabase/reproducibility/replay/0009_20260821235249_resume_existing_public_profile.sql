create or replace function public.register_public_aviation_lead(
  p_full_name text,
  p_mobile text,
  p_email text,
  p_date_of_birth date,
  p_education_stage text,
  p_current_city text,
  p_aviation_interest text,
  p_preferred_language text,
  p_consent boolean
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id uuid;
  v_exact_id uuid;
begin
  if coalesce(p_consent,false) is not true then raise exception 'CONSENT_REQUIRED'; end if;

  select id into v_exact_id
  from public.aviation_interest_leads
  where lower(trim(email))=lower(trim(p_email))
    and public.normalize_public_mobile(mobile)=public.normalize_public_mobile(p_mobile)
    and date_of_birth=p_date_of_birth
  order by created_at asc
  limit 1;

  if v_exact_id is not null then
    return jsonb_build_object('created',false,'existing_profile',true,'resume_allowed',true,'lead_id',v_exact_id,'reason','exact_match');
  end if;

  if exists(select 1 from public.aviation_interest_leads where lower(trim(email))=lower(trim(p_email))) then
    return jsonb_build_object('created',false,'existing_profile',true,'resume_allowed',false,'reason','email');
  end if;
  if exists(select 1 from public.aviation_interest_leads where public.normalize_public_mobile(mobile)=public.normalize_public_mobile(p_mobile)) then
    return jsonb_build_object('created',false,'existing_profile',true,'resume_allowed',false,'reason','mobile');
  end if;

  insert into public.aviation_interest_leads(full_name,mobile,email,date_of_birth,education_stage,current_city,aviation_interest,preferred_language,consent,source,status)
  values(trim(p_full_name),trim(p_mobile),lower(trim(p_email)),p_date_of_birth,p_education_stage,trim(p_current_city),p_aviation_interest,p_preferred_language,true,'landing_pilot','new')
  returning id into v_id;

  return jsonb_build_object('created',true,'existing_profile',false,'resume_allowed',true,'lead_id',v_id);
end;
$$;
