
-- Explicit gap tracking for the four actually authored case-study roles only.
update avi_knowledge.role_axis_coverage c
set coverage_status='research_gap',
    scope_note='No qualified role- and jurisdiction-scoped evidence is recorded in the current knowledge base for this axis. Do not infer the work or concept did not exist.',
    scope_reviewed_at=now()
where coverage_status='unassessed' and role_id in
(select id from avi_knowledge.role_profiles where code in ('pilot','aircraft_mechanic','air_traffic_controller','flight_attendant'));

create view avi_knowledge.role_research_queue with (security_invoker=true) as
select p.code role_code,p.role_ar,p.role_en,a.code axis_code,a.label_ar,a.label_en,a.axis_group,
       c.coverage_status,
       case when p.code in ('pilot','aircraft_mechanic','air_traffic_controller','flight_attendant') then true else false end case_study_role,
       case
         when c.coverage_status in ('expert_approved','not_applicable') then 5
         when a.code in ('historical_origin','underlying_need','precursor_tasks','original_title','geography','hand_offs','safety','regulatory','training','technology','specialization') then 1
         when a.code in ('economic','financial','workforce_access','human_factors','flight_phase','data_digital','organization','passenger','quality') then 2
         else 3 end research_priority,
       case when c.coverage_status='research_gap' then 'No scoped evidence recorded. Source research required; no unsupported claims.'
            when c.coverage_status='source_checked' then 'AI-assisted source check only; expert validation required.'
            when c.coverage_status='unassessed' then 'Not yet assessed for this role and axis.'
            else c.coverage_status end editorial_next_step
from avi_knowledge.role_profiles p
join avi_knowledge.role_axis_coverage c on c.role_id=p.id
join avi_knowledge.role_axes a on a.code=c.axis_code;

revoke all on avi_knowledge.role_research_queue from public,anon,authenticated;
grant select on avi_knowledge.role_research_queue to service_role;
comment on view avi_knowledge.role_research_queue is 'Research-management aid only. Priority is an editorial heuristic, not a certification or competence ranking.';
