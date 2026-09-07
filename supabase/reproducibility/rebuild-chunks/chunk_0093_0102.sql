-- BEGIN CANONICAL MIGRATION 0093 20260903120956 p0_security_search_path_hardening
ALTER FUNCTION public.normalize_public_mobile(text) SET search_path = pg_catalog, extensions, public;
ALTER FUNCTION public.set_store_updated_at() SET search_path = pg_catalog, public;
ALTER FUNCTION public.kids_touch_updated_at() SET search_path = pg_catalog, public;
ALTER FUNCTION public.kids_get_brand_logo_bundle(text) SET search_path = pg_catalog, public;
ALTER FUNCTION public.am_lifetime_integrity_hash(uuid,uuid,text,jsonb,timestamp with time zone) SET search_path = pg_catalog, extensions, public;
ALTER FUNCTION public.am_block_lifetime_history_mutation() SET search_path = pg_catalog, public;
ALTER FUNCTION public.am_block_registration_event_mutation() SET search_path = pg_catalog, public;
-- END CANONICAL MIGRATION 0093

-- BEGIN CANONICAL MIGRATION 0094 20260903121051 p0_revoke_dormant_grants_on_rls_deny_all_tables
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relkind='r'
      AND c.relrowsecurity
      AND NOT EXISTS (
        SELECT 1 FROM pg_policies p
        WHERE p.schemaname='public' AND p.tablename=c.relname
      )
      AND (
        has_table_privilege('anon',c.oid,'select') OR has_table_privilege('anon',c.oid,'insert') OR has_table_privilege('anon',c.oid,'update') OR has_table_privilege('anon',c.oid,'delete') OR
        has_table_privilege('authenticated',c.oid,'select') OR has_table_privilege('authenticated',c.oid,'insert') OR has_table_privilege('authenticated',c.oid,'update') OR has_table_privilege('authenticated',c.oid,'delete')
      )
  LOOP
    EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM anon, authenticated', r.relname);
  END LOOP;
END $$;
-- END CANONICAL MIGRATION 0094

-- BEGIN CANONICAL MIGRATION 0095 20260903124407 p0_lock_legacy_assessment_rpcs_to_service_role
revoke execute on function public.start_public_career_assessment(uuid, text) from public, anon, authenticated;
revoke execute on function public.submit_public_assessment_answer(uuid, uuid, uuid, integer) from public, anon, authenticated;
revoke execute on function public.finish_public_career_assessment(uuid, text) from public, anon, authenticated;

grant execute on function public.start_public_career_assessment(uuid, text) to service_role;
grant execute on function public.submit_public_assessment_answer(uuid, uuid, uuid, integer) to service_role;
grant execute on function public.finish_public_career_assessment(uuid, text) to service_role;
-- END CANONICAL MIGRATION 0095

-- BEGIN CANONICAL MIGRATION 0096 20260903124751 temporary_enable_http_for_phase06_edge_runtime_verify
create extension if not exists http with schema extensions;
-- END CANONICAL MIGRATION 0096

-- BEGIN CANONICAL MIGRATION 0097 20260903125114 p0_phase06_scoped_queue_performance_fix
create or replace function assessment.get_phase06_review_queue_scoped(
  p_reviewer_id uuid,
  p_cefr_level text default null,
  p_skill_code text default null,
  p_status text default null,
  p_release_code text default null,
  p_limit integer default 50,
  p_offset integer default 0
) returns jsonb
language plpgsql
stable
set search_path to ''
as $$
declare
  v_limit integer;
  v_offset integer;
  v_result jsonb;
  v_cefr_scope text[];
  v_can_review_lng boolean;
  v_can_review_rdg boolean;
begin
  v_limit := least(greatest(coalesce(p_limit,50),1),200);
  v_offset := greatest(coalesce(p_offset,0),0);

  select r.cefr_scope,r.can_review_lng,r.can_review_rdg
    into v_cefr_scope,v_can_review_lng,v_can_review_rdg
  from assessment.phase06_reviewers r
  where r.auth_user_id=p_reviewer_id and r.reviewer_status='ACTIVE';

  if not found then
    raise exception 'REVIEWER_NOT_AUTHORIZED' using errcode='42501';
  end if;

  if p_cefr_level is not null and p_cefr_level not in ('A1','A2','B1','B2','C1','C2') then
    raise exception 'Unsupported CEFR level %',p_cefr_level using errcode='23514';
  end if;
  if p_skill_code is not null and p_skill_code not in ('LNG','RDG') then
    raise exception 'Unsupported skill_code %',p_skill_code using errcode='23514';
  end if;
  if p_cefr_level is not null and not (p_cefr_level = any(coalesce(v_cefr_scope,array[]::text[]))) then
    raise exception 'REVIEW_SCOPE_NOT_AUTHORIZED' using errcode='42501';
  end if;
  if p_skill_code='LNG' and not coalesce(v_can_review_lng,false) then
    raise exception 'REVIEW_SCOPE_NOT_AUTHORIZED' using errcode='42501';
  end if;
  if p_skill_code='RDG' and not coalesce(v_can_review_rdg,false) then
    raise exception 'REVIEW_SCOPE_NOT_AUTHORIZED' using errcode='42501';
  end if;

  with
  active_gates as materialized (
    select g.code,g.name,g.sort_order,
      case when g.code='QA09_PSYCHOMETRIC' then 'POST_PILOT_PSYCHOMETRIC'
           when g.code in ('QA03_OBJECTIVE','QA04_KEY','QA07_SECURITY') then 'SYSTEM_AND_REVIEWER'
           else 'HUMAN_REVIEW' end as review_channel
    from assessment.ref_qa_gates g
    where g.is_active and g.gate_scope='ITEM' and g.qa_phase in ('QA03','QA04','QA05','QA06','QA07')
  ),
  base_items as materialized (
    select i.id as item_id,i.item_code,i.skill_code,i.cefr_level,i.sequence_number,i.lifecycle_status,
           iv.id as item_version_id,iv.review_status,iv.approval_status,
           m.mapping_status as primary_lo_mapping_status,rel.release_code
    from assessment.items i
    join assessment.assessment_banks b on b.id=i.bank_id and b.bank_code='ENG-GENERAL-P06'
    join assessment.releases rel on rel.id=i.release_id and rel.bank_id=b.id
    join assessment.item_versions iv on iv.id=i.current_version_id and iv.is_current
    left join assessment.item_lo_mappings m on m.item_version_id=iv.id and m.mapping_role='PRIMARY'
    where i.cefr_level = any(coalesce(v_cefr_scope,array[]::text[]))
      and ((i.skill_code='LNG' and coalesce(v_can_review_lng,false)) or (i.skill_code='RDG' and coalesce(v_can_review_rdg,false)))
      and (p_cefr_level is null or i.cefr_level=p_cefr_level)
      and (p_skill_code is null or i.skill_code=p_skill_code)
      and (p_release_code is null or rel.release_code=p_release_code)
  ),
  latest_gate_review as materialized (
    select distinct on (q.item_version_id,q.qa_gate)
      q.item_version_id,q.qa_gate,q.decision,q.reviewer_id,q.review_notes,q.reviewed_at
    from assessment.qa_reviews q
    join base_items bi on bi.item_version_id=q.item_version_id
    join active_gates g on g.code=q.qa_gate
    order by q.item_version_id,q.qa_gate,q.reviewed_at desc,q.id desc
  ),
  gate_state as materialized (
    select bi.item_version_id,g.code as qa_gate,g.name as qa_gate_name,g.sort_order,g.review_channel,
           r.decision,r.reviewer_id,r.review_notes,r.reviewed_at
    from base_items bi
    cross join active_gates g
    left join latest_gate_review r on r.item_version_id=bi.item_version_id and r.qa_gate=g.code
  ),
  gate_rollup as (
    select gs.item_version_id,
      count(*)::integer as pre_pilot_gate_total,
      count(*) filter (where gs.decision in ('PASS','PASS_WITH_EDIT'))::integer as pre_pilot_gate_passed,
      count(*) filter (where gs.decision is null)::integer as pre_pilot_gate_pending,
      count(*) filter (where gs.decision in ('REMEDIATE','REPLACE','REJECT'))::integer as pre_pilot_gate_action_required,
      count(*) filter (where gs.decision='PASS_WITH_EDIT')::integer as pass_with_edit_count,
      count(*) filter (where gs.decision='REJECT')::integer as reject_count,
      count(*) filter (where gs.decision in ('REMEDIATE','REPLACE'))::integer as remediation_count,
      count(*) filter (where gs.decision is not null)::integer as decided_count
    from gate_state gs group by gs.item_version_id
  ),
  next_gate as (
    select distinct on (gs.item_version_id)
      gs.item_version_id,gs.qa_gate as next_qa_gate,gs.qa_gate_name as next_qa_gate_name,gs.review_channel as next_review_channel
    from gate_state gs
    where gs.decision is null or gs.decision in ('PENDING','REMEDIATE','REPLACE','REJECT')
    order by gs.item_version_id,
      case when gs.decision in ('REMEDIATE','REPLACE','REJECT') then 0 else 1 end,
      gs.sort_order,gs.qa_gate
  ),
  defect_rollup as (
    select d.item_version_id,
      count(*) filter (where d.status in ('OPEN','IN_REMEDIATION') and d.severity='BLOCKER')::integer as open_blocker_count,
      count(*) filter (where d.status in ('OPEN','IN_REMEDIATION') and d.severity='MAJOR')::integer as open_major_count
    from assessment.qa_defects d
    join base_items bi on bi.item_version_id=d.item_version_id
    group by d.item_version_id
  ),
  latest_action as (
    select distinct on (a.item_version_id)
      a.item_version_id,a.action_code,a.qa_gate,a.reviewer_id,a.created_at
    from assessment.item_review_actions a
    join base_items bi on bi.item_version_id=a.item_version_id
    order by a.item_version_id,a.created_at desc,a.id desc
  ),
  queue_status as materialized (
    select bi.item_version_id,bi.item_code,bi.release_code,bi.cefr_level,bi.skill_code,bi.sequence_number,
      bi.lifecycle_status,bi.review_status,bi.approval_status,bi.primary_lo_mapping_status,
      case when gr.reject_count>0 then 'REJECTED'
           when gr.remediation_count>0 then 'ACTION_REQUIRED'
           when gr.pre_pilot_gate_total=gr.pre_pilot_gate_passed then case when gr.pass_with_edit_count>0 then 'COMPLETE_WITH_EDIT' else 'COMPLETE' end
           when gr.decided_count>0 then 'IN_REVIEW'
           else 'NOT_STARTED' end as pre_pilot_review_status,
      gr.pre_pilot_gate_total,gr.pre_pilot_gate_passed,gr.pre_pilot_gate_pending,gr.pre_pilot_gate_action_required,
      case when gr.pre_pilot_gate_total=0 then 0::numeric else round(100.0*gr.pre_pilot_gate_passed::numeric/gr.pre_pilot_gate_total::numeric,2) end as review_completion_pct,
      ng.next_qa_gate,ng.next_qa_gate_name,ng.next_review_channel,
      coalesce(dr.open_blocker_count,0) as open_blocker_count,
      coalesce(dr.open_major_count,0) as open_major_count,
      la.action_code as latest_review_action,la.qa_gate as latest_review_gate,la.reviewer_id as latest_reviewer_id,la.created_at as latest_reviewed_at,
      case bi.cefr_level when 'A1' then 1 when 'A2' then 2 when 'B1' then 3 when 'B2' then 4 when 'C1' then 5 when 'C2' then 6 else 99 end as cefr_sort_order,
      case bi.skill_code when 'LNG' then 1 when 'RDG' then 2 else 99 end as skill_sort_order
    from base_items bi
    join gate_rollup gr on gr.item_version_id=bi.item_version_id
    left join next_gate ng on ng.item_version_id=bi.item_version_id
    left join defect_rollup dr on dr.item_version_id=bi.item_version_id
    left join latest_action la on la.item_version_id=bi.item_version_id
  ),
  queue_filtered as materialized (
    select q.*,
      case q.pre_pilot_review_status when 'ACTION_REQUIRED' then 1 when 'IN_REVIEW' then 2 when 'NOT_STARTED' then 3 when 'REJECTED' then 4 when 'COMPLETE_WITH_EDIT' then 5 when 'COMPLETE' then 6 else 99 end as queue_priority
    from queue_status q
    where p_status is null or q.pre_pilot_review_status=p_status
  ),
  page_rows as (
    select q.* from queue_filtered q
    order by q.queue_priority,q.cefr_sort_order,q.skill_sort_order,q.sequence_number,q.item_code
    limit v_limit offset v_offset
  ),
  totals as (select count(*)::bigint as total from queue_filtered)
  select jsonb_build_object(
    'total',coalesce((select total from totals),0),
    'limit',v_limit,
    'offset',v_offset,
    'rows',coalesce((select jsonb_agg(to_jsonb(p) order by p.queue_priority,p.cefr_sort_order,p.skill_sort_order,p.sequence_number,p.item_code) from page_rows p),'[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all privileges on function assessment.get_phase06_review_queue_scoped(uuid,text,text,text,text,integer,integer) from public,anon,authenticated;
grant execute on function assessment.get_phase06_review_queue_scoped(uuid,text,text,text,text,integer,integer) to service_role;
-- END CANONICAL MIGRATION 0097

-- BEGIN CANONICAL MIGRATION 0098 20260903125414 p0_phase06_fast_item_scope_neighbor_submit
create or replace function assessment.phase06_item_status_fast(p_item_version_id uuid)
returns text
language sql
stable
set search_path to ''
as $$
with active_gates as (
  select g.code
  from assessment.ref_qa_gates g
  where g.is_active
    and g.gate_scope='ITEM'
    and g.qa_phase in ('QA03','QA04','QA05','QA06','QA07')
), latest as (
  select distinct on (q.qa_gate) q.qa_gate,q.decision
  from assessment.qa_reviews q
  join active_gates g on g.code=q.qa_gate
  where q.item_version_id=p_item_version_id
  order by q.qa_gate,q.reviewed_at desc,q.id desc
), rollup as (
  select
    count(*)::integer as gate_total,
    count(*) filter (where l.decision in ('PASS','PASS_WITH_EDIT'))::integer as passed,
    count(*) filter (where l.decision='PASS_WITH_EDIT')::integer as pass_with_edit,
    count(*) filter (where l.decision='REJECT')::integer as rejected,
    count(*) filter (where l.decision in ('REMEDIATE','REPLACE'))::integer as remediation,
    count(*) filter (where l.decision is not null)::integer as decided
  from active_gates g
  left join latest l on l.qa_gate=g.code
)
select case
  when rejected>0 then 'REJECTED'
  when remediation>0 then 'ACTION_REQUIRED'
  when gate_total=passed then case when pass_with_edit>0 then 'COMPLETE_WITH_EDIT' else 'COMPLETE' end
  when decided>0 then 'IN_REVIEW'
  else 'NOT_STARTED'
end
from rollup;
$$;

create or replace function assessment.is_phase06_reviewer_for_item(
  p_auth_user_id uuid,
  p_item_version_id uuid
) returns boolean
language sql
stable
set search_path to ''
as $$
  select exists (
    select 1
    from assessment.items i
    join assessment.assessment_banks b on b.id=i.bank_id and b.bank_code='ENG-GENERAL-P06'
    join assessment.item_versions iv on iv.id=i.current_version_id and iv.is_current
    where iv.id=p_item_version_id
      and assessment.is_phase06_reviewer(p_auth_user_id,i.cefr_level,i.skill_code)
  );
$$;

create or replace function assessment.get_phase06_review_neighbor_scoped(
  p_reviewer_id uuid,
  p_item_version_id uuid,
  p_direction text default 'NEXT',
  p_status text default null
) returns jsonb
language plpgsql
stable
set search_path to ''
as $$
declare
  v_dir text := upper(trim(coalesce(p_direction,'NEXT')));
  v_current record;
  v_candidate record;
  v_status text;
  v_cefr_scope text[];
  v_can_review_lng boolean;
  v_can_review_rdg boolean;
begin
  if v_dir not in ('NEXT','PREVIOUS') then
    raise exception 'Direction must be NEXT or PREVIOUS' using errcode='23514';
  end if;
  if p_status is not null and p_status not in ('NOT_STARTED','IN_REVIEW','ACTION_REQUIRED','REJECTED','COMPLETE_WITH_EDIT','COMPLETE') then
    raise exception 'Unsupported review status %',p_status using errcode='23514';
  end if;

  select r.cefr_scope,r.can_review_lng,r.can_review_rdg
  into v_cefr_scope,v_can_review_lng,v_can_review_rdg
  from assessment.phase06_reviewers r
  where r.auth_user_id=p_reviewer_id and r.reviewer_status='ACTIVE';
  if not found then
    raise exception 'REVIEWER_NOT_AUTHORIZED' using errcode='42501';
  end if;

  select iv.id as item_version_id,i.item_code,i.cefr_level,i.skill_code,i.sequence_number,
    case i.cefr_level when 'A1' then 1 when 'A2' then 2 when 'B1' then 3 when 'B2' then 4 when 'C1' then 5 when 'C2' then 6 else 99 end as cefr_sort_order,
    case i.skill_code when 'LNG' then 1 when 'RDG' then 2 else 99 end as skill_sort_order
  into v_current
  from assessment.items i
  join assessment.assessment_banks b on b.id=i.bank_id and b.bank_code='ENG-GENERAL-P06'
  join assessment.item_versions iv on iv.id=i.current_version_id and iv.is_current
  where iv.id=p_item_version_id
    and i.cefr_level=any(coalesce(v_cefr_scope,array[]::text[]))
    and ((i.skill_code='LNG' and coalesce(v_can_review_lng,false)) or (i.skill_code='RDG' and coalesce(v_can_review_rdg,false)));
  if not found then
    raise exception 'REVIEW_SCOPE_NOT_AUTHORIZED' using errcode='42501';
  end if;

  if v_dir='NEXT' then
    for v_candidate in
      select iv.id as item_version_id,i.item_code,i.cefr_level,i.skill_code,i.sequence_number,
        case i.cefr_level when 'A1' then 1 when 'A2' then 2 when 'B1' then 3 when 'B2' then 4 when 'C1' then 5 when 'C2' then 6 else 99 end as cefr_sort_order,
        case i.skill_code when 'LNG' then 1 when 'RDG' then 2 else 99 end as skill_sort_order
      from assessment.items i
      join assessment.assessment_banks b on b.id=i.bank_id and b.bank_code='ENG-GENERAL-P06'
      join assessment.item_versions iv on iv.id=i.current_version_id and iv.is_current
      where i.cefr_level=any(coalesce(v_cefr_scope,array[]::text[]))
        and ((i.skill_code='LNG' and coalesce(v_can_review_lng,false)) or (i.skill_code='RDG' and coalesce(v_can_review_rdg,false)))
        and (
          case i.cefr_level when 'A1' then 1 when 'A2' then 2 when 'B1' then 3 when 'B2' then 4 when 'C1' then 5 when 'C2' then 6 else 99 end,
          case i.skill_code when 'LNG' then 1 when 'RDG' then 2 else 99 end,
          i.sequence_number,i.item_code
        ) > (v_current.cefr_sort_order,v_current.skill_sort_order,v_current.sequence_number,v_current.item_code)
      order by
        case i.cefr_level when 'A1' then 1 when 'A2' then 2 when 'B1' then 3 when 'B2' then 4 when 'C1' then 5 when 'C2' then 6 else 99 end,
        case i.skill_code when 'LNG' then 1 when 'RDG' then 2 else 99 end,
        i.sequence_number,i.item_code
    loop
      v_status := assessment.phase06_item_status_fast(v_candidate.item_version_id);
      if p_status is null or v_status=p_status then
        return jsonb_build_object(
          'direction',v_dir,'item_version_id',v_candidate.item_version_id,'item_code',v_candidate.item_code,
          'cefr_level',v_candidate.cefr_level,'skill_code',v_candidate.skill_code,'sequence_number',v_candidate.sequence_number,
          'pre_pilot_review_status',v_status,'boundary_reached',false
        );
      end if;
    end loop;
  else
    for v_candidate in
      select iv.id as item_version_id,i.item_code,i.cefr_level,i.skill_code,i.sequence_number,
        case i.cefr_level when 'A1' then 1 when 'A2' then 2 when 'B1' then 3 when 'B2' then 4 when 'C1' then 5 when 'C2' then 6 else 99 end as cefr_sort_order,
        case i.skill_code when 'LNG' then 1 when 'RDG' then 2 else 99 end as skill_sort_order
      from assessment.items i
      join assessment.assessment_banks b on b.id=i.bank_id and b.bank_code='ENG-GENERAL-P06'
      join assessment.item_versions iv on iv.id=i.current_version_id and iv.is_current
      where i.cefr_level=any(coalesce(v_cefr_scope,array[]::text[]))
        and ((i.skill_code='LNG' and coalesce(v_can_review_lng,false)) or (i.skill_code='RDG' and coalesce(v_can_review_rdg,false)))
        and (
          case i.cefr_level when 'A1' then 1 when 'A2' then 2 when 'B1' then 3 when 'B2' then 4 when 'C1' then 5 when 'C2' then 6 else 99 end,
          case i.skill_code when 'LNG' then 1 when 'RDG' then 2 else 99 end,
          i.sequence_number,i.item_code
        ) < (v_current.cefr_sort_order,v_current.skill_sort_order,v_current.sequence_number,v_current.item_code)
      order by
        case i.cefr_level when 'A1' then 1 when 'A2' then 2 when 'B1' then 3 when 'B2' then 4 when 'C1' then 5 when 'C2' then 6 else 99 end desc,
        case i.skill_code when 'LNG' then 1 when 'RDG' then 2 else 99 end desc,
        i.sequence_number desc,i.item_code desc
    loop
      v_status := assessment.phase06_item_status_fast(v_candidate.item_version_id);
      if p_status is null or v_status=p_status then
        return jsonb_build_object(
          'direction',v_dir,'item_version_id',v_candidate.item_version_id,'item_code',v_candidate.item_code,
          'cefr_level',v_candidate.cefr_level,'skill_code',v_candidate.skill_code,'sequence_number',v_candidate.sequence_number,
          'pre_pilot_review_status',v_status,'boundary_reached',false
        );
      end if;
    end loop;
  end if;

  return jsonb_build_object('direction',v_dir,'item_version_id',null,'item_code',null,'boundary_reached',true);
end;
$$;

create or replace function assessment.submit_phase06_review_action(
  p_item_version_id uuid,
  p_action_code text,
  p_reviewer_id uuid,
  p_qa_gate text,
  p_notes text default null
) returns jsonb
language plpgsql
set search_path to ''
as $$
declare
  v_action_id uuid;
  v_item jsonb;
  v_cefr_level text;
  v_skill_code text;
begin
  if p_reviewer_id is null then
    raise exception 'Reviewer identity is required' using errcode='23514';
  end if;

  select i.cefr_level,i.skill_code
  into v_cefr_level,v_skill_code
  from assessment.items i
  join assessment.assessment_banks b on b.id=i.bank_id and b.bank_code='ENG-GENERAL-P06'
  join assessment.item_versions iv on iv.id=i.current_version_id and iv.is_current
  where iv.id=p_item_version_id;

  if not found then
    raise exception 'Item version % is not in ENG-GENERAL-P06 reviewer workspace',p_item_version_id using errcode='23503';
  end if;
  if not assessment.is_phase06_reviewer(p_reviewer_id,v_cefr_level,v_skill_code) then
    raise exception 'REVIEW_SCOPE_NOT_AUTHORIZED' using errcode='42501';
  end if;

  v_action_id := assessment.record_item_review_action(p_item_version_id,p_action_code,p_reviewer_id,p_notes,p_qa_gate);
  select assessment.get_phase06_review_item(p_item_version_id) into v_item;
  return jsonb_build_object('action_id',v_action_id,'item',v_item);
end;
$$;

revoke all privileges on function assessment.phase06_item_status_fast(uuid) from public,anon,authenticated;
revoke all privileges on function assessment.is_phase06_reviewer_for_item(uuid,uuid) from public,anon,authenticated;
revoke all privileges on function assessment.get_phase06_review_neighbor_scoped(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function assessment.phase06_item_status_fast(uuid),assessment.is_phase06_reviewer_for_item(uuid,uuid),assessment.get_phase06_review_neighbor_scoped(uuid,uuid,text,text),assessment.submit_phase06_review_action(uuid,text,uuid,text,text) to service_role;
-- END CANONICAL MIGRATION 0098

-- BEGIN CANONICAL MIGRATION 0099 20260903125649 p1_hide_public_question_option_scoring_metadata
revoke select on table public.question_options from anon, authenticated;
grant select (id, question_id, option_code, option_text, sequence_no) on table public.question_options to anon, authenticated;

-- Preserve full server-side access explicitly.
grant select on table public.question_options to service_role;
-- END CANONICAL MIGRATION 0099

-- BEGIN CANONICAL MIGRATION 0100 20260903125807 disable_temporary_http_after_phase06_edge_runtime_verify
drop extension if exists http;
-- END CANONICAL MIGRATION 0100

-- BEGIN CANONICAL MIGRATION 0101 20260903125957 p1_secure_quotation_customer_action_tokens
create table if not exists public.am_quotation_action_tokens (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.am_requests(id) on delete cascade,
  quotation_id uuid not null references public.am_quotations(id) on delete cascade,
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  used_at timestamptz,
  used_action text check (used_action is null or used_action in ('accept_quotation','reject_quotation')),
  revoked_at timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  check (used_at is not null or used_action is null)
);

create index if not exists am_quotation_action_tokens_lookup_idx
  on public.am_quotation_action_tokens(token_hash, request_id, quotation_id);
create index if not exists am_quotation_action_tokens_active_idx
  on public.am_quotation_action_tokens(quotation_id, expires_at)
  where used_at is null and revoked_at is null;

alter table public.am_quotation_action_tokens enable row level security;
revoke all on table public.am_quotation_action_tokens from public, anon, authenticated;
grant select, insert, update, delete on table public.am_quotation_action_tokens to service_role;

create or replace function public.am_apply_customer_quotation_action(
  p_token_hash text,
  p_request_id uuid,
  p_quotation_id uuid,
  p_action text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  t public.am_quotation_action_tokens%rowtype;
  q public.am_quotations%rowtype;
  r public.am_requests%rowtype;
  v_now timestamptz := now();
  v_to_status text;
  v_event_type text;
  v_title text;
  v_detail text;
begin
  if p_action not in ('accept_quotation','reject_quotation') then
    return jsonb_build_object('ok', false, 'error', 'INVALID_ACTION');
  end if;

  select * into t
  from public.am_quotation_action_tokens
  where token_hash = lower(p_token_hash)
    and request_id = p_request_id
    and quotation_id = p_quotation_id
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'INVALID_ACTION_TOKEN');
  end if;
  if t.revoked_at is not null then
    return jsonb_build_object('ok', false, 'error', 'ACTION_TOKEN_REVOKED');
  end if;
  if t.used_at is not null then
    return jsonb_build_object('ok', false, 'error', 'ACTION_TOKEN_USED');
  end if;
  if t.expires_at <= v_now then
    return jsonb_build_object('ok', false, 'error', 'ACTION_TOKEN_EXPIRED');
  end if;

  select * into q
  from public.am_quotations
  where id = p_quotation_id and request_id = p_request_id
  for update;

  if not found or q.status <> 'sent' then
    return jsonb_build_object('ok', false, 'error', 'QUOTATION_NOT_AVAILABLE');
  end if;
  if q.valid_until is not null and q.valid_until < current_date then
    return jsonb_build_object('ok', false, 'error', 'QUOTATION_EXPIRED');
  end if;

  select * into r from public.am_requests where id = p_request_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'REQUEST_NOT_FOUND');
  end if;

  update public.am_quotation_action_tokens
     set used_at = v_now, used_action = p_action
   where id = t.id;

  if p_action = 'accept_quotation' then
    update public.am_quotations
       set status='accepted', accepted_at=v_now, rejected_at=null, updated_at=v_now
     where id=q.id;
    update public.am_requests set status='approved', updated_at=v_now where id=r.id;
    v_to_status := 'approved';
    v_event_type := 'quotation_accepted';
    v_title := 'Quotation accepted';
    v_detail := format('Quotation %s was accepted by the customer.', q.quotation_number);

    insert into public.am_customer_notifications(
      request_id, quotation_id, channel, recipient, template_code, subject, payload, status, sent_at
    ) values (
      r.id, q.id, 'portal', coalesce(r.email,r.mobile), 'quotation_accepted', 'Quotation accepted',
      jsonb_build_object('quotation_number',q.quotation_number), 'sent', v_now
    );
  else
    update public.am_quotations
       set status='rejected', rejected_at=v_now, accepted_at=null, updated_at=v_now
     where id=q.id;
    update public.am_requests set status='reviewing', updated_at=v_now where id=r.id;
    v_to_status := 'reviewing';
    v_event_type := 'quotation_rejected';
    v_title := 'Quotation needs revision';
    v_detail := format('Quotation %s was not accepted. Aviation Matrix will review the request.', q.quotation_number);
  end if;

  insert into public.am_request_events(
    request_id,event_type,from_status,to_status,title,detail,visibility,actor_type
  ) values (
    r.id,v_event_type,r.status,v_to_status,v_title,v_detail,'customer','customer'
  );

  return jsonb_build_object(
    'ok', true,
    'action', p_action,
    'request_id', r.id,
    'quotation_id', q.id,
    'request_status', v_to_status,
    'quotation_status', case when p_action='accept_quotation' then 'accepted' else 'rejected' end
  );
end;
$$;

revoke all on function public.am_apply_customer_quotation_action(text,uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.am_apply_customer_quotation_action(text,uuid,uuid,text) to service_role;
-- END CANONICAL MIGRATION 0101

-- BEGIN CANONICAL MIGRATION 0102 20260903130036 p1_issue_quotation_action_token_on_send
create or replace function public.am_issue_quotation_action_token_on_send()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  r public.am_requests%rowtype;
  v_token text;
  v_hash text;
  v_expires_at timestamptz;
begin
  if new.status = 'sent' and old.status is distinct from 'sent' then
    select * into r from public.am_requests where id = new.request_id;
    if not found then
      raise exception 'REQUEST_NOT_FOUND';
    end if;

    update public.am_quotation_action_tokens
       set revoked_at = now()
     where quotation_id = new.id
       and used_at is null
       and revoked_at is null;

    v_token := encode(extensions.gen_random_bytes(32), 'hex');
    v_hash := encode(extensions.digest(v_token, 'sha256'), 'hex');
    v_expires_at := least(
      now() + interval '7 days',
      coalesce((new.valid_until + 1)::timestamptz, now() + interval '7 days')
    );

    if v_expires_at <= now() then
      v_expires_at := now() + interval '1 hour';
    end if;

    insert into public.am_quotation_action_tokens(
      request_id, quotation_id, token_hash, expires_at, created_by
    ) values (
      new.request_id, new.id, v_hash, v_expires_at, new.created_by
    );

    insert into public.am_customer_notifications(
      request_id, quotation_id, channel, recipient, template_code, subject, payload, status
    ) values (
      new.request_id,
      new.id,
      case when r.email is not null then 'email' else 'portal' end,
      coalesce(r.email,r.mobile),
      'quotation_action_authorization',
      'Secure quotation response link',
      jsonb_build_object(
        'quotation_number', new.quotation_number,
        'action_token', v_token,
        'action_token_expires_at', v_expires_at
      ),
      case when r.email is not null then 'pending' else 'sent' end
    );
  end if;
  return new;
end;
$$;

revoke all on function public.am_issue_quotation_action_token_on_send() from public, anon, authenticated;
grant execute on function public.am_issue_quotation_action_token_on_send() to service_role;

drop trigger if exists trg_am_issue_quotation_action_token_on_send on public.am_quotations;
create trigger trg_am_issue_quotation_action_token_on_send
after update of status on public.am_quotations
for each row execute function public.am_issue_quotation_action_token_on_send();
-- END CANONICAL MIGRATION 0102

