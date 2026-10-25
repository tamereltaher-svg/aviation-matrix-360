
-- Knowledge Core V1.1: add lesson authoring and evidence-based release controls.
-- Strictly additive: do not alter any public.* or assessment.* data.
create table avi_knowledge.source_verifications (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references avi_knowledge.sources(id) on delete restrict,
  checked_on date not null,
  method text not null check (method in ('publisher_page_review','indexed_publisher_content','document_review','expert_review')),
  reviewer_kind text not null check (reviewer_kind in ('assistant_research','human_editor','subject_expert')),
  outcome text not null check (outcome in ('corroborated','partial','needs_review','contradicted')),
  scope text not null,
  evidence_summary text not null,
  reviewed_by text,
  created_at timestamptz not null default now(),
  unique(source_id,checked_on,method,scope),
  check ((reviewer_kind='assistant_research' and reviewed_by is null) or (reviewer_kind <> 'assistant_research' and length(trim(coalesce(reviewed_by,''))) >= 3))
);
create table avi_knowledge.lesson_versions (
  id uuid primary key default gen_random_uuid(),
  journey_step_id uuid not null references avi_knowledge.journey_steps(id) on delete restrict,
  version_no integer not null check(version_no >= 1),
  title_en text not null,
  title_ar text not null,
  opening_question_en text not null,
  opening_question_ar text not null,
  learning_objective_en text not null,
  learning_objective_ar text not null,
  estimated_minutes integer not null check(estimated_minutes between 1 and 180),
  status text not null default 'draft' check(status in ('draft','in_review','expert_approved','published','retired')),
  created_at timestamptz not null default now(),
  published_at timestamptz,
  unique(journey_step_id,version_no),
  unique(id,journey_step_id),
  check(status <> 'published' or published_at is not null)
);
create table avi_knowledge.lesson_blocks (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references avi_knowledge.lesson_versions(id) on delete restrict,
  position integer not null check(position > 0),
  block_kind text not null check(block_kind in ('opening','evidence','connection','uncertainty','reflection','takeaway','context')),
  heading_en text,
  heading_ar text,
  body_en text not null,
  body_ar text not null,
  scope_note_en text,
  scope_note_ar text,
  editorial_status text not null default 'draft' check(editorial_status in ('draft','source_checked','expert_approved')),
  unique(lesson_id,position),
  unique(id,lesson_id)
);
create table avi_knowledge.lesson_block_claims (
  block_id uuid not null references avi_knowledge.lesson_blocks(id) on delete restrict,
  claim_id uuid not null references avi_knowledge.claims(id) on delete restrict,
  usage_role text not null check(usage_role in ('states','contextualizes','qualifies','contrasts')),
  primary key(block_id,claim_id)
);
create table avi_knowledge.lesson_block_relationships (
  block_id uuid not null references avi_knowledge.lesson_blocks(id) on delete restrict,
  relationship_id uuid not null references avi_knowledge.relationships(id) on delete restrict,
  usage_role text not null check(usage_role in ('explains','illustrates','qualifies')),
  primary key(block_id,relationship_id)
);
create table avi_knowledge.lesson_questions (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references avi_knowledge.lesson_versions(id) on delete restrict,
  question_code text not null check(question_code ~ '^[a-z0-9_]+$'),
  position integer not null check(position>0),
  question_type text not null default 'single_choice' check(question_type in ('single_choice')),
  stem_en text not null,
  stem_ar text not null,
  explanation_en text not null,
  explanation_ar text not null,
  editorial_status text not null default 'draft' check(editorial_status in ('draft','source_checked','expert_approved')),
  unique(lesson_id,position),
  unique(lesson_id,question_code)
);
create table avi_knowledge.lesson_question_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references avi_knowledge.lesson_questions(id) on delete restrict,
  position integer not null check(position>0),
  answer_en text not null,
  answer_ar text not null,
  is_correct boolean not null,
  feedback_en text not null,
  feedback_ar text not null,
  unique(question_id,position)
);
create unique index one_correct_answer_per_question on avi_knowledge.lesson_question_options(question_id) where is_correct;
create table avi_knowledge.lesson_question_claims (
  question_id uuid not null references avi_knowledge.lesson_questions(id) on delete restrict,
  claim_id uuid not null references avi_knowledge.claims(id) on delete restrict,
  primary key(question_id,claim_id)
);
create table avi_knowledge.lesson_reviews (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references avi_knowledge.lesson_versions(id) on delete restrict,
  review_kind text not null check(review_kind in ('source_research','subject_expert','instructional_design','language','safety')),
  verdict text not null check(verdict in ('pending','changes_required','approved')),
  reviewer_identity text,
  notes text not null,
  reviewed_at timestamptz not null default now(),
  check(verdict <> 'approved' or length(trim(coalesce(reviewer_identity,''))) >= 3)
);
create table avi_knowledge.course_lesson_links (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.am_learning_courses(id) on delete restrict,
  lesson_id uuid not null references avi_knowledge.lesson_versions(id) on delete restrict,
  module_code text not null,
  sequence_no integer not null check(sequence_no > 0),
  placement_kind text not null check(placement_kind in ('core','prerequisite','application','optional')),
  unique(course_id,lesson_id),
  unique(course_id,module_code,sequence_no)
);

create index avi_source_verifications_source_idx on avi_knowledge.source_verifications(source_id);
create index avi_lesson_blocks_lesson_idx on avi_knowledge.lesson_blocks(lesson_id);
create index avi_block_claims_claim_idx on avi_knowledge.lesson_block_claims(claim_id);
create index avi_block_rel_rel_idx on avi_knowledge.lesson_block_relationships(relationship_id);
create index avi_questions_lesson_idx on avi_knowledge.lesson_questions(lesson_id);
create index avi_options_question_idx on avi_knowledge.lesson_question_options(question_id);
create index avi_questions_claims_claim_idx on avi_knowledge.lesson_question_claims(claim_id);
create index avi_reviews_lesson_idx on avi_knowledge.lesson_reviews(lesson_id);
create index avi_course_lesson_lesson_idx on avi_knowledge.course_lesson_links(lesson_id);

-- Private editorial diagnostic; it is not exposed to anonymous or authenticated roles.
create view avi_knowledge.lesson_quality_dashboard
with (security_invoker = true)
as
select lv.id lesson_id, j.slug journey_slug, js.step_no, lv.version_no, lv.title_en,
       lv.status,
       (select count(*) from avi_knowledge.lesson_blocks b where b.lesson_id=lv.id)::int total_blocks,
       (select count(*) from avi_knowledge.lesson_questions q where q.lesson_id=lv.id)::int total_questions,
       (select count(*) from avi_knowledge.lesson_blocks b where b.lesson_id=lv.id and b.block_kind in ('evidence','connection','takeaway') and not exists
           (select 1 from avi_knowledge.lesson_block_claims bc where bc.block_id=b.id)
           and not exists(select 1 from avi_knowledge.lesson_block_relationships br where br.block_id=b.id)
       )::int unreferenced_fact_blocks,
       (select count(*) from avi_knowledge.lesson_question_options o join avi_knowledge.lesson_questions q on q.id=o.question_id where q.lesson_id=lv.id and o.is_correct)::int total_correct_options,
       (select count(*) from avi_knowledge.lesson_questions q where q.lesson_id=lv.id and (
             (select count(*) from avi_knowledge.lesson_question_options o where o.question_id=q.id)<2
             or (select count(*) from avi_knowledge.lesson_question_options o where o.question_id=q.id and o.is_correct)<>1
             or not exists(select 1 from avi_knowledge.lesson_question_claims qc where qc.question_id=q.id)
       ))::int invalid_questions,
       (select count(*) from avi_knowledge.lesson_reviews r where r.lesson_id=lv.id and r.review_kind='subject_expert' and r.verdict='approved')::int expert_approvals,
       (select count(*) from avi_knowledge.lesson_reviews r where r.lesson_id=lv.id and r.review_kind='instructional_design' and r.verdict='approved')::int instructional_approvals
from avi_knowledge.lesson_versions lv
join avi_knowledge.journey_steps js on js.id=lv.journey_step_id
join avi_knowledge.journeys j on j.id=js.journey_id;

-- Release gate: no lesson can be marked expert_approved or published without genuine expert & instructional reviews.
create function avi_knowledge.validate_lesson_release()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge
as $$
declare
  missing_block_evidence integer;
  bad_questions integer;
  unapproved_blocks integer;
  unapproved_questions integer;
  unapproved_claims integer;
  unapproved_edges integer;
begin
  if new.status not in ('expert_approved','published') then
     return new;
  end if;
  if not exists(select 1 from avi_knowledge.lesson_reviews r where r.lesson_id=new.id and r.review_kind='subject_expert' and r.verdict='approved')
     or not exists(select 1 from avi_knowledge.lesson_reviews r where r.lesson_id=new.id and r.review_kind='instructional_design' and r.verdict='approved') then
     raise exception 'Lesson release blocked: missing qualified expert and instructional design approvals.';
  end if;
  select count(*) into unapproved_blocks from avi_knowledge.lesson_blocks b where b.lesson_id=new.id and b.editorial_status<>'expert_approved';
  if unapproved_blocks>0 then raise exception 'Lesson release blocked: % unapproved blocks.',unapproved_blocks; end if;
  select count(*) into missing_block_evidence from avi_knowledge.lesson_blocks b where b.lesson_id=new.id and b.block_kind in ('evidence','connection','takeaway') and not exists(
     select 1 from avi_knowledge.lesson_block_claims x where x.block_id=b.id
  ) and not exists(
     select 1 from avi_knowledge.lesson_block_relationships x where x.block_id=b.id
  );
  if missing_block_evidence>0 then raise exception 'Lesson release blocked: factual blocks without evidence.'; end if;
  if not exists(select 1 from avi_knowledge.lesson_blocks where lesson_id=new.id) then raise exception 'Lesson release blocked: empty lesson.'; end if;
  select count(*) into bad_questions from avi_knowledge.lesson_questions q where q.lesson_id=new.id and
    ((select count(*) from avi_knowledge.lesson_question_options o where o.question_id=q.id)<2
    or (select count(*) from avi_knowledge.lesson_question_options o where o.question_id=q.id and o.is_correct)<>1
    or not exists(select 1 from avi_knowledge.lesson_question_claims qc where qc.question_id=q.id));
  if bad_questions>0 then raise exception 'Lesson release blocked: % invalid questions.',bad_questions; end if;
  if not exists(select 1 from avi_knowledge.lesson_questions where lesson_id=new.id) then raise exception 'Lesson release blocked: no knowledge checks.'; end if;
  select count(*) into unapproved_questions from avi_knowledge.lesson_questions q where q.lesson_id=new.id and q.editorial_status <> 'expert_approved';
  if unapproved_questions>0 then raise exception 'Lesson release blocked: unapproved questions.'; end if;
  select count(*) into unapproved_claims from avi_knowledge.claims c where
    c.id in (select bc.claim_id from avi_knowledge.lesson_block_claims bc join avi_knowledge.lesson_blocks b on bc.block_id=b.id where b.lesson_id=new.id
      union select qc.claim_id from avi_knowledge.lesson_question_claims qc join avi_knowledge.lesson_questions q on qc.question_id=q.id where q.lesson_id=new.id)
    and (c.evidence_status <> 'expert_approved' or c.publication_status <> 'approved' or not exists (
        select 1 from avi_knowledge.claim_sources cs where cs.claim_id=c.id and cs.support_kind='direct'));
  if unapproved_claims>0 then raise exception 'Lesson release blocked: unapproved or unsupported claims.'; end if;
  select count(*) into unapproved_edges from avi_knowledge.relationships r where
     r.id in (select br.relationship_id from avi_knowledge.lesson_block_relationships br join avi_knowledge.lesson_blocks b on b.id=br.block_id where b.lesson_id=new.id)
     and (r.review_status <> 'expert_approved' or not exists(select 1 from avi_knowledge.relationship_sources rs where rs.relationship_id=r.id));
  if unapproved_edges>0 then raise exception 'Lesson release blocked: unapproved relationships.'; end if;
  if new.status='published' and new.published_at is null then raise exception 'Published lesson must have a published_at timestamp.'; end if;
  return new;
end
$$;
revoke all on function avi_knowledge.validate_lesson_release() from public,anon,authenticated;
create trigger trg_validate_lesson_release
before update of status on avi_knowledge.lesson_versions
for each row when (new.status in ('expert_approved','published'))
execute function avi_knowledge.validate_lesson_release();

do $$
declare r record;
begin
  for r in select tablename from pg_tables where schemaname='avi_knowledge' loop
    execute format('alter table avi_knowledge.%I enable row level security',r.tablename);
    execute format('revoke all on avi_knowledge.%I from public,anon,authenticated',r.tablename);
  end loop;
end $$;
revoke all on avi_knowledge.lesson_quality_dashboard from public,anon,authenticated;
grant select on all tables in schema avi_knowledge to service_role;
grant select on avi_knowledge.lesson_quality_dashboard to service_role;
comment on view avi_knowledge.lesson_quality_dashboard is 'Private diagnostic only; does not constitute editorial approval.';
