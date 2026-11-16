
-- V1.2 editorial immutability and journey release gates.
create function avi_knowledge.lock_reviewed_lesson_content()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge
as $$
declare data_new jsonb; data_old jsonb; lesson_a uuid; lesson_b uuid; state_a text; state_b text; item_id uuid;
begin
  if tg_op='DELETE' then data_new:=null; data_old:=to_jsonb(old);
  elsif tg_op='INSERT' then data_new:=to_jsonb(new); data_old:=null;
  else data_new:=to_jsonb(new);data_old:=to_jsonb(old); end if;
  if tg_table_name in ('lesson_blocks','lesson_questions') then
     lesson_a:=(data_new->>'lesson_id')::uuid;
     lesson_b:=(data_old->>'lesson_id')::uuid;
  elsif tg_table_name in ('lesson_block_claims','lesson_block_relationships') then
     if data_new is not null then
       select b.lesson_id into lesson_a from avi_knowledge.lesson_blocks b where b.id=(data_new->>'block_id')::uuid;
     end if;
     if data_old is not null then
       select b.lesson_id into lesson_b from avi_knowledge.lesson_blocks b where b.id=(data_old->>'block_id')::uuid;
     end if;
  elsif tg_table_name in ('lesson_question_options','lesson_question_claims') then
     if data_new is not null then
       select q.lesson_id into lesson_a from avi_knowledge.lesson_questions q where q.id=(data_new->>'question_id')::uuid;
     end if;
     if data_old is not null then
       select q.lesson_id into lesson_b from avi_knowledge.lesson_questions q where q.id=(data_old->>'question_id')::uuid;
     end if;
  end if;
  if lesson_a is not null then select status into state_a from avi_knowledge.lesson_versions where id=lesson_a; end if;
  if lesson_b is not null then select status into state_b from avi_knowledge.lesson_versions where id=lesson_b; end if;
  if coalesce(state_a,'draft') in ('expert_approved','published','retired')
     or coalesce(state_b,'draft') in ('expert_approved','published','retired') then
     raise exception 'Approved lesson is immutable. Create the next lesson version instead.';
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end
$$;
revoke all on function avi_knowledge.lock_reviewed_lesson_content() from public,anon,authenticated;
create trigger trg_lock_lesson_blocks before insert or update or delete on avi_knowledge.lesson_blocks for each row execute function avi_knowledge.lock_reviewed_lesson_content();
create trigger trg_lock_lesson_questions before insert or update or delete on avi_knowledge.lesson_questions for each row execute function avi_knowledge.lock_reviewed_lesson_content();
create trigger trg_lock_lesson_block_claims before insert or update or delete on avi_knowledge.lesson_block_claims for each row execute function avi_knowledge.lock_reviewed_lesson_content();
create trigger trg_lock_lesson_block_relationships before insert or update or delete on avi_knowledge.lesson_block_relationships for each row execute function avi_knowledge.lock_reviewed_lesson_content();
create trigger trg_lock_lesson_question_options before insert or update or delete on avi_knowledge.lesson_question_options for each row execute function avi_knowledge.lock_reviewed_lesson_content();
create trigger trg_lock_lesson_question_claims before insert or update or delete on avi_knowledge.lesson_question_claims for each row execute function avi_knowledge.lock_reviewed_lesson_content();

create function avi_knowledge.guard_approved_lesson_version()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge
as $$
begin
  if old.status in ('expert_approved','published','retired') then
    if to_jsonb(old)-'status'-'published_at' is distinct from to_jsonb(new)-'status'-'published_at'
       then raise exception 'Approved lesson metadata cannot change. Create a new version.'; end if;
    if not ((old.status='expert_approved' and new.status in ('expert_approved','published','retired'))
       or (old.status='published' and new.status in ('published','retired'))
       or (old.status='retired' and new.status='retired')) then
       raise exception 'Approved or published lesson cannot be reset to a draft.'; end if;
    if old.status='retired' and new.published_at is distinct from old.published_at then
      raise exception 'Retired lesson timestamp cannot change.'; end if;
  end if;
  return new;
end
$$;
revoke all on function avi_knowledge.guard_approved_lesson_version() from public,anon,authenticated;
create trigger trg_guard_approved_lesson_version before update on avi_knowledge.lesson_versions
for each row execute function avi_knowledge.guard_approved_lesson_version();

create function avi_knowledge.gate_step_publication()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge
as $$
begin
  if new.status='published' and old.status is distinct from new.status and not exists
   (select 1 from avi_knowledge.lesson_versions l where l.journey_step_id=new.id and l.status='published')
  then raise exception 'Journey step cannot publish without a published, approved lesson.'; end if;
  return new;
end $$;
revoke all on function avi_knowledge.gate_step_publication() from public,anon,authenticated;
create trigger trg_gate_step_publication before update of status on avi_knowledge.journey_steps
for each row execute function avi_knowledge.gate_step_publication();

create function avi_knowledge.gate_journey_publication()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge
as $$
begin
  if new.status='published' and old.status is distinct from new.status then
    if not exists(select 1 from avi_knowledge.journey_steps s where s.journey_id=new.id)
       or exists(select 1 from avi_knowledge.journey_steps s where s.journey_id=new.id and s.status<>'published')
       then raise exception 'Journey cannot publish until all steps are published.'; end if;
  end if;
  return new;
end $$;
revoke all on function avi_knowledge.gate_journey_publication() from public,anon,authenticated;
create trigger trg_gate_journey_publication before update of status on avi_knowledge.journeys
for each row execute function avi_knowledge.gate_journey_publication();
