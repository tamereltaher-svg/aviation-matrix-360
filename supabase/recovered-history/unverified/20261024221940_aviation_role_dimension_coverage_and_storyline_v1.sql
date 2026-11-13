
create table avi_knowledge.role_axis_coverage (
 role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 axis_code text not null references avi_knowledge.role_axes(code) on delete restrict,
 coverage_status text not null default 'unassessed'
  check(coverage_status in ('unassessed','research_gap','source_identified','source_checked','expert_approved','not_applicable')),
 scope_note text,
 scope_reviewed_at timestamptz,
 primary key(role_id,axis_code),
 check(coverage_status<>'not_applicable' or length(trim(coalesce(scope_note,'')))>=10)
);
create index role_axis_coverage_status_idx on avi_knowledge.role_axis_coverage(coverage_status);

create table avi_knowledge.role_storylines (
 id uuid primary key default gen_random_uuid(),
 slug text not null unique check(slug~'^[a-z0-9_]+$'),
 title_en text not null,title_ar text not null,
 purpose_en text not null,purpose_ar text not null,
 version_no integer not null default 1 check(version_no>0),
 status text not null default 'draft' check(status in ('draft','in_review','published','retired')),
 created_at timestamptz not null default now()
);
create table avi_knowledge.role_storyline_stops (
 id uuid primary key default gen_random_uuid(),
 storyline_id uuid not null references avi_knowledge.role_storylines(id) on delete restrict,
 sequence_no integer not null check(sequence_no>0),
 milestone_id uuid not null references avi_knowledge.role_milestones(id) on delete restrict,
 focus_axis_code text not null references avi_knowledge.role_axes(code) on delete restrict,
 title_en text not null,title_ar text not null,
 why_question_en text not null,why_question_ar text not null,
 narrative_en text not null,narrative_ar text not null,
 lesson_kind text not null check(lesson_kind in ('historical','problem_and_need','interdependence','regulatory','economic','cross_discipline')),
 status text not null default 'draft' check(status in ('draft','in_review','published')),
 unique(storyline_id,sequence_no),
 unique(storyline_id,milestone_id)
);
create index role_storyline_stops_milestone_idx on avi_knowledge.role_storyline_stops(milestone_id);
create table avi_knowledge.role_storyline_course_links (
 storyline_id uuid not null references avi_knowledge.role_storylines(id) on delete restrict,
 course_id uuid not null references public.am_learning_courses(id) on delete restrict,
 placement text not null check(placement in ('foundation','orientation','specialization')),
 primary key(storyline_id,course_id)
);
create index role_storyline_course_course_idx on avi_knowledge.role_storyline_course_links(course_id);

insert into avi_knowledge.role_axis_coverage(role_id,axis_code,coverage_status)
select p.id,a.code,'unassessed' from avi_knowledge.role_profiles p cross join avi_knowledge.role_axes a
on conflict(role_id,axis_code) do nothing;

update avi_knowledge.role_axis_coverage x
set coverage_status='source_checked',
 scope_note='At least one linked source-backed observation; not yet reviewed by an independent expert',
 scope_reviewed_at=now()
where x.coverage_status in ('unassessed','research_gap','source_identified')
  and exists (select 1 from avi_knowledge.role_axis_evidence e where e.role_id=x.role_id and e.axis_code=x.axis_code and e.review_status='source_checked');

create view avi_knowledge.role_multidimensional_coverage with (security_invoker=true)
as select p.code role_code,p.role_en,p.role_ar,f.code family_code,a.code axis_code,a.label_en axis_name_en,a.label_ar axis_name_ar,
x.coverage_status,
(select count(*)::int from avi_knowledge.role_axis_evidence e where e.role_id=p.id and e.axis_code=a.code) evidence_count
from avi_knowledge.role_profiles p join avi_knowledge.role_families f on f.id=p.family_id
cross join avi_knowledge.role_axes a
join avi_knowledge.role_axis_coverage x on x.role_id=p.id and x.axis_code=a.code;

create function avi_knowledge.gate_role_storyline_publication()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
declare n integer; bad integer;
begin
 if new.status='published' and old.status <> 'published' then
  select count(*) into n from avi_knowledge.role_storyline_stops where storyline_id=new.id;
  select count(*) into bad from avi_knowledge.role_storyline_stops s join avi_knowledge.role_milestones m on m.id=s.milestone_id
  where s.storyline_id=new.id and (s.status<>'published' or m.review_status<>'expert_approved' or not exists (
   select 1 from avi_knowledge.role_milestone_sources rs where rs.milestone_id=m.id and rs.support_kind='direct'));
  if n=0 or bad>0 then raise exception 'Role storyline cannot publish without expert-reviewed, evidenced, published stops.'; end if;
 end if;
 return new;
end $$;
revoke all on function avi_knowledge.gate_role_storyline_publication() from public,anon,authenticated;
create trigger trg_gate_role_storyline_publication before update of status on avi_knowledge.role_storylines
for each row execute function avi_knowledge.gate_role_storyline_publication();

do $$ declare tab record; begin
 for tab in select tablename from pg_tables where schemaname='avi_knowledge' loop
   execute format('alter table avi_knowledge.%I enable row level security',tab.tablename);
   execute format('revoke all on avi_knowledge.%I from public,anon,authenticated',tab.tablename);
 end loop;
end $$;
revoke all on avi_knowledge.role_multidimensional_coverage from public,anon,authenticated;
grant select on all tables in schema avi_knowledge to service_role;
grant select on avi_knowledge.role_multidimensional_coverage to service_role;
