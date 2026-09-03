alter table public.assessment_attempts add column if not exists lead_id uuid references public.aviation_interest_leads(id);

create index if not exists assessment_attempts_lead_id_idx on public.assessment_attempts(lead_id);

update public.question_bank set status='published' where code like 'CFV1_CC_%';

create or replace function public.start_public_career_assessment(p_lead_id uuid, p_career_code text default 'cabin_crew')
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_version_id uuid;
  v_career_id uuid;
  v_attempt_id uuid;
begin
  if not exists(select 1 from public.aviation_interest_leads where id=p_lead_id) then
    raise exception 'Lead not found';
  end if;
  select av.id into v_version_id
  from public.assessment_versions av
  join public.assessment_frameworks af on af.id=av.framework_id
  where af.code='career_fit' and av.version_no=1
  order by av.created_at desc limit 1;
  if v_version_id is null then raise exception 'Assessment version not found'; end if;
  select id into v_career_id from public.career_tracks where code=p_career_code and is_active=true;
  if v_career_id is null then raise exception 'Career track not found'; end if;
  select id into v_attempt_id from public.assessment_attempts
   where lead_id=p_lead_id and assessment_version_id=v_version_id and target_career_track_id=v_career_id and status='in_progress'
   order by started_at desc limit 1;
  if v_attempt_id is null then
    insert into public.assessment_attempts(lead_id,assessment_version_id,target_career_track_id,status)
    values(p_lead_id,v_version_id,v_career_id,'in_progress') returning id into v_attempt_id;
  end if;
  return jsonb_build_object('attempt_id',v_attempt_id,'assessment_version_id',v_version_id,'career_code',p_career_code);
end;
$$;

create or replace function public.submit_public_assessment_answer(p_attempt_id uuid, p_question_id uuid, p_option_id uuid, p_response_time_seconds integer default null)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
begin
  if not exists(select 1 from public.assessment_attempts where id=p_attempt_id and status='in_progress') then
    raise exception 'Assessment attempt is not active';
  end if;
  if not exists(select 1 from public.question_options qo join public.question_bank q on q.id=qo.question_id where qo.id=p_option_id and qo.question_id=p_question_id and q.status='published') then
    raise exception 'Question option mismatch';
  end if;
  delete from public.assessment_answers where attempt_id=p_attempt_id and question_id=p_question_id;
  insert into public.assessment_answers(attempt_id,question_id,option_id,response_time_seconds)
  values(p_attempt_id,p_question_id,p_option_id,p_response_time_seconds);
  return jsonb_build_object('saved',true);
end;
$$;

create or replace function public.finish_public_career_assessment(p_attempt_id uuid, p_career_code text default 'cabin_crew')
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_count integer;
  v_result jsonb;
begin
  select count(*) into v_count from public.assessment_answers where attempt_id=p_attempt_id;
  if v_count < 10 then raise exception 'Assessment incomplete'; end if;
  v_result := public.calculate_assessment_career_fit(p_attempt_id,p_career_code);
  update public.assessment_attempts set status='completed',completed_at=now() where id=p_attempt_id;
  return v_result;
end;
$$;

grant execute on function public.start_public_career_assessment(uuid,text) to anon, authenticated;
grant execute on function public.submit_public_assessment_answer(uuid,uuid,uuid,integer) to anon, authenticated;
grant execute on function public.finish_public_career_assessment(uuid,text) to anon, authenticated;
