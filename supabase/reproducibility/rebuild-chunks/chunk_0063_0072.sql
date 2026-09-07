-- BEGIN CANONICAL MIGRATION 0063 20260825140301 kam_activity_book_logo_lock_prep_v1
with bp as (
  select id from kids_brand_profiles where brand_code='KAM360' limit 1
)
insert into kids_brand_logo_rules (brand_profile_id, product_code, rule_code, rule_type, rule_text, is_active)
select bp.id, 'ACTIVITY_BOOK', v.rule_code, v.rule_type, v.rule_text, true
from bp
cross join (values
  ('LOCK_CANONICAL_ASSET','required','Use the approved canonical Activity Book logo asset; do not regenerate the logo inside AI artwork.'),
  ('NO_CHARACTER_REDRAW','forbidden','If Ava or Ben appear in the approved Activity Book logo, do not redraw, replace, or reinterpret them.'),
  ('NO_DISTORTION','forbidden','Do not stretch, skew, crop through, or distort the Activity Book logo badge.'),
  ('NO_RANDOM_RECOLOR','forbidden','Do not recolor individual Activity Book logo elements outside approved variants.'),
  ('UNIFORM_SCALE_ONLY','allowed','Uniform scaling is allowed while preserving proportions.')
) as v(rule_code, rule_type, rule_text)
where not exists (
  select 1 from kids_brand_logo_rules r
  where r.brand_profile_id=bp.id and r.product_code='ACTIVITY_BOOK' and r.rule_code=v.rule_code
);

with bp as (
  select id from kids_brand_profiles where brand_code='KAM360' limit 1
)
insert into kids_brand_placement_rules (
  brand_profile_id, product_code, placement_code, placement_name,
  is_required, safe_area_rule, notes
)
select bp.id, 'ACTIVITY_BOOK', v.placement_code, v.placement_name,
       v.is_required, v.safe_area_rule, v.notes
from bp
cross join (values
  ('FRONT_COVER','Front Cover',true,'Use top-center or upper third with clear space around full badge.','Primary Activity Book cover placement.'),
  ('BACK_COVER','Back Cover',false,'Use as a smaller series/brand mark; keep clear of barcode and legal blocks.','Secondary placement.'),
  ('INTERIOR_TITLE','Interior Title/Copyright',false,'Optional small mark only; avoid repeating on every page.','Interior placement.'),
  ('STORE_THUMBNAIL','Store Thumbnail',false,'Prefer 512px or 768px approved derivative.','Digital commerce placement.')
) as v(placement_code, placement_name, is_required, safe_area_rule, notes)
where not exists (
  select 1 from kids_brand_placement_rules p
  where p.brand_profile_id=bp.id and p.product_code='ACTIVITY_BOOK' and p.placement_code=v.placement_code
);
-- END CANONICAL MIGRATION 0063

-- BEGIN CANONICAL MIGRATION 0064 20260826131734 phase1_person_lifetime_evidence_foundation
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
-- END CANONICAL MIGRATION 0064

-- BEGIN CANONICAL MIGRATION 0065 20260826140155 phase1_registration_documents_batch_activation_final
create sequence if not exists am_application_number_seq start 1;
create sequence if not exists am_batch_number_seq start 1;

create table if not exists public.am_registration_applications (
 id uuid primary key default gen_random_uuid(),
 application_number text not null unique default ('AM-A-'||lpad(nextval('am_application_number_seq')::text,7,'0')),
 intake_type text not null check (intake_type in ('individual','institution_bulk','admin_sponsored')),
 institution_id uuid references public.am_institutions(id) on delete set null,
 batch_id uuid,
 person_id uuid references public.am_persons(id) on delete set null,
 candidate_id uuid references public.am_candidate_records(id) on delete set null,
 full_name text not null,
 email text,
 mobile text,
 date_of_birth date,
 current_city text,
 preferred_language text default 'en',
 source_code text default 'direct',
 program_code text,
 lifecycle_status text not null default 'draft' check (lifecycle_status in ('draft','submitted','under_review','approved','invited','code_verified','registration_in_progress','documents_pending','payment_pending','ready_for_activation','candidate_active','rejected','withdrawn','suspended','expired')),
 contact_verification_status text not null default 'unverified' check (contact_verification_status in ('unverified','pending','verified')),
 identity_verification_status text not null default 'unverified' check (identity_verification_status in ('unverified','pending','verified','rejected')),
 payment_required boolean not null default true,
 payment_status text not null default 'pending' check (payment_status in ('not_required','pending','confirmed','failed','refunded')),
 consent_status text not null default 'pending' check (consent_status in ('pending','accepted','withdrawn')),
 data_quality_score numeric(5,2) not null default 0,
 duplicate_status text not null default 'unchecked' check (duplicate_status in ('unchecked','clear','possible_duplicate','merged')),
 activation_eligible boolean not null default false,
 activated_at timestamptz,
 approved_at timestamptz,
 approved_by uuid,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.am_institution_batches (
 id uuid primary key default gen_random_uuid(),
 institution_id uuid not null references public.am_institutions(id) on delete cascade,
 batch_number text not null unique default ('AM-B-'||lpad(nextval('am_batch_number_seq')::text,6,'0')),
 batch_code text not null unique,
 name text not null,
 program_code text,
 status text not null default 'draft' check (status in ('draft','approved','inviting','active','completed','cancelled')),
 contract_payment_status text not null default 'pending' check (contract_payment_status in ('pending','confirmed','not_required')),
 starts_on date,
 ends_on date,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

alter table public.am_registration_applications drop constraint if exists am_registration_applications_batch_id_fkey;
alter table public.am_registration_applications add constraint am_registration_applications_batch_id_fkey foreign key (batch_id) references public.am_institution_batches(id) on delete set null;

create table if not exists public.am_batch_trainees (
 id uuid primary key default gen_random_uuid(),
 batch_id uuid not null references public.am_institution_batches(id) on delete cascade,
 application_id uuid not null unique references public.am_registration_applications(id) on delete cascade,
 external_person_ref text,
 seat_no integer,
 status text not null default 'draft',
 created_at timestamptz not null default now()
);

create table if not exists public.am_registration_activation_codes (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.am_registration_applications(id) on delete cascade,
 channel text not null check (channel in ('email','sms','manual')),
 destination_masked text,
 code_hash text not null,
 expires_at timestamptz not null,
 max_attempts integer not null default 5,
 attempt_count integer not null default 0,
 sent_at timestamptz,
 verified_at timestamptz,
 consumed_at timestamptz,
 revoked_at timestamptz,
 created_by uuid,
 created_at timestamptz not null default now()
);
create index if not exists idx_reg_codes_app on public.am_registration_activation_codes(application_id,created_at desc);

create table if not exists public.am_registration_sessions (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.am_registration_applications(id) on delete cascade,
 token_hash text not null unique,
 expires_at timestamptz not null,
 revoked_at timestamptz,
 last_seen_at timestamptz not null default now(),
 created_at timestamptz not null default now()
);

create table if not exists public.am_document_type_registry (
 id uuid primary key default gen_random_uuid(),
 code text not null unique,
 name text not null,
 description text,
 requires_expiry boolean not null default false,
 requires_verification boolean not null default true,
 allowed_mime_types text[] not null default array['application/pdf','image/jpeg','image/png'],
 max_file_mb numeric(6,2) not null default 10,
 is_active boolean not null default true,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.am_document_requirement_rules (
 id uuid primary key default gen_random_uuid(),
 document_type_id uuid not null references public.am_document_type_registry(id) on delete cascade,
 rule_name text not null,
 scope_type text not null check (scope_type in ('global','intake_type','institution','batch','program','application','stage')),
 scope_text text,
 scope_uuid uuid,
 mandatory boolean not null default true,
 blocking boolean not null default true,
 valid_from date,
 valid_until date,
 priority integer not null default 100,
 applicability jsonb not null default '{}'::jsonb,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists idx_doc_rules_active on public.am_document_requirement_rules(is_active,scope_type,priority);

create table if not exists public.am_application_documents (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.am_registration_applications(id) on delete cascade,
 document_type_id uuid not null references public.am_document_type_registry(id),
 version_no integer not null default 1,
 storage_bucket text not null default 'candidate-registration-documents',
 storage_path text not null,
 original_filename text,
 mime_type text,
 file_size bigint,
 document_number text,
 issued_at date,
 expires_at date,
 verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected','expired','superseded')),
 rejection_reason text,
 verified_at timestamptz,
 verified_by uuid,
 replaced_document_id uuid references public.am_application_documents(id) on delete set null,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index if not exists idx_app_docs_app on public.am_application_documents(application_id,document_type_id,version_no desc);

create table if not exists public.am_application_consents (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.am_registration_applications(id) on delete cascade,
 consent_code text not null,
 terms_version text not null,
 status text not null check (status in ('accepted','withdrawn')),
 accepted_at timestamptz,
 withdrawn_at timestamptz,
 source_ip text,
 user_agent text,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);

create table if not exists public.am_registration_payment_refs (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.am_registration_applications(id) on delete cascade,
 payment_source text not null,
 external_reference text,
 amount numeric(14,2),
 currency text default 'EGP',
 status text not null default 'pending' check (status in ('pending','confirmed','failed','refunded','not_required')),
 confirmed_at timestamptz,
 confirmed_by uuid,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.am_registration_delivery_outbox (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.am_registration_applications(id) on delete cascade,
 activation_code_id uuid references public.am_registration_activation_codes(id) on delete set null,
 channel text not null check (channel in ('email','sms')),
 recipient text not null,
 template_code text not null,
 payload jsonb not null default '{}'::jsonb,
 status text not null default 'pending' check (status in ('pending','sent','failed','cancelled')),
 provider_message_id text,
 sent_at timestamptz,
 error_text text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.am_registration_events (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.am_registration_applications(id) on delete cascade,
 event_code text not null,
 title text not null,
 detail text,
 actor_type text not null default 'system',
 actor_ref uuid,
 metadata jsonb not null default '{}'::jsonb,
 occurred_at timestamptz not null default now(),
 created_at timestamptz not null default now()
);

create or replace function public.am_registration_required_documents(p_application_id uuid)
returns table(document_type_id uuid, code text, name text, mandatory boolean, blocking boolean)
language sql stable security definer set search_path=public as $$
 select distinct on (d.id) d.id,d.code,d.name,r.mandatory,r.blocking
 from am_registration_applications a
 join am_document_requirement_rules r on r.is_active=true
 join am_document_type_registry d on d.id=r.document_type_id and d.is_active=true
 where a.id=p_application_id
   and (r.valid_from is null or r.valid_from<=current_date)
   and (r.valid_until is null or r.valid_until>=current_date)
   and (
     r.scope_type='global'
     or (r.scope_type='intake_type' and r.scope_text=a.intake_type)
     or (r.scope_type='institution' and r.scope_uuid=a.institution_id)
     or (r.scope_type='batch' and r.scope_uuid=a.batch_id)
     or (r.scope_type='program' and r.scope_text=a.program_code)
     or (r.scope_type='application' and r.scope_uuid=a.id)
     or (r.scope_type='stage' and r.scope_text=a.lifecycle_status)
   )
 order by d.id,r.priority asc,r.created_at desc;
$$;

create or replace function public.am_recalculate_registration_gate(p_application_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a am_registration_applications%rowtype; missing_count int:=0; blocking_missing int:=0; consent_ok boolean:=false; payment_ok boolean:=false; code_ok boolean:=false; eligible boolean:=false; dq numeric:=0;
begin
 select * into a from am_registration_applications where id=p_application_id for update;
 if not found then raise exception 'APPLICATION_NOT_FOUND'; end if;
 select count(*) filter(where r.mandatory), count(*) filter(where r.mandatory and r.blocking)
 into missing_count,blocking_missing
 from am_registration_required_documents(p_application_id) r
 where not exists (
   select 1 from am_application_documents d
   where d.application_id=p_application_id and d.document_type_id=r.document_type_id and d.verification_status='verified'
 );
 select exists(select 1 from am_application_consents c where c.application_id=p_application_id and c.status='accepted') into consent_ok;
 payment_ok := (not a.payment_required) or a.payment_status in ('confirmed','not_required');
 select exists(select 1 from am_registration_activation_codes c where c.application_id=p_application_id and c.verified_at is not null and c.revoked_at is null) into code_ok;
 dq := ((case when nullif(trim(a.full_name),'') is not null then 20 else 0 end)
      +(case when nullif(trim(coalesce(a.email,'')),'') is not null then 15 else 0 end)
      +(case when nullif(trim(coalesce(a.mobile,'')),'') is not null then 15 else 0 end)
      +(case when a.date_of_birth is not null then 15 else 0 end)
      +(case when a.current_city is not null then 10 else 0 end)
      +(case when code_ok then 10 else 0 end)
      +(case when consent_ok then 15 else 0 end));
 eligible := code_ok and consent_ok and payment_ok and blocking_missing=0 and a.identity_verification_status in ('verified','unverified','pending');
 update am_registration_applications set activation_eligible=eligible,data_quality_score=dq,
 lifecycle_status=case when candidate_id is not null then 'candidate_active' when eligible then 'ready_for_activation' when code_ok then case when blocking_missing>0 then 'documents_pending' when not payment_ok then 'payment_pending' else 'registration_in_progress' end else lifecycle_status end,
 updated_at=now() where id=p_application_id;
 return jsonb_build_object('eligible',eligible,'missing_required',missing_count,'blocking_missing',blocking_missing,'consent_ok',consent_ok,'payment_ok',payment_ok,'code_ok',code_ok,'data_quality_score',dq);
end $$;

create or replace function public.am_activate_registration_application(p_application_id uuid,p_actor uuid default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare a am_registration_applications%rowtype; gate jsonb; p_id uuid; c_id uuid;
begin
 gate:=am_recalculate_registration_gate(p_application_id);
 if coalesce((gate->>'eligible')::boolean,false)=false then raise exception 'APPLICATION_NOT_ELIGIBLE'; end if;
 select * into a from am_registration_applications where id=p_application_id for update;
 if a.candidate_id is not null then return a.candidate_id; end if;
 -- duplicate reuse only when same verified email/mobile and an existing person is unique
 select id into p_id from am_persons p where (a.email is not null and lower(p.email)=lower(a.email)) or (a.mobile is not null and p.mobile=a.mobile) order by created_at asc limit 1;
 if p_id is null then
   insert into am_persons(full_name,date_of_birth,email,mobile,current_city,preferred_language,person_status)
   values(a.full_name,a.date_of_birth,a.email,a.mobile,a.current_city,a.preferred_language,'active') returning id into p_id;
 end if;
 select id into c_id from am_candidate_records where person_id=p_id order by created_at asc limit 1;
 if c_id is null then
   insert into am_candidate_records(person_id,lifecycle_stage,activation_status,activated_at,metadata)
   values(p_id,'candidate','active',now(),jsonb_build_object('application_id',a.id,'source',a.source_code,'institution_id',a.institution_id,'batch_id',a.batch_id)) returning id into c_id;
 end if;
 update am_registration_applications set person_id=p_id,candidate_id=c_id,lifecycle_status='candidate_active',activated_at=now(),updated_at=now() where id=a.id;
 insert into am_registration_events(application_id,event_code,title,detail,actor_type,actor_ref) values(a.id,'CANDIDATE_ACTIVATED','Candidate activated','Registration gate passed and lifetime candidate record created.','system',p_actor);
 begin
   perform am_append_candidate_lifetime_event(c_id,'CANDIDATE_ACTIVATED','registration','Candidate activated','Registration completed and candidate lifetime journey started.','system',p_actor,null,jsonb_build_object('application_id',a.id));
 exception when undefined_function then null; end;
 return c_id;
end $$;

create or replace function public.am_block_registration_event_mutation() returns trigger language plpgsql as $$ begin raise exception 'APPEND_ONLY_RECORD'; end $$;
drop trigger if exists trg_registration_events_append_only on public.am_registration_events;
create trigger trg_registration_events_append_only before update or delete on public.am_registration_events for each row execute function public.am_block_registration_event_mutation();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('candidate-registration-documents','candidate-registration-documents',false,10485760,array['application/pdf','image/jpeg','image/png'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

alter table public.am_registration_applications enable row level security;
alter table public.am_institution_batches enable row level security;
alter table public.am_batch_trainees enable row level security;
alter table public.am_registration_activation_codes enable row level security;
alter table public.am_registration_sessions enable row level security;
alter table public.am_document_type_registry enable row level security;
alter table public.am_document_requirement_rules enable row level security;
alter table public.am_application_documents enable row level security;
alter table public.am_application_consents enable row level security;
alter table public.am_registration_payment_refs enable row level security;
alter table public.am_registration_delivery_outbox enable row level security;
alter table public.am_registration_events enable row level security;

insert into public.am_document_type_registry(code,name,description,requires_expiry,requires_verification)
values
 ('NATIONAL_ID','National ID / Passport','Government-issued identity document',false,true),
 ('PERSONAL_PHOTO','Personal Photo','Recent personal photo',false,true),
 ('EDUCATION_CERT','Education Certificate','Latest education certificate or proof',false,true)
on conflict(code) do nothing;

insert into public.am_document_requirement_rules(document_type_id,rule_name,scope_type,mandatory,blocking,priority)
select id,'Default identity requirement','global',true,true,100 from public.am_document_type_registry where code='NATIONAL_ID'
on conflict do nothing;
insert into public.am_document_requirement_rules(document_type_id,rule_name,scope_type,mandatory,blocking,priority)
select id,'Default personal photo','global',true,false,120 from public.am_document_type_registry where code='PERSONAL_PHOTO'
on conflict do nothing;
-- END CANONICAL MIGRATION 0065

-- BEGIN CANONICAL MIGRATION 0066 20260826140654 phase1_auto_activation_finalize
create or replace function public.am_activate_registration_application(p_application_id uuid,p_actor uuid default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare a am_registration_applications%rowtype; p_id uuid; c_id uuid;
begin
 select * into a from am_registration_applications where id=p_application_id for update;
 if not found then raise exception 'APPLICATION_NOT_FOUND'; end if;
 if a.candidate_id is not null then return a.candidate_id; end if;
 if not a.activation_eligible then raise exception 'APPLICATION_NOT_ELIGIBLE'; end if;
 select id into p_id from am_persons p where (a.email is not null and lower(p.email)=lower(a.email)) or (a.mobile is not null and p.mobile=a.mobile) order by created_at asc limit 1;
 if p_id is null then
   insert into am_persons(full_name,date_of_birth,email,mobile,current_city,preferred_language,person_status)
   values(a.full_name,a.date_of_birth,a.email,a.mobile,a.current_city,a.preferred_language,'active') returning id into p_id;
 end if;
 select id into c_id from am_candidate_records where person_id=p_id order by created_at asc limit 1;
 if c_id is null then
   insert into am_candidate_records(person_id,lifecycle_stage,activation_status,activated_at,metadata)
   values(p_id,'candidate','active',now(),jsonb_build_object('application_id',a.id,'source',a.source_code,'institution_id',a.institution_id,'batch_id',a.batch_id)) returning id into c_id;
 end if;
 insert into am_candidate_current_state(candidate_id,person_id,lifecycle_stage,qualification_status,readiness_status)
 values(c_id,p_id,'candidate','unassessed','not_calculated')
 on conflict (candidate_id) do nothing;
 update am_registration_applications set person_id=p_id,candidate_id=c_id,lifecycle_status='candidate_active',activated_at=coalesce(activated_at,now()),updated_at=now() where id=a.id;
 insert into am_registration_events(application_id,event_code,title,detail,actor_type,actor_ref)
 values(a.id,'CANDIDATE_ACTIVATED','Candidate activated','Registration gate passed and lifetime candidate record created.','system',p_actor);
 perform am_append_candidate_lifetime_event(
   p_candidate_id=>c_id,
   p_event_code=>'CANDIDATE_ACTIVATED',
   p_event_domain=>'registration',
   p_title=>'Candidate activated',
   p_detail=>'Registration completed and candidate lifetime journey started.',
   p_payload=>jsonb_build_object('application_id',a.id,'application_number',a.application_number,'institution_id',a.institution_id,'batch_id',a.batch_id),
   p_source_system=>'registration-gateway',
   p_source_table=>'am_registration_applications',
   p_source_id=>a.id,
   p_recorded_by=>p_actor
 );
 return c_id;
end $$;

create or replace function public.am_recalculate_registration_gate(p_application_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a am_registration_applications%rowtype; missing_count int:=0; blocking_missing int:=0; consent_ok boolean:=false; payment_ok boolean:=false; code_ok boolean:=false; eligible boolean:=false; dq numeric:=0; activated_candidate uuid:=null;
begin
 select * into a from am_registration_applications where id=p_application_id for update;
 if not found then raise exception 'APPLICATION_NOT_FOUND'; end if;
 select count(*) filter(where r.mandatory), count(*) filter(where r.mandatory and r.blocking)
 into missing_count,blocking_missing
 from am_registration_required_documents(p_application_id) r
 where not exists (
   select 1 from am_application_documents d
   where d.application_id=p_application_id and d.document_type_id=r.document_type_id and d.verification_status='verified'
 );
 select exists(select 1 from am_application_consents c where c.application_id=p_application_id and c.status='accepted') into consent_ok;
 payment_ok := (not a.payment_required) or a.payment_status in ('confirmed','not_required');
 select exists(select 1 from am_registration_activation_codes c where c.application_id=p_application_id and c.verified_at is not null and c.revoked_at is null) into code_ok;
 dq := ((case when nullif(trim(a.full_name),'') is not null then 20 else 0 end)
      +(case when nullif(trim(coalesce(a.email,'')),'') is not null then 15 else 0 end)
      +(case when nullif(trim(coalesce(a.mobile,'')),'') is not null then 15 else 0 end)
      +(case when a.date_of_birth is not null then 15 else 0 end)
      +(case when a.current_city is not null then 10 else 0 end)
      +(case when code_ok then 10 else 0 end)
      +(case when consent_ok then 15 else 0 end));
 eligible := code_ok and consent_ok and payment_ok and blocking_missing=0 and a.identity_verification_status in ('verified','unverified','pending');
 update am_registration_applications set activation_eligible=eligible,data_quality_score=dq,
 lifecycle_status=case when candidate_id is not null then 'candidate_active' when eligible then 'ready_for_activation' when code_ok then case when blocking_missing>0 then 'documents_pending' when not payment_ok then 'payment_pending' else 'registration_in_progress' end else lifecycle_status end,
 updated_at=now() where id=p_application_id;
 if eligible and a.candidate_id is null then
   activated_candidate:=am_activate_registration_application(p_application_id,null);
 end if;
 return jsonb_build_object('eligible',eligible,'missing_required',missing_count,'blocking_missing',blocking_missing,'consent_ok',consent_ok,'payment_ok',payment_ok,'code_ok',code_ok,'data_quality_score',dq,'candidate_id',activated_candidate);
end $$;
-- END CANONICAL MIGRATION 0066

-- BEGIN CANONICAL MIGRATION 0067 20260826143052 phase2_multi_stage_assessment_engine
create table if not exists am_assessment_stage_registry (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  stage_order integer not null unique,
  assessment_kind text not null,
  description text,
  level_scheme jsonb not null default '{}'::jsonb,
  is_required boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists am_assessment_stage_versions (
  id uuid primary key default gen_random_uuid(),
  stage_id uuid not null references am_assessment_stage_registry(id) on delete cascade,
  version_no integer not null,
  version_label text not null,
  status text not null default 'draft',
  instructions text,
  min_questions integer not null default 0,
  time_limit_minutes integer,
  scoring_rule jsonb not null default '{}'::jsonb,
  level_bands jsonb not null default '[]'::jsonb,
  retake_rule jsonb not null default '{}'::jsonb,
  effective_from timestamptz,
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(stage_id, version_no)
);

create table if not exists am_assessment_stage_version_items (
  id uuid primary key default gen_random_uuid(),
  stage_version_id uuid not null references am_assessment_stage_versions(id) on delete cascade,
  question_id uuid not null references question_bank(id) on delete restrict,
  sequence_no integer not null default 999,
  weight numeric not null default 1,
  is_required boolean not null default true,
  created_at timestamptz not null default now(),
  unique(stage_version_id, question_id)
);

create table if not exists am_candidate_assessment_journeys (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null unique references am_candidate_records(id) on delete cascade,
  status text not null default 'not_started',
  current_stage_code text,
  started_at timestamptz,
  completed_at timestamptz,
  last_activity_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists am_candidate_stage_attempts (
  id uuid primary key default gen_random_uuid(),
  journey_id uuid not null references am_candidate_assessment_journeys(id) on delete cascade,
  candidate_id uuid not null references am_candidate_records(id) on delete cascade,
  stage_code text not null references am_assessment_stage_registry(code) on update cascade,
  stage_version_id uuid references am_assessment_stage_versions(id) on delete restrict,
  attempt_no integer not null,
  status text not null default 'in_progress',
  access_token uuid not null default gen_random_uuid(),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  completed_at timestamptz,
  overall_score numeric,
  level_code text,
  outcome_code text,
  result_json jsonb not null default '{}'::jsonb,
  integrity_flags jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(candidate_id, stage_code, attempt_no)
);

create table if not exists am_candidate_stage_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references am_candidate_stage_attempts(id) on delete cascade,
  question_id uuid not null references question_bank(id) on delete restrict,
  option_id uuid references question_options(id) on delete restrict,
  answer_payload jsonb not null default '{}'::jsonb,
  response_time_seconds integer,
  answered_at timestamptz not null default now(),
  unique(attempt_id, question_id)
);

create table if not exists am_candidate_stage_dimension_results (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references am_candidate_stage_attempts(id) on delete cascade,
  dimension_code text not null,
  dimension_name text,
  raw_score numeric,
  normalized_score numeric,
  level_code text,
  evidence_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(attempt_id, dimension_code)
);

create table if not exists am_candidate_career_recommendations (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references am_candidate_stage_attempts(id) on delete cascade,
  candidate_id uuid not null references am_candidate_records(id) on delete cascade,
  career_code text not null,
  career_name text,
  rank_no integer not null,
  fit_score numeric not null,
  decision_code text,
  gaps jsonb not null default '[]'::jsonb,
  explanation jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(attempt_id, career_code)
);

create index if not exists idx_stage_attempts_candidate on am_candidate_stage_attempts(candidate_id, stage_code, attempt_no desc);
create index if not exists idx_stage_answers_attempt on am_candidate_stage_answers(attempt_id);
create index if not exists idx_stage_dimension_attempt on am_candidate_stage_dimension_results(attempt_id);
create index if not exists idx_career_recommendations_candidate on am_candidate_career_recommendations(candidate_id, fit_score desc);

insert into am_assessment_stage_registry(code,name,stage_order,assessment_kind,description,level_scheme,is_required,is_active)
values
('ENGLISH','English Assessment',1,'foundation','English readiness and level assessment.','{"labels":["A1","A2","B1","B2","C1"],"thresholds":"admin_configured"}'::jsonb,true,true),
('COMPUTER','Computer Assessment',2,'foundation','Digital and computer readiness assessment.','{"labels":["Basic","Intermediate","Advanced"],"thresholds":"admin_configured"}'::jsonb,true,true),
('TRAITS','Traits & Behavioral Assessment',3,'behavioral','Work-style, behavioral and trait dimensions.','{"type":"dimension_profile","thresholds":"admin_configured"}'::jsonb,true,true),
('CAREER','Career Aptitude Assessment',4,'career_fit','Career suitability and pathway recommendation stage.','{"type":"ranked_career_fit","thresholds":"admin_configured"}'::jsonb,true,true)
on conflict(code) do update set name=excluded.name,stage_order=excluded.stage_order,assessment_kind=excluded.assessment_kind,description=excluded.description,level_scheme=excluded.level_scheme,is_required=excluded.is_required,is_active=excluded.is_active,updated_at=now();

insert into am_assessment_stage_versions(stage_id,version_no,version_label,status,instructions,min_questions,time_limit_minutes,scoring_rule,level_bands,retake_rule)
select id,1,'v1.0','draft',
  case code
    when 'ENGLISH' then 'Complete the configured English assessment. Final thresholds are controlled by the approved stage version.'
    when 'COMPUTER' then 'Complete the configured computer assessment. Final thresholds are controlled by the approved stage version.'
    when 'TRAITS' then 'Complete the configured behavioral assessment. Results are a profile, not a simple pass/fail.'
    when 'CAREER' then 'Complete the configured career aptitude assessment. Results produce ranked career fit and gap evidence.'
  end,
  0,null,'{"method":"question_option_dimension_aggregation","normalization":"configured_by_stage_version"}'::jsonb,'[]'::jsonb,
  '{"max_attempts":null,"cooldown_hours":0,"approval_required_for_retake":false}'::jsonb
from am_assessment_stage_registry s
where not exists(select 1 from am_assessment_stage_versions v where v.stage_id=s.id and v.version_no=1);

create or replace view am_candidate_assessment_journey_summary as
select j.id as journey_id,j.candidate_id,c.candidate_number,p.full_name,j.status,j.current_stage_code,j.started_at,j.completed_at,j.last_activity_at,
       coalesce((select count(*) from am_candidate_stage_attempts a where a.journey_id=j.id),0) attempts_total,
       coalesce((select count(*) from am_candidate_stage_attempts a where a.journey_id=j.id and a.status='completed'),0) attempts_completed,
       coalesce((select count(*) from am_candidate_stage_attempts a where a.journey_id=j.id and a.status='in_progress'),0) attempts_in_progress
from am_candidate_assessment_journeys j
join am_candidate_records c on c.id=j.candidate_id
join am_persons p on p.id=c.person_id;

alter table am_assessment_stage_registry enable row level security;
alter table am_assessment_stage_versions enable row level security;
alter table am_assessment_stage_version_items enable row level security;
alter table am_candidate_assessment_journeys enable row level security;
alter table am_candidate_stage_attempts enable row level security;
alter table am_candidate_stage_answers enable row level security;
alter table am_candidate_stage_dimension_results enable row level security;
alter table am_candidate_career_recommendations enable row level security;

create or replace function am_refresh_candidate_assessment_state(p_candidate_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_journey am_candidate_assessment_journeys%rowtype;
  v_next text;
  v_all_done boolean;
  v_eng text;
  v_comp text;
  v_career text;
  v_fit numeric;
begin
  select * into v_journey from am_candidate_assessment_journeys where candidate_id=p_candidate_id;
  if v_journey.id is null then return; end if;

  select s.code into v_next
  from am_assessment_stage_registry s
  where s.is_active and s.is_required
    and not exists(
      select 1 from am_candidate_stage_attempts a
      where a.candidate_id=p_candidate_id and a.stage_code=s.code and a.status='completed'
    )
  order by s.stage_order
  limit 1;

  v_all_done := v_next is null;

  select level_code into v_eng from am_candidate_stage_attempts where candidate_id=p_candidate_id and stage_code='ENGLISH' and status='completed' order by attempt_no desc limit 1;
  select level_code into v_comp from am_candidate_stage_attempts where candidate_id=p_candidate_id and stage_code='COMPUTER' and status='completed' order by attempt_no desc limit 1;
  select r.career_code,r.fit_score into v_career,v_fit
  from am_candidate_career_recommendations r
  join am_candidate_stage_attempts a on a.id=r.attempt_id
  where r.candidate_id=p_candidate_id and a.status='completed'
  order by a.completed_at desc nulls last,r.rank_no asc
  limit 1;

  update am_candidate_assessment_journeys
  set status=case when v_all_done then 'completed' when started_at is null then 'not_started' else 'in_progress' end,
      current_stage_code=v_next,
      completed_at=case when v_all_done then coalesce(completed_at,now()) else null end,
      last_activity_at=now(),updated_at=now()
  where candidate_id=p_candidate_id;

  update am_candidate_current_state
  set english_level=coalesce(v_eng,english_level),
      computer_level=coalesce(v_comp,computer_level),
      current_career_code=coalesce(v_career,current_career_code),
      current_career_fit=coalesce(v_fit,current_career_fit),
      latest_assessment_at=now(),
      qualification_status=case when v_all_done then 'assessment_complete' else 'assessment_in_progress' end,
      recalculated_at=now(),updated_at=now()
  where candidate_id=p_candidate_id;
end;
$$;
-- END CANONICAL MIGRATION 0067

-- BEGIN CANONICAL MIGRATION 0068 20260902131530 phase08_writing_foundation_schema
create table if not exists assessment.writing_level_policies (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  cefr_level text not null,
  tasks_per_form smallint not null check (tasks_per_form > 0),
  total_marks smallint not null check (total_marks > 0),
  time_minutes smallint null check (time_minutes is null or time_minutes > 0),
  launch_form_equivalents smallint not null check (launch_form_equivalents > 0),
  target_bank_prompts integer not null check (target_bank_prompts > 0),
  rubric_model_code text not null,
  blueprint_version text not null,
  source_status text not null,
  recovery_status text not null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, cefr_level)
);

create table if not exists assessment.writing_task_policies (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  cefr_level text not null,
  task_number smallint not null check (task_number in (1,2)),
  marks smallint not null check (marks > 0),
  word_min integer null check (word_min is null or word_min >= 0),
  word_max integer null check (word_max is null or word_max >= 0),
  task_family text null,
  task_description text null,
  blueprint_version text not null,
  source_status text not null,
  recovery_status text not null,
  source_reference text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (word_min is null or word_max is null or word_max >= word_min),
  unique(bank_id, cefr_level, task_number)
);

create table if not exists assessment.writing_rubric_criteria (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  criterion_code text not null,
  criterion_name text not null,
  ordinal smallint not null check (ordinal > 0),
  criterion_definition text null,
  weighting_status text not null,
  blueprint_version text not null,
  source_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, criterion_code),
  unique(bank_id, ordinal)
);

create table if not exists assessment.writing_item_specs (
  item_version_id uuid primary key references assessment.item_versions(id) on delete restrict,
  task_number smallint not null check (task_number in (1,2)),
  word_min integer null check (word_min is null or word_min >= 0),
  word_max integer null check (word_max is null or word_max >= 0),
  rubric_version text not null,
  response_mode_code text not null default 'EXTENDED_WRITING',
  scoring_status text not null default 'HUMAN_SCORING_REQUIRED',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (word_min is null or word_max is null or word_max >= word_min)
);

create index if not exists idx_writing_level_policies_bank on assessment.writing_level_policies(bank_id, cefr_level);
create index if not exists idx_writing_task_policies_bank on assessment.writing_task_policies(bank_id, cefr_level, task_number);
create index if not exists idx_writing_rubric_criteria_bank on assessment.writing_rubric_criteria(bank_id, ordinal);
-- END CANONICAL MIGRATION 0068

-- BEGIN CANONICAL MIGRATION 0069 20260902131905 phase08_allow_analytic_rubric_scoring
alter table assessment.item_versions drop constraint if exists item_versions_scoring_mode_check;
alter table assessment.item_versions add constraint item_versions_scoring_mode_check
check (scoring_mode = any (array[
  'OPTION_KEY'::text,
  'EXACT_KEY'::text,
  'FINITE_KEYSET'::text,
  'BOOLEAN_KEY'::text,
  'MATCH_KEY'::text,
  'ORDER_KEY'::text,
  'ANALYTIC_RUBRIC'::text
]));
-- END CANONICAL MIGRATION 0069

-- BEGIN CANONICAL MIGRATION 0070 20260902151732 phase08_writing_rubric_human_scoring_governance
alter table assessment.writing_rubric_criteria
  add column if not exists weight_units numeric(8,4) not null default 1.0000;

create table if not exists assessment.writing_rubric_bands (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  scale_code text not null,
  band_score smallint not null check (band_score between 0 and 5),
  band_label text not null,
  generic_descriptor text not null,
  source_status text not null,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, scale_code, band_score)
);

create table if not exists assessment.writing_rubric_level_descriptors (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  criterion_code text not null,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  target_descriptor text not null,
  source_status text not null,
  source_reference text null,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, criterion_code, cefr_level),
  foreign key (bank_id, criterion_code) references assessment.writing_rubric_criteria(bank_id, criterion_code) on delete restrict
);

create table if not exists assessment.writing_scoring_policy (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  policy_code text not null,
  policy_version text not null,
  raters_required smallint not null check (raters_required >= 1),
  blind_independent_scoring boolean not null,
  criteria_count smallint not null check (criteria_count > 0),
  criterion_band_min smallint not null,
  criterion_band_max smallint not null,
  raw_total_min numeric(8,3) not null,
  raw_total_max numeric(8,3) not null,
  task_score_formula text not null,
  early_rounding_allowed boolean not null,
  final_rounding_stage text not null,
  source_status text not null,
  external_certification_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, policy_code, policy_version)
);

create table if not exists assessment.writing_adjudication_rules (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  rule_code text not null,
  trigger_type text not null,
  threshold_numeric numeric(10,3) null,
  rule_text text not null,
  finalization_action text not null,
  is_active boolean not null default true,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, rule_code)
);

create table if not exists assessment.writing_rater_policy (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  policy_code text not null,
  requirement_type text not null,
  requirement_text text not null,
  threshold_numeric numeric(10,3) null,
  unit_code text null,
  is_active boolean not null default true,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, policy_code)
);

create table if not exists assessment.writing_special_case_rules (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  case_code text not null,
  case_name text not null,
  scoring_rule text not null,
  security_flag_required boolean not null default false,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, case_code)
);

create index if not exists idx_writing_rubric_level_descriptors_bank_level
  on assessment.writing_rubric_level_descriptors(bank_id, cefr_level, criterion_code);
create index if not exists idx_writing_adjudication_rules_bank
  on assessment.writing_adjudication_rules(bank_id, is_active);
create index if not exists idx_writing_rater_policy_bank
  on assessment.writing_rater_policy(bank_id, is_active);
-- END CANONICAL MIGRATION 0070

-- BEGIN CANONICAL MIGRATION 0071 20260902154215 phase09_speaking_foundation_schema
create table if not exists assessment.speaking_level_policies (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  parts_per_form smallint null check (parts_per_form is null or parts_per_form > 0),
  total_marks numeric(8,2) null check (total_marks is null or total_marks > 0),
  total_time_seconds integer null check (total_time_seconds is null or total_time_seconds > 0),
  launch_form_equivalents smallint not null check (launch_form_equivalents > 0),
  target_bank_prompts integer null check (target_bank_prompts is null or target_bank_prompts > 0),
  rubric_model_code text not null,
  blueprint_version text not null,
  source_status text not null,
  recovery_status text not null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, cefr_level)
);

create table if not exists assessment.speaking_task_policies (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  part_number smallint not null check (part_number > 0),
  task_family text null,
  interaction_mode text null,
  prompt_count smallint null check (prompt_count is null or prompt_count > 0),
  preparation_seconds integer null check (preparation_seconds is null or preparation_seconds >= 0),
  response_seconds integer null check (response_seconds is null or response_seconds > 0),
  marks numeric(8,2) null check (marks is null or marks > 0),
  interlocutor_role text null,
  blueprint_version text not null,
  source_status text not null,
  recovery_status text not null,
  source_reference text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, cefr_level, part_number)
);

create table if not exists assessment.speaking_rubric_criteria (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  criterion_code text not null,
  criterion_name text not null,
  ordinal smallint not null check (ordinal > 0),
  criterion_definition text not null,
  weight_units numeric(8,4) null,
  weighting_status text not null,
  source_status text not null,
  source_reference text null,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, criterion_code),
  unique(bank_id, ordinal)
);

create table if not exists assessment.speaking_lo_construct_map (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  lo_id uuid not null references assessment.learning_outcomes(id) on delete restrict,
  criterion_code text not null,
  mapping_status text not null,
  source_status text not null,
  created_at timestamptz not null default now(),
  unique(bank_id, lo_id),
  foreign key (bank_id, criterion_code) references assessment.speaking_rubric_criteria(bank_id, criterion_code) on delete restrict
);

create table if not exists assessment.speaking_item_specs (
  item_version_id uuid primary key references assessment.item_versions(id) on delete restrict,
  part_number smallint not null check (part_number > 0),
  task_family text null,
  interaction_mode text null,
  preparation_seconds integer null check (preparation_seconds is null or preparation_seconds >= 0),
  response_seconds integer null check (response_seconds is null or response_seconds > 0),
  rubric_version text not null,
  response_mode_code text not null default 'SPOKEN_RESPONSE',
  scoring_status text not null default 'HUMAN_SCORING_REQUIRED',
  evidence_status text not null default 'EVIDENCE_POLICY_PENDING',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists assessment.speaking_evidence_policy (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  policy_code text not null,
  audio_recording_required boolean null,
  video_recording_required boolean null,
  live_interlocutor_required boolean null,
  second_rater_mode text null,
  retention_rule text null,
  source_status text not null,
  recovery_status text not null,
  version_code text not null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, policy_code)
);

create index if not exists idx_speaking_level_policies_bank on assessment.speaking_level_policies(bank_id, cefr_level);
create index if not exists idx_speaking_task_policies_bank on assessment.speaking_task_policies(bank_id, cefr_level, part_number);
create index if not exists idx_speaking_lo_construct_map_bank on assessment.speaking_lo_construct_map(bank_id, criterion_code);
-- END CANONICAL MIGRATION 0071

-- BEGIN CANONICAL MIGRATION 0072 20260902160546 phase09_speaking_operational_blueprint_scoring_schema
create table if not exists assessment.speaking_rubric_bands (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  scale_code text not null,
  band_score smallint not null check (band_score between 0 and 5),
  band_label text not null,
  generic_descriptor text not null,
  source_status text not null,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, scale_code, band_score)
);

create table if not exists assessment.speaking_rubric_level_descriptors (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  criterion_code text not null,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  target_descriptor text not null,
  source_status text not null,
  source_reference text null,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, criterion_code, cefr_level),
  foreign key (bank_id, criterion_code) references assessment.speaking_rubric_criteria(bank_id, criterion_code) on delete restrict
);

create table if not exists assessment.speaking_part_criterion_weights (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  part_number smallint not null check (part_number between 1 and 3),
  criterion_code text not null,
  weight_fraction numeric(8,5) not null check (weight_fraction >= 0 and weight_fraction <= 1),
  version_code text not null,
  source_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, part_number, criterion_code),
  foreign key (bank_id, criterion_code) references assessment.speaking_rubric_criteria(bank_id, criterion_code) on delete restrict
);

create table if not exists assessment.speaking_scoring_policy (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  policy_code text not null,
  policy_version text not null,
  raters_required smallint not null check (raters_required >= 1),
  blind_independent_scoring boolean not null,
  interlocutor_scores boolean not null,
  criteria_count smallint not null,
  criterion_band_min smallint not null,
  criterion_band_max smallint not null,
  total_marks numeric(8,2) not null,
  score_formula text not null,
  early_rounding_allowed boolean not null,
  final_rounding_stage text not null,
  source_status text not null,
  external_certification_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, policy_code, policy_version)
);

create table if not exists assessment.speaking_adjudication_rules (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  rule_code text not null,
  trigger_type text not null,
  threshold_numeric numeric(10,3) null,
  rule_text text not null,
  finalization_action text not null,
  is_active boolean not null default true,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, rule_code)
);

create table if not exists assessment.speaking_rater_policy (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  policy_code text not null,
  requirement_type text not null,
  requirement_text text not null,
  threshold_numeric numeric(10,3) null,
  unit_code text null,
  is_active boolean not null default true,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, policy_code)
);

create index if not exists idx_speaking_rubric_level_desc_bank_level on assessment.speaking_rubric_level_descriptors(bank_id, cefr_level, criterion_code);
create index if not exists idx_speaking_part_weights_bank_part on assessment.speaking_part_criterion_weights(bank_id, part_number);
create index if not exists idx_speaking_rater_policy_bank on assessment.speaking_rater_policy(bank_id, is_active);
-- END CANONICAL MIGRATION 0072

