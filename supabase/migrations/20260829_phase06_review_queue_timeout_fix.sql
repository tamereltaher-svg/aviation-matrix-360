-- Phase 06 Human Review queue performance fix
-- Production fix applied 2026-08-29 after SQLSTATE 57014 statement timeout.
-- Replaces the heavy view-backed queue RPC with early filtering and direct table aggregation.

create or replace function assessment.get_phase06_review_queue(
  p_cefr_level text default null,
  p_skill_code text default null,
  p_status text default null,
  p_release_code text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
set search_path to ''
as $function$
declare
  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  v_limit := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  if p_cefr_level is not null
     and p_cefr_level not in ('A1','A2','B1','B2','C1','C2') then
    raise exception 'Unsupported CEFR level %', p_cefr_level
      using errcode = '23514';
  end if;

  if p_skill_code is not null
     and p_skill_code not in ('LNG','RDG') then
    raise exception 'Unsupported skill_code %', p_skill_code
      using errcode = '23514';
  end if;

  with
  active_gates as materialized (
    select
      g.code,
      g.name,
      g.sort_order,
      case
        when g.code = 'QA09_PSYCHOMETRIC' then 'POST_PILOT_PSYCHOMETRIC'
        when g.code in ('QA03_OBJECTIVE','QA04_KEY','QA07_SECURITY') then 'SYSTEM_AND_REVIEWER'
        else 'HUMAN_REVIEW'
      end as review_channel
    from assessment.ref_qa_gates g
    where g.is_active
      and g.gate_scope = 'ITEM'
      and g.qa_phase in ('QA03','QA04','QA05','QA06','QA07')
  ),
  base_items as materialized (
    select
      i.id as item_id,
      i.item_code,
      i.skill_code,
      i.cefr_level,
      i.sequence_number,
      i.lifecycle_status,
      iv.id as item_version_id,
      iv.review_status,
      iv.approval_status,
      m.mapping_status as primary_lo_mapping_status,
      rel.release_code
    from assessment.items i
    join assessment.assessment_banks b
      on b.id = i.bank_id
     and b.bank_code = 'ENG-GENERAL-P06'
    join assessment.releases rel
      on rel.id = i.release_id
     and rel.bank_id = b.id
    join assessment.item_versions iv
      on iv.id = i.current_version_id
     and iv.is_current
    left join assessment.item_lo_mappings m
      on m.item_version_id = iv.id
     and m.mapping_role = 'PRIMARY'
    where (p_cefr_level is null or i.cefr_level = p_cefr_level)
      and (p_skill_code is null or i.skill_code = p_skill_code)
      and (p_release_code is null or rel.release_code = p_release_code)
  ),
  latest_gate_review as materialized (
    select distinct on (q.item_version_id, q.qa_gate)
      q.item_version_id,
      q.qa_gate,
      q.decision,
      q.reviewer_id,
      q.review_notes,
      q.reviewed_at
    from assessment.qa_reviews q
    join base_items bi on bi.item_version_id = q.item_version_id
    join active_gates g on g.code = q.qa_gate
    order by q.item_version_id, q.qa_gate, q.reviewed_at desc, q.id desc
  ),
  gate_state as materialized (
    select
      bi.item_version_id,
      g.code as qa_gate,
      g.name as qa_gate_name,
      g.sort_order,
      g.review_channel,
      r.decision,
      r.reviewer_id,
      r.review_notes,
      r.reviewed_at
    from base_items bi
    cross join active_gates g
    left join latest_gate_review r
      on r.item_version_id = bi.item_version_id
     and r.qa_gate = g.code
  ),
  gate_rollup as (
    select
      gs.item_version_id,
      count(*)::integer as pre_pilot_gate_total,
      count(*) filter (where gs.decision in ('PASS','PASS_WITH_EDIT'))::integer as pre_pilot_gate_passed,
      count(*) filter (where gs.decision is null)::integer as pre_pilot_gate_pending,
      count(*) filter (where gs.decision in ('REMEDIATE','REPLACE','REJECT'))::integer as pre_pilot_gate_action_required,
      count(*) filter (where gs.decision = 'PASS_WITH_EDIT')::integer as pass_with_edit_count,
      count(*) filter (where gs.decision = 'REJECT')::integer as reject_count,
      count(*) filter (where gs.decision in ('REMEDIATE','REPLACE'))::integer as remediation_count,
      count(*) filter (where gs.decision is not null)::integer as decided_count
    from gate_state gs
    group by gs.item_version_id
  ),
  next_gate as (
    select distinct on (gs.item_version_id)
      gs.item_version_id,
      gs.qa_gate as next_qa_gate,
      gs.qa_gate_name as next_qa_gate_name,
      gs.review_channel as next_review_channel
    from gate_state gs
    where gs.decision is null
       or gs.decision in ('PENDING','REMEDIATE','REPLACE','REJECT')
    order by
      gs.item_version_id,
      case when gs.decision in ('REMEDIATE','REPLACE','REJECT') then 0 else 1 end,
      gs.sort_order,
      gs.qa_gate
  ),
  defect_rollup as (
    select
      d.item_version_id,
      count(*) filter (where d.status in ('OPEN','IN_REMEDIATION') and d.severity = 'BLOCKER')::integer as open_blocker_count,
      count(*) filter (where d.status in ('OPEN','IN_REMEDIATION') and d.severity = 'MAJOR')::integer as open_major_count
    from assessment.qa_defects d
    join base_items bi on bi.item_version_id = d.item_version_id
    group by d.item_version_id
  ),
  latest_action as (
    select distinct on (a.item_version_id)
      a.item_version_id,
      a.action_code,
      a.qa_gate,
      a.reviewer_id,
      a.created_at
    from assessment.item_review_actions a
    join base_items bi on bi.item_version_id = a.item_version_id
    order by a.item_version_id, a.created_at desc, a.id desc
  ),
  queue_status as materialized (
    select
      bi.item_version_id,
      bi.item_code,
      bi.release_code,
      bi.cefr_level,
      bi.skill_code,
      bi.sequence_number,
      bi.lifecycle_status,
      bi.review_status,
      bi.approval_status,
      bi.primary_lo_mapping_status,
      case
        when gr.reject_count > 0 then 'REJECTED'
        when gr.remediation_count > 0 then 'ACTION_REQUIRED'
        when gr.pre_pilot_gate_total = gr.pre_pilot_gate_passed then
          case when gr.pass_with_edit_count > 0 then 'COMPLETE_WITH_EDIT' else 'COMPLETE' end
        when gr.decided_count > 0 then 'IN_REVIEW'
        else 'NOT_STARTED'
      end as pre_pilot_review_status,
      gr.pre_pilot_gate_total,
      gr.pre_pilot_gate_passed,
      gr.pre_pilot_gate_pending,
      gr.pre_pilot_gate_action_required,
      case
        when gr.pre_pilot_gate_total = 0 then 0::numeric
        else round(100.0 * gr.pre_pilot_gate_passed::numeric / gr.pre_pilot_gate_total::numeric, 2)
      end as review_completion_pct,
      ng.next_qa_gate,
      ng.next_qa_gate_name,
      ng.next_review_channel,
      coalesce(dr.open_blocker_count, 0) as open_blocker_count,
      coalesce(dr.open_major_count, 0) as open_major_count,
      la.action_code as latest_review_action,
      la.qa_gate as latest_review_gate,
      la.reviewer_id as latest_reviewer_id,
      la.created_at as latest_reviewed_at,
      case bi.cefr_level
        when 'A1' then 1 when 'A2' then 2 when 'B1' then 3 when 'B2' then 4 when 'C1' then 5 when 'C2' then 6 else 99
      end as cefr_sort_order,
      case bi.skill_code when 'LNG' then 1 when 'RDG' then 2 else 99 end as skill_sort_order
    from base_items bi
    join gate_rollup gr on gr.item_version_id = bi.item_version_id
    left join next_gate ng on ng.item_version_id = bi.item_version_id
    left join defect_rollup dr on dr.item_version_id = bi.item_version_id
    left join latest_action la on la.item_version_id = bi.item_version_id
  ),
  queue_filtered as materialized (
    select
      q.*,
      case q.pre_pilot_review_status
        when 'ACTION_REQUIRED' then 1
        when 'IN_REVIEW' then 2
        when 'NOT_STARTED' then 3
        when 'REJECTED' then 4
        when 'COMPLETE_WITH_EDIT' then 5
        when 'COMPLETE' then 6
        else 99
      end as queue_priority
    from queue_status q
    where p_status is null or q.pre_pilot_review_status = p_status
  ),
  page_rows as (
    select
      q.item_version_id,
      q.item_code,
      q.release_code,
      q.cefr_level,
      q.skill_code,
      q.sequence_number,
      q.lifecycle_status,
      q.review_status,
      q.approval_status,
      q.primary_lo_mapping_status,
      q.pre_pilot_review_status,
      q.review_completion_pct,
      q.pre_pilot_gate_total,
      q.pre_pilot_gate_passed,
      q.pre_pilot_gate_pending,
      q.pre_pilot_gate_action_required,
      q.next_qa_gate,
      q.next_qa_gate_name,
      q.next_review_channel,
      q.open_blocker_count,
      q.open_major_count,
      q.latest_review_action,
      q.latest_review_gate,
      q.latest_reviewer_id,
      q.latest_reviewed_at,
      q.queue_priority,
      q.cefr_sort_order,
      q.skill_sort_order
    from queue_filtered q
    order by q.queue_priority, q.cefr_sort_order, q.skill_sort_order, q.sequence_number, q.item_code
    limit v_limit
    offset v_offset
  ),
  totals as (
    select count(*)::bigint as total from queue_filtered
  )
  select jsonb_build_object(
    'total', coalesce((select total from totals), 0),
    'limit', v_limit,
    'offset', v_offset,
    'rows', coalesce((
      select jsonb_agg(
        to_jsonb(p)
        order by p.queue_priority, p.cefr_sort_order, p.skill_sort_order, p.sequence_number, p.item_code
      )
      from page_rows p
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$function$;
