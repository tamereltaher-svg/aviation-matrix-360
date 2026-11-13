
-- Narrow release gates for Aviation Matrix foundation assets only.
-- Existing unrelated courses and paths are not affected.
create function avi_knowledge.guard_foundation_course_status()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge,public
as $$
declare total_lessons integer; qualified integer;
begin
  if (new.metadata->>'avi_knowledge_journey_slug') is null
     or new.status is not distinct from old.status
     or new.status not in ('approved','active') then
    return new;
  end if;
  select count(*) into total_lessons from avi_knowledge.course_lesson_links l where l.course_id=new.id;
  if total_lessons=0 then raise exception 'Foundation course has no linked lessons.'; end if;
  if new.status='approved' then
    select count(*) into qualified from avi_knowledge.course_lesson_links l join avi_knowledge.lesson_versions v on v.id=l.lesson_id
     where l.course_id=new.id and v.status in ('expert_approved','published');
    if qualified<>total_lessons then raise exception 'Foundation course cannot be approved: all lesson versions require expert and instructional review.'; end if;
  elsif new.status='active' then
    select count(*) into qualified from avi_knowledge.course_lesson_links l join avi_knowledge.lesson_versions v on v.id=l.lesson_id
     where l.course_id=new.id and v.status='published';
    if qualified<>total_lessons then raise exception 'Foundation course cannot activate until all lessons are published.'; end if;
  end if;
  return new;
end $$;
revoke all on function avi_knowledge.guard_foundation_course_status() from public,anon,authenticated;
create trigger trg_avi_foundation_course_release
before update of status on public.am_learning_courses
for each row execute function avi_knowledge.guard_foundation_course_status();

create function avi_knowledge.guard_foundation_path_status()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge,public
as $$
declare total_courses integer; ready_courses integer;
begin
  if (new.metadata->>'origin') is distinct from 'avi_knowledge'
    or new.status is not distinct from old.status
    or new.status not in ('approved','active') then return new; end if;
  select count(*) into total_courses from public.am_learning_path_courses l where l.learning_path_id=new.id;
  if total_courses=0 then raise exception 'Foundation path has no linked courses.'; end if;
  select count(*) into ready_courses
  from public.am_learning_path_courses l join public.am_learning_courses c on c.id=l.course_id
  where l.learning_path_id=new.id and
    ((new.status='active' and c.status='active') or (new.status='approved' and c.status in ('approved','active')));
  if ready_courses<>total_courses then raise exception 'Foundation path cannot advance until linked courses are approved or active.'; end if;
  return new;
end $$;
revoke all on function avi_knowledge.guard_foundation_path_status() from public,anon,authenticated;
create trigger trg_avi_foundation_path_release
before update of status on public.am_learning_paths
for each row execute function avi_knowledge.guard_foundation_path_status();
