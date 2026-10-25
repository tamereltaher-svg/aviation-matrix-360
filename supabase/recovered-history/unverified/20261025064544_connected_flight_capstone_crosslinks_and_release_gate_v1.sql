
create table avi_knowledge.connected_flight_phase_lesson_blocks(
 case_id uuid not null,
 phase_id uuid not null,
 block_id uuid not null references avi_knowledge.lesson_blocks(id) on delete restrict,
 coverage_kind text not null check(coverage_kind in ('explained','referenced')),
 primary key(phase_id,block_id),
 foreign key(case_id,phase_id) references avi_knowledge.connected_flight_phases(case_id,id) on delete restrict
);
create index connected_flight_phase_lesson_block_block_idx on avi_knowledge.connected_flight_phase_lesson_blocks(block_id);
create index connected_flight_phase_lesson_block_case_idx on avi_knowledge.connected_flight_phase_lesson_blocks(case_id);
create table avi_knowledge.connected_flight_disruption_lesson_questions(
 case_id uuid not null,
 disruption_id uuid not null,
 question_id uuid not null references avi_knowledge.lesson_questions(id) on delete restrict,
 primary key(disruption_id,question_id),
 foreign key(case_id,disruption_id) references avi_knowledge.connected_flight_disruptions(case_id,id) on delete restrict
);
create index connected_flight_disruption_lesson_question_q_idx on avi_knowledge.connected_flight_disruption_lesson_questions(question_id);
create index connected_flight_disruption_lesson_question_case_idx on avi_knowledge.connected_flight_disruption_lesson_questions(case_id);
alter table avi_knowledge.connected_flight_phase_lesson_blocks enable row level security;
alter table avi_knowledge.connected_flight_disruption_lesson_questions enable row level security;
revoke all on avi_knowledge.connected_flight_phase_lesson_blocks,avi_knowledge.connected_flight_disruption_lesson_questions from public,anon,authenticated;
grant select on avi_knowledge.connected_flight_phase_lesson_blocks,avi_knowledge.connected_flight_disruption_lesson_questions to service_role;

create function avi_knowledge.gate_connected_flight_course_publication() returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge,public as $$
declare ready boolean;
begin
 if new.code <> 'AVI_FOUNDATION_SYSTEM_FLIGHT_03'
    or new.status not in ('approved','active')
    or new.status is not distinct from old.status then return new; end if;
 select exists(
   select 1 from avi_knowledge.connected_flight_cases c
   join avi_knowledge.connected_flight_lesson_links cl on cl.case_id=c.id and cl.placement='capstone'
   join avi_knowledge.lesson_versions lv on lv.id=cl.lesson_id
   join avi_knowledge.course_lesson_links ll on ll.lesson_id=lv.id and ll.course_id=new.id
   where c.case_code='one_flight_connected_system_v1' and c.status='published' and lv.status='published'
 ) into ready;
 if not ready then raise exception 'Connected flight capstone course blocked: source scenario and capstone lesson are not published by qualified reviewers.'; end if;
 return new;
end $$;
revoke all on function avi_knowledge.gate_connected_flight_course_publication() from public,anon,authenticated;
create trigger trg_gate_connected_flight_course_publication before update of status on public.am_learning_courses
for each row execute function avi_knowledge.gate_connected_flight_course_publication();

create view avi_knowledge.connected_flight_learning_coverage with (security_invoker=true) as
select c.case_code,p.phase_key,p.narrative_order,p.temporal_mode,p.stage_importance,
count(distinct f.role_id)::int participating_roles,
count(distinct l.block_id) filter(where l.coverage_kind='explained')::int explanatory_blocks,
count(distinct f.source_id)::int role_scope_sources,
p.source_id is not null as has_phase_source
from avi_knowledge.connected_flight_cases c
join avi_knowledge.connected_flight_phases p on p.case_id=c.id
left join avi_knowledge.connected_flight_phase_roles f on f.phase_id=p.id
left join avi_knowledge.connected_flight_phase_lesson_blocks l on l.phase_id=p.id
group by c.case_code,p.id;
revoke all on avi_knowledge.connected_flight_learning_coverage from public,anon,authenticated;
grant select on avi_knowledge.connected_flight_learning_coverage to service_role;
