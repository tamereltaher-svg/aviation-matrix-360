CREATE OR REPLACE FUNCTION assessment.get_phase06_review_progress_scoped(
  p_reviewer_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE v_result jsonb;
BEGIN
  IF p_reviewer_id IS NULL OR NOT assessment.is_phase06_reviewer(p_reviewer_id,NULL,NULL) THEN
    RAISE EXCEPTION 'REVIEWER_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;

  WITH authorized_dims AS MATERIALIZED (
    SELECT p.*
    FROM assessment.phase06_review_progress_console p
    WHERE assessment.is_phase06_reviewer(p_reviewer_id,p.cefr_level,p.skill_code)
  ), overall AS (
    SELECT
      coalesce(sum(total_items),0)::integer AS total_items,
      coalesce(sum(not_started),0)::integer AS not_started,
      coalesce(sum(in_review),0)::integer AS in_review,
      coalesce(sum(action_required),0)::integer AS action_required,
      coalesce(sum(rejected),0)::integer AS rejected,
      coalesce(sum(review_complete),0)::integer AS review_complete,
      coalesce(sum(primary_lo_human_confirmed),0)::integer AS lo_human_confirmed,
      coalesce(sum(approved_versions),0)::integer AS approved_versions
    FROM authorized_dims
  ), dims AS (
    SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY
      CASE p.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END,
      p.skill_code),'[]'::jsonb) AS rows
    FROM authorized_dims p
  )
  SELECT jsonb_build_object('overall',to_jsonb(o),'by_level_skill',d.rows)
  INTO v_result
  FROM overall o CROSS JOIN dims d;
  RETURN v_result;
END;
$$;

REVOKE ALL PRIVILEGES ON FUNCTION assessment.get_phase06_review_progress_scoped(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION assessment.get_phase06_review_progress_scoped(uuid) TO service_role;
