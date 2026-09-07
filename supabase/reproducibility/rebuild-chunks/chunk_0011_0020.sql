-- BEGIN CANONICAL MIGRATION 0011 20260822071212 english_cabin_crew_questions_with_timeout
update public.question_bank set prompt = case code
when 'CFV1_CC_001' then 'During boarding, you notice a large bag positioned in a way that could obstruct the aisle. The passenger asks you to leave it there because the flight is short. What would you do?'
when 'CFV1_CC_002' then 'A passenger is angry about a seat change and is speaking loudly in front of other passengers. What is your first action?'
when 'CFV1_CC_003' then 'During pre-departure preparation, you notice a colleague has skipped a check step because they are in a hurry. What do you do?'
when 'CFV1_CC_004' then 'During turbulence, several passengers request different services while the crew instructions require the cabin to be secured. How do you prioritize?'
when 'CFV1_CC_005' then 'During a cabin check, you notice a small difference between what should be present and what is actually there. There is no obvious immediate danger. What do you do?'
when 'CFV1_CC_006' then 'A passenger insists on doing something that conflicts with current safety instructions and says a previous crew allowed it. What would you do?'
when 'CFV1_CC_007' then 'A passenger is very anxious about flying and keeps asking the same question while you are under workload pressure. How do you handle it?'
when 'CFV1_CC_008' then 'You receive a new procedure update that you have not used before, and departure time is close. What is your approach?'
when 'CFV1_CC_009' then 'A passenger makes a provocative personal comment toward you during service. How do you respond?'
when 'CFV1_CC_010' then 'You receive a short operational instruction in English with one word you do not understand, while the rest is clear. What do you do?'
else prompt end
where code like 'CFV1_CC_%';

update public.question_options qo set option_text = case q.code || ':' || qo.option_code
when 'CFV1_CC_001:A' then 'Ask for the bag to be stowed safely according to procedure and explain that the aisle must remain clear.'
when 'CFV1_CC_001:B' then 'Leave it temporarily and return to it before departure if time allows.'
when 'CFV1_CC_001:C' then 'Allow it because the flight is short and passengers can still pass.'
when 'CFV1_CC_001:D' then 'Tell the passenger to deal with it without further explanation.'
when 'CFV1_CC_002:A' then 'Listen calmly, identify the issue briefly, and explain what can realistically be done.'
when 'CFV1_CC_002:B' then 'State the rule immediately and ask the passenger to lower their voice.'
when 'CFV1_CC_002:C' then 'Ask another crew member to handle the passenger because they are speaking loudly.'
when 'CFV1_CC_002:D' then 'Ignore the passenger for a few minutes until they calm down.'
when 'CFV1_CC_003:A' then 'Address the colleague professionally, make sure the missed step is completed, and escalate if the issue remains unresolved.'
when 'CFV1_CC_003:B' then 'Complete the step for them without saying anything to avoid tension.'
when 'CFV1_CC_003:C' then 'Assume each crew member is responsible for their own tasks and do not intervene.'
when 'CFV1_CC_003:D' then 'Report it immediately without first speaking to the colleague or checking the situation.'
when 'CFV1_CC_004:A' then 'Secure the cabin according to crew instructions first, then return to service requests when conditions allow.'
when 'CFV1_CC_004:B' then 'Complete the two quickest requests first, then secure the cabin.'
when 'CFV1_CC_004:C' then 'Handle the most demanding passenger first to avoid a complaint.'
when 'CFV1_CC_004:D' then 'Stop all communication with passengers until the turbulence ends.'
when 'CFV1_CC_005:A' then 'Verify the difference according to procedure and report it if the condition does not match what is required.'
when 'CFV1_CC_005:B' then 'Make a mental note, continue the check, and return to it later.'
when 'CFV1_CC_005:C' then 'Ignore it because the difference is small and there is no obvious danger.'
when 'CFV1_CC_005:D' then 'Correct it yourself based on what you think is right without verifying.'
when 'CFV1_CC_006:A' then 'Stay calm, explain that the current safety instruction is the reference, follow it, and escalate if needed.'
when 'CFV1_CC_006:B' then 'Allow the request this time to avoid conflict with the passenger.'
when 'CFV1_CC_006:C' then 'Tell the passenger that the previous crew was wrong.'
when 'CFV1_CC_006:D' then 'Immediately ask a more senior colleague to make the decision for you.'
when 'CFV1_CC_007:A' then 'Give a clear and reassuring answer, confirm understanding, and briefly follow up when priorities allow.'
when 'CFV1_CC_007:B' then 'Repeat the same answer each time no matter how often the question is asked.'
when 'CFV1_CC_007:C' then 'Tell the passenger you are busy and ask them to speak to you later.'
when 'CFV1_CC_007:D' then 'Ask the passenger next to them to reassure them.'
when 'CFV1_CC_008:A' then 'Review the update from the approved source, identify what changed, and clarify anything unclear before applying it.'
when 'CFV1_CC_008:B' then 'Rely on a quick explanation from a colleague and apply it immediately.'
when 'CFV1_CC_008:C' then 'Use the old procedure because you already know it well.'
when 'CFV1_CC_008:D' then 'Memorize the new steps quickly without understanding why they changed.'
when 'CFV1_CC_009:A' then 'Remain calm, maintain professional boundaries, and redirect the interaction to the situation or service needed.'
when 'CFV1_CC_009:B' then 'Respond in the same tone, but without insulting the passenger.'
when 'CFV1_CC_009:C' then 'Walk away immediately without saying anything.'
when 'CFV1_CC_009:D' then 'Tell nearby passengers that the comment was unacceptable.'
when 'CFV1_CC_010:A' then 'Confirm the meaning of the word using an approved source or authorized person before acting on the part that depends on it.'
when 'CFV1_CC_010:B' then 'Infer the meaning from context and proceed because the rest is clear.'
when 'CFV1_CC_010:C' then 'Ignore the word and focus only on the part you understood.'
when 'CFV1_CC_010:D' then 'Ask any nearby person to translate the entire instruction.'
else qo.option_text end
from public.question_bank q where q.id=qo.question_id and q.code like 'CFV1_CC_%';

insert into public.question_options(question_id,option_code,option_text,sequence_no,scoring_rationale,candidate_feedback)
select q.id,'TIMEOUT','Time expired',99,'No response was submitted within the 15-second limit.','Time expired before an answer was submitted.'
from public.question_bank q
where q.code like 'CFV1_CC_%'
and not exists(select 1 from public.question_options qo where qo.question_id=q.id and qo.option_code='TIMEOUT');

insert into public.question_dimension_scores(option_id,dimension_id,score,evidence_note)
select topt.id,qds.dimension_id,0,'No response within the 15-second limit; recorded as timeout.'
from public.question_bank q
join public.question_options src on src.question_id=q.id and src.option_code='A'
join public.question_dimension_scores qds on qds.option_id=src.id
join public.question_options topt on topt.question_id=q.id and topt.option_code='TIMEOUT'
where q.code like 'CFV1_CC_%'
and not exists(select 1 from public.question_dimension_scores ex where ex.option_id=topt.id and ex.dimension_id=qds.dimension_id);
-- END CANONICAL MIGRATION 0011

-- BEGIN CANONICAL MIGRATION 0012 20260822071345 secure_public_assessment_runtime
alter table public.question_bank add column if not exists time_limit_seconds integer not null default 30 check (time_limit_seconds between 5 and 300);
update public.question_bank set time_limit_seconds=15 where code like 'CFV1_CC_%';

alter table public.assessment_attempts add column if not exists access_token uuid not null default gen_random_uuid();
create unique index if not exists assessment_attempts_access_token_uidx on public.assessment_attempts(access_token);

update public.assessment_versions set status='published', effective_from=coalesce(effective_from,now()) where version_label='Career Fit v1';
update public.assessment_frameworks set status='published' where code='career_fit';

drop policy if exists public_read_question_scores on public.question_dimension_scores;
revoke select on public.question_dimension_scores from anon, authenticated;

grant select on public.question_bank to anon, authenticated;
grant select on public.question_options to anon, authenticated;

create or replace function public.public_start_assessment(
  p_email text,
  p_mobile text,
  p_date_of_birth date,
  p_career_code text default 'cabin_crew'
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_lead public.aviation_interest_leads%rowtype;
  v_candidate_id uuid;
  v_version_id uuid;
  v_career_id uuid;
  v_attempt_id uuid;
  v_token uuid;
begin
  select * into v_lead
  from public.aviation_interest_leads l
  where lower(trim(l.email))=lower(trim(p_email))
    and public.normalize_public_mobile(l.mobile)=public.normalize_public_mobile(p_mobile)
    and l.date_of_birth=p_date_of_birth
  order by l.created_at desc
  limit 1;
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;

  select id into v_candidate_id from public.candidate_profiles where lead_id=v_lead.id;
  if v_candidate_id is null then
    insert into public.candidate_profiles(lead_id,full_name,mobile,email,date_of_birth,education_stage,current_city,aviation_interest,preferred_language,profile_status)
    values(v_lead.id,v_lead.full_name,v_lead.mobile,v_lead.email,v_lead.date_of_birth,v_lead.education_stage,v_lead.current_city,v_lead.aviation_interest,v_lead.preferred_language,'assessment_in_progress')
    returning id into v_candidate_id;
  else
    update public.candidate_profiles set profile_status='assessment_in_progress',updated_at=now() where id=v_candidate_id;
  end if;

  select av.id into v_version_id
  from public.assessment_versions av join public.assessment_frameworks af on af.id=av.framework_id
  where af.code='career_fit' and av.status='published'
  order by av.version_no desc limit 1;
  if v_version_id is null then raise exception 'NO_PUBLISHED_ASSESSMENT'; end if;

  select id into v_career_id from public.career_tracks where code=p_career_code and is_active=true;
  if v_career_id is null then raise exception 'CAREER_NOT_FOUND'; end if;

  insert into public.assessment_attempts(candidate_id,assessment_version_id,target_career_track_id,status)
  values(v_candidate_id,v_version_id,v_career_id,'in_progress')
  returning id,access_token into v_attempt_id,v_token;

  return jsonb_build_object('attempt_id',v_attempt_id,'access_token',v_token,'candidate_id',v_candidate_id,'assessment_version_id',v_version_id);
end;$$;

create or replace function public.public_submit_assessment_answer(
  p_attempt_id uuid,
  p_access_token uuid,
  p_question_id uuid,
  p_option_id uuid,
  p_response_time_seconds integer
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_limit integer;
  v_code text;
begin
  if not exists(select 1 from public.assessment_attempts where id=p_attempt_id and access_token=p_access_token and status='in_progress') then
    raise exception 'INVALID_ASSESSMENT_SESSION';
  end if;
  select q.time_limit_seconds,q.code into v_limit,v_code
  from public.question_bank q
  where q.id=p_question_id and q.status='published';
  if v_limit is null then raise exception 'QUESTION_NOT_AVAILABLE'; end if;
  if not exists(select 1 from public.question_options o where o.id=p_option_id and o.question_id=p_question_id) then
    raise exception 'INVALID_OPTION';
  end if;

  delete from public.assessment_answers where attempt_id=p_attempt_id and question_id=p_question_id;
  insert into public.assessment_answers(attempt_id,question_id,option_id,response_time_seconds)
  values(p_attempt_id,p_question_id,p_option_id,least(greatest(coalesce(p_response_time_seconds,0),0),v_limit));
  return jsonb_build_object('saved',true,'question_code',v_code);
end;$$;

create or replace function public.public_finish_assessment(
  p_attempt_id uuid,
  p_access_token uuid,
  p_career_code text default 'cabin_crew'
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_result jsonb;
begin
  if not exists(select 1 from public.assessment_attempts where id=p_attempt_id and access_token=p_access_token and status='in_progress') then
    raise exception 'INVALID_ASSESSMENT_SESSION';
  end if;
  v_result := public.calculate_assessment_career_fit(p_attempt_id,p_career_code);
  update public.assessment_attempts set status='completed',completed_at=now() where id=p_attempt_id;
  update public.candidate_profiles cp set profile_status='assessment_completed',updated_at=now()
  where cp.id=(select candidate_id from public.assessment_attempts where id=p_attempt_id);
  return v_result;
end;$$;

grant execute on function public.public_start_assessment(text,text,date,text) to anon, authenticated;
grant execute on function public.public_submit_assessment_answer(uuid,uuid,uuid,uuid,integer) to anon, authenticated;
grant execute on function public.public_finish_assessment(uuid,uuid,text) to anon, authenticated;
-- END CANONICAL MIGRATION 0012

-- BEGIN CANONICAL MIGRATION 0013 20260822072511 add_application_number_and_resume_flow
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
-- END CANONICAL MIGRATION 0013

-- BEGIN CANONICAL MIGRATION 0014 20260822072555 public_registration_rpc_and_languages_v2
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
-- END CANONICAL MIGRATION 0014

-- BEGIN CANONICAL MIGRATION 0015 20260822072629 resume_in_progress_assessment
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
-- END CANONICAL MIGRATION 0015

-- BEGIN CANONICAL MIGRATION 0016 20260822075738 add_authenticated_application_resume
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
-- END CANONICAL MIGRATION 0016

-- BEGIN CANONICAL MIGRATION 0017 20260822075756 add_application_otp_rate_limit
create table if not exists public.application_otp_requests(
  application_number text primary key,
  last_sent_at timestamptz not null default now(),
  send_count integer not null default 1
);
alter table public.application_otp_requests enable row level security;
revoke all on public.application_otp_requests from anon, authenticated;
-- END CANONICAL MIGRATION 0017

-- BEGIN CANONICAL MIGRATION 0018 20260822113812 store_backend_foundation_v1
create extension if not exists pgcrypto;

create table if not exists public.store_products (
  id uuid primary key default gen_random_uuid(),
  sku text unique,
  slug text unique not null,
  name text not null,
  short_description text,
  description text,
  category text not null,
  currency text not null default 'EGP',
  base_price numeric(12,2) not null default 0 check (base_price >= 0),
  price_is_estimate boolean not null default true,
  is_active boolean not null default true,
  is_featured boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.store_products(id) on delete cascade,
  storage_path text not null,
  alt_text text,
  is_primary boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique(product_id, storage_path)
);

create unique index if not exists uq_store_product_primary_image
  on public.store_product_images(product_id)
  where is_primary = true;

create table if not exists public.store_product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.store_products(id) on delete cascade,
  variant_type text not null,
  variant_value text not null,
  price_delta numeric(12,2) not null default 0,
  sku_suffix text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique(product_id, variant_type, variant_value)
);

create table if not exists public.store_personalization_options (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.store_products(id) on delete cascade,
  code text not null,
  label text not null,
  input_type text not null check (input_type in ('text','image','select','boolean','textarea')),
  is_required boolean not null default false,
  price_delta numeric(12,2) not null default 0,
  config jsonb not null default '{}'::jsonb,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(product_id, code)
);

create table if not exists public.store_product_audiences (
  product_id uuid not null references public.store_products(id) on delete cascade,
  audience_code text not null check (audience_code in ('nursery','school','university','individual','institution','government')),
  primary key(product_id, audience_code)
);

create or replace function public.set_store_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_store_products_updated_at on public.store_products;
create trigger trg_store_products_updated_at
before update on public.store_products
for each row execute function public.set_store_updated_at();

alter table public.store_products enable row level security;
alter table public.store_product_images enable row level security;
alter table public.store_product_variants enable row level security;
alter table public.store_personalization_options enable row level security;
alter table public.store_product_audiences enable row level security;

create policy store_products_public_read on public.store_products
for select to anon, authenticated
using (is_active = true);

create policy store_images_public_read on public.store_product_images
for select to anon, authenticated
using (exists (select 1 from public.store_products p where p.id = product_id and p.is_active = true));

create policy store_variants_public_read on public.store_product_variants
for select to anon, authenticated
using (is_active = true and exists (select 1 from public.store_products p where p.id = product_id and p.is_active = true));

create policy store_personalization_public_read on public.store_personalization_options
for select to anon, authenticated
using (is_active = true and exists (select 1 from public.store_products p where p.id = product_id and p.is_active = true));

create policy store_audiences_public_read on public.store_product_audiences
for select to anon, authenticated
using (exists (select 1 from public.store_products p where p.id = product_id and p.is_active = true));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy product_images_public_storage_read on storage.objects
for select to public
using (bucket_id = 'product-images');
-- END CANONICAL MIGRATION 0018

-- BEGIN CANONICAL MIGRATION 0019 20260822113828 store_seed_products_v1
insert into public.store_products (sku,slug,name,short_description,description,category,currency,base_price,price_is_estimate,is_active,sort_order)
values
('AM-NB-001','aviation-matrix-notebook','Aviation Matrix Notebook','Premium aviation-themed notebook for students and institutional programs.','Hard cover notebook suitable for student kits, school programs, events, and personalization.','STATIONERY','EGP',220,true,true,10),
('AM-MG-001','aviation-matrix-mug','Aviation Matrix Mug','Branded aviation mug for gifts, staff packs, and events.','Ceramic mug with branding and personalization options.','MERCH','EGP',180,true,true,20),
('AM-ID-001','student-id-lanyard','Student ID + Lanyard','Student identity card and lanyard for programs and clubs.','Printed student ID card with lanyard for aviation programs, clubs, and institutional events.','IDENTITY','EGP',150,true,true,30),
('AM-KIT-001','student-aviation-kit','Student Aviation Kit','Bundled student kit for Aviation Matrix learning experiences.','Student kit combining selected learning and branded materials.','KIT','EGP',650,true,true,40),
('AM-TS-001','aviation-tshirt','Aviation T-Shirt','Aviation-themed T-shirt for students, teams, and school clubs.','Comfort apparel with branding and personalization options.','APPAREL','EGP',450,true,true,50),
('AM-CAP-001','aviation-cap','Aviation Cap','Aviation Matrix cap for activities and student kits.','Adjustable cap suitable for school programs, clubs, field days, and events.','APPAREL','EGP',280,true,true,60),
('AM-UNI-001','full-aviation-uniform','Full Aviation Uniform','Full aviation-inspired uniform for programs and institutional packages.','Uniform package with apparel components and personalization options.','UNIFORM','EGP',1850,true,true,70),
('AM-BAG-001','aviation-backpack','Aviation Backpack','Aviation-themed backpack for student bundles and programs.','Multi-pocket backpack suitable for student use and institutional branding.','BAG','EGP',760,true,true,80),
('AM-BDG-001','personalized-name-badge','Personalized Name Badge','Individual name badge for students, uniforms, clubs, and events.','Printed or engraved student name badge with Aviation Matrix identity.','IDENTITY','EGP',120,true,true,90)
on conflict (slug) do update set
 name=excluded.name, short_description=excluded.short_description, description=excluded.description,
 category=excluded.category, base_price=excluded.base_price, price_is_estimate=excluded.price_is_estimate,
 is_active=excluded.is_active, sort_order=excluded.sort_order, updated_at=now();

insert into public.store_product_audiences(product_id,audience_code)
select p.id,a.audience_code
from public.store_products p
cross join (values ('nursery'),('school'),('university'),('institution'),('government')) a(audience_code)
where p.slug in ('aviation-matrix-notebook','aviation-matrix-mug','student-id-lanyard','student-aviation-kit','aviation-tshirt','aviation-cap','full-aviation-uniform','aviation-backpack','personalized-name-badge')
on conflict do nothing;

insert into public.store_product_variants(product_id,variant_type,variant_value,sort_order)
select p.id,'size',v.val,v.ord
from public.store_products p
join lateral (values
 ('6Y',10),('8Y',20),('10Y',30),('12Y',40),('14Y',50),('XS',60),('S',70),('M',80),('L',90),('XL',100)
) v(val,ord) on true
where p.slug in ('aviation-tshirt','full-aviation-uniform')
on conflict do nothing;

insert into public.store_product_variants(product_id,variant_type,variant_value,sort_order)
select p.id,'size',v.val,v.ord
from public.store_products p
join lateral (values ('Kids',10),('Adult',20)) v(val,ord) on true
where p.slug='aviation-cap'
on conflict do nothing;

insert into public.store_personalization_options(product_id,code,label,input_type,is_required,price_delta,sort_order)
select p.id,x.code,x.label,x.input_type,x.required,x.price_delta,x.sort_order
from public.store_products p
join lateral (values
 ('student_name','Student Name','text',false,0::numeric,10),
 ('institution_name','Institution Name','text',false,0::numeric,20),
 ('logo','Institution Logo','image',false,0::numeric,30)
) x(code,label,input_type,required,price_delta,sort_order) on true
where p.slug in ('aviation-matrix-notebook','aviation-matrix-mug','student-id-lanyard','student-aviation-kit','aviation-tshirt','aviation-cap','aviation-backpack','personalized-name-badge','full-aviation-uniform')
on conflict do nothing;

insert into public.store_personalization_options(product_id,code,label,input_type,is_required,price_delta,sort_order,config)
select p.id,'uniform_notes','Uniform Notes','textarea',false,0,40,'{"placeholder":"Badge text, trousers/skirt, jacket notes, sizing notes"}'::jsonb
from public.store_products p where p.slug='full-aviation-uniform'
on conflict do nothing;
-- END CANONICAL MIGRATION 0019

-- BEGIN CANONICAL MIGRATION 0020 20260822113953 store_admin_management_security
create table if not exists public.store_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'store_admin' check (role in ('store_admin','store_manager')),
  created_at timestamptz not null default now()
);

alter table public.store_admins enable row level security;

create or replace function public.is_store_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.store_admins a where a.user_id = auth.uid()
  );
$$;

revoke all on function public.is_store_admin() from public;
grant execute on function public.is_store_admin() to authenticated;

-- Sanitized: production store-admin identity seed omitted.

drop policy if exists store_admin_self_read on public.store_admins;
create policy store_admin_self_read on public.store_admins
for select to authenticated
using (user_id = auth.uid());

-- Admin write policies for product tables
create policy store_products_admin_insert on public.store_products for insert to authenticated with check (public.is_store_admin());
create policy store_products_admin_update on public.store_products for update to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy store_products_admin_delete on public.store_products for delete to authenticated using (public.is_store_admin());

create policy store_images_admin_insert on public.store_product_images for insert to authenticated with check (public.is_store_admin());
create policy store_images_admin_update on public.store_product_images for update to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy store_images_admin_delete on public.store_product_images for delete to authenticated using (public.is_store_admin());

create policy store_variants_admin_insert on public.store_product_variants for insert to authenticated with check (public.is_store_admin());
create policy store_variants_admin_update on public.store_product_variants for update to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy store_variants_admin_delete on public.store_product_variants for delete to authenticated using (public.is_store_admin());

create policy store_personalization_admin_insert on public.store_personalization_options for insert to authenticated with check (public.is_store_admin());
create policy store_personalization_admin_update on public.store_personalization_options for update to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy store_personalization_admin_delete on public.store_personalization_options for delete to authenticated using (public.is_store_admin());

create policy store_audiences_admin_insert on public.store_product_audiences for insert to authenticated with check (public.is_store_admin());
create policy store_audiences_admin_update on public.store_product_audiences for update to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy store_audiences_admin_delete on public.store_product_audiences for delete to authenticated using (public.is_store_admin());

-- Authenticated store admins can upload/update/delete product images in the product-images bucket
create policy product_images_admin_insert on storage.objects for insert to authenticated with check (bucket_id='product-images' and public.is_store_admin());
create policy product_images_admin_update on storage.objects for update to authenticated using (bucket_id='product-images' and public.is_store_admin()) with check (bucket_id='product-images' and public.is_store_admin());
create policy product_images_admin_delete on storage.objects for delete to authenticated using (bucket_id='product-images' and public.is_store_admin());
-- END CANONICAL MIGRATION 0020

