
-- Course 02 content gates: historical evidence + living role matrix + cross-functional scope.
create function avi_knowledge.gate_role_case_study_approval()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
declare primary_count integer; approved_primary integer; reviewed_events integer; total_events integer;
        approved_edges integer; total_edges integer; applied boolean;
begin
 select exists(select 1 from avi_knowledge.journey_steps s join avi_knowledge.journeys j on j.id=s.journey_id where s.id=new.journey_step_id and j.slug='aviation_role_genesis_case_studies_v1') into applied;
 if not applied or new.status not in ('expert_approved','published') then return new;end if;
 select count(*) into primary_count from avi_knowledge.lesson_role_focus f where f.lesson_id=new.id and f.emphasis='primary';
 select count(*) into approved_primary from avi_knowledge.lesson_role_focus f join avi_knowledge.role_profiles p on p.id=f.role_id where f.lesson_id=new.id and f.emphasis='primary' and p.status in ('expert_approved','published');
 if primary_count<>1 or approved_primary<>1 then raise exception 'Role lesson approval blocked: one expert-approved primary role required.';end if;
 select count(*) into total_events from avi_knowledge.lesson_role_milestones ms where ms.lesson_id=new.id and ms.evidence_role='direct_historical_evidence';
 select count(*) into reviewed_events from avi_knowledge.lesson_role_milestones ms join avi_knowledge.role_milestones m on m.id=ms.milestone_id
 where ms.lesson_id=new.id and ms.evidence_role='direct_historical_evidence' and m.review_status='expert_approved'
 and exists(select 1 from avi_knowledge.role_milestone_sources s where s.milestone_id=m.id and s.support_kind='direct');
 if total_events<1 or reviewed_events<>total_events then raise exception 'Role lesson approval blocked: every taught historical event requires a sourced historian approval.';end if;
 select count(*) into total_edges from avi_knowledge.lesson_role_relations lr where lr.lesson_id=new.id;
 select count(*) into approved_edges from avi_knowledge.lesson_role_relations lr join avi_knowledge.role_interdependencies rd on rd.id=lr.interdependency_id where lr.lesson_id=new.id and rd.review_status='expert_approved';
 if total_edges<1 or total_edges<>approved_edges then raise exception 'Role lesson approval blocked: cross-role relationships require expert review.';end if;
 if not exists(select 1 from avi_knowledge.role_storyline_lesson_links sl where sl.lesson_id=new.id and sl.coverage_kind='taught_and_assessed')
 then raise exception 'Role lesson approval blocked: no directly taught timeline event.';end if;
 return new;
end $$;
revoke all on function avi_knowledge.gate_role_case_study_approval() from public,anon,authenticated;
create trigger trg_role_case_study_release before update of status on avi_knowledge.lesson_versions
for each row execute function avi_knowledge.gate_role_case_study_approval();

create function avi_knowledge.gate_timeline_stop_lesson()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
begin
 if new.status='published' and old.status<>'published'
 and not exists(select 1 from avi_knowledge.role_storyline_lesson_links sl join avi_knowledge.lesson_versions lv on lv.id=sl.lesson_id
  where sl.stop_id=new.id and sl.coverage_kind='taught_and_assessed' and lv.status='published')
 then raise exception 'Timeline stop publishing requires an assessed, published, traceable lesson.';end if;
 return new;
end $$;
revoke all on function avi_knowledge.gate_timeline_stop_lesson() from public,anon,authenticated;
create trigger trg_gate_timeline_stop_lesson before update of status on avi_knowledge.role_storyline_stops
for each row execute function avi_knowledge.gate_timeline_stop_lesson();

create function avi_knowledge.gate_role_course_full_coverage()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge,public as $$
declare total_stops integer; covered_stops integer; source_story_status text;
begin
 if new.code<>'AVI_FOUNDATION_ROLE_EVOLUTION_02' or new.status not in ('approved','active') or new.status is not distinct from old.status then return new;end if;
 select j.status,count(st.id) into source_story_status,total_stops
 from avi_knowledge.role_storyline_course_links l join avi_knowledge.role_storylines j on j.id=l.storyline_id
 left join avi_knowledge.role_storyline_stops st on st.storyline_id=j.id
 where l.course_id=new.id group by j.status;
 select count(distinct st.id) into covered_stops from avi_knowledge.role_storyline_course_links l
 join avi_knowledge.role_storyline_stops st on st.storyline_id=l.storyline_id
 join avi_knowledge.role_storyline_lesson_links sl on sl.stop_id=st.id and sl.coverage_kind='taught_and_assessed'
 join avi_knowledge.lesson_versions lv on lv.id=sl.lesson_id and lv.status='published'
 where l.course_id=new.id and st.status='published';
 if total_stops is null or total_stops<1 or covered_stops<>total_stops or source_story_status<>'published'
 then raise exception 'Origin-of-roles course cannot be approved or activated until every planned timeline stop has a published assessed lesson and the storyline is published.';end if;
 return new;
end $$;
revoke all on function avi_knowledge.gate_role_course_full_coverage() from public,anon,authenticated;
create trigger trg_role_course_full_coverage before update of status on public.am_learning_courses
for each row execute function avi_knowledge.gate_role_course_full_coverage();

create view avi_knowledge.role_course_coverage with (security_invoker=true) as
select c.id course_id,c.code course_code,c.status course_status,
j.slug storyline_slug,j.status storyline_status,
count(distinct s.id)::int planned_stops,
count(distinct s.id) filter(where exists(select 1 from avi_knowledge.role_storyline_lesson_links x where x.stop_id=s.id and x.coverage_kind='taught_and_assessed'))::int stops_with_assessed_lesson_draft,
count(distinct s.id) filter(where s.status='published')::int published_stops,
(select count(*)::int from avi_knowledge.course_lesson_links l where l.course_id=c.id) authored_lessons,
(select count(*)::int from avi_knowledge.role_course_bridges b where b.course_id=c.id) planned_role_links,
(select count(distinct rf.role_id)::int from avi_knowledge.course_lesson_links ll join avi_knowledge.lesson_role_focus rf on rf.lesson_id=ll.lesson_id and rf.emphasis='primary' where ll.course_id=c.id) roles_with_authored_lessons
from public.am_learning_courses c
join avi_knowledge.role_storyline_course_links cl on cl.course_id=c.id
join avi_knowledge.role_storylines j on j.id=cl.storyline_id
left join avi_knowledge.role_storyline_stops s on s.storyline_id=j.id
group by c.id,j.id;

create view avi_knowledge.role_lesson_citations with (security_invoker=true) as
select lv.id lesson_id,lb.id block_id,lb.position block_position,
 c.claim_key,c.statement_ar,c.statement_en,s.publisher,s.title source_title,s.source_url,cs.locator,cs.support_kind
from avi_knowledge.lesson_versions lv
join avi_knowledge.lesson_blocks lb on lb.lesson_id=lv.id
join avi_knowledge.lesson_block_claims bc on bc.block_id=lb.id
join avi_knowledge.claims c on c.id=bc.claim_id
join avi_knowledge.claim_sources cs on cs.claim_id=c.id
join avi_knowledge.sources s on s.id=cs.source_id;

revoke all on avi_knowledge.role_course_coverage from public,anon,authenticated;
revoke all on avi_knowledge.role_lesson_citations from public,anon,authenticated;
grant select on avi_knowledge.role_course_coverage,avi_knowledge.role_lesson_citations to service_role;
