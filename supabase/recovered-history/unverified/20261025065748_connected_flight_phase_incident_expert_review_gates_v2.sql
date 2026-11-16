
create table avi_knowledge.connected_flight_phase_reviews(
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null references avi_knowledge.connected_flight_cases(id) on delete restrict,
 phase_id uuid not null,
 review_kind text not null check(review_kind in ('operations','safety','regulatory','instructional')),
 verdict text not null check(verdict in ('pending','changes_required','approved')),
 reviewer_identity text,
 review_note text not null,
 reviewed_at timestamptz not null default now(),
 check(verdict<>'approved' or length(trim(coalesce(reviewer_identity,'')))>=3),
 foreign key(case_id,phase_id) references avi_knowledge.connected_flight_phases(case_id,id) on delete restrict
);
create index connected_flight_phase_reviews_case_phase_idx on avi_knowledge.connected_flight_phase_reviews(case_id,phase_id);

create table avi_knowledge.connected_flight_disruption_reviews(
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null references avi_knowledge.connected_flight_cases(id) on delete restrict,
 disruption_id uuid not null,
 review_kind text not null check(review_kind in ('operations','safety','regulatory','instructional')),
 verdict text not null check(verdict in ('pending','changes_required','approved')),
 reviewer_identity text,
 review_note text not null,
 reviewed_at timestamptz not null default now(),
 check(verdict<>'approved' or length(trim(coalesce(reviewer_identity,'')))>=3),
 foreign key(case_id,disruption_id) references avi_knowledge.connected_flight_disruptions(case_id,id) on delete restrict
);
create index connected_flight_disruption_reviews_case_disrupt_idx on avi_knowledge.connected_flight_disruption_reviews(case_id,disruption_id);

create function avi_knowledge.gate_connected_flight_phase_review() returns trigger
language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
declare people integer;
begin
 if old.status in ('expert_approved','published') then
   if to_jsonb(new)-'status' is distinct from to_jsonb(old)-'status'
   then raise exception 'Expert-approved flight phase cannot be modified: create a new case version.';end if;
 end if;
 if new.status='expert_approved' and old.status is distinct from new.status then
  select count(distinct reviewer_identity) into people
  from avi_knowledge.connected_flight_phase_reviews
  where case_id=new.case_id and phase_id=new.id and verdict='approved' and review_kind in ('operations','safety');
  if people<2 or (select count(distinct review_kind) from avi_knowledge.connected_flight_phase_reviews
   where case_id=new.case_id and phase_id=new.id and verdict='approved' and review_kind in ('operations','safety'))<>2
  then raise exception 'Flight phase expert approval blocked: distinct operations and safety expert approvals required.';end if;
 end if;
 if old.status='published' and new.status not in ('published') then
 raise exception 'Published flight phase immutable except version retirement in a new case.';end if;
 return new;
end $$;
revoke all on function avi_knowledge.gate_connected_flight_phase_review() from public,anon,authenticated;
create trigger trg_connected_flight_phase_review before update on avi_knowledge.connected_flight_phases
for each row execute function avi_knowledge.gate_connected_flight_phase_review();

create function avi_knowledge.gate_connected_flight_disruption_review() returns trigger
language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
declare people integer;
begin
 if old.status in ('approved','published') then
  if to_jsonb(new)-'status' is distinct from to_jsonb(old)-'status' then
    raise exception 'Approved flight disruption immutable: create a new case version.'; end if;
 end if;
 if new.status='approved' and old.status is distinct from new.status then
 select count(distinct reviewer_identity) into people from avi_knowledge.connected_flight_disruption_reviews
 where case_id=new.case_id and disruption_id=new.id and verdict='approved' and review_kind in ('operations','safety');
 if people<2 or (select count(distinct review_kind) from avi_knowledge.connected_flight_disruption_reviews
 where case_id=new.case_id and disruption_id=new.id and verdict='approved' and review_kind in ('operations','safety'))<>2
 then raise exception 'Flight disruption approval blocked: distinct operations and safety expert approvals required.';end if;
 end if;
 if old.status='published' and new.status<>'published' then raise exception 'Published flight disruption immutable.';end if;
 return new;
end $$;
revoke all on function avi_knowledge.gate_connected_flight_disruption_review() from public,anon,authenticated;
create trigger trg_connected_flight_disruption_review before update on avi_knowledge.connected_flight_disruptions
for each row execute function avi_knowledge.gate_connected_flight_disruption_review();

create or replace function avi_knowledge.gate_connected_flight_publication() returns trigger
language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
declare total_p integer; total_cases integer; approved_review_kinds integer; lesson_ok boolean;
begin
 if old.status in ('approved','published') and to_jsonb(new)-'status'-'updated_at' is distinct from to_jsonb(old)-'status'-'updated_at' then
   raise exception 'Approved connected flight case content is immutable; create a new version.';end if;
 if old.status='published' and new.status<>'published' and new.status<>'retired' then
   raise exception 'Published flight case cannot return to draft or review.';end if;
 if new.status not in ('approved','published') or new.status is not distinct from old.status then return new; end if;
 if new.status='published' and old.status<>'approved' then
 raise exception 'Connected-flight publication requires prior approved status.';end if;

 select count(*) into total_p from avi_knowledge.connected_flight_phases where case_id=new.id;
 select count(*) into total_cases from avi_knowledge.connected_flight_disruptions where case_id=new.id;
 select count(distinct review_kind) into approved_review_kinds from avi_knowledge.connected_flight_case_reviews
 where case_id=new.id and verdict='approved' and review_kind in ('operations','safety','regulatory','instructional');
 select exists(
  select 1 from avi_knowledge.connected_flight_lesson_links l
  join avi_knowledge.lesson_versions lv on lv.id=l.lesson_id
  where l.case_id=new.id and l.placement='capstone' and lv.status='published') into lesson_ok;

 if total_p<10 or total_cases<3 or approved_review_kinds<>4 or not lesson_ok
 or exists(select 1 from avi_knowledge.connected_flight_phases p where p.case_id=new.id
           and (p.status not in ('expert_approved','published')
             or not exists(select 1 from avi_knowledge.connected_flight_phase_roles r where r.phase_id=p.id)
             or not exists(select 1 from avi_knowledge.connected_flight_phase_lesson_blocks l where l.phase_id=p.id and l.coverage_kind='explained')))
 or exists(select 1 from avi_knowledge.connected_flight_disruptions d where d.case_id=new.id
           and (d.status not in ('approved','published')
             or not exists(select 1 from avi_knowledge.connected_flight_disruption_impacts im where im.disruption_id=d.id)
             or not exists(select 1 from avi_knowledge.connected_flight_disruption_lesson_questions q where q.disruption_id=d.id)
             or (select count(*) from avi_knowledge.connected_flight_disruption_choices ch where ch.disruption_id=d.id and ch.is_pedagogically_preferred)<>1))
 then raise exception 'Connected-flight case release blocked: qualified phase, scenario, course and case reviews are mandatory.';end if;
 return new;
end $$;

create function avi_knowledge.guard_approved_connected_flight_children() returns trigger
language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
declare cid uuid; cstatus text;
begin
 if tg_op='DELETE' then cid:=old.case_id;
 else cid:=new.case_id;end if;
 select status into cstatus from avi_knowledge.connected_flight_cases where id=cid;
 if cstatus in ('approved','published','retired') then
  raise exception 'Approved connected-flight case child data are immutable: create a new case version.';
 end if;
 if tg_op='DELETE' then return old; end if;return new;
end $$;
revoke all on function avi_knowledge.guard_approved_connected_flight_children() from public,anon,authenticated;

create trigger immut_connected_flight_role before insert or update or delete on avi_knowledge.connected_flight_phase_roles for each row execute function avi_knowledge.guard_approved_connected_flight_children();
create trigger immut_connected_flight_dependency before insert or update or delete on avi_knowledge.connected_flight_dependencies for each row execute function avi_knowledge.guard_approved_connected_flight_children();
create trigger immut_connected_flight_handoff before insert or update or delete on avi_knowledge.connected_flight_data_handoffs for each row execute function avi_knowledge.guard_approved_connected_flight_children();
create trigger immut_connected_flight_impact before insert or update or delete on avi_knowledge.connected_flight_disruption_impacts for each row execute function avi_knowledge.guard_approved_connected_flight_children();
create trigger immut_connected_flight_choice before insert or update or delete on avi_knowledge.connected_flight_disruption_choices for each row execute function avi_knowledge.guard_approved_connected_flight_children();
create trigger immut_connected_flight_lesson before insert or update or delete on avi_knowledge.connected_flight_lesson_links for each row execute function avi_knowledge.guard_approved_connected_flight_children();
create trigger immut_connected_flight_blocklink before insert or update or delete on avi_knowledge.connected_flight_phase_lesson_blocks for each row execute function avi_knowledge.guard_approved_connected_flight_children();
create trigger immut_connected_flight_questionlink before insert or update or delete on avi_knowledge.connected_flight_disruption_lesson_questions for each row execute function avi_knowledge.guard_approved_connected_flight_children();

alter table avi_knowledge.connected_flight_phase_reviews enable row level security;
alter table avi_knowledge.connected_flight_disruption_reviews enable row level security;
revoke all on avi_knowledge.connected_flight_phase_reviews,avi_knowledge.connected_flight_disruption_reviews from public,anon,authenticated;
grant select on avi_knowledge.connected_flight_phase_reviews,avi_knowledge.connected_flight_disruption_reviews to service_role;
