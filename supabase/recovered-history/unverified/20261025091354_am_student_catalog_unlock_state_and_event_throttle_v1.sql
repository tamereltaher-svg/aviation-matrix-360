
create or replace function public.am_student_catalog()
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
 join public.am_candidate_records cr on cr.id=b.candidate_id and cr.activation_status='active'
 where b.auth_user_id=v_uid and b.binding_state='verified';

 select coalesce(jsonb_agg(jsonb_build_object(
   'path_id',p.id,'path_code',p.code,'path_name',p.name,
   'course_id',c.id,'course_code',c.code,'title',c.name,
   'duration_minutes',c.duration_minutes,'sequence_no',pc.sequence_no,
   'is_required',pc.is_required,
   'unlock_status',case
     when v_candidate is null then 'verify_identity'
     when exists(select 1 from public.am_candidate_learning_enrollments e
           where e.candidate_id=v_candidate and e.course_id=c.id and e.learning_path_id=p.id and e.status='completed') then 'completed'
     when exists(select 1 from public.am_student_learning_rules r
         where r.course_id=c.id and r.gate_prerequisite_courses
          and exists(select 1 from public.am_learning_path_courses earlier
             where earlier.learning_path_id=p.id and earlier.sequence_no<pc.sequence_no
               and earlier.is_required and not exists(
                 select 1 from public.am_candidate_learning_enrollments prev_e
                 where prev_e.candidate_id=v_candidate and prev_e.course_id=earlier.course_id
                   and prev_e.learning_path_id=p.id and prev_e.status='completed'
               ))) then 'previous_course_required'
     else 'available' end
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

create or replace function public.am_student_lesson_map(p_enrollment_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare v_candidate uuid;v_course uuid;v_enrollment_state text;v_out jsonb;
begin
 v_candidate:=public.am_student_verified_candidate();
 select e.course_id,e.status into v_course,v_enrollment_state from public.am_candidate_learning_enrollments e
 where e.id=p_enrollment_id and e.candidate_id=v_candidate;
 if v_course is null or not public.am_student_course_is_ready(v_course) then
   raise exception 'Course lessons are not available.' using errcode='42501';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'lesson_id',lv.id,'title_ar',lv.title_ar,'title_en',lv.title_en,
  'module_code',cl.module_code,'sequence_no',cl.sequence_no,
  'estimated_minutes',lv.estimated_minutes,
  'progress_state',coalesce(lp.progress_state,'not_started'),
  'score',lp.best_score,'attempts_used',coalesce(lp.attempts_used,0),
  'unlocked',case when v_enrollment_state not in ('enrolled','in_progress','completed')
                 or lp.progress_state='failed' then false
      else public.am_student_lesson_is_unlocked(p_enrollment_id,lv.id) end
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

create or replace function public.am_student_throttle_open_events()
returns trigger language plpgsql security invoker set search_path = ''
as $$
begin
 if new.event_type='lesson_opened' and exists(
   select 1 from public.am_student_learning_events e
   where e.auth_user_id=new.auth_user_id and e.enrollment_id=new.enrollment_id
     and e.lesson_id=new.lesson_id and e.event_type='lesson_opened'
     and e.created_at>pg_catalog.now()-interval '1 minute'
 )
 then return null; end if;
 return new;
end $$;
revoke all on function public.am_student_throttle_open_events() from public,anon,authenticated;
create trigger am_student_throttle_lesson_open_event before insert on public.am_student_learning_events
for each row execute function public.am_student_throttle_open_events();
