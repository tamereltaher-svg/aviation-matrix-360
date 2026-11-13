
-- Additive role-to-lesson traceability; no public access. Reuses existing approved lesson engine.
create table avi_knowledge.lesson_role_focus (
 lesson_id uuid not null references avi_knowledge.lesson_versions(id) on delete restrict,
 role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 emphasis text not null check(emphasis in ('primary','cross_functional','historical_comparison')),
 scope_note_en text not null,
 scope_note_ar text not null,
 primary key(lesson_id,role_id)
);
create unique index lesson_one_primary_role_idx on avi_knowledge.lesson_role_focus(lesson_id) where emphasis='primary';
create index lesson_role_focus_role_idx on avi_knowledge.lesson_role_focus(role_id);

create table avi_knowledge.lesson_role_milestones (
 lesson_id uuid not null references avi_knowledge.lesson_versions(id) on delete restrict,
 milestone_id uuid not null references avi_knowledge.role_milestones(id) on delete restrict,
 evidence_role text not null check(evidence_role in ('direct_historical_evidence','context_only','chronology_not_causality')),
 note_en text not null, note_ar text not null,
 primary key(lesson_id,milestone_id)
);
create index lesson_role_milestones_milestone_idx on avi_knowledge.lesson_role_milestones(milestone_id);

create table avi_knowledge.lesson_role_relations (
 lesson_id uuid not null references avi_knowledge.lesson_versions(id) on delete restrict,
 interdependency_id uuid not null references avi_knowledge.role_interdependencies(id) on delete restrict,
 learning_use text not null check(learning_use in ('documented_historical_handoff','current_guidance','illustrative_scenario')),
 explanation_en text not null,explanation_ar text not null,
 primary key(lesson_id,interdependency_id)
);
create index lesson_role_relations_rel_idx on avi_knowledge.lesson_role_relations(interdependency_id);

create table avi_knowledge.role_storyline_lesson_links (
 stop_id uuid not null references avi_knowledge.role_storyline_stops(id) on delete restrict,
 lesson_id uuid not null references avi_knowledge.lesson_versions(id) on delete restrict,
 coverage_kind text not null check(coverage_kind in ('taught_and_assessed','context_reference')),
 primary key(stop_id,lesson_id)
);
create index role_storyline_lesson_links_lesson_idx on avi_knowledge.role_storyline_lesson_links(lesson_id);

create view avi_knowledge.role_lesson_quality with (security_invoker=true) as
 select lv.id lesson_id,st.step_no,lv.title_en,lv.status,
 count(distinct lr.role_id) filter(where lr.emphasis='primary')::int primary_roles,
 count(distinct ms.milestone_id)::int historical_events,
 count(distinct rr.interdependency_id)::int role_relations,
 count(distinct sc.stop_id)::int storyline_stops,
 (select count(*)::int from avi_knowledge.lesson_questions lq where lq.lesson_id=lv.id) questions,
 (select count(*)::int from avi_knowledge.lesson_blocks lb where lb.lesson_id=lv.id) blocks
 from avi_knowledge.lesson_versions lv
 join avi_knowledge.journey_steps st on st.id=lv.journey_step_id
 join avi_knowledge.journeys j on j.id=st.journey_id and j.slug='aviation_role_genesis_case_studies_v1'
 left join avi_knowledge.lesson_role_focus lr on lr.lesson_id=lv.id
 left join avi_knowledge.lesson_role_milestones ms on ms.lesson_id=lv.id
 left join avi_knowledge.lesson_role_relations rr on rr.lesson_id=lv.id
 left join avi_knowledge.role_storyline_lesson_links sc on sc.lesson_id=lv.id
 group by lv.id,st.step_no;

create function avi_knowledge.lock_role_lesson_joins()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
declare status_new text;status_old text; lid_new uuid; lid_old uuid;
begin
 if tg_op<>'DELETE' then lid_new:=new.lesson_id;end if;
 if tg_op<>'INSERT' then lid_old:=old.lesson_id;end if;
 if lid_new is not null then select status into status_new from avi_knowledge.lesson_versions where id=lid_new;end if;
 if lid_old is not null then select status into status_old from avi_knowledge.lesson_versions where id=lid_old;end if;
 if coalesce(status_new,'draft') in ('expert_approved','published','retired')
   or coalesce(status_old,'draft') in ('expert_approved','published','retired') then
   raise exception 'Role-to-lesson evidence links are immutable after expert approval; create new lesson version.';
 end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
revoke all on function avi_knowledge.lock_role_lesson_joins() from public,anon,authenticated;
create trigger lock_role_focus before insert or update or delete on avi_knowledge.lesson_role_focus
for each row execute function avi_knowledge.lock_role_lesson_joins();
create trigger lock_role_milestones before insert or update or delete on avi_knowledge.lesson_role_milestones
for each row execute function avi_knowledge.lock_role_lesson_joins();
create trigger lock_role_relations before insert or update or delete on avi_knowledge.lesson_role_relations
for each row execute function avi_knowledge.lock_role_lesson_joins();
create trigger lock_role_storyline_joins before insert or update or delete on avi_knowledge.role_storyline_lesson_links
for each row execute function avi_knowledge.lock_role_lesson_joins();

do $$ declare t record;begin
 for t in select tablename from pg_tables where schemaname='avi_knowledge' loop
 execute format('alter table avi_knowledge.%I enable row level security',t.tablename);
 execute format('revoke all on avi_knowledge.%I from public,anon,authenticated',t.tablename);
 end loop;
end $$;
revoke all on avi_knowledge.role_lesson_quality from public,anon,authenticated;
grant select on all tables in schema avi_knowledge to service_role;
grant select on avi_knowledge.role_lesson_quality to service_role;
