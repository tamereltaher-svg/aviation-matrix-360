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
