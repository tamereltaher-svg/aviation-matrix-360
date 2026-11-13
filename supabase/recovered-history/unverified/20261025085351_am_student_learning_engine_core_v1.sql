
create table if not exists public.am_student_auth_bindings(
  auth_user_id uuid primary key references auth.users(id) on delete restrict,
  candidate_id uuid not null unique references public.am_candidate_records(id) on delete restrict,
  binding_state text not null default 'verified' check(binding_state in ('verified','revoked')),
  verified_at timestamptz not null default now(),
  verified_by text not null check(length(btrim(verified_by))>=3),
  reason text not null default 'Independent identity verification',
  updated_at timestamptz not null default now()
);
comment on table public.am_student_auth_bindings is 'Admin-verified Supabase-auth-to-candidate mapping. Never infer mapping from email, editable JWT user_metadata, or unverified lead linkage.';

create table if not exists public.am_student_learning_rules(
 course_id uuid primary key references public.am_learning_courses(id) on delete restrict,
 enabled boolean not null default false,
 passing_percent numeric(5,2),
 max_attempts integer,
 require_order boolean not null default true,
 gate_prerequisite_courses boolean not null default true,
 reviewer_id text,
 reviewer_note text,
 revision_no integer not null default 1 check(revision_no>0),
 updated_at timestamptz not null default now(),
 check(passing_percent is null or (passing_percent>=1 and passing_percent<=100)),
 check(max_attempts is null or (max_attempts between 1 and 10)),
 check(not enabled or (passing_percent is not null and max_attempts is not null and length(btrim(coalesce(reviewer_id,'')))>=3))
);
comment on table public.am_student_learning_rules is 'Pedagogical passing/retake policy. All initial rows are disabled pending human decision; do not invent thresholds.';

create table if not exists public.am_student_lesson_progress(
 id uuid primary key default gen_random_uuid(),
 enrollment_id uuid not null references public.am_candidate_learning_enrollments(id) on delete restrict,
 lesson_id uuid not null references avi_knowledge.lesson_versions(id) on delete restrict,
 progress_state text not null default 'in_progress' check(progress_state in ('in_progress','completed','failed')),
 attempts_used integer not null default 0 check(attempts_used>=0),
 last_score numeric(5,2) check(last_score between 0 and 100),
 best_score numeric(5,2) check(best_score between 0 and 100),
 started_at timestamptz not null default now(),
 completed_at timestamptz,
 updated_at timestamptz not null default now(),
 unique(enrollment_id,lesson_id),
 check(progress_state<>'completed' or (completed_at is not null and best_score is not null))
);
create index if not exists am_student_progress_enrollment_state_idx on public.am_student_lesson_progress(enrollment_id,progress_state);
create index if not exists am_student_progress_lesson_idx on public.am_student_lesson_progress(lesson_id);

create table if not exists public.am_student_lesson_attempts(
 id uuid primary key default gen_random_uuid(),
 progress_id uuid not null references public.am_student_lesson_progress(id) on delete restrict,
 attempt_no integer not null check(attempt_no>=1),
 scored_percent numeric(5,2) not null check(scored_percent between 0 and 100),
 correct_count integer not null check(correct_count>=0),
 question_count integer not null check(question_count>=1),
 passed boolean not null,
 answers jsonb not null check(jsonb_typeof(answers)='array'),
 created_at timestamptz not null default now(),
 unique(progress_id,attempt_no),
 check(correct_count<=question_count)
);
create index if not exists am_student_lesson_attempts_created_idx on public.am_student_lesson_attempts(created_at);

create table if not exists public.am_student_learning_events(
 id uuid primary key default gen_random_uuid(),
 auth_user_id uuid not null references auth.users(id) on delete restrict,
 enrollment_id uuid not null references public.am_candidate_learning_enrollments(id) on delete restrict,
 lesson_id uuid references avi_knowledge.lesson_versions(id) on delete restrict,
 event_type text not null check(event_type in ('course_enrolled','lesson_opened','lesson_submitted','lesson_passed','lesson_failed','course_completed')),
 event_detail jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 check(jsonb_typeof(event_detail)='object')
);
create index if not exists am_student_events_user_created_idx on public.am_student_learning_events(auth_user_id,created_at desc);
create index if not exists am_student_events_enrollment_idx on public.am_student_learning_events(enrollment_id);

alter table public.am_student_auth_bindings enable row level security;
alter table public.am_student_learning_rules enable row level security;
alter table public.am_student_lesson_progress enable row level security;
alter table public.am_student_lesson_attempts enable row level security;
alter table public.am_student_learning_events enable row level security;

revoke all on public.am_student_auth_bindings,public.am_student_learning_rules,public.am_student_lesson_progress,public.am_student_lesson_attempts,public.am_student_learning_events from public,anon,authenticated;
grant select,insert,update on public.am_student_auth_bindings,public.am_student_learning_rules,public.am_student_lesson_progress,public.am_student_lesson_attempts to service_role;
grant select,insert on public.am_student_learning_events to service_role;

-- Explicitly block accidental edits of append-only activity and attempt history.
create or replace function public.am_student_reject_history_mutation()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
 raise exception 'Student activity/attempt records are immutable. Record a new event instead.' using errcode='23514';
end $$;
revoke all on function public.am_student_reject_history_mutation() from public,anon,authenticated;
create trigger am_student_attempts_immutable before update or delete on public.am_student_lesson_attempts
for each row execute function public.am_student_reject_history_mutation();
create trigger am_student_events_immutable before update or delete on public.am_student_learning_events
for each row execute function public.am_student_reject_history_mutation();

create or replace function public.am_student_guard_disabled_rules()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
 if new.enabled and
 (not exists(select 1 from public.am_learning_courses c where c.id=new.course_id and c.status='active')
  or not exists(select 1 from avi_knowledge.course_lesson_links l where l.course_id=new.course_id))
 then
  raise exception 'Cannot enable an unreleased or empty student course rule.';
 end if;
 return new;
end $$;
revoke all on function public.am_student_guard_disabled_rules() from public,anon,authenticated;
create trigger am_student_rule_activation_guard before insert or update of enabled,course_id on public.am_student_learning_rules
for each row execute function public.am_student_guard_disabled_rules();
