
create or replace function public.am_student_enroll_course(p_path_id uuid,p_course_id uuid)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare v_candidate uuid;v_course_seq integer;v_enrollment uuid;v_state text;
begin
 v_candidate:=public.am_student_verified_candidate();

 if not public.am_student_course_is_ready(p_course_id) then
    raise exception 'Course is not released for enrollment.' using errcode='42501';
 end if;

 select pc.sequence_no into v_course_seq
 from public.am_learning_path_courses pc
 join public.am_learning_paths p on p.id=pc.learning_path_id and p.status='active'
 where pc.learning_path_id=p_path_id and pc.course_id=p_course_id
   and coalesce((pc.unlock_rule->>'enrollment_enabled')::boolean,false)=true;
 if v_course_seq is null then
   raise exception 'Path/course enrollment is unavailable.' using errcode='42501';
 end if;

 -- Existing completed enrollments are the only proof of satisfying mandatory earlier path courses.
 if (select r.gate_prerequisite_courses from public.am_student_learning_rules r where r.course_id=p_course_id)=true
   and exists (
      select 1 from public.am_learning_path_courses prev
      where prev.learning_path_id=p_path_id and prev.sequence_no<v_course_seq and prev.is_required
        and not exists(
          select 1 from public.am_candidate_learning_enrollments e
          where e.candidate_id=v_candidate and e.learning_path_id=p_path_id
            and e.course_id=prev.course_id and e.status='completed'
        )
   )
 then raise exception 'Required earlier course is not completed.' using errcode='42501';
 end if;

 insert into public.am_candidate_learning_enrollments(candidate_id,learning_path_id,course_id,status,metadata)
 values(v_candidate,p_path_id,p_course_id,'enrolled','{"engine":"student_learning_v1","enrollment_source":"authenticated_verified_candidate"}'::jsonb)
 on conflict do nothing returning id,status into v_enrollment,v_state;

 if v_enrollment is null then
   select e.id,e.status into v_enrollment,v_state
   from public.am_candidate_learning_enrollments e
   where e.candidate_id=v_candidate and e.learning_path_id=p_path_id and e.course_id=p_course_id;
 end if;
 if v_enrollment is null then
  raise exception 'Enrollment could not be established.' using errcode='23505';
 end if;

 insert into public.am_student_learning_events(auth_user_id,enrollment_id,event_type,event_detail)
 select (select auth.uid()),v_enrollment,'course_enrolled',jsonb_build_object('path_id',p_path_id,'course_id',p_course_id)
 where v_state='enrolled' and not exists(
     select 1 from public.am_student_learning_events x
     where x.enrollment_id=v_enrollment and x.event_type='course_enrolled');

 return jsonb_build_object('enrollment_id',v_enrollment,'course_id',p_course_id,'status',v_state);
end $$;
revoke all on function public.am_student_enroll_course(uuid,uuid) from public,anon;
grant execute on function public.am_student_enroll_course(uuid,uuid) to authenticated;

create or replace function public.am_student_open_lesson(p_enrollment_id uuid,p_lesson_id uuid)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare v_candidate uuid;v_course uuid;v_enrollment_state text;v_progress uuid;v_progress_state text;
        v_title_ar text;v_title_en text;v_intro_ar text;v_intro_en text;v_objective_ar text;v_objective_en text;
        v_blocks jsonb;v_questions jsonb;
begin
 v_candidate:=public.am_student_verified_candidate();
 select e.course_id,e.status into v_course,v_enrollment_state
 from public.am_candidate_learning_enrollments e
 where e.id=p_enrollment_id and e.candidate_id=v_candidate for update;
 if v_course is null or v_enrollment_state not in ('enrolled','in_progress','completed') then
   raise exception 'Lesson is not available for this learner.' using errcode='42501';
 end if;
 if not public.am_student_course_is_ready(v_course) then
   raise exception 'Course is not released.' using errcode='42501';
 end if;
 if not exists(select 1 from avi_knowledge.course_lesson_links cl where cl.course_id=v_course and cl.lesson_id=p_lesson_id) then
   raise exception 'Lesson is not available for this learner.' using errcode='42501';
 end if;
 if not public.am_student_lesson_is_unlocked(p_enrollment_id,p_lesson_id) then
   raise exception 'A previous lesson must be completed.' using errcode='42501';
 end if;

 select lv.title_ar,lv.title_en,lv.opening_question_ar,lv.opening_question_en,
        lv.learning_objective_ar,lv.learning_objective_en
 into v_title_ar,v_title_en,v_intro_ar,v_intro_en,v_objective_ar,v_objective_en
 from avi_knowledge.lesson_versions lv where lv.id=p_lesson_id;

 insert into public.am_student_lesson_progress(enrollment_id,lesson_id,progress_state)
 values(p_enrollment_id,p_lesson_id,'in_progress') on conflict(enrollment_id,lesson_id) do nothing;

 select lp.id,lp.progress_state into v_progress,v_progress_state
 from public.am_student_lesson_progress lp
 where lp.enrollment_id=p_enrollment_id and lp.lesson_id=p_lesson_id;

 if v_progress_state='failed' then
   raise exception 'The approved attempt limit was reached.' using errcode='42501';
 end if;

 if v_enrollment_state='enrolled' then
   update public.am_candidate_learning_enrollments set status='in_progress',
     started_at=coalesce(started_at,now()),updated_at=now()
   where id=p_enrollment_id;
 end if;

 select coalesce(jsonb_agg(jsonb_build_object(
   'block_id',b.id,'position',b.position,'kind',b.block_kind,
   'heading_ar',b.heading_ar,'heading_en',b.heading_en,
   'body_ar',b.body_ar,'body_en',b.body_en,
   'citations',(select coalesce(jsonb_agg(distinct jsonb_build_object(
         'publisher',src.publisher,'title',src.title,'url',src.source_url,'locator',cs.locator)),'[]'::jsonb)
       from avi_knowledge.lesson_block_claims bc
       join avi_knowledge.claim_sources cs on cs.claim_id=bc.claim_id and cs.support_kind='direct'
       join avi_knowledge.sources src on src.id=cs.source_id
       where bc.block_id=b.id)
 ) order by b.position),'[]'::jsonb) into v_blocks
 from avi_knowledge.lesson_blocks b where b.lesson_id=p_lesson_id;

 select coalesce(jsonb_agg(jsonb_build_object(
    'question_id',q.id,'question_code',q.question_code,'position',q.position,
    'stem_ar',q.stem_ar,'stem_en',q.stem_en,
    'options',(select coalesce(jsonb_agg(jsonb_build_object(
       'option_id',o.id,'answer_ar',o.answer_ar,'answer_en',o.answer_en,'position',o.position
    ) order by o.position),'[]'::jsonb)
    from avi_knowledge.lesson_question_options o where o.question_id=q.id)
 ) order by q.position),'[]'::jsonb) into v_questions
 from avi_knowledge.lesson_questions q where q.lesson_id=p_lesson_id;

 insert into public.am_student_learning_events(auth_user_id,enrollment_id,lesson_id,event_type)
 values((select auth.uid()),p_enrollment_id,p_lesson_id,'lesson_opened');

 return jsonb_build_object(
 'enrollment_id',p_enrollment_id,'lesson_id',p_lesson_id,
 'title_ar',v_title_ar,'title_en',v_title_en,
 'opening_question_ar',v_intro_ar,'opening_question_en',v_intro_en,
 'objective_ar',v_objective_ar,'objective_en',v_objective_en,
 'progress_state',v_progress_state,'blocks',v_blocks,'questions',v_questions
 );
end $$;
revoke all on function public.am_student_open_lesson(uuid,uuid) from public,anon;
grant execute on function public.am_student_open_lesson(uuid,uuid) to authenticated;
