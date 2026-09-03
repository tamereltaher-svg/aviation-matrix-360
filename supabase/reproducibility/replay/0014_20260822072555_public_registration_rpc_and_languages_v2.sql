do $$
declare r record;
begin
  for r in select conname from pg_constraint where conrelid='public.aviation_interest_leads'::regclass and contype='c' and pg_get_constraintdef(oid) ilike '%preferred_language%'
  loop execute format('alter table public.aviation_interest_leads drop constraint %I', r.conname); end loop;
end $$;

update public.aviation_interest_leads set preferred_language='en' where preferred_language not in ('en','fr','ru') or preferred_language is null;

alter table public.aviation_interest_leads add constraint aviation_interest_leads_preferred_language_check check (preferred_language = any (array['en'::text,'fr'::text,'ru'::text]));

create or replace function public.public_register_application(
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
  v_row public.aviation_interest_leads%rowtype;
begin
  if coalesce(p_consent,false) is not true then raise exception 'CONSENT_REQUIRED'; end if;
  insert into public.aviation_interest_leads(full_name,mobile,email,date_of_birth,education_stage,current_city,aviation_interest,preferred_language,consent,source,status)
  values(trim(p_full_name),trim(p_mobile),lower(trim(p_email)),p_date_of_birth,p_education_stage,trim(p_current_city),p_aviation_interest,p_preferred_language,true,'landing_pilot','new')
  returning * into v_row;
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
    'lead_status',v_row.status
  );
end;
$$;

grant execute on function public.public_register_application(text,text,text,date,text,text,text,text,boolean) to anon,authenticated;
