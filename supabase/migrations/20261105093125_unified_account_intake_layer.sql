-- Identity and intake layer. Existing admissions and enrollment tables remain authoritative.
create table public.am_access_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null check(length(full_name) between 2 and 220),
 mobile text not null default '', city text not null default '',
 updated_at timestamptz not null default now()
);
create table public.am_access_requests (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 route text not null check(route in ('applicant','guardian','employer','instructor','institution')),
 status text not null default 'draft' check(status in ('draft','submitted','more_info','reviewed','rejected')),
 payload jsonb not null default '{}'::jsonb check(jsonb_typeof(payload)='object'),
 lead_id uuid references public.aviation_interest_leads(id),
 reviewer_message text, reviewed_by uuid, submitted_at timestamptz,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(user_id,route)
);
create table public.am_access_events (
 id bigint generated always as identity primary key,
 request_id uuid not null references public.am_access_requests(id) on delete cascade,
 event text not null,actor_id uuid not null,message text,created_at timestamptz not null default now()
);
create index am_access_requests_queue_idx on public.am_access_requests(status,created_at);
create index am_access_events_request_idx on public.am_access_events(request_id);
alter table public.am_access_profiles enable row level security;
alter table public.am_access_requests enable row level security;
alter table public.am_access_events enable row level security;
revoke all on public.am_access_profiles,public.am_access_requests,public.am_access_events from anon,authenticated;
grant all on public.am_access_profiles,public.am_access_requests,public.am_access_events to service_role;
grant usage,select on sequence public.am_access_events_id_seq to service_role;

-- Service-only transaction; no browser role may execute it or create admission bindings.
create function public.am_access_submit(p_user uuid,p_email text,p_route text,p_payload jsonb,p_submit boolean)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare r public.am_access_requests%rowtype; profile public.am_access_profiles%rowtype; l public.aviation_interest_leads%rowtype;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text||p_route,0));
 select * into profile from public.am_access_profiles where user_id=p_user;
 if not found then raise exception 'PROFILE_REQUIRED'; end if;
 select * into r from public.am_access_requests where user_id=p_user and route=p_route for update;
 if found and r.status not in ('draft','more_info') then raise exception 'REQUEST_LOCKED'; end if;
 if r.id is null then
  insert into public.am_access_requests(user_id,route,payload) values(p_user,p_route,p_payload) returning * into r;
 else
  update public.am_access_requests set payload=p_payload,updated_at=now() where id=r.id returning * into r;
 end if;
 if p_submit then
  if p_route='applicant' and r.lead_id is null then
   -- This creates an application, never course enrollment or an exam eligibility decision.
   insert into public.aviation_interest_leads(full_name,mobile,email,date_of_birth,education_stage,current_city,aviation_interest,preferred_language,consent,source,status)
   values(profile.full_name,profile.mobile,lower(p_email),(p_payload->>'date_of_birth')::date,p_payload->>'education_stage',profile.city,p_payload->>'aviation_interest','en',true,'unified_account','new') returning * into l;
   insert into public.am_application_auth_bindings(auth_user_id,lead_id,application_number) values(p_user,l.id,l.application_number);
   r.lead_id:=l.id;
  end if;
  update public.am_access_requests set status='submitted',lead_id=r.lead_id,submitted_at=now(),updated_at=now(),reviewer_message=null where id=r.id returning * into r;
  insert into public.am_access_events(request_id,event,actor_id) values(r.id,'submitted',p_user);
 end if;
 return to_jsonb(r);
end $$;
revoke all on function public.am_access_submit(uuid,text,text,jsonb,boolean) from public,anon,authenticated;
grant execute on function public.am_access_submit(uuid,text,text,jsonb,boolean) to service_role;

create function public.am_access_review(p_id uuid,p_actor uuid,p_status text,p_message text)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare r public.am_access_requests%rowtype;
begin
 if p_status not in ('more_info','reviewed','rejected') or length(trim(p_message))<3 then raise exception 'INVALID_REVIEW'; end if;
 select * into r from public.am_access_requests where id=p_id for update;
 if not found or r.status<>'submitted' then raise exception 'REQUEST_NOT_SUBMITTED'; end if;
 if r.user_id=p_actor then raise exception 'SELF_REVIEW_FORBIDDEN'; end if;
 update public.am_access_requests set status=p_status,reviewer_message=left(p_message,1000),reviewed_by=p_actor,updated_at=now() where id=p_id returning * into r;
 insert into public.am_access_events(request_id,event,actor_id,message) values(r.id,p_status,p_actor,left(p_message,1000));
 return to_jsonb(r);
end $$;
revoke all on function public.am_access_review(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.am_access_review(uuid,uuid,text,text) to service_role;
