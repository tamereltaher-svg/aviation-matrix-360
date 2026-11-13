
-- Role Genesis & Evolution Matrix V1 — additive, private and evidence-first.
-- Roles are not job vacancies; origin milestones are not universal firsts.
create table avi_knowledge.role_families (
 id uuid primary key default gen_random_uuid(),
 code text not null unique check(code ~ '^[a-z0-9_]+$'),
 label_en text not null, label_ar text not null,
 scope_note_en text not null, scope_note_ar text not null,
 created_at timestamptz not null default now()
);
create table avi_knowledge.role_axes (
 code text primary key check(code ~ '^[a-z0-9_]+$'),
 label_en text not null,label_ar text not null,
 question_en text not null,question_ar text not null,
 axis_group text not null check(axis_group in ('origin','evolution','ecosystem','qualification','business','governance')),
 display_order integer not null unique check(display_order>0)
);
create table avi_knowledge.role_profiles (
 id uuid primary key default gen_random_uuid(),
 code text not null unique check(code ~ '^[a-z0-9_]+$'),
 node_id uuid not null unique references avi_knowledge.nodes(id) on delete restrict,
 family_id uuid not null references avi_knowledge.role_families(id) on delete restrict,
 role_en text not null, role_ar text not null,
 definition_en text not null, definition_ar text not null,
 scope_note_en text not null, scope_note_ar text not null,
 earliest_origin_note text not null default 'Not established; no global first implied',
 status text not null default 'draft' check(status in ('draft','in_review','expert_approved','published','retired')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index avi_roles_family_idx on avi_knowledge.role_profiles(family_id);
create table avi_knowledge.role_titles (
 id uuid primary key default gen_random_uuid(),
 role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 title text not null,language_code text not null default 'en',
 locale_scope text not null,
 valid_from_year integer, valid_to_year integer,
 title_kind text not null check(title_kind in ('historical','modern_alias','translated','organizational')),
 source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
 attribution_note text not null,
 unique(role_id,title,locale_scope,title_kind),
 check(valid_to_year is null or valid_from_year is null or valid_to_year>=valid_from_year)
);
create index avi_role_titles_source_idx on avi_knowledge.role_titles(source_id);
create table avi_knowledge.role_functions (
 id uuid primary key default gen_random_uuid(),
 code text not null unique check(code ~ '^[a-z0-9_]+$'),
 name_en text not null,name_ar text not null,
 description_en text not null,description_ar text not null,
 function_class text not null check(function_class in ('technical','operational','safety','security','passenger','commercial','regulatory','information','training','management','environmental','logistics')),
 review_status text not null default 'draft' check(review_status in ('draft','source_checked','expert_approved'))
);
create table avi_knowledge.role_function_assignments (
 id uuid primary key default gen_random_uuid(),
 role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 function_id uuid not null references avi_knowledge.role_functions(id) on delete restrict,
 source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
 relationship_kind text not null check(relationship_kind in ('performs','oversees','coordinates','supports','historically_performed')),
 locale_scope text not null,
 period_from integer,period_to integer,
 explanation_en text not null, explanation_ar text not null,
 status text not null default 'source_checked' check(status in ('draft','source_checked','expert_approved')),
 unique(role_id,function_id,source_id,relationship_kind,locale_scope),
 check(period_to is null or period_from is null or period_to>=period_from)
);
create index avi_role_function_by_func_idx on avi_knowledge.role_function_assignments(function_id);
create index avi_role_function_source_idx on avi_knowledge.role_function_assignments(source_id);

create table avi_knowledge.role_needs (
 id uuid primary key default gen_random_uuid(),
 code text not null unique check(code ~ '^[a-z0-9_]+$'),
 need_en text not null,need_ar text not null,
 rationale_en text not null,rationale_ar text not null,
 need_class text not null check(need_class in ('scientific','technical','operational','safety','security','commercial','regulatory','logistics','passenger','information','environmental','training','financial'))
);
create table avi_knowledge.role_need_links (
 id uuid primary key default gen_random_uuid(),
 role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 need_id uuid not null references avi_knowledge.role_needs(id) on delete restrict,
 source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
 link_kind text not null check(link_kind in ('role_addresses','role_emergence_context','expanded_responsibility','regulatory_driver')),
 historical_claim_level text not null check(historical_claim_level in ('documented_context','documented_cause','analytical_framework')),
 explanation_en text not null,explanation_ar text not null,
 locale_scope text not null,
 status text not null default 'source_checked' check(status in ('draft','source_checked','expert_approved')),
 unique(role_id,need_id,link_kind,source_id,locale_scope)
);
create index avi_need_role_idx on avi_knowledge.role_need_links(need_id);
create index avi_need_source_idx on avi_knowledge.role_need_links(source_id);

create table avi_knowledge.role_milestones (
 id uuid primary key default gen_random_uuid(),
 event_key text not null unique check(event_key ~ '^[a-z0-9_]+$'),
 event_en text not null,event_ar text not null,
 details_en text not null,details_ar text not null,
 milestone_kind text not null check(milestone_kind in ('practice','technology','commercialization','title','specialization','coordination','regulation','training','safety','security','institutionalization','economic_change','workforce_change')),
 date_precision text not null check(date_precision in ('unknown','approximate','year','range','day')),
 year_from integer,year_to integer,
 exact_date date,
 geographic_scope text not null,
 evidence_scope text not null check(evidence_scope in ('historical_example','documented_first_in_named_context','specific_regulatory_milestone','illustrative_non_first')),
 never_global_first boolean not null default true,
 review_status text not null default 'source_checked' check(review_status in ('draft','source_checked','expert_approved')),
 created_at timestamptz not null default now(),
 check (year_to is null or year_from is null or year_to>=year_from),
 check (date_precision not in ('year','range','approximate','day') or year_from is not null),
 check (date_precision<>'day' or exact_date is not null),
 check(evidence_scope <> 'documented_first_in_named_context' or geographic_scope <> 'global unspecified')
);
create table avi_knowledge.role_milestone_sources (
 milestone_id uuid not null references avi_knowledge.role_milestones(id) on delete restrict,
 source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
 support_kind text not null check(support_kind in ('direct','context','contradiction')),
 locator text not null,
 review_note text,
 primary key(milestone_id,source_id)
);
create index avi_role_milestone_sources_source_idx on avi_knowledge.role_milestone_sources(source_id);
create table avi_knowledge.role_milestone_roles (
 milestone_id uuid not null references avi_knowledge.role_milestones(id) on delete restrict,
 role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 relation_kind text not null check(relation_kind in ('demonstrates_work','shows_specialization','names_role','regulates_role','changes_conditions','creates_demand_context','enables_coordination')),
 source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
 explanation_en text not null,explanation_ar text not null,
 primary key(milestone_id,role_id,relation_kind)
);
create index avi_role_milestone_role_idx on avi_knowledge.role_milestone_roles(role_id);
create index avi_role_milestone_role_source_idx on avi_knowledge.role_milestone_roles(source_id);

create table avi_knowledge.role_axis_evidence (
 id uuid primary key default gen_random_uuid(),
 role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 axis_code text not null references avi_knowledge.role_axes(code) on delete restrict,
 source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
 observation_en text not null, observation_ar text not null,
 locale_scope text not null,
 period_from integer,period_to integer,
 evidence_kind text not null check(evidence_kind in ('historical_record','current_framework','contextual_relation','historical_uncertainty')),
 review_status text not null default 'source_checked' check(review_status in ('draft','source_checked','expert_approved')),
 unique(role_id,axis_code,source_id,locale_scope),
 check(period_to is null or period_from is null or period_to>=period_from)
);
create index avi_role_axis_src_idx on avi_knowledge.role_axis_evidence(source_id);
create index avi_role_axis_code_idx on avi_knowledge.role_axis_evidence(axis_code);

create table avi_knowledge.role_interdependencies (
 id uuid primary key default gen_random_uuid(),
 from_role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 to_role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
 dimension_code text not null references avi_knowledge.role_axes(code) on delete restrict,
 relation_kind text not null check(relation_kind in ('coordinates_with','provides_information_to','receives_information_from','supplies_service_to','depends_on','supervises','regulates','influences','shares_safety_responsibility','handoff_to')),
 scope_text text not null,
 scenario_en text not null,scenario_ar text not null,
 evidence_strength text not null check(evidence_strength in ('direct','general_guidance','analytical_scenario')),
 review_status text not null default 'source_checked' check(review_status in ('draft','source_checked','expert_approved')),
 unique(from_role_id,to_role_id,relation_kind,scope_text),
 check(from_role_id<>to_role_id)
);
create index avi_role_interdep_to_idx on avi_knowledge.role_interdependencies(to_role_id);
create index avi_role_interdep_source_idx on avi_knowledge.role_interdependencies(source_id);

create table avi_knowledge.role_job_bridges (
 role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 job_id uuid not null references public.am_job_roles(id) on delete restrict,
 match_kind text not null check(match_kind in ('exact_scope','broader','narrower','related')),
 rationale text not null,
 primary key(role_id,job_id)
);
create index avi_role_job_bridge_job_idx on avi_knowledge.role_job_bridges(job_id);
create table avi_knowledge.role_course_bridges (
 role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 course_id uuid not null references public.am_learning_courses(id) on delete restrict,
 learning_stage text not null check(learning_stage in ('foundation','orientation','specialization','practical','assessment')),
 rationale text not null,
 primary key(role_id,course_id,learning_stage)
);
create index avi_role_course_bridge_course_idx on avi_knowledge.role_course_bridges(course_id);
create table avi_knowledge.role_reviews (
 id uuid primary key default gen_random_uuid(),
 role_id uuid not null references avi_knowledge.role_profiles(id) on delete restrict,
 review_type text not null check(review_type in ('historian','subject_expert','operational_expert','regulatory','instructional','language')),
 verdict text not null check(verdict in ('pending','changes_required','approved')),
 reviewer_identity text,
 notes text not null,
 reviewed_at timestamptz not null default now(),
 check(verdict <> 'approved' or length(trim(coalesce(reviewer_identity,'')))>=3)
);
create index avi_role_reviews_role_idx on avi_knowledge.role_reviews(role_id);

create view avi_knowledge.role_readiness WITH (security_invoker=true) as
select p.id,p.code,p.role_en,p.role_ar,p.status,
(select count(distinct a.axis_code)::int from avi_knowledge.role_axis_evidence a where a.role_id=p.id) dimensions_covered,
(select count(*)::int from avi_knowledge.role_milestone_roles mr join avi_knowledge.role_milestones m on m.id=mr.milestone_id where mr.role_id=p.id and exists(select 1 from avi_knowledge.role_milestone_sources ms where ms.milestone_id=m.id and ms.support_kind='direct')) sourced_milestones,
(select count(*)::int from avi_knowledge.role_function_assignments f where f.role_id=p.id) sourced_functions,
(select count(*)::int from avi_knowledge.role_need_links n where n.role_id=p.id) sourced_needs,
(select count(*)::int from avi_knowledge.role_interdependencies d where d.from_role_id=p.id or d.to_role_id=p.id) cross_role_links,
(select count(*)::int from avi_knowledge.role_reviews r where r.role_id=p.id and r.verdict='approved' and r.review_type='historian') historian_approvals,
(select count(*)::int from avi_knowledge.role_reviews r where r.role_id=p.id and r.verdict='approved' and r.review_type='operational_expert') operational_approvals
from avi_knowledge.role_profiles p;

create function avi_knowledge.guard_role_release()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
declare m integer; f integer; n integer; a integer; historian integer; expert integer; latest_bad integer;
begin
  if new.status not in ('expert_approved','published') then return new; end if;
  select count(*) into m from avi_knowledge.role_milestone_roles mr join avi_knowledge.role_milestones em on em.id=mr.milestone_id
   where mr.role_id=new.id and em.review_status='expert_approved'
    and exists(select 1 from avi_knowledge.role_milestone_sources s where s.milestone_id=em.id and s.support_kind='direct');
  select count(*) into f from avi_knowledge.role_function_assignments where role_id=new.id and status='expert_approved';
  select count(*) into n from avi_knowledge.role_need_links where role_id=new.id and status='expert_approved';
  select count(distinct axis_code) into a from avi_knowledge.role_axis_evidence where role_id=new.id and review_status='expert_approved';
  select count(*) into historian from avi_knowledge.role_reviews where role_id=new.id and review_type='historian' and verdict='approved';
  select count(*) into expert from avi_knowledge.role_reviews where role_id=new.id and review_type='operational_expert' and verdict='approved';
  if m<1 or f<1 or n<1 or a<3 or historian<1 or expert<1 then
    raise exception 'Role approval blocked: milestone %, function %, need %, dimensions %, historian %, operations %',m,f,n,a,historian,expert;
  end if;
  return new;
end $$;
revoke all on function avi_knowledge.guard_role_release() from public,anon,authenticated;
create trigger trg_role_release before update of status on avi_knowledge.role_profiles for each row execute function avi_knowledge.guard_role_release();

do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname='avi_knowledge' loop
    execute format('alter table avi_knowledge.%I enable row level security',t.tablename);
    execute format('revoke all on avi_knowledge.%I from public,anon,authenticated',t.tablename);
  end loop;
end $$;
revoke all on avi_knowledge.role_readiness from public,anon,authenticated;
grant select on all tables in schema avi_knowledge to service_role;
grant select on avi_knowledge.role_readiness to service_role;
comment on view avi_knowledge.role_readiness is 'Internal editorial coverage report only; NOT a certification score.';
