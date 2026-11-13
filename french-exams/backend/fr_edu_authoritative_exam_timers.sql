
-- French Education timed assessment snapshot and authoritative deadlines.
alter table fr_edu.assessments
 add column if not exists timer_enabled boolean not null default false;
alter table fr_edu.assessments
 add column if not exists timer_duration_seconds integer;
alter table fr_edu.assessments
 add constraint fr_assessments_duration_range
 check(timer_duration_seconds is null or timer_duration_seconds between 60 and 7200);
alter table fr_edu.assessments
 add constraint fr_assessments_timer_configuration
 check(not timer_enabled or timer_duration_seconds is not null);
alter table fr_edu.attempts
 add column if not exists deadline_at timestamptz;
alter table fr_edu.attempts
 add column if not exists time_limit_seconds integer;
alter table fr_edu.attempts
 add column if not exists submission_reason text;
alter table fr_edu.attempts
 add constraint fr_attempts_deadline_snapshot_consistent
 check((deadline_at is null)=(time_limit_seconds is null));
alter table fr_edu.attempts
 add constraint fr_attempts_time_limit_range
 check(time_limit_seconds is null or time_limit_seconds between 60 and 7200);
alter table fr_edu.attempts
 add constraint fr_attempts_submission_reason
 check(submission_reason is null or submission_reason in ('manual','timeout'));

create index if not exists fr_attempts_due_timeouts_idx
 on fr_edu.attempts(deadline_at)
 where state='in_progress' and deadline_at is not null;

-- Demo values, not grade-specific curriculum approvals.
-- The administrator can change or disable either setting through protected API.
update fr_edu.assessments
 set timer_enabled=true, timer_duration_seconds=1200
 where code='fr.general';
update fr_edu.assessments
 set timer_enabled=true, timer_duration_seconds=300
 where code='fr.colors.choose';

-- Score submitted and timed-out attempts identically, including zero for unanswered.
-- SECURITY INVOKER, private schema, never callable by anon or authenticated via Data API.
create or replace function fr_edu.finalize_attempt(p_attempt_id uuid, p_requested_reason text default 'manual')
 returns table(auto_score integer, maximum_score integer, state text, submission_reason text)
 language plpgsql security invoker
 set search_path = ''
 as $function$
 declare
   v fr_edu.attempts%rowtype;
   v_reason text;
   v_score integer;
   v_max integer;
 begin
   select * into v from fr_edu.attempts a
    where a.id=p_attempt_id for update;
   if not found then
     raise exception 'Attempt not found';
   end if;

   if v.state <> 'in_progress' then
     return query select coalesce(v.auto_score,0)::integer,
       coalesce(v.maximum_score,0)::integer,v.state,v.submission_reason;
     return;
   end if;

   if v.deadline_at is not null and clock_timestamp()>=v.deadline_at then
     v_reason:='timeout';
   elsif p_requested_reason='manual' then
     v_reason:='manual';
   elsif p_requested_reason='timeout' then
     raise exception 'Attempt deadline has not been reached';
   else
     raise exception 'Invalid finalization reason';
   end if;

   update fr_edu.responses r
   set score=case
     when r.answer_value is null or btrim(r.answer_value)='' then 0
     when lower(btrim(regexp_replace(replace(r.answer_value,'œ','oe'),'[[:space:]]+',' ','g'))) =
       lower(btrim(regexp_replace(replace(
         case when r.answer_mode='letter'
           then case when l.topic_code='alphabet' then l.canonical_fr
                 else substring(l.canonical_fr from (coalesce(l.missing_index,1)+1) for 1) end
           else l.canonical_fr end,
       'œ','oe'),'[[:space:]]+',' ','g'))) then 1
     else 0 end,
     checked_at=clock_timestamp()
   from fr_edu.lexemes l
   where r.attempt_id=p_attempt_id and r.lexeme_id=l.id;

   select coalesce(sum(r.score),0)::integer, count(*)::integer
    into v_score,v_max
   from fr_edu.responses r where r.attempt_id=p_attempt_id;

   update fr_edu.attempts a set
    state='scored',auto_score=v_score,maximum_score=v_max,
    submitted_at=clock_timestamp(),submission_reason=v_reason
   where a.id=p_attempt_id;

   return query select v_score,v_max,'scored'::text,v_reason;
 end
 $function$;

create or replace function fr_edu.expire_due_attempts(p_limit integer default 100)
 returns integer language plpgsql security invoker
 set search_path = ''
 as $function$
 declare
   v_row record;
   v_count integer:=0;
 begin
   for v_row in
    select a.id from fr_edu.attempts a
    where a.state='in_progress' and a.deadline_at<=clock_timestamp()
    order by a.deadline_at asc
    limit least(greatest(p_limit,1),200)
    for update skip locked
   loop
     perform fr_edu.finalize_attempt(v_row.id,'timeout');
     v_count:=v_count+1;
   end loop;
   return v_count;
 end
 $function$;

revoke all on function fr_edu.finalize_attempt(uuid,text) from public,anon,authenticated;
revoke all on function fr_edu.expire_due_attempts(integer) from public,anon,authenticated;
grant execute on function fr_edu.finalize_attempt(uuid,text) to service_role;
grant execute on function fr_edu.expire_due_attempts(integer) to service_role;
