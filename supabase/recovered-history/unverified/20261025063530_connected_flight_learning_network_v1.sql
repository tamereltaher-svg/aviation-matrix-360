
-- Connected Flight Case V1. Private, draft-first scenario layer. No passenger/aircraft data.
create table avi_knowledge.connected_flight_cases(
  id uuid primary key default gen_random_uuid(),
  case_code text not null unique check(case_code ~ '^[a-z0-9_]+$'),
  version_no integer not null default 1 check(version_no>=1),
  title_en text not null, title_ar text not null,
  purpose_en text not null, purpose_ar text not null,
  scope_en text not null, scope_ar text not null,
  teaching_sequence_note_en text not null, teaching_sequence_note_ar text not null,
  is_synthetic boolean not null default true check(is_synthetic=true),
  status text not null default 'draft' check(status in ('draft','in_review','approved','published','retired')),
  created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table avi_knowledge.connected_flight_phases(
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references avi_knowledge.connected_flight_cases(id) on delete restrict,
  phase_key text not null check(phase_key ~ '^[a-z0-9_]+$'),
  narrative_order integer not null check(narrative_order>0),
  flight_segment text not null check(flight_segment in ('commercial_planning','preflight','ground_departure','airborne','ground_arrival','postflight')),
  temporal_mode text not null check(temporal_mode in ('sequence_example','can_overlap','conditional')),
  stage_importance text not null check(stage_importance in ('core','conditional','illustrative')),
  title_en text not null,title_ar text not null,
  need_en text not null,need_ar text not null,
  inputs_en text not null,inputs_ar text not null,
  outputs_en text not null,outputs_ar text not null,
  process_en text not null,process_ar text not null,
  risks_en text not null,risks_ar text not null,
  business_effect_en text not null,business_effect_ar text not null,
  source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
  evidence_scope text not null check(evidence_scope in ('official_topic_coverage','illustrative_operational_model')),
  evidence_locator text not null,
  status text not null default 'draft' check(status in ('draft','in_review','expert_approved','published')),
  unique(case_id,phase_key),unique(case_id,narrative_order),unique(case_id,id)
);
create index connected_flight_phases_source_idx on avi_knowledge.connected_flight_phases(source_id);
create table avi_knowledge.connected_flight_phase_roles(
  case_id uuid not null,
  phase_id uuid not null,
  role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
  participation text not null check(participation in ('lead_example','contributor','interface','governance_context')),
  description_en text not null,description_ar text not null,
  scope_note_en text not null,scope_note_ar text not null,
  source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
  evidence_strength text not null check(evidence_strength in ('official_role_scope','illustrative_assignment')),
  primary key(phase_id,role_id),
  foreign key(case_id,phase_id) references avi_knowledge.connected_flight_phases(case_id,id) on delete restrict
);
create index connected_flight_phase_roles_role_idx on avi_knowledge.connected_flight_phase_roles(role_id);
create index connected_flight_phase_roles_source_idx on avi_knowledge.connected_flight_phase_roles(source_id);
create index connected_flight_phase_roles_case_idx on avi_knowledge.connected_flight_phase_roles(case_id);

create table avi_knowledge.connected_flight_dependencies(
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references avi_knowledge.connected_flight_cases(id) on delete restrict,
  from_phase_id uuid not null,to_phase_id uuid not null,
  dependency_kind text not null check(dependency_kind in ('information_handoff','process_link','parallel_coordination','learning_feedback','conditional_branch')),
  detail_en text not null,detail_ar text not null,
  potential_consequence_en text not null,potential_consequence_ar text not null,
  source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
  relation_scope text not null check(relation_scope in ('documented_process_scope','illustrative_dependency')),
  check(from_phase_id<>to_phase_id),
  unique(case_id,from_phase_id,to_phase_id,dependency_kind),
  foreign key(case_id,from_phase_id) references avi_knowledge.connected_flight_phases(case_id,id) on delete restrict,
  foreign key(case_id,to_phase_id) references avi_knowledge.connected_flight_phases(case_id,id) on delete restrict
);
create index connected_flight_deps_from_idx on avi_knowledge.connected_flight_dependencies(from_phase_id);
create index connected_flight_deps_to_idx on avi_knowledge.connected_flight_dependencies(to_phase_id);
create index connected_flight_deps_source_idx on avi_knowledge.connected_flight_dependencies(source_id);

create table avi_knowledge.connected_flight_data_handoffs(
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references avi_knowledge.connected_flight_cases(id) on delete restrict,
  from_phase_id uuid not null,to_phase_id uuid not null,
  from_role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
  to_role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
  data_code text not null check(data_code ~ '^[a-z0-9_]+$'),
  data_en text not null,data_ar text not null,
  why_en text not null,why_ar text not null,
  scope_en text not null,scope_ar text not null,
  source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
  evidence_scope text not null check(evidence_scope in ('official_topic_coverage','illustrative_handoff')),
  check(from_phase_id<>to_phase_id),
  unique(case_id,data_code),
  foreign key(case_id,from_phase_id) references avi_knowledge.connected_flight_phases(case_id,id) on delete restrict,
  foreign key(case_id,to_phase_id) references avi_knowledge.connected_flight_phases(case_id,id) on delete restrict
);
create index connected_flight_handoffs_from_phase_idx on avi_knowledge.connected_flight_data_handoffs(from_phase_id);
create index connected_flight_handoffs_to_phase_idx on avi_knowledge.connected_flight_data_handoffs(to_phase_id);
create index connected_flight_handoffs_from_role_idx on avi_knowledge.connected_flight_data_handoffs(from_role_id);
create index connected_flight_handoffs_to_role_idx on avi_knowledge.connected_flight_data_handoffs(to_role_id);
create index connected_flight_handoffs_source_idx on avi_knowledge.connected_flight_data_handoffs(source_id);

create table avi_knowledge.connected_flight_disruptions(
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null references avi_knowledge.connected_flight_cases(id) on delete restrict,
 case_key text not null check(case_key ~ '^[a-z0-9_]+$'),
 trigger_phase_id uuid not null,
 title_en text not null,title_ar text not null,
 event_en text not null,event_ar text not null,
 problem_en text not null,problem_ar text not null,
 educational_caveat_en text not null,educational_caveat_ar text not null,
 source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
 scenario_nature text not null default 'hypothetical' check(scenario_nature='hypothetical'),
 status text not null default 'draft' check(status in ('draft','in_review','approved','published')),
 unique(case_id,case_key),unique(case_id,id),
 foreign key(case_id,trigger_phase_id) references avi_knowledge.connected_flight_phases(case_id,id) on delete restrict
);
create index connected_flight_disruptions_phase_idx on avi_knowledge.connected_flight_disruptions(trigger_phase_id);
create index connected_flight_disruptions_source_idx on avi_knowledge.connected_flight_disruptions(source_id);

create table avi_knowledge.connected_flight_disruption_impacts(
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null,
 disruption_id uuid not null,
 affected_phase_id uuid not null,
 impact_dimension text not null check(impact_dimension in ('safety','security','operations','passenger','baggage','information','financial','regulatory','quality','environment','training')),
 effect_en text not null,effect_ar text not null,
 confidence_scope text not null check(confidence_scope in ('plausible_not_guaranteed','topic_documented_effect_hypothetical')),
 educational_response_en text not null,educational_response_ar text not null,
 source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
 unique(disruption_id,affected_phase_id,impact_dimension),
 foreign key(case_id,disruption_id) references avi_knowledge.connected_flight_disruptions(case_id,id) on delete restrict,
 foreign key(case_id,affected_phase_id) references avi_knowledge.connected_flight_phases(case_id,id) on delete restrict
);
create index connected_flight_impacts_phase_idx on avi_knowledge.connected_flight_disruption_impacts(affected_phase_id);
create index connected_flight_impacts_source_idx on avi_knowledge.connected_flight_disruption_impacts(source_id);
create index connected_flight_impacts_case_idx on avi_knowledge.connected_flight_disruption_impacts(case_id);

create table avi_knowledge.connected_flight_disruption_choices(
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null,
 disruption_id uuid not null,
 choice_no integer not null check(choice_no>0),
 prompt_en text not null,prompt_ar text not null,
 response_en text not null,response_ar text not null,
 is_pedagogically_preferred boolean not null,
 feedback_en text not null,feedback_ar text not null,
 source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
 unique(disruption_id,choice_no),
 foreign key(case_id,disruption_id) references avi_knowledge.connected_flight_disruptions(case_id,id) on delete restrict
);
create index connected_flight_choices_source_idx on avi_knowledge.connected_flight_disruption_choices(source_id);
create index connected_flight_choices_case_idx on avi_knowledge.connected_flight_disruption_choices(case_id);

create table avi_knowledge.connected_flight_lesson_links(
 case_id uuid not null references avi_knowledge.connected_flight_cases(id) on delete restrict,
 lesson_id uuid not null references avi_knowledge.lesson_versions(id) on delete restrict,
 placement text not null check(placement in ('capstone','supporting','prerequisite')),
 primary key(case_id,lesson_id)
);
create index connected_flight_lesson_links_lesson_idx on avi_knowledge.connected_flight_lesson_links(lesson_id);
create table avi_knowledge.connected_flight_case_reviews(
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null references avi_knowledge.connected_flight_cases(id) on delete restrict,
 review_kind text not null check(review_kind in ('operations','safety','regulatory','instructional','historical')),
 verdict text not null check(verdict in ('pending','changes_required','approved')),
 reviewer_identity text,
 review_note text not null,
 reviewed_at timestamptz not null default now(),
 check(verdict<>'approved' or length(trim(coalesce(reviewer_identity,'')))>=3)
);
create index connected_flight_case_reviews_case_idx on avi_knowledge.connected_flight_case_reviews(case_id);

create function avi_knowledge.gate_connected_flight_publication() returns trigger
 language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
declare count_phases integer; count_roles integer; count_cases integer; count_approved integer; lesson_ok boolean;
begin
 if new.status not in ('approved','published') or new.status is not distinct from old.status then return new; end if;
 select count(*) into count_phases from avi_knowledge.connected_flight_phases where case_id=new.id;
 select count(*) into count_roles from avi_knowledge.connected_flight_phase_roles where case_id=new.id;
 select count(*) into count_cases from avi_knowledge.connected_flight_disruptions where case_id=new.id;
 select count(distinct review_kind) into count_approved from avi_knowledge.connected_flight_case_reviews where case_id=new.id and verdict='approved' and review_kind in ('operations','safety','regulatory','instructional');
 select exists(select 1 from avi_knowledge.connected_flight_lesson_links l join avi_knowledge.lesson_versions lv on lv.id=l.lesson_id where l.case_id=new.id and l.placement='capstone' and lv.status='published') into lesson_ok;
 if count_phases<10 or count_cases<3 or count_roles<count_phases or count_approved<>4 or not lesson_ok
 or exists(select 1 from avi_knowledge.connected_flight_phases p where p.case_id=new.id and not exists(select 1 from avi_knowledge.connected_flight_phase_roles r where r.phase_id=p.id))
 or exists(select 1 from avi_knowledge.connected_flight_disruptions d where d.case_id=new.id and (select count(*) from avi_knowledge.connected_flight_disruption_choices c where c.disruption_id=d.id and c.is_pedagogically_preferred)<>1)
 then raise exception 'Connected-flight case release blocked: all phase roles, cases, qualified reviews and published capstone lesson are required.';end if;
 return new;
end $$;
revoke all on function avi_knowledge.gate_connected_flight_publication() from public,anon,authenticated;
create trigger trg_gate_connected_flight_publication before update of status on avi_knowledge.connected_flight_cases
for each row execute function avi_knowledge.gate_connected_flight_publication();

create view avi_knowledge.connected_flight_case_quality with (security_invoker=true) as
select s.id case_id,s.case_code,s.status,
count(distinct p.id)::integer phase_count,
count(distinct r.role_id)::integer distinct_roles,
count(distinct h.id)::integer information_handoffs,
count(distinct d.id)::integer network_dependencies,
count(distinct x.id)::integer disruptions,
(select count(*)::integer from avi_knowledge.connected_flight_disruption_impacts i where i.case_id=s.id) impact_links,
(select count(*)::integer from avi_knowledge.connected_flight_disruption_choices ch where ch.case_id=s.id) answer_choices,
(select count(*)::integer from avi_knowledge.connected_flight_lesson_links l where l.case_id=s.id) linked_lessons,
(select count(*)::integer from avi_knowledge.connected_flight_case_reviews rv where rv.case_id=s.id and rv.verdict='approved') human_approvals
from avi_knowledge.connected_flight_cases s
left join avi_knowledge.connected_flight_phases p on p.case_id=s.id
left join avi_knowledge.connected_flight_phase_roles r on r.case_id=s.id
left join avi_knowledge.connected_flight_dependencies d on d.case_id=s.id
left join avi_knowledge.connected_flight_data_handoffs h on h.case_id=s.id
left join avi_knowledge.connected_flight_disruptions x on x.case_id=s.id
group by s.id;
revoke all on avi_knowledge.connected_flight_case_quality from public,anon,authenticated;
grant select on avi_knowledge.connected_flight_case_quality to service_role;

do $$ declare rr record;begin
for rr in select tablename from pg_tables where schemaname='avi_knowledge' loop
execute format('alter table avi_knowledge.%I enable row level security',rr.tablename);
execute format('revoke all on avi_knowledge.%I from public,anon,authenticated',rr.tablename);
end loop;end $$;
grant select on all tables in schema avi_knowledge to service_role;
