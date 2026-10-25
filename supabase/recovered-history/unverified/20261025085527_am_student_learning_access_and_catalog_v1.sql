
-- One active enrollment per candidate/path/course; reuse existing enrollment table.
create unique index if not exists am_student_enrollments_unique_path_course
on public.am_candidate_learning_enrollments(candidate_id,learning_path_id,course_id)
where learning_path_id is not null and course_id is not null;

create or replace function public.am_student_verified_candidate()
returns uuid
language plpgsql stable security definer set search_path = ''
as $$
declare v_candidate uuid;
begin
 if (select auth.uid()) is null or coalesce((select auth.jwt()->>'is_anonymous')::boolean,false) then
   raise exception 'Authentication required.' using errcode='42501';
 end if;
 select b.candidate_id into v_candidate
 from public.am_student_auth_bindings b
 join public.am_candidate_records c on c.id=b.candidate_id
 where b.auth_user_id=(select auth.uid()) and b.binding_state='verified'
   and c.activation_status='active';
 if v_candidate is null then
   raise exception 'A verified, active learner identity is required.' using errcode='42501';
 end if;
 return v_candidate;
end $$;
revoke all on function public.am_student_verified_candidate() from public,anon,authenticated;

-- Internal safety gate: a published date, review trail, approved blocks/questions and a released course are ALL required.
create or replace function public.am_student_course_is_ready(p_course_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
select exists(
 select 1 from public.am_learning_courses c
 join public.am_learning_curricula cur on cur.id=c.curriculum_id
 join public.am_student_learning_rules r on r.course_id=c.id
 where c.id=p_course_id and c.status='active' and cur.status='active'
   and coalesce((c.completion_rule->>'enabled')::boolean,false)=true
   and r.enabled=true and r.passing_percent is not null and r.max_attempts is not null
   and (select count(*) from avi_knowledge.course_lesson_links cl where cl.course_id=c.id)>0
   and not exists(
     select 1 from avi_knowledge.course_lesson_links cl
     join avi_knowledge.lesson_versions lv on lv.id=cl.lesson_id
     join avi_knowledge.journey_steps st on st.id=lv.journey_step_id
     join avi_knowledge.journeys j on j.id=st.journey_id
     where cl.course_id=c.id and (
       lv.status<>'published' or lv.published_at is null
       or st.status<>'published' or j.status<>'published'
       or (select count(distinct rv.review_kind) from avi_knowledge.lesson_reviews rv
             where rv.lesson_id=lv.id and rv.verdict='approved'
             and rv.review_kind in ('subject_expert','instructional_design','language','safety'))<>4
       or not exists(select 1 from avi_knowledge.lesson_blocks lb where lb.lesson_id=lv.id)
       or exists(select 1 from avi_knowledge.lesson_blocks lb where lb.lesson_id=lv.id
          and (lb.editorial_status<>'expert_approved' or
            not exists(select 1 from avi_knowledge.lesson_block_claims bc
              join avi_knowledge.claim_sources cs on cs.claim_id=bc.claim_id and cs.support_kind='direct'
              where bc.block_id=lb.id)))
       or not exists(select 1 from avi_knowledge.lesson_questions lq where lq.lesson_id=lv.id)
       or exists(select 1 from avi_knowledge.lesson_questions lq where lq.lesson_id=lv.id
           and (lq.editorial_status<>'expert_approved'
               or not exists(select 1 from avi_knowledge.lesson_question_claims qc
                     join avi_knowledge.claim_sources cs on cs.claim_id=qc.claim_id and cs.support_kind='direct'
                     where qc.question_id=lq.id)
               or (select count(*) from avi_knowledge.lesson_question_options o where o.question_id=lq.id and o.is_correct)<>1
               or (select count(*) from avi_knowledge.lesson_question_options o where o.question_id=lq.id)<2))
     )
   )
);
$$;
revoke all on function public.am_student_course_is_ready(uuid) from public,anon,authenticated;

-- Authenticated catalog: only active, configured, reviewed courses. No answer keys.
create or replace function public.am_student_catalog()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare v_out jsonb;
begin
 if (select auth.uid()) is null or coalesce((select auth.jwt()->>'is_anonymous')::boolean,false) then
   raise exception 'Authentication required.' using errcode='42501';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'path_id',p.id,'path_code',p.code,'path_name',p.name,
   'course_id',c.id,'course_code',c.code,'title',c.name,
   'duration_minutes',c.duration_minutes,'sequence_no',pc.sequence_no,
   'is_required',pc.is_required
 ) order by p.code,pc.sequence_no),'[]'::jsonb) into v_out
 from public.am_learning_paths p
 join public.am_learning_path_courses pc on pc.learning_path_id=p.id
 join public.am_learning_courses c on c.id=pc.course_id
 where p.status='active'
 and coalesce((pc.unlock_rule->>'enrollment_enabled')::boolean,false)=true
 and public.am_student_course_is_ready(c.id);
 return v_out;
end $$;
revoke all on function public.am_student_catalog() from public,anon;
grant execute on function public.am_student_catalog() to authenticated;

create or replace function public.am_student_dashboard()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare v_uid uuid;v_candidate uuid;v_out jsonb;
begin
 v_uid:=(select auth.uid());
 if v_uid is null or coalesce((select auth.jwt()->>'is_anonymous')::boolean,false) then
   raise exception 'Authentication required.' using errcode='42501';
 end if;
 select b.candidate_id into v_candidate
 from public.am_student_auth_bindings b
 join public.am_candidate_records c on c.id=b.candidate_id and c.activation_status='active'
 where b.auth_user_id=v_uid and b.binding_state='verified';
 if v_candidate is null then
   return jsonb_build_object('identity_status','verification_required','enrollments','[]'::jsonb,'catalog',public.am_student_catalog());
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'enrollment_id',e.id,'course_id',e.course_id,'course_code',c.code,'course_title',c.name,
   'status',e.status,'completion_score',e.completion_score,
   'completed_lessons',(select count(*) from public.am_student_lesson_progress lp where lp.enrollment_id=e.id and lp.progress_state='completed'),
   'total_lessons',(select count(*) from avi_knowledge.course_lesson_links cl where cl.course_id=e.course_id),
   'path_id',e.learning_path_id,
   'started_at',e.started_at,'completed_at',e.completed_at
 ) order by e.enrolled_at),'[]'::jsonb) into v_out
 from public.am_candidate_learning_enrollments e
 join public.am_learning_courses c on c.id=e.course_id
 where e.candidate_id=v_candidate
   and (public.am_student_course_is_ready(e.course_id) or e.status='completed');
 return jsonb_build_object('identity_status','verified','enrollments',v_out,'catalog',public.am_student_catalog());
end $$;
revoke all on function public.am_student_dashboard() from public,anon;
grant execute on function public.am_student_dashboard() to authenticated;

-- Internal utility used for strict lesson ordering.
create or replace function public.am_student_lesson_is_unlocked(p_enrollment_id uuid,p_lesson_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
with info as (
  select e.course_id, r.require_order
  from public.am_candidate_learning_enrollments e
  join public.am_student_learning_rules r on r.course_id=e.course_id and r.enabled
  where e.id=p_enrollment_id
), sequenced as (
 select cl.lesson_id,
 row_number() over(order by cl.module_code,cl.sequence_no,cl.id) as step_no
 from avi_knowledge.course_lesson_links cl join info i on i.course_id=cl.course_id
), requested as (
 select step_no from sequenced where lesson_id=p_lesson_id
)
select exists(select 1 from requested) and (
 (select require_order from info)=false
 or not exists(
   select 1 from sequenced s cross join requested r
   where s.step_no<r.step_no
     and not exists(select 1 from public.am_student_lesson_progress prog
      where prog.enrollment_id=p_enrollment_id and prog.lesson_id=s.lesson_id and prog.progress_state='completed')
 )
);
$$;
revoke all on function public.am_student_lesson_is_unlocked(uuid,uuid) from public,anon,authenticated;
