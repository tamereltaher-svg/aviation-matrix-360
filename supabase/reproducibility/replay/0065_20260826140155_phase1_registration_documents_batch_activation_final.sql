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
