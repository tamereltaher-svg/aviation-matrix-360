
-- Registration governance: only authorized admins decide account and learner activation.
create table if not exists fr_edu.account_requests (
 user_id uuid primary key references auth.users(id) on delete cascade,
 account_type text not null check (account_type in ('guardian','adult_student','teacher')),
 approval_status text not null default 'pending' check (approval_status in ('pending','active','rejected','suspended')),
 requested_at timestamptz not null default now(),
 decided_at timestamptz,
 decided_by uuid references auth.users(id),
 admin_note text check (admin_note is null or length(admin_note)<=500),
 check (
  (approval_status='pending' and decided_at is null and decided_by is null)
  or (approval_status<>'pending' and decided_at is not null and decided_by is not null)
 )
);
create index if not exists fr_account_requests_queue_idx
 on fr_edu.account_requests(approval_status,requested_at desc);
create index if not exists fr_account_requests_decided_by_idx
 on fr_edu.account_requests(decided_by);

alter table fr_edu.learners
 add column if not exists approval_status text not null default 'pending'
 check (approval_status in ('pending','active','rejected','suspended'));
alter table fr_edu.learners
 add column if not exists decided_at timestamptz;
alter table fr_edu.learners
 add column if not exists decided_by uuid references auth.users(id);
alter table fr_edu.learners
 add column if not exists admin_note text
 check (admin_note is null or length(admin_note)<=500);
create index if not exists fr_learners_approval_queue_idx
 on fr_edu.learners(approval_status,created_at desc);
create index if not exists fr_learners_decided_by_idx on fr_edu.learners(decided_by);

create table if not exists fr_edu.registration_decisions (
 id bigint generated always as identity primary key,
 target_type text not null check(target_type in ('account','learner')),
 account_user_id uuid references auth.users(id),
 learner_id uuid references fr_edu.learners(id) on delete set null,
 action text not null check(action in ('approve','reject','suspend','reactivate')),
 decided_by uuid not null references auth.users(id),
 note text check(note is null or length(note)<=500),
 decided_at timestamptz not null default now(),
 check ((target_type='account' and account_user_id is not null)
    or (target_type='learner' and learner_id is not null))
);
create index if not exists fr_registration_decisions_admin_idx
 on fr_edu.registration_decisions(decided_by,decided_at desc);
create index if not exists fr_registration_decisions_account_idx
 on fr_edu.registration_decisions(account_user_id);
create index if not exists fr_registration_decisions_learner_idx
 on fr_edu.registration_decisions(learner_id);

alter table fr_edu.account_requests enable row level security;
alter table fr_edu.registration_decisions enable row level security;
revoke all on table fr_edu.account_requests,fr_edu.registration_decisions from public,anon,authenticated;
revoke all on sequence fr_edu.registration_decisions_id_seq from public,anon,authenticated;
grant select,insert,update,delete on fr_edu.account_requests,fr_edu.registration_decisions to service_role;
grant usage,select on sequence fr_edu.registration_decisions_id_seq to service_role;
