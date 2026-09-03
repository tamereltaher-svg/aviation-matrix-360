create or replace function public.normalize_public_mobile(p_mobile text)
returns text language sql immutable as $$ select regexp_replace(coalesce(p_mobile,''),'\D','','g') $$;

create or replace function public.guard_public_lead_duplicates()
returns trigger language plpgsql set search_path=public as $$
begin
  if exists(select 1 from public.aviation_interest_leads l where lower(trim(l.email))=lower(trim(new.email))) then
    raise exception 'EMAIL_ALREADY_REGISTERED';
  end if;
  if exists(select 1 from public.aviation_interest_leads l where public.normalize_public_mobile(l.mobile)=public.normalize_public_mobile(new.mobile)) then
    raise exception 'MOBILE_ALREADY_REGISTERED';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_public_lead_duplicates on public.aviation_interest_leads;
create trigger trg_guard_public_lead_duplicates before insert on public.aviation_interest_leads for each row execute function public.guard_public_lead_duplicates();

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
begin
  if coalesce(p_consent,false) is not true then raise exception 'CONSENT_REQUIRED'; end if;
  if exists(select 1 from public.aviation_interest_leads where lower(trim(email))=lower(trim(p_email))) then
    return jsonb_build_object('created',false,'existing_profile',true,'reason','email');
  end if;
  if exists(select 1 from public.aviation_interest_leads where public.normalize_public_mobile(mobile)=public.normalize_public_mobile(p_mobile)) then
    return jsonb_build_object('created',false,'existing_profile',true,'reason','mobile');
  end if;
  insert into public.aviation_interest_leads(full_name,mobile,email,date_of_birth,education_stage,current_city,aviation_interest,preferred_language,consent,source,status)
  values(trim(p_full_name),trim(p_mobile),lower(trim(p_email)),p_date_of_birth,p_education_stage,trim(p_current_city),p_aviation_interest,p_preferred_language,true,'landing_pilot','new')
  returning id into v_id;
  return jsonb_build_object('created',true,'existing_profile',false,'lead_id',v_id);
end;
$$;

grant execute on function public.register_public_aviation_lead(text,text,text,date,text,text,text,text,boolean) to anon, authenticated;
