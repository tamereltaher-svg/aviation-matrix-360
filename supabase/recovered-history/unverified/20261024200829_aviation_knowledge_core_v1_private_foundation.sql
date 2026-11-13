
create schema avi_knowledge;
revoke all on schema avi_knowledge from public, anon, authenticated;
grant usage on schema avi_knowledge to service_role;

create table avi_knowledge.sources (
  id uuid primary key default gen_random_uuid(),
  source_key text not null unique check (source_key ~ '^[a-z0-9_]+$'),
  publisher text not null,
  title text not null,
  source_url text not null unique check (source_url ~ '^https://'),
  source_type text not null check (source_type in ('museum','government','primary_document','academic','regulator','other')),
  language_code text not null default 'en',
  accessed_on date not null,
  rights_note text,
  created_at timestamptz not null default now()
);
create table avi_knowledge.nodes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9_]+$'),
  node_kind text not null check (node_kind in ('idea','observation','historical_event','person','scientific_concept','engineering_challenge','technology','system','industry_activity','role','process','regulation')),
  title_en text not null,
  title_ar text not null,
  summary_en text,
  summary_ar text,
  year_from integer,
  year_to integer,
  exact_date date,
  time_precision text not null default 'undated' check(time_precision in ('undated','approximate','year','range','day')),
  review_status text not null default 'draft' check(review_status in ('draft','source_checked','expert_approved')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint knowledge_date_range check (year_to is null or year_from is null or year_to >= year_from),
  constraint knowledge_day_date check (time_precision <> 'day' or exact_date is not null)
);
create table avi_knowledge.claims (
  id uuid primary key default gen_random_uuid(),
  claim_key text not null unique check (claim_key ~ '^[a-z0-9_]+$'),
  node_id uuid not null references avi_knowledge.nodes(id) on delete restrict,
  statement_en text not null,
  statement_ar text not null,
  claim_kind text not null check (claim_kind in ('historical','scientific','interpretive','pedagogical')),
  precision_note text,
  confidence text not null default 'medium' check (confidence in ('high','medium','low')),
  evidence_status text not null default 'draft' check(evidence_status in ('draft','source_checked','expert_approved','rejected')),
  publication_status text not null default 'blocked' check(publication_status in ('blocked','approved')),
  checked_on date,
  created_at timestamptz not null default now(),
  constraint only_expert_approved_can_publish check (publication_status <> 'approved' or evidence_status = 'expert_approved')
);
create table avi_knowledge.claim_sources (
  claim_id uuid not null references avi_knowledge.claims(id) on delete restrict,
  source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
  support_kind text not null check (support_kind in ('direct','context','contradiction')),
  locator text not null,
  review_note text,
  primary key (claim_id,source_id)
);
create table avi_knowledge.relationships (
  id uuid primary key default gen_random_uuid(),
  from_node_id uuid not null references avi_knowledge.nodes(id) on delete restrict,
  to_node_id uuid not null references avi_knowledge.nodes(id) on delete restrict,
  relationship_type text not null check (relationship_type in ('chronologically_precedes','inspired','studied','demonstrates','uses','depends_on','addresses','explains','historical_context','leads_to')),
  basis text not null check(basis in ('documented_historical','scientific_mechanism','pedagogical_navigation','interpretive')),
  explanation_en text not null,
  explanation_ar text not null,
  review_status text not null default 'draft' check (review_status in ('draft','source_checked','expert_approved')),
  created_at timestamptz not null default now(),
  constraint knowledge_no_self_edges check(from_node_id<>to_node_id),
  constraint knowledge_unique_relationship unique (from_node_id,to_node_id,relationship_type)
);
create table avi_knowledge.relationship_sources (
  relationship_id uuid not null references avi_knowledge.relationships(id) on delete restrict,
  source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
  support_kind text not null check (support_kind in ('direct','context','contradiction')),
  locator text not null,
  primary key(relationship_id,source_id)
);
create table avi_knowledge.journeys (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9_]+$'),
  title_en text not null,
  title_ar text not null,
  description_en text,
  description_ar text,
  release_version integer not null default 1,
  status text not null default 'draft' check(status in ('draft','in_review','published','retired')),
  created_at timestamptz not null default now()
);
create table avi_knowledge.journey_steps (
  id uuid primary key default gen_random_uuid(),
  journey_id uuid not null references avi_knowledge.journeys(id) on delete restrict,
  step_no integer not null check(step_no > 0),
  focus_node_id uuid not null references avi_knowledge.nodes(id) on delete restrict,
  title_en text not null,
  title_ar text not null,
  question_en text,
  question_ar text,
  step_kind text not null default 'discovery' check(step_kind in ('discovery','historical','scientific','connection','assessment')),
  status text not null default 'draft' check(status in ('draft','reviewed','published')),
  unique(journey_id,step_no)
);
create table avi_knowledge.journey_step_claims (
  journey_step_id uuid not null references avi_knowledge.journey_steps(id) on delete restrict,
  claim_id uuid not null references avi_knowledge.claims(id) on delete restrict,
  primary key(journey_step_id,claim_id)
);
create table avi_knowledge.course_node_links (
  course_id uuid not null references public.am_learning_courses(id) on delete restrict,
  node_id uuid not null references avi_knowledge.nodes(id) on delete restrict,
  learning_role text not null check (learning_role in ('prerequisite','core','application','extension','assessment')),
  notes text,
  primary key(course_id,node_id,learning_role)
);
create index idx_avi_claims_node on avi_knowledge.claims(node_id);
create index idx_avi_rel_to on avi_knowledge.relationships(to_node_id);
create index idx_avi_rel_from on avi_knowledge.relationships(from_node_id);
create index idx_avi_steps_node on avi_knowledge.journey_steps(focus_node_id);
create index idx_avi_step_claims_claim on avi_knowledge.journey_step_claims(claim_id);
create index idx_avi_course_nodes_node on avi_knowledge.course_node_links(node_id);
create index idx_avi_claim_sources_source on avi_knowledge.claim_sources(source_id);
create index idx_avi_relationship_sources_source on avi_knowledge.relationship_sources(source_id);
do $$
declare rec record;
begin
  for rec in select tablename from pg_tables where schemaname='avi_knowledge' loop
    execute format('alter table avi_knowledge.%I enable row level security',rec.tablename);
    execute format('revoke all on avi_knowledge.%I from public,anon,authenticated',rec.tablename);
  end loop;
end $$;
grant select on all tables in schema avi_knowledge to service_role;
alter default privileges in schema avi_knowledge revoke all on tables from public,anon,authenticated;
comment on schema avi_knowledge is 'AVIATION MATRIX Knowledge Core V1: private, source-traced draft graph. No public Data API exposure.';
