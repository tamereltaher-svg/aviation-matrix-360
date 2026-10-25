
create or replace function public.am_student_submit_lesson(p_enrollment_id uuid,p_lesson_id uuid,p_answers jsonb)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
 v_candidate uuid;
 v_course uuid;
 v_course_state text;
 v_progress uuid;
 v_progress_state text;
 v_used integer;
 v_best numeric(5,2);
 v_max_attempts integer;
 v_passing numeric(5,2);
 v_expected integer;
 v_submitted integer;
 v_unique integer;
 v_valid integer;
 v_correct integer;
 v_score numeric(5,2);
 v_passed boolean;
 v_next_attempt integer;
 v_done integer;
 v_total integer;
 v_course_completed boolean := false;
 v_clean_answers jsonb;
begin
 v_candidate:=public.am_student_verified_candidate();

 if p_answers is null or jsonb_typeof(p_answers)<>'array'
   or pg_catalog.octet_length(p_answers::text)>32768 then
    raise exception 'Invalid assessment response payload.' using errcode='22023';
 end if;

 select e.course_id,e.status into v_course,v_course_state
 from public.am_candidate_learning_enrollments e
 where e.id=p_enrollment_id and e.candidate_id=v_candidate for update;
 if v_course is null or v_course_state<>'in_progress' or
    not public.am_student_course_is_ready(v_course) then
   raise exception 'Assessment is unavailable.' using errcode='42501';
 end if;

 if not exists(select 1 from avi_knowledge.course_lesson_links cl
                where cl.course_id=v_course and cl.lesson_id=p_lesson_id)
    or not public.am_student_lesson_is_unlocked(p_enrollment_id,p_lesson_id)
 then raise exception 'Assessment is unavailable.' using errcode='42501';end if;

 select r.max_attempts,r.passing_percent into v_max_attempts,v_passing
 from public.am_student_learning_rules r where r.course_id=v_course and r.enabled;

 select lp.id,lp.progress_state,lp.attempts_used,lp.best_score
 into v_progress,v_progress_state,v_used,v_best
 from public.am_student_lesson_progress lp
 where lp.enrollment_id=p_enrollment_id and lp.lesson_id=p_lesson_id
 for update;

 if v_progress is null or v_progress_state<>'in_progress' or v_used>=v_max_attempts then
   raise exception 'Lesson is not open for another attempt.' using errcode='42501';
 end if;

 select count(*) into v_expected from avi_knowledge.lesson_questions q where q.lesson_id=p_lesson_id;
 if v_expected=0 or v_expected>100 then
   raise exception 'Invalid published assessment definition.' using errcode='22023';
 end if;

 with submitted as (
    select x.question_id,x.option_id
    from jsonb_to_recordset(p_answers) as x(question_id uuid,option_id uuid)
 ), checked as (
    select s.question_id,s.option_id,q.id as valid_question,o.id as valid_option,
      coalesce(o.is_correct,false) as is_correct
    from submitted s
    left join avi_knowledge.lesson_questions q on q.id=s.question_id and q.lesson_id=p_lesson_id
    left join avi_knowledge.lesson_question_options o on o.id=s.option_id and o.question_id=q.id
 )
 select count(*)::integer,count(distinct question_id)::integer,
    count(valid_option)::integer,
    count(*) filter(where is_correct)::integer
 into v_submitted,v_unique,v_valid,v_correct from checked;

 if v_submitted<>v_expected or v_unique<>v_expected or v_valid<>v_expected then
   raise exception 'Every lesson question must have one valid answer.' using errcode='22023';
 end if;

 select coalesce(jsonb_agg(jsonb_build_object(
  'question_id',x.question_id,'option_id',x.option_id
 ) order by x.question_id),'[]'::jsonb) into v_clean_answers
 from jsonb_to_recordset(p_answers) as x(question_id uuid,option_id uuid);

 v_score:=round((100.0*v_correct/v_expected)::numeric,2);
 v_passed:=v_score>=v_passing;
 v_next_attempt:=v_used+1;

 insert into public.am_student_lesson_attempts(
  progress_id,attempt_no,scored_percent,correct_count,question_count,passed,answers)
 values(v_progress,v_next_attempt,v_score,v_correct,v_expected,v_passed,v_clean_answers);

 update public.am_student_lesson_progress
 set attempts_used=v_next_attempt, last_score=v_score,
     best_score=greatest(coalesce(v_best,0),v_score),
     progress_state=case when v_passed then 'completed'
            when v_next_attempt>=v_max_attempts then 'failed'
            else 'in_progress' end,
     completed_at=case when v_passed then now() else null end,
     updated_at=now()
 where id=v_progress;

 insert into public.am_student_learning_events(
   auth_user_id,enrollment_id,lesson_id,event_type,event_detail)
 values((select auth.uid()),p_enrollment_id,p_lesson_id,'lesson_submitted',
   jsonb_build_object('attempt_no',v_next_attempt,'score',v_score,'passed',v_passed));

 if v_passed then
   insert into public.am_student_learning_events(auth_user_id,enrollment_id,lesson_id,event_type,event_detail)
   values((select auth.uid()),p_enrollment_id,p_lesson_id,'lesson_passed',jsonb_build_object('score',v_score));
 else
   insert into public.am_student_learning_events(auth_user_id,enrollment_id,lesson_id,event_type,event_detail)
   values((select auth.uid()),p_enrollment_id,p_lesson_id,'lesson_failed',
      jsonb_build_object('attempt_no',v_next_attempt,'attempts_exhausted',(v_next_attempt>=v_max_attempts)));
 end if;

 if v_passed then
   select count(*),count(*) filter(where exists(
     select 1 from public.am_student_lesson_progress lp
      where lp.enrollment_id=p_enrollment_id and lp.lesson_id=cl.lesson_id and lp.progress_state='completed'))
   into v_total,v_done
   from avi_knowledge.course_lesson_links cl where cl.course_id=v_course;

   if v_total>0 and v_done=v_total then
      update public.am_candidate_learning_enrollments e
      set status='completed',completed_at=now(),updated_at=now(),
         completion_score=(select round(avg(lp.best_score)::numeric,2)
           from public.am_student_lesson_progress lp where lp.enrollment_id=p_enrollment_id)
      where e.id=p_enrollment_id;
      v_course_completed:=true;
      insert into public.am_student_learning_events(auth_user_id,enrollment_id,event_type,event_detail)
      values((select auth.uid()),p_enrollment_id,'course_completed',jsonb_build_object('course_id',v_course));
   end if;
 elsif v_next_attempt>=v_max_attempts then
   update public.am_candidate_learning_enrollments
   set status='failed',updated_at=now() where id=p_enrollment_id;
 end if;

 return jsonb_build_object(
    'enrollment_id',p_enrollment_id,'lesson_id',p_lesson_id,
    'passed',v_passed,'score',v_score,'attempt_no',v_next_attempt,
    'attempts_remaining',greatest(0,v_max_attempts-v_next_attempt),
    'course_completed',v_course_completed,
    'status',case when v_passed then 'completed'
        when v_next_attempt>=v_max_attempts then 'attempt_limit_reached' else 'retry_available' end
 );
end $$;
revoke all on function public.am_student_submit_lesson(uuid,uuid,jsonb) from public,anon;
grant execute on function public.am_student_submit_lesson(uuid,uuid,jsonb) to authenticated;

-- Read-only per-student lesson sequence (publication-locked, no answer keys).
create or replace function public.am_student_lesson_map(p_enrollment_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare v_candidate uuid;v_course uuid;v_out jsonb;v_prev_completed boolean:=true;
begin
 v_candidate:=public.am_student_verified_candidate();
 select e.course_id into v_course from public.am_candidate_learning_enrollments e
 where e.id=p_enrollment_id and e.candidate_id=v_candidate;

 if v_course is null or not public.am_student_course_is_ready(v_course) then
   raise exception 'Course lessons are not available.' using errcode='42501';
 end if;

 select coalesce(jsonb_agg(jsonb_build_object(
  'lesson_id',lv.id,'title_ar',lv.title_ar,'title_en',lv.title_en,
  'module_code',cl.module_code,'sequence_no',cl.sequence_no,
  'estimated_minutes',lv.estimated_minutes,
  'progress_state',coalesce(lp.progress_state,'not_started'),
  'score',lp.best_score,
  'unlocked',public.am_student_lesson_is_unlocked(p_enrollment_id,lv.id)
 ) order by cl.module_code,cl.sequence_no,cl.id),'[]'::jsonb) into v_out
 from avi_knowledge.course_lesson_links cl
 join avi_knowledge.lesson_versions lv on lv.id=cl.lesson_id
 left join public.am_student_lesson_progress lp
   on lp.enrollment_id=p_enrollment_id and lp.lesson_id=lv.id
 where cl.course_id=v_course;

 return v_out;
end $$;
revoke all on function public.am_student_lesson_map(uuid) from public,anon;
grant execute on function public.am_student_lesson_map(uuid) to authenticated;
