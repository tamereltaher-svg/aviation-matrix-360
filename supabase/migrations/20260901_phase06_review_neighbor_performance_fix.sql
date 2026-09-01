-- Phase 06 Human Review neighbor performance fix
-- Production fix applied after NEXT/PREVIOUS navigation failed on the heavy queue view.

create or replace function assessment.get_phase06_review_neighbor(
  p_item_version_id uuid,
  p_direction text default 'NEXT',
  p_status text default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path=''
as $function$
declare
  v_dir text;
  v_current record;
  v_target record;
begin
  v_dir := upper(trim(coalesce(p_direction,'NEXT')));

  if v_dir not in ('NEXT','PREVIOUS') then
    raise exception 'Direction must be NEXT or PREVIOUS'
      using errcode='23514';
  end if;

  if p_status is not null
     and p_status not in (
       'NOT_STARTED',
       'IN_REVIEW',
       'ACTION_REQUIRED',
       'REJECTED',
       'COMPLETE_WITH_EDIT',
       'COMPLETE'
     ) then
    raise exception 'Unsupported review status %', p_status
      using errcode='23514';
  end if;

  select
    iv.id as item_version_id,
    i.item_code,
    i.cefr_level,
    i.skill_code,
    i.sequence_number,
    case i.cefr_level
      when 'A1' then 1
      when 'A2' then 2
      when 'B1' then 3
      when 'B2' then 4
      when 'C1' then 5
      when 'C2' then 6
      else 99
    end as cefr_sort_order,
    case i.skill_code
      when 'LNG' then 1
      when 'RDG' then 2
      else 99
    end as skill_sort_order
  into v_current
  from assessment.items i
  join assessment.assessment_banks b
    on b.id=i.bank_id
   and b.bank_code='ENG-GENERAL-P06'
  join assessment.item_versions iv
    on iv.id=i.current_version_id
   and iv.is_current
  where iv.id=p_item_version_id;

  if not found then
    raise exception
      'Unknown Phase06 review item version %',
      p_item_version_id
      using errcode='23503';
  end if;

  with
  active_gates as materialized (
    select g.code
    from assessment.ref_qa_gates g
    where g.is_active
      and g.gate_scope='ITEM'
      and g.qa_phase in ('QA03','QA04','QA05','QA06','QA07')
  ),
  candidate_items as materialized (
    select
      iv.id as item_version_id,
      i.item_code,
      i.cefr_level,
      i.skill_code,
      i.sequence_number,
      case i.cefr_level
        when 'A1' then 1
        when 'A2' then 2
        when 'B1' then 3
        when 'B2' then 4
        when 'C1' then 5
        when 'C2' then 6
        else 99
      end as cefr_sort_order,
      case i.skill_code
        when 'LNG' then 1
        when 'RDG' then 2
        else 99
      end as skill_sort_order
    from assessment.items i
    join assessment.assessment_banks b
      on b.id=i.bank_id
     and b.bank_code='ENG-GENERAL-P06'
    join assessment.item_versions iv
      on iv.id=i.current_version_id
     and iv.is_current
    where
      (
        v_dir='NEXT'
        and (
          case i.cefr_level
            when 'A1' then 1
            when 'A2' then 2
            when 'B1' then 3
            when 'B2' then 4
            when 'C1' then 5
            when 'C2' then 6
            else 99
          end,
          case i.skill_code
            when 'LNG' then 1
            when 'RDG' then 2
            else 99
          end,
          i.sequence_number,
          i.item_code
        ) > (
          v_current.cefr_sort_order,
          v_current.skill_sort_order,
          v_current.sequence_number,
          v_current.item_code
        )
      )
      or
      (
        v_dir='PREVIOUS'
        and (
          case i.cefr_level
            when 'A1' then 1
            when 'A2' then 2
            when 'B1' then 3
            when 'B2' then 4
            when 'C1' then 5
            when 'C2' then 6
            else 99
          end,
          case i.skill_code
            when 'LNG' then 1
            when 'RDG' then 2
            else 99
          end,
          i.sequence_number,
          i.item_code
        ) < (
          v_current.cefr_sort_order,
          v_current.skill_sort_order,
          v_current.sequence_number,
          v_current.item_code
        )
      )
  ),
  latest_gate_review as materialized (
    select distinct on (q.item_version_id,q.qa_gate)
      q.item_version_id,
      q.qa_gate,
      q.decision
    from assessment.qa_reviews q
    join candidate_items ci
      on ci.item_version_id=q.item_version_id
    join active_gates g
      on g.code=q.qa_gate
    order by
      q.item_version_id,
      q.qa_gate,
      q.reviewed_at desc,
      q.id desc
  ),
  gate_rollup as (
    select
      ci.item_version_id,
      count(*)::integer as gate_total,
      count(*) filter (where r.decision in ('PASS','PASS_WITH_EDIT'))::integer as gate_passed,
      count(*) filter (where r.decision='PASS_WITH_EDIT')::integer as pass_with_edit_count,
      count(*) filter (where r.decision='REJECT')::integer as reject_count,
      count(*) filter (where r.decision in ('REMEDIATE','REPLACE'))::integer as remediation_count,
      count(*) filter (where r.decision is not null)::integer as decided_count
    from candidate_items ci
    cross join active_gates g
    left join latest_gate_review r
      on r.item_version_id=ci.item_version_id
     and r.qa_gate=g.code
    group by ci.item_version_id
  ),
  candidate_status as (
    select
      ci.*,
      case
        when gr.reject_count > 0 then 'REJECTED'
        when gr.remediation_count > 0 then 'ACTION_REQUIRED'
        when gr.gate_total = gr.gate_passed then
          case when gr.pass_with_edit_count > 0 then 'COMPLETE_WITH_EDIT' else 'COMPLETE' end
        when gr.decided_count > 0 then 'IN_REVIEW'
        else 'NOT_STARTED'
      end as pre_pilot_review_status
    from candidate_items ci
    join gate_rollup gr
      on gr.item_version_id=ci.item_version_id
  )
  select *
  into v_target
  from candidate_status c
  where p_status is null
     or c.pre_pilot_review_status=p_status
  order by
    case when v_dir='NEXT' then c.cefr_sort_order end asc,
    case when v_dir='NEXT' then c.skill_sort_order end asc,
    case when v_dir='NEXT' then c.sequence_number end asc,
    case when v_dir='NEXT' then c.item_code end asc,
    case when v_dir='PREVIOUS' then c.cefr_sort_order end desc,
    case when v_dir='PREVIOUS' then c.skill_sort_order end desc,
    case when v_dir='PREVIOUS' then c.sequence_number end desc,
    case when v_dir='PREVIOUS' then c.item_code end desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'direction',v_dir,
      'item_version_id',null,
      'item_code',null,
      'boundary_reached',true
    );
  end if;

  return jsonb_build_object(
    'direction',v_dir,
    'item_version_id',v_target.item_version_id,
    'item_code',v_target.item_code,
    'cefr_level',v_target.cefr_level,
    'skill_code',v_target.skill_code,
    'sequence_number',v_target.sequence_number,
    'pre_pilot_review_status',v_target.pre_pilot_review_status,
    'boundary_reached',false
  );
end;
$function$;
