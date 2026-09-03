CREATE OR REPLACE FUNCTION assessment.get_phase06_review_neighbor_scoped(
  p_reviewer_id uuid,
  p_item_version_id uuid,
  p_direction text DEFAULT 'NEXT',
  p_status text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_dir text := upper(trim(coalesce(p_direction,'NEXT')));
  v_current record;
  v_target record;
BEGIN
  IF v_dir NOT IN ('NEXT','PREVIOUS') THEN
    RAISE EXCEPTION 'Direction must be NEXT or PREVIOUS' USING ERRCODE='23514';
  END IF;
  IF p_status IS NOT NULL AND p_status NOT IN ('NOT_STARTED','IN_REVIEW','ACTION_REQUIRED','REJECTED','COMPLETE_WITH_EDIT','COMPLETE') THEN
    RAISE EXCEPTION 'Unsupported review status %', p_status USING ERRCODE='23514';
  END IF;

  SELECT
    iv.id AS item_version_id,
    i.item_code,
    i.cefr_level,
    i.skill_code,
    i.sequence_number,
    CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END AS cefr_sort_order,
    CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END AS skill_sort_order
  INTO v_current
  FROM assessment.items i
  JOIN assessment.assessment_banks b ON b.id=i.bank_id AND b.bank_code='ENG-GENERAL-P06'
  JOIN assessment.item_versions iv ON iv.id=i.current_version_id AND iv.is_current
  WHERE iv.id=p_item_version_id
    AND assessment.is_phase06_reviewer(p_reviewer_id,i.cefr_level,i.skill_code);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REVIEW_SCOPE_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;

  SELECT
    iv.id AS item_version_id,
    i.item_code,
    i.cefr_level,
    i.skill_code,
    i.sequence_number,
    s.pre_pilot_review_status,
    CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END AS cefr_sort_order,
    CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END AS skill_sort_order
  INTO v_target
  FROM assessment.items i
  JOIN assessment.assessment_banks b ON b.id=i.bank_id AND b.bank_code='ENG-GENERAL-P06'
  JOIN assessment.item_versions iv ON iv.id=i.current_version_id AND iv.is_current
  JOIN assessment.item_pre_pilot_review_status s ON s.item_version_id=iv.id
  WHERE assessment.is_phase06_reviewer(p_reviewer_id,i.cefr_level,i.skill_code)
    AND (p_status IS NULL OR s.pre_pilot_review_status=p_status)
    AND (
      (v_dir='NEXT' AND (
        CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END,
        CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END,
        i.sequence_number,i.item_code
      ) > (v_current.cefr_sort_order,v_current.skill_sort_order,v_current.sequence_number,v_current.item_code))
      OR
      (v_dir='PREVIOUS' AND (
        CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END,
        CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END,
        i.sequence_number,i.item_code
      ) < (v_current.cefr_sort_order,v_current.skill_sort_order,v_current.sequence_number,v_current.item_code))
    )
  ORDER BY
    CASE WHEN v_dir='NEXT' THEN CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END END ASC,
    CASE WHEN v_dir='NEXT' THEN CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END END ASC,
    CASE WHEN v_dir='NEXT' THEN i.sequence_number END ASC,
    CASE WHEN v_dir='NEXT' THEN i.item_code END ASC,
    CASE WHEN v_dir='PREVIOUS' THEN CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN i.sequence_number END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN i.item_code END DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('direction',v_dir,'item_version_id',NULL,'item_code',NULL,'boundary_reached',true);
  END IF;

  RETURN jsonb_build_object(
    'direction',v_dir,
    'item_version_id',v_target.item_version_id,
    'item_code',v_target.item_code,
    'cefr_level',v_target.cefr_level,
    'skill_code',v_target.skill_code,
    'sequence_number',v_target.sequence_number,
    'pre_pilot_review_status',v_target.pre_pilot_review_status,
    'boundary_reached',false
  );
END;
$$;

REVOKE ALL PRIVILEGES ON FUNCTION assessment.get_phase06_review_neighbor_scoped(uuid,uuid,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION assessment.get_phase06_review_neighbor_scoped(uuid,uuid,text,text) TO service_role;
