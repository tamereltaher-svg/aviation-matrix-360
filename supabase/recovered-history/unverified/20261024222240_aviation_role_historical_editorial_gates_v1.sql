
create table avi_knowledge.role_milestone_reviews (
 id uuid primary key default gen_random_uuid(),
 milestone_id uuid not null references avi_knowledge.role_milestones(id) on delete restrict,
 review_type text not null check(review_type in ('historian','operational_expert','regulatory','editorial')),
 verdict text not null check(verdict in ('pending','changes_required','approved')),
 reviewer_identity text,
 notes text not null,
 reviewed_at timestamptz not null default now(),
 check(verdict <> 'approved' or length(trim(coalesce(reviewer_identity,'')))>=3)
);
create index avi_role_milestone_reviews_event_idx on avi_knowledge.role_milestone_reviews(milestone_id);
alter table avi_knowledge.role_milestone_reviews enable row level security;
revoke all on avi_knowledge.role_milestone_reviews from public,anon,authenticated;
grant select on avi_knowledge.role_milestone_reviews to service_role;

create function avi_knowledge.gate_role_milestone_review()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
begin
 if new.review_status='expert_approved' and old.review_status <> 'expert_approved' then
   if not exists(select 1 from avi_knowledge.role_milestone_sources s where s.milestone_id=new.id and s.support_kind='direct')
    or not exists(select 1 from avi_knowledge.role_milestone_reviews r where r.milestone_id=new.id and r.review_type='historian' and r.verdict='approved')
   then raise exception 'Historical milestone cannot be expert-approved without direct evidence and signed historian review.'; end if;
 end if;
 return new;
end $$;
revoke all on function avi_knowledge.gate_role_milestone_review() from public,anon,authenticated;
create trigger trg_gate_role_milestone_review before update of review_status on avi_knowledge.role_milestones
for each row execute function avi_knowledge.gate_role_milestone_review();

create function avi_knowledge.gate_role_storyline_stop()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
begin
 if new.status='published' and old.status <> 'published' then
   if not exists(select 1 from avi_knowledge.role_milestones m where m.id=new.milestone_id and m.review_status='expert_approved'
       and exists(select 1 from avi_knowledge.role_milestone_sources s where s.milestone_id=m.id and s.support_kind='direct'))
    then raise exception 'Role storyline stop cannot publish before the historical milestone is expert-approved with a direct source.'; end if;
 end if;
 return new;
end $$;
revoke all on function avi_knowledge.gate_role_storyline_stop() from public,anon,authenticated;
create trigger trg_gate_role_storyline_stop before update of status on avi_knowledge.role_storyline_stops
for each row execute function avi_knowledge.gate_role_storyline_stop();

create function avi_knowledge.guard_published_role_integrity()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
begin
 if old.status in ('expert_approved','published','retired') then
   if to_jsonb(old)-'status'-'updated_at' is distinct from to_jsonb(new)-'status'-'updated_at' then
      raise exception 'Approved role metadata is immutable: create revised draft record and review before change.'; end if;
   if (old.status='published' and new.status not in ('published','retired'))
       or (old.status='retired' and new.status<>'retired')
       or (old.status='expert_approved' and new.status not in ('expert_approved','published','retired'))
   then raise exception 'Approved role cannot return to draft.'; end if;
 end if;
 return new;
end $$;
revoke all on function avi_knowledge.guard_published_role_integrity() from public,anon,authenticated;
create trigger trg_guard_published_role_integrity before update on avi_knowledge.role_profiles
for each row execute function avi_knowledge.guard_published_role_integrity();

create view avi_knowledge.role_historical_timeline with (security_invoker=true) as
select m.event_key,m.event_en,m.event_ar,m.year_from,m.year_to,m.exact_date,m.date_precision,
 m.geographic_scope,m.evidence_scope,m.never_global_first,m.review_status,
 count(distinct mr.role_id)::int related_roles,
 count(distinct ms.source_id) filter(where ms.support_kind='direct')::int supporting_sources
from avi_knowledge.role_milestones m
left join avi_knowledge.role_milestone_roles mr on mr.milestone_id=m.id
left join avi_knowledge.role_milestone_sources ms on ms.milestone_id=m.id
group by m.id;
revoke all on avi_knowledge.role_historical_timeline from public,anon,authenticated;
grant select on avi_knowledge.role_historical_timeline to service_role;
