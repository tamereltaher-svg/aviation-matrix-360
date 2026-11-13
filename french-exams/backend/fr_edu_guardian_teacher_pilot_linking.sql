-- Pilot guardian-managed learner records; no child email/password or birth date.
alter table fr_edu.assessments add column if not exists pilot_enabled boolean not null default false;
update fr_edu.assessments set pilot_enabled=true where code like 'fr.%' and code <> 'fr.grammar.conjugaison.v1';

create table if not exists fr_edu.learners (
 id uuid primary key default gen_random_uuid(),
 guardian_user_id uuid not null references auth.users(id) on delete cascade,
 display_name text not null check(length(btrim(display_name)) between 1 and 60),
 grade_code text references fr_edu.grades(code),
 consent_version text not null,
 consent_at timestamptz not null default now(),
 consent_revoked_at timestamptz,
 created_at timestamptz not null default now(),
 unique(id,guardian_user_id),
 check(consent_version <> '')
);
create index if not exists fr_learners_guardian_idx on fr_edu.learners(guardian_user_id);

create table if not exists fr_edu.teacher_codes (
 teacher_user_id uuid primary key references auth.users(id) on delete cascade,
 share_code text not null unique check(length(share_code) >= 8),
 created_at timestamptz not null default now()
);
create table if not exists fr_edu.teacher_learner_access (
 teacher_user_id uuid not null references auth.users(id) on delete cascade,
 learner_id uuid not null references fr_edu.learners(id) on delete cascade,
 granted_by_guardian_id uuid not null references auth.users(id),
 granted_at timestamptz not null default now(),
 revoked_at timestamptz,
 primary key(teacher_user_id,learner_id)
);
create index if not exists fr_teacher_access_learner_idx on fr_edu.teacher_learner_access(learner_id);

alter table fr_edu.attempts add column if not exists learner_id uuid;
alter table fr_edu.attempts add constraint attempts_learner_guardian_link_fkey
 foreign key (learner_id,student_user_id) references fr_edu.learners(id,guardian_user_id);
create index if not exists fr_attempts_learner_idx on fr_edu.attempts(learner_id,started_at desc);
alter table fr_edu.learners enable row level security;
alter table fr_edu.teacher_codes enable row level security;
alter table fr_edu.teacher_learner_access enable row level security;
revoke all on fr_edu.learners,fr_edu.teacher_codes,fr_edu.teacher_learner_access from public,anon,authenticated;
grant select,insert,update,delete on fr_edu.learners,fr_edu.teacher_codes,fr_edu.teacher_learner_access to service_role;