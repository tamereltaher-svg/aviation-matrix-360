create extension if not exists pgcrypto;

create table if not exists am_candidate_lifetime_events (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references am_candidate_records(id) on delete cascade,
  person_id uuid not null references am_persons(id) on delete cascade,
  event_code text not null,
  event_domain text not null default 'lifetime',
  source_system text not null default 'aviation_matrix',
  source_table text,
  source_id uuid,
  title text not null,
  detail text,
  payload jsonb not null default '{}'::jsonb,
  evidence_id uuid references am_candidate_evidence(id) on delete set null,
  occurred_at timestamptz not null default now(),
  recorded_at timestamptz not null default now(),
  recorded_by uuid,
  integrity_hash text not null
);

create index if not exists idx_am_candidate_lifetime_events_candidate_time on am_candidate_lifetime_events(candidate_id, occurred_at desc);
create index if not exists idx_am_candidate_lifetime_events_person_time on am_candidate_lifetime_events(person_id, occurred_at desc);
create index if not exists idx_am_candidate_lifetime_events_code on am_candidate_lifetime_events(event_code);

create table if not exists am_candidate_current_state (
  candidate_id uuid primary key references am_candidate_records(id) on delete cascade,
  person_id uuid not null references am_persons(id) on delete cascade,
  lifecycle_stage text not null default 'applicant',
  qualification_status text not null default 'unassessed',
  readiness_status text not null default 'not_calculated',
  english_level text,
  computer_level text,
  current_career_code text,
  current_career_fit numeric(6,2),
  active_gap_count integer not null default 0,
  active_course_count integer not null default 0,
  valid_credential_count integer not null default 0,
  latest_assessment_at timestamptz,
  latest_training_at timestamptz,
  latest_exam_at timestamptz,
  latest_credential_at timestamptz,
  state_json jsonb not null default '{}'::jsonb,
  recalculated_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_am_candidate_current_state_person on am_candidate_current_state(person_id);
create index if not exists idx_am_candidate_current_state_status on am_candidate_current_state(qualification_status, readiness_status);

create table if not exists am_candidate_lifetime_snapshots (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references am_candidate_records(id) on delete cascade,
  person_id uuid not null references am_persons(id) on delete cascade,
  snapshot_type text not null default 'current_state',
  snapshot_version integer not null default 1,
  payload jsonb not null,
  captured_at timestamptz not null default now(),
  captured_by uuid,
  integrity_hash text not null
);

create index if not exists idx_am_candidate_lifetime_snapshots_candidate_time on am_candidate_lifetime_snapshots(candidate_id, captured_at desc);

create or replace function am_lifetime_integrity_hash(p_candidate_id uuid, p_person_id uuid, p_code text, p_payload jsonb, p_when timestamptz)
returns text
language sql
immutable
as $$
  select encode(digest(coalesce(p_candidate_id::text,'') || '|' || coalesce(p_person_id::text,'') || '|' || coalesce(p_code,'') || '|' || coalesce(p_payload::text,'{}') || '|' || coalesce(p_when::text,''), 'sha256'),'hex');
$$;

create or replace function am_append_candidate_lifetime_event(
  p_candidate_id uuid,
  p_event_code text,
  p_event_domain text,
  p_title text,
  p_detail text default null,
  p_payload jsonb default '{}'::jsonb,
  p_source_system text default 'aviation_matrix',
  p_source_table text default null,
  p_source_id uuid default null,
  p_evidence_id uuid default null,
  p_occurred_at timestamptz default now(),
  p_recorded_by uuid default null
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_person_id uuid;
  v_id uuid := gen_random_uuid();
  v_hash text;
begin
  select person_id into v_person_id from am_candidate_records where id=p_candidate_id;
  if v_person_id is null then raise exception 'candidate_not_found'; end if;
  v_hash := am_lifetime_integrity_hash(p_candidate_id,v_person_id,p_event_code,coalesce(p_payload,'{}'::jsonb),coalesce(p_occurred_at,now()));
  insert into am_candidate_lifetime_events(id,candidate_id,person_id,event_code,event_domain,source_system,source_table,source_id,title,detail,payload,evidence_id,occurred_at,recorded_by,integrity_hash)
  values(v_id,p_candidate_id,v_person_id,upper(trim(p_event_code)),coalesce(nullif(trim(p_event_domain),''),'lifetime'),coalesce(nullif(trim(p_source_system),''),'aviation_matrix'),p_source_table,p_source_id,p_title,p_detail,coalesce(p_payload,'{}'::jsonb),p_evidence_id,coalesce(p_occurred_at,now()),p_recorded_by,v_hash);
  return v_id;
end;
$$;

create or replace function am_capture_candidate_lifetime_snapshot(p_candidate_id uuid, p_snapshot_type text default 'current_state', p_captured_by uuid default null)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_state am_candidate_current_state%rowtype;
  v_person_id uuid;
  v_payload jsonb;
  v_version integer;
  v_id uuid := gen_random_uuid();
  v_hash text;
begin
  select * into v_state from am_candidate_current_state where candidate_id=p_candidate_id;
  if not found then raise exception 'current_state_not_found'; end if;
  v_person_id := v_state.person_id;
  v_payload := to_jsonb(v_state);
  select coalesce(max(snapshot_version),0)+1 into v_version from am_candidate_lifetime_snapshots where candidate_id=p_candidate_id and snapshot_type=coalesce(nullif(trim(p_snapshot_type),''),'current_state');
  v_hash := am_lifetime_integrity_hash(p_candidate_id,v_person_id,coalesce(nullif(trim(p_snapshot_type),''),'current_state'),v_payload,now());
  insert into am_candidate_lifetime_snapshots(id,candidate_id,person_id,snapshot_type,snapshot_version,payload,captured_by,integrity_hash)
  values(v_id,p_candidate_id,v_person_id,coalesce(nullif(trim(p_snapshot_type),''),'current_state'),v_version,v_payload,p_captured_by,v_hash);
  return v_id;
end;
$$;

create or replace function am_block_lifetime_history_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'lifetime_history_is_append_only';
end;
$$;

drop trigger if exists trg_am_candidate_lifetime_events_append_only on am_candidate_lifetime_events;
create trigger trg_am_candidate_lifetime_events_append_only
before update or delete on am_candidate_lifetime_events
for each row execute function am_block_lifetime_history_mutation();

drop trigger if exists trg_am_candidate_lifetime_snapshots_append_only on am_candidate_lifetime_snapshots;
create trigger trg_am_candidate_lifetime_snapshots_append_only
before update or delete on am_candidate_lifetime_snapshots
for each row execute function am_block_lifetime_history_mutation();

insert into am_candidate_current_state(candidate_id,person_id,lifecycle_stage)
select c.id,c.person_id,c.lifecycle_stage from am_candidate_records c
on conflict (candidate_id) do nothing;

insert into am_candidate_lifetime_events(candidate_id,person_id,event_code,event_domain,source_system,source_table,source_id,title,detail,payload,occurred_at,integrity_hash)
select c.id,c.person_id,'CANDIDATE_RECORD_CREATED','identity','aviation_matrix','am_candidate_records',c.id,'Candidate record created','Backfilled foundation event',jsonb_build_object('candidate_number',c.candidate_number,'lifecycle_stage',c.lifecycle_stage),c.created_at,
       am_lifetime_integrity_hash(c.id,c.person_id,'CANDIDATE_RECORD_CREATED',jsonb_build_object('candidate_number',c.candidate_number,'lifecycle_stage',c.lifecycle_stage),c.created_at)
from am_candidate_records c
where not exists (select 1 from am_candidate_lifetime_events e where e.candidate_id=c.id and e.event_code='CANDIDATE_RECORD_CREATED');

create or replace view am_candidate_lifetime_summary as
select
  c.id as candidate_id,
  c.candidate_number,
  c.lifecycle_stage,
  c.activation_status,
  p.id as person_id,
  p.full_name,
  p.email,
  p.mobile,
  p.current_city,
  p.preferred_language,
  s.qualification_status,
  s.readiness_status,
  s.english_level,
  s.computer_level,
  s.current_career_code,
  s.current_career_fit,
  s.active_gap_count,
  s.active_course_count,
  s.valid_credential_count,
  s.recalculated_at,
  (select count(*) from am_candidate_lifetime_events e where e.candidate_id=c.id) as lifetime_event_count,
  (select count(*) from am_candidate_evidence ev where ev.candidate_id=c.id) as evidence_count,
  (select max(e.occurred_at) from am_candidate_lifetime_events e where e.candidate_id=c.id) as last_lifetime_event_at,
  c.created_at,
  c.updated_at
from am_candidate_records c
join am_persons p on p.id=c.person_id
left join am_candidate_current_state s on s.candidate_id=c.id;
