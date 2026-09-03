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
